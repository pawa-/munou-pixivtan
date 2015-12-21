package Munou::Twitter::NormalizeText;

use strict;
use warnings;
use utf8;
use Exporter qw/import/;
use Lingua::JA::Halfwidth::Katakana;

our @EXPORT    = qw//;
our @EXPORT_OK = qw/unify_warai  unify_url  strip_hashtag  strip_kao  aaaa2aaa
ore2watashi  unify_kakko  unify_3dots  unify_kutouten  strip_pictograph  etc/;

sub unify_warai
{
    local $_ = shift;
    tr/\x{1F600}-\x{1F64F}//d; # エモティコンの削除
    tr/ʬ/ｗ/;
    s/(?:ｗ|ｖ){4,}/ ʬ /g; # ｗ｜ｖ ４つ以上は大笑い扱い
    s/ｗ+/ ｗ /g;
    s/wwww+/ ʬ /g;
    s/vvvv+/ ʬ /g;
    s/([^0-9a-zA-Z])w+(\s|$)/$1 ｗ$2/g;
    tr/ʬ/ʬ/s;
    tr/ｗ/\x{1F60A}/s;
    $_;
}

sub unify_url     { local $_ = shift; s/http(?:s|):[^\s]*/XXXURLXXX/g; $_; }
sub strip_hashtag { local $_ = shift; s/#[^\s]+/ /g; $_; }

sub strip_kao
{
    local $_ = shift;

    s/\((?:爆|泣)\)/ /g;
    s/\(笑\)/ \x{1F60A} /g;
    s/【.*?】/ /g;
    s/\[.*?\]/ /g;
    s/⁉︎/!?/g;
    s/⁇/??/g;
    tr/♡♥/ /;
    tr/（）/()/;
    s/(?:><|;;)/ /g;
    s/orz($|\s)/$1/g;
    s/([^\p{Han}]|\s)笑($|\s)/$1 \x{1F60A} $2/g;
    s/([\p{InHiragana}\p{InKatakana}]|\s)爆($|\s)/$1$2/g;
    s/(?:泣|←|♫|♬|♪|★|☆)(\s|$)/$1/g;
    s/(?:★|☆)+(?:彡|ミ)(\s|$)/$1/g;
    s/zzz+($|\s)/$1/ig; # Zzz(睡眠マーク)を削除

    s/\)人\(/)(/g; # ヽ(∀ﾟ )人(ﾟ∀ﾟ)人( ﾟ∀)ノ の人を削除
    s/\)つ//g;     # ( ・ω・)つ の「)つ」を削除
    s/ヘ(\()/$1/g; # ヘ(* - -)ノ の「へ」を削除
    tr/ゝヽ//d;
    s/・3・//g;

    s/[^\p{InJapanese}0-9a-zA-Z?%!！？ー]*(?:ヾ|o|m|ξ|)         # 顔の左側
      \( .*? \)                                                 # 顔本体
      (?:ゞ|ヾ|ノ゙|ノ|丿|屮|o|m|)[^\p{InJapanese}0-9a-zA-Z?？!！\x{1F60A}]*  # 顔の右側
      \s?                                                       # 空白ある or ない
      (?:[\p{Inkatakana}\p{InHalfwidthKatakana}]*\z|)           # カタカナ
      / /gxms;

    s/\(?                                                # 左輪郭ある or ない
      \^                                                 # 左目
      (?:|.)                                             # 口
      \^                                                 # 右目
      (?:ゞ|ヾ|ノ゙|ノ|丿|屮|)[^\p{InJapanese}0-9a-zA-Z]*  # 汗など
      / /gxms;

    s/c[^\p{InJapanese}]*\)//g;        # c⌒っ*.=д=)を削除
    s/\( .+ \z//gxms;                  # (ペタペタ ←こういうのを削除
    tr/\// /s;                         # ///を削除
    s/(\p{InJapanese})b(\s|$)/$1$2/g;  # b（グッド）を削除
    s/[^:0-9]\/\/*//g;                 # :(URL)と0-9（日付）じゃない文字の後ろのスラッシュを削除
    s/[^\p{InJapanese}a-zA-Z0-9%」!！?？\x{1F60A}ʬ…]+?(\s|、|。|$)/$1/g;             # 末尾にゴミがあれば削除
    s/(^|\s)[^\p{InJapanese}\p{InHalfwidthKatakana}a-zA-Z0-9「!！?？\x{1F60A}ʬ…]+/$1/g; # 先頭にゴミがあれば削除
    s/ノシ$//;

    $_;
}

sub aaaa2aaa
{
    local $_ = shift;

    my %uniq_char_set;
    @uniq_char_set{ split(//, $_) } = ();

    for my $char (keys %uniq_char_set)
    {
        if ($char =~ /[^\p{InJapanese}a-zA-Z0-9]/)
        {
            # 記号なら３文字以上の連続を２文字に
            my $qchar = quotemeta $char;
            s/$qchar{3,}/"$char$char"/eg;
        }
        else
        {
            # 普通の文字なら４文字以上の連続を３文字に
            s/$char{4,}/"$char$char$char"/eg;
        }
    }

    $_;
}

sub ore2watashi { local $_ = shift; tr/俺/私/; $_;            }
sub unify_kakko { local $_ = shift; s/『(.*?)』/「$1」/g; $_; }

sub unify_3dots
{
    local $_ = shift;
    tr/\x{2025}\x{22EF}/\x{2026}/;                # U+2025: ２点リーダー, U+22EF: MIDLINE HORIZONTAL ELLIPSIS（数学演算子ブロック）
    s/。{2,}/……/g; s/、{2,}/……/g; s/・{2,}/……/g;  # ２つ以上のリーダーっぽいのを３点リーダー２つに統一
    s/(^|[^…])…($|[^…])/$1……$2/g;                 # １つの３点リーダーを２つに統一
    s/(^|[^…])…($|[^…])/$1……$2/g;                 # １つの３点リーダーを２つに統一（２回実行しないと全て統一できない）
    $_;
}

sub unify_kutouten   { local $_ = shift; tr/｡．.､，,/。。。、、、/; $_; } # 句読点は「、」or「。」
sub strip_pictograph { local $_ = shift; tr/\x{1F300}-\x{1F5FF}//d; $_; } # うんこマークとかを消す

sub etc
{
    local $_ = shift;
    s/\s([、。?!]+)(\s|$)/$1$2/g;
    s/[っッ]+(\s|$)/$1/g; # なるほどっ などの末尾の「っ」「ッ」を消す
    $_;
}

sub InJapanese
{
    return <<"END";
+utf8::InHiragana
+utf8::InKatakana
+utf8::Han
END
}

1;
