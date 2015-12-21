#!/usr/bin/env perl

use strict;
use warnings;
use feature qw/say/;
use utf8;
use open qw/:utf8 :std/;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Munou::Tool                   qw/InEmoticonLike InEmoticonDislike/;
use Munou::Twitter::NormalizeText qw/unify_warai  unify_url  strip_hashtag  strip_kao  aaaa2aaa
ore2watashi  unify_kakko  unify_3dots  unify_kutouten  strip_pictograph  etc/;
use DDP;
use Unicode::UTF8 ();
use Config::Tiny;
use Log::Handler;
use TokyoCabinet;
use JSON::XS qw/encode_json decode_json/;
use List::AllUtils qw/any uniq/;
use AnyEvent::Twitter::Stream;
use Net::Twitter::Lite::WithAPIv1_1;
use Text::MeCab;
use Lingua::JA::KanjiTable;
use Lingua::JA::NormalizeText qw/trim/;
use Lingua::JA::Halfwidth::Katakana;

# 基本設定
my $config          = Config::Tiny->read('config.conf', 'encoding(utf-8)') // die '設定の読み込みに失敗しました';
my $bdb_dialog_path = $config->{_}{db_path}                                // die '設定の読み込みに失敗しました';
my $bdb_dialog      = TokyoCabinet::BDB->new; # 対話DB更新用

my @NG_TWITTER_ID          = qw/nandemo_magic/;
my $LOCK_FILE              = 'lock';
my $TARGET_TWITTER_LEN_MAX = 60;

my $log = Log::Handler->new(
    file   => $config->{log_file_learning},
    screen => $config->{log_screen_learning},
);

my $twitter_config = $config->{'twitter_api'};

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

my $mecab = Text::MeCab->new;

# シグナル受信時の処理
$SIG{$_} = "exit_after_close_db" for qw/INT TERM HUP QUIT KILL/;
sub nop { say "Avoid breaking DB! Please retry!"; }

if ( ! -f $LOCK_FILE )
{
    open(my $fh, '>', $LOCK_FILE) or die $!;
    close($fh);
}

my @dup_checker = qw/1/;

