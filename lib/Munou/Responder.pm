package Munou::Responder;

use strict;
use warnings;
use utf8;
use Carp     qw/croak/;
use Exporter qw/import/;
use DDP;
use Unicode::UTF8 ();
use Config::Tiny;
use Log::Handler;
use Text::MeCab;
use JSON::XS       qw/decode_json/;
use List::AllUtils qw/uniq any/;
use TokyoCabinet;
use lib "$FindBin::Bin/lib";
use Munou::Tool qw/InEmoticonDere InEmoticonIkari InEmoticonWarai InEmoticonNamida is_contains_R18word/;
use Munou::Twitter::NormalizeText qw/unify_warai  unify_url  strip_hashtag  strip_kao  aaaa2aaa
ore2watashi  unify_kakko  unify_3dots  unify_kutouten  strip_pictograph  etc/;
use Lingua::JA::NormalizeText qw/strip_html  decode_entities/;
use Net::Twitter::Lite::WithAPIv1_1;

our @EXPORT    = qw//;
our @EXPORT_OK = qw/respond  db_close  db_reopen/;

my $config = Config::Tiny->read('config.conf', 'encoding(utf-8)') // croak '設定の読み込みに失敗しました';
my $NAME = $config->{munou}{name}                                 // croak '人工無脳の名前を設定してください';

our $EMOTION = '';

# & が &amp; になっているので decode_entities は２回適用必要がある
my $normalizer = Lingua::JA::NormalizeText->new([
    'remove_controls',       'remove_DFC',              \&unify_url,
    'decode_entities',       'decode_entities',         \&strip_hashtag,
    \&unify_warai,           \&strip_pictograph,        \&ore2watashi,
    'wavetilde2long',        'fullminus2long',          'dashes2long',
    'drawing_lines2long',    \&unify_kakko,             'unify_whitespaces',
    'nl2space',              'tab2space',               \&unify_3dots,
    \&unify_kutouten,        \&strip_kao,               'space_z2h',
    'trim',                  'unify_long_spaces',       'alnum_z2h',  'lc',
    'katakana_h2z',          'square2katakana',         'circled2kanji',
    'circled2kana',          'all_dakuon_normalize',    'decompose_parenthesized_kanji',
    \&aaaa2aaa,              \&etc,
]);

my $log = Log::Handler->new(
    file   => $config->{log_file},
    screen => $config->{log_screen},
);

my $mecab = Text::MeCab->new;

my $bdb = TokyoCabinet::BDB->new;
$bdb->open($config->{_}{db_path}, $bdb->OREADER | $bdb->ONOLCK) or die $bdb->errmsg($bdb->ecode);

sub db_reopen
{
    db_close();
    # リオープンして更新を反映させる
    $bdb->open($config->{_}{db_path}, $bdb->OREADER | $bdb->ONOLCK) or die $bdb->errmsg($bdb->ecode);
}

sub fetch_face_name_using_emoticon
{
    my ($last_emoticon, $text) = @_;

    my $emotion;

    if ($last_emoticon =~ /\p{InEmoticonWarai}/)
    {
        $emotion = 'warai';
    }
    elsif ($last_emoticon =~ /\p{InEmoticonIkari}/)
    {
        $emotion = 'ikari';
    }
    elsif ($last_emoticon =~ /\p{InEmoticonDere}/)
    {
        $emotion = 'dere';
    }
    elsif ($last_emoticon =~ /\p{InEmoticonNamida}/)
    {
        $emotion = 'namida';
    }
    else
    {
        $emotion = 'normal';
    }

    if ( is_contains_R18word($text) )
    {
        $emotion = 'dere';
    }

    $EMOTION = $emotion;

    return $emotion;
}

sub db_close
{
    $bdb->close;
}

sub respond
{
    my ($text, $user_name) = @_;

    $text = $normalizer->normalize($text);

    my $like_ratio = 0.7;

    my ($reply, $emotion); # この emotion は使っていない

    my $replies = $bdb->getlist($text) // [];

    if (scalar @{ $replies })
    {
        ($reply, $emotion) = fetch_better_reply($replies, $like_ratio);
    }
    else
    {
        my @replies = partial_matching($text);

        if ( ! scalar @replies ) # 部分マッチしなかったら返答がないようの返答
        {
            my @replies = split(/\|/, $config->{munou}{no_reply_msg});
            $reply   = $replies[int rand @replies];
            $emotion = 'neutral';
        }
        else
        {
            ($reply, $emotion) = fetch_better_reply(\@replies, $like_ratio);
        }
    }

    $reply =~ s/kysname/$user_name/g;
    $reply =~ s/(?:お前|オマエ|てめぇ|てめえ|テメー|おまえ|オメエ|おめえ)/$user_name/g;
    $reply =~ s/kyrname/$NAME/go;
    $reply =~ s/俺/$NAME/go;
    $reply =~ s/(?:ぼく|おれ|オレ|ボク)(?:も|は|に)/$NAME/go;
    $reply =~ s/(?:^|[^\p{Han}])僕/$NAME/go;

    my $last_emoticon = ($reply =~ /[\p{InEmoticonWarai}\p{InEmoticonIkari}\p{InEmoticonDere}\p{InEmoticonNamida}]/g)[-1] // '';

    my $munou_emotion = fetch_face_name_using_emoticon($last_emoticon, $reply);

    return $reply, $munou_emotion;
}

