package Munou::Tool;

use strict;
use warnings;
use utf8;
use Exporter qw/import/;

our @EXPORT    = qw//;
our @EXPORT_OK = qw/InEmoticonLike InEmoticonDislike
InEmoticonDere InEmoticonIkari InEmoticonWarai InEmoticonNamida
is_contains_R18word/;

sub InEmoticonLike
{
return <<"END";
2665
2764
1F44D
1F48F
1F493
1F495
1F496
1F497
1F498
1F49D
1F49E
1F600
1F601
1F602
1F603
1F604
1F606
1F607
1F609
1F60A
1F60B
1F60D
1F618
1F619
1F61A
1F638
1F639
1F63A
1F63B
1F64C
END
}

sub InEmoticonDislike
{
    return <<"END";
1F44E
1F47A
1F47F
1F494
1F4A2
1F612
1F614
1F616
1F61E
1F61F
1F620
1F621
1F622
1F623
1F624
1F625
1F628
1F629
1F62B
1F630
1F63E
1F63F
END
}

sub InEmoticonDere
{
    return <<"END";
2764
1F493
1F48F
1F495
1F496
1F497
1F498
1F49D
1F49E
END
}

sub InEmoticonWarai
{
    return <<"END";
1F600\t1F607
1F609\t1F60B
1F60D
1F618\t1F61A
1F638\t1F63B
1F64C
END
}

sub InEmoticonNamida
{
    return <<"END";
1F616
1F622
1F623
1F628
1F629
1F62B
1F630
1F63F
END
}

sub InEmoticonIkari
{
    return <<"END";
1F44E
1F47A
1F47F
1F494
1F4A2
1F612
1F620
1F621
1F624
1F63E
END
}

sub is_contains_R18word
{
    ($_[0] =~ /(?:エッチ|陰毛|マンコ|まんこ|ちんこ|チンコ|ちんちん|チンチン|ペニス|金玉|肉棒|陰茎|アナル|おっぱい|勃起|精子|乳首|オナニー|マスターベーション|クンニ|デリヘル|包茎|ヤリマン|性器|処女|乱交|バイブ|ローター|中出し|パコパコ|パイパン|ノーブラ|ノーパン|手こき|手コキ|自慰|手マン|ちんげ|チンゲ|チン毛|射精|顔射|淫|谷間|手ブラ|パンティ|乳輪|巨乳|貧乳|フェラ|騎乗位|正常位|後背位|ヤリチン|ホモ|レズ|ゲイ|セックス|SEX|sex|ヘンタイ|変態|hentai|HENTAI|童貞|ショタ|ロリコン|性癖|シコシコ|精液|ぶっかけ|まんまん|マンマン|クンニ|卑猥|ひｙ|ふたなり|フタナリ|シモネタ|下ネタ|電マ|愛液|合体)/) ? 1 : 0;
}

1;