while (1)
{
    my $done = AE::cv; # イベントループ制御変数

    my $connected = 0;

    my $stream = AnyEvent::Twitter::Stream->new(

        consumer_key    => $twitter_config->{consumer_key},
        consumer_secret => $twitter_config->{consumer_secret},
        token           => $twitter_config->{access_token},
        token_secret    => $twitter_config->{access_token_secret},
        method          => 'sample',
        timeout         => 15,
        on_keepalive    => sub { $log->info('生存');           $connected = 1; },
        on_error        => sub { $log->error("エラー $_[0]");  $done->send;    }, # エラーでイベントループを抜ける
        on_tweet        => sub {

            $connected = 1;

            my $tweet = shift;

            goto NEXT_TWEET unless $tweet->{id};
            goto NEXT_TWEET if any { $tweet->{id} eq $_ } @dup_checker;

            my $text = $tweet->{text};
            my $lang = $tweet->{user}->{lang} // '';

            if ( $lang eq 'ja' && is_japanese($text) ) # この条件以外のツイートは処理しない
            {
                unshift(@dup_checker, $tweet->{id});
                pop @dup_checker while scalar @dup_checker > 10;

                if ( $text =~ /^@[a-zA-Z0-9_]+/ && length $text <= $TARGET_TWITTER_LEN_MAX && $tweet->{in_reply_to_status_id} ) # 返信の場合
                {
                    my $twit = Net::Twitter::Lite::WithAPIv1_1->new
                    (
                        consumer_key        => $twitter_config->{consumer_key},
                        consumer_secret     => $twitter_config->{consumer_secret},
                        access_token        => $twitter_config->{access_token},
                        access_token_secret => $twitter_config->{access_token_secret},
                        ssl                 => 1.
                    );

                    my $api_status         = $twit->rate_limit_status;
                    my $api_screen_name    = $twitter_config->{screen_name};
                    my $remaining_api_call = $api_status->{resources}{application}{"/application/rate_limit_status"}{remaining};

                    $log->debug("残りのAPIコール：$remaining_api_call");

                    if ($remaining_api_call >= 3)
                    {
                        my $reply_id = $tweet->{id};

                        # 返信された発言
                        my $search      = $twit->show_status($tweet->{in_reply_to_status_id});
                        my $orig_lang   = $search->{user}->{lang} // '';
                        my $tweet_id    = $search->{id};
                        my $tweet_text  = $search->{text};

                        if ( $orig_lang eq 'ja' && length $tweet_text <= $TARGET_TWITTER_LEN_MAX && is_japanese($tweet_text) )
                        {
                            open(my $fh, '+<', $LOCK_FILE) or tranabort("flock", "");
                            flock($fh, 2);

                            $SIG{$_} = "nop" for qw/INT TERM HUP QUIT KILL/; # avoid breaking DB

                            $bdb_dialog->open($bdb_dialog_path, $bdb_dialog->OWRITER | $bdb_dialog->OCREAT | $bdb_dialog->ONOLCK) or tranabort("open dialog", "");
                            regist($search, $tweet);
                            $bdb_dialog->close or tranabort("close dialog", $bdb_dialog->errmsg($bdb_dialog->ecode));

                            $SIG{$_} = "exit_after_close_db" for qw/INT TERM HUP QUIT KILL/;

                            close($fh);
                        }
                    }
                    else
                    {
                        $log->error('APIの制限に達しているので、どうにかするコードを自己責任で書く必要があります。');
                        exit_after_close_db();
                    }
                } # end if reply
            } #end if lang eq ja

            NEXT_TWEET:
        }, # end sub
    ); #end AE::Twitter::Stream->new

    $done->recv; # 終了条件を満たすまでイベントループを回す

    undef $stream;

    if ($connected) { $log->warn('接続が切れました');     }
    else            { $log->warn('接続できませんでした'); }

    my $wait_time = $connected ? 0 : 2; # とりあえず2秒待つ

    my $wait_cv = AE::cv;
    my $wait_t  = AE::timer($wait_time, 0, $wait_cv);

    $wait_cv->recv;

} # end while

exit_after_close_db();

sub tranabort
{
    my ($key, $val) = @_;

    if (length $key)
    {
        say "abort key: $key";
        p $val;
    }

    $bdb_dialog->tranabort;
    $bdb_dialog->close;

    exit;
}

sub exit_after_close_db
{
    $bdb_dialog->tranabort;
    $bdb_dialog->close;
    $log->notice('DBを閉じて終了しました');
    exit;
}

sub is_japanese
{
    my $text = shift;

    return 1 if $text =~ /[\p{InHiragana}\p{InKatakana}\p{InHalfwidthKatakana}]/;
    return 1 if $text =~ /\p{Han}/ && $text !~ /[^\p{InJoyoKanji}\p{InJinmeiyoKanji}]/; # 漢字が含まれていて、常用漢字と人名用漢字以外の漢字が含まれていなければ日本語
    return 1 if $text =~ /^[^\p{Han}\p{Hangul}]+$/; # 数字だけとか顔文字にも対応できるように（英語だけでも通るだけどあとで処理すれば良い）

    return 0;
}