sub fetch_better_reply
{
    my ($replies, $like_ratio) = @_;

    my ($reply, $emotion);

    my @replies = map { decode_json($_) } @{ $replies };

    if (scalar @replies > 1)
    {
        my $level_min = 999;

        for my $reply (@replies)
        {
            if ($level_min > $reply->{kezuri})
            {
                $level_min = $reply->{kezuri};
            }
        }

        @replies = grep { $_->{kezuri} == $level_min } @replies; # レベルでふるいにかける

        # 人工無脳の気分に応じてゲタを履かせる
        my $emotion_geta = 0;
        $emotion_geta =  0.2 if $EMOTION eq 'warai' || $EMOTION eq 'dere';
        $emotion_geta = -0.2 if $EMOTION eq 'ikari' || $EMOTION eq 'namida';

        if ( int(rand 2) == 1 && ( ($like_ratio + $emotion_geta) <= 0.3 || ($like_ratio + $emotion_geta) >= 0.7 ) )
        {
            if ( ($like_ratio + $emotion_geta) <= 0.3 )
            {
                my @dislike_replies = grep { $_->{emotion} eq 'dislike' } @replies; # 嫌感情のセリフを抽出

                if (scalar @dislike_replies)
                {
                    @replies = @dislike_replies;
                }
            }
            elsif ( ($like_ratio + $emotion_geta) >= 0.7 )
            {
                my @like_replies = grep { $_->{emotion} eq 'like' } @replies; # 好感情のセリフを抽出

                if (scalar @like_replies)
                {
                    @replies = @like_replies;
                }
            }
        }

        @replies = sort { $b->{favo_plus_rt} <=> $a->{favo_plus_rt} } @replies; # favo と RT の合計数でソート

        my $fetch_max = 10; # ふるいにかけたあとは１０個の中から乱択

        $fetch_max = scalar @replies if scalar @replies < $fetch_max;

        my $reply_info = $replies[int(rand $fetch_max)];
        $reply   = $reply_info->{text};
        $emotion = $reply_info->{emotion};
    }
    else
    {
        my $reply_info = decode_json($replies->[0]);
        $reply   = $reply_info->{text};
        $emotion = $reply_info->{emotion};
    }

    return ($reply, $emotion);
}

sub partial_matching
{
    my $text = shift;

    my @words = strip_needless_morpheme($text);

    # 形態素がなければ飛ばす
    return unless scalar @words;

    my ($words_str, $gimon_flag);

    for my $word (@words)
    {
        $words_str .= $word;
    }

    if ($words_str =~ /^(だれ|誰|どこ|何処|何|なんで|何で|なぜ|何故|どれ|どんくら|どうして|どうやって|どの|いかに)[^か]+/
     || $words[0] eq 'いつ' || $words[0] eq 'なに')
    {
        $gimon_flag = 1;
    }

    my @replies;

    for (my $i = 1; @words; ++$i)
    {
        $log->debug("@words");

        my $ret = $bdb->getlist("@words") // [];
        push(@replies, @{ $ret }) if scalar @{ $ret };

        last if scalar @replies;

        # 疑問文の場合は文頭が応答文生成に大きく関わる
        if ($gimon_flag) { pop @words;   }
        else             { shift @words; }
    }

    return @replies;
}

sub strip_needless_morpheme
{
    my $str = shift;

    my @words;

    for (my $node = $mecab->parse($str); $node->surface; $node = $node->next)
    {
        my $surface = Unicode::UTF8::decode_utf8($node->surface);
        my $feature = Unicode::UTF8::decode_utf8($node->feature);

        my ($hinshi1, $hinshi2, undef, undef, undef, undef, $kihon) = split(/,/, $feature);

        if ($hinshi1 eq '名詞')
        {
            if ($hinshi2 eq '非自立')
            {
                if ($surface eq 'の' || $surface eq 'か' || $surface eq 'こと')
                {
                    push(@words, $surface);
                }
            }
            else
            {
                push(@words, $surface);
            }
        }
        elsif ($hinshi1 eq '助詞')
        {
            if ($hinshi2 eq '終助詞')
            {
                if ($surface eq 'よ' || $surface eq 'ね' || $surface eq 'な' || $surface eq 'だって' || $surface eq 'かしら' || $surface eq 'やら')
                {
                    push(@words, $surface);
                }
            }
            elsif ($hinshi2 eq '副助詞／並立助詞／終助詞' && $surface eq 'か')
            {
                push(@words, $surface);
            }
            elsif ($hinshi2 eq '接続助詞')
            {
                if ($surface eq 'ながら' || $surface eq 'どころか' || $surface eq 'つつ' || $surface eq 'て')
                {
                    push(@words, $surface);
                }
            }
            elsif ($hinshi2 eq '格助詞' && $surface eq 'から')
            {
                push(@words, $surface);
            }
            elsif ($hinshi2 eq '副助詞')
            {
                if ( ($surface eq 'だけ' || $surface eq 'まで' || $surface eq '迄')
                        || ( @words && ($words[-1] eq 'どれ' || $words[-1] eq 'どん') && $surface eq 'くらい' ) )
                {
                    push(@words, $surface);
                }
            }
        }
        elsif ($hinshi1 eq '副詞')
        {
            if ($surface eq 'そう' || $surface eq 'なんで'   || $surface eq '何で' || $surface eq 'なぜ'
                    || $surface eq '何故' || $surface eq 'どうして' || $surface eq 'どう' || $surface eq 'いかに')
            {
                push(@words, $surface);
            }
        }
        elsif ($hinshi1 eq '動詞'   || $hinshi1 eq '形容詞'   || $hinshi1 eq '助動詞'
                || $hinshi1 eq '感動詞' || $hinshi1 eq 'フィラー' || $hinshi1 eq '接続詞')
        {
            push(@words, $surface);
        }
        elsif (!@words && $hinshi1 eq '連体詞' && $surface eq 'どの')
        {
            push(@words, $surface);
        }
        elsif ($surface && $surface eq '?')
        {
            push(@words, $surface);
        }
    }

    return @words;
}

1;