sub regist
{
    my ($speak, $reply) = @_;

    # RT/QT が含まれていれば飛ばす
    return if $speak->{text} =~ /\s(?:RT|QT)\s/;
    return if $reply->{text} =~ /\s(?:RT|QT)\s/;

    # URL, ハッシュタグが含まれていれば飛ばす
    return if $speak->{text} =~ /http(?:s|):/;
    return if $reply->{text} =~ /http(?:s|):/;
    return if $speak->{text} =~ /#[^\s]+/;
    return if $reply->{text} =~ /#[^\s]+/;

    # ボットの発言ならば飛ばす
    return if $speak->{user}{screen_name} =~ /bot/i;
    return if $reply->{user}{screen_name} =~ /bot/i;
    return if $speak->{user}{name}        =~ /bot|ボット|人工無[能脳]/i;
    return if $reply->{user}{name}        =~ /bot|ボット|人工無[能脳]/i;
    return if $speak->{source}            =~ /bot|ボット|人工無[能脳]/i;
    return if $reply->{source}            =~ /bot|ボット|人工無[能脳]/i;

    # NGなIDなら飛ばす
    return if List::AllUtils::any { $speak->{user}{screen_name} eq $_ } @NG_TWITTER_ID;
    return if List::AllUtils::any { $reply->{user}{screen_name} eq $_ } @NG_TWITTER_ID;

    # 返信時につけるTwitter ID を削除
    $speak->{text} =~ s/@[a-zA-Z0-9_]+//g;
    $reply->{text} =~ s/@[a-zA-Z0-9_]+//g;

    # 正規表現で使えるようにクォートをつける
    $speak->{user}{name} = quotemeta $speak->{user}{name};
    $reply->{user}{name} = quotemeta $reply->{user}{name};

    # 名前部分を特別扱いにする
    $speak->{text} =~ s/$speak->{user}{name}/kysname/g;
    $speak->{text} =~ s/$reply->{user}{name}/kyrname/g;
    $reply->{text} =~ s/$reply->{user}{name}/kyrname/g;
    $reply->{text} =~ s/$speak->{user}{name}/kysname/g;

    # ＠付きの名前に対処
    if ($speak->{user}{name} =~ /(.+?)(?:@|＠)/)
    {
        $speak->{user}{name} =  $1;
        $speak->{user}{name} =~ s/\\//g; # (.+)で「\」マークまで切り取られることがあるため掃除
        $speak->{user}{name} =  quotemeta $speak->{user}{name};
        $speak->{text} =~ s/$speak->{user}{name}/kysname/g;
        $reply->{text} =~ s/$speak->{user}{name}/kysname/g;
    }

    if ($reply->{user}{name} =~ /(.+?)(?:@|＠)/)
    {
        $reply->{user}{name} =  $1;
        $reply->{user}{name} =~ s/\\//g;
        $reply->{user}{name} =  quotemeta $reply->{user}{name};
        $speak->{text} =~ s/$reply->{user}{name}/kyrname/g;
        $reply->{text} =~ s/$reply->{user}{name}/kyrname/g;
    }

    # 括弧つきの名前に対処
    $speak->{user}{name} =~ s/\\//g;
    $reply->{user}{name} =~ s/\\//g;
    $speak->{user}{name} =~ s/\(.*?\)//g;
    $reply->{user}{name} =~ s/\(.*?\)//g;
    $speak->{user}{name} =~ s/（.*?）//g;
    $reply->{user}{name} =~ s/（.*?）//g;

    $speak->{user}{name} = quotemeta trim($speak->{user}{name});
    $reply->{user}{name} = quotemeta trim($reply->{user}{name});

    $speak->{text} =~ s/$speak->{user}{name}/kysname/g;
    $speak->{text} =~ s/$reply->{user}{name}/kyrname/g;
    $reply->{text} =~ s/$reply->{user}{name}/kyrname/g;
    $reply->{text} =~ s/$speak->{user}{name}/kysname/g;

    $speak->{user}{name} =~ s/\\//g;
    $reply->{user}{name} =~ s/\\//g;

    # スペースで区切られた名前に対処
    my @speak_name = split(/\s+/, $speak->{user}{name});
    my @reply_name = split(/\s+/, $reply->{user}{name});

    # 中点で区切られた名前に対処
    push(@speak_name, split(/・/, $speak->{user}{name}));
    push(@reply_name, split(/・/, $reply->{user}{name}));

    for my $name (@reply_name)
    {
        next if length $name < 3;
        $name = quotemeta $name;
        $speak->{text} =~ s/$name/kyrname/g;
        $reply->{text} =~ s/$name/kyrname/g;
    }

    for my $name (@speak_name)
    {
        next if length $name < 3;
        $name = quotemeta $name;
        $speak->{text} =~ s/$name/kysname/g;
        $reply->{text} =~ s/$name/kysname/g;
    }

    # ノーマライズ
    $speak->{text} = $normalizer->normalize($speak->{text});
    $reply->{text} = trim($reply->{text});

    return if length $speak->{text} == 0 || length $reply->{text} < 2;

    # 絵文字を抽出
    my $last_emoji = ($reply->{text} =~ /[\p{InEmoticonLike}\p{InEmoticonDislike}]/g)[-1];

    my $emotion = 'neutral';

    if (defined $last_emoji)
    {
           if ($last_emoji =~ /\p{InEmoticonLike}/)    { $emotion = 'like';    }
        elsif ($last_emoji =~ /\p{InEmoticonDislike}/) { $emotion = 'dislike'; }
    }

    my $cols = {
        created_at         => $reply->{created_at},
        user_id            => $reply->{user}{screen_name},
        user_name          => $reply->{user}{name},
        text               => $reply->{text},
        client             => $reply->{source},
        favorite_count     => $reply->{favorite_count},
        retweet_count      => $reply->{retweet_count},
        hashtags           => $reply->{entities}{hashtags},
        favo_plus_rt       => $reply->{favorite_count} + $reply->{retweet_count},
        kezuri             => 0,
        emotion            => $emotion,
    };

    # 完全一致で登録
    $bdb_dialog->putdup( $speak->{text}, encode_json($cols) ) or tranabort($speak->{text}, $cols);
    sweep($speak->{text}, $cols->{kezuri});

    $log->debug($speak->{text});
    $log->debug($cols->{text});

    # 形態素解析して登録
    my $modified_speak = $speak->{text};

    # 形態素解析器が文の切れ目がわからないようなのでそのための前処理
    $modified_speak =~ s/(!+)/$1 /g;
    $modified_speak =~ s/(\?+)/$1 /g;

    # 形態素解析
    my @words = strip_needless_morpheme($modified_speak);

    # 形態素がなければ飛ばす
    return unless scalar @words;

    my ($gimon_flag, $words_str);

    for my $word (@words)
    {
        $words_str .= $word;
    }

    if ($words_str =~ /^(だれ|誰|どこ|何処|何|なんで|何で|なぜ|何故|どれ|どんくら|どうして|どうやって|どの|いかに)[^か]+/
     || $words[0] eq 'いつ' || $words[0] eq 'なに')
    {
        $gimon_flag = 1;
    }

    $cols->{kezuri} = 999;

    my @words2 = @words;

    # 単語一致で登録
    for my $word (uniq @words)
    {
        next if $speak->{text} eq $word;
        next if length $word == 1 && $word =~ /[\p{InHiragana}\p{InKatakana}]/;
        $bdb_dialog->putdup( $word, encode_json($cols) ) or tranabort($word, $cols);
        $log->debug("単語一致：$word");
        sweep($word, $cols->{kezuri});
    }

    my $level = 2;

    # 部分一致で登録
    return if scalar @words2 < 3;

    while (@words2)
    {
        $cols->{kezuri} = $level;

        if ($gimon_flag) { pop   @words2; } # 疑問文の場合、主辞は先頭にある
        else             { shift @words2; } # 普通の場合、主辞は末尾にある

        $bdb_dialog->putdup( "@words2", encode_json($cols) ) or tranabort("@words2", $cols);
        $log->debug("部分一致：@words2");
        sweep("@words2", $cols->{kezuri});

        last if scalar @words2 == 2;

        ++$level;
    }
}

# remove high level reply
sub sweep
{
    my ($key, $level) = @_;

    my $replies = $bdb_dialog->getlist($key) // [];
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

        $log->debug("高いレベルの返答の削除中");

        $bdb_dialog->outlist($key) or warn 'nyaaa';

        for my $reply (@replies)
        {
            if ($level_min == $reply->{kezuri})
            {
                $bdb_dialog->putdup( $key, encode_json($reply) ) or tranabort($key, $reply);
            }
        }
    }
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
