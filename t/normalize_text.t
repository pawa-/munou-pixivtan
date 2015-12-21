use strict;
use warnings;
use utf8;
use Test::More;
use FindBin ();
use lib "$FindBin::Bin/../lib";
use Lingua::JA::NormalizeText;
use Munou::Twitter::NormalizeText qw/unify_warai  unify_url  strip_hashtag  strip_kao
aaaa2aaa  ore2watashi  unify_kakko  unify_3dots  unify_kutouten  strip_pictograph  etc/;

binmode Test::More->builder->$_ => ':utf8'
    for qw/output failure_output todo_output/;

subtest 'unify_warai' => sub {
    is(unify_warai("オウフｗ"), "オウフ \x{1F60A} ");
    is(unify_warai("オウフｗｗ"), "オウフ \x{1F60A} ");
    is(unify_warai("オウフｗｗｗ"), "オウフ \x{1F60A} ");
    is(unify_warai("オウフｗｗｗｗ"), "オウフ ʬ ");
    is(unify_warai("オウフｗｗｗｗドュフｗコポォwww"), "オウフ ʬ ドュフ \x{1F60A} コポォ \x{1F60A}");
    is(unify_warai("オウフｗｗｗｗドュフｗコポォwwww"), "オウフ ʬ ドュフ \x{1F60A} コポォ ʬ ");
    is(unify_warai("オウフｗｗｗｗ ドュフｗ コポォwwww"), "オウフ ʬ  ドュフ \x{1F60A}  コポォ ʬ ");
    is(unify_warai("オウフ ｗ"), "オウフ  \x{1F60A} ");
    is(unify_warai("オウフ ｗｗ"), "オウフ  \x{1F60A} ");
    is(unify_warai("オウフ ｖ"), "オウフ ｖ");
    is(unify_warai("オウフ ｖｖ"), "オウフ ｖｖ");
    is(unify_warai("うはw"), "うは \x{1F60A}");
    is(unify_warai("うはww"), "うは \x{1F60A}");
    is(unify_warai("うはwwwwwww"), "うは ʬ ");
    is(unify_warai("うはv"), "うはv");
    is(unify_warai("うはvv"), "うはvv");
    is(unify_warai("うはwwwwwwおふww"), "うは ʬ おふ \x{1F60A}");
    is(unify_warai("うはvvvvvvおふvv"), "うは ʬ おふvv");
    is(unify_warai("うはvvvvvvおふvvv"), "うは ʬ おふvvv");
    is(unify_warai("うはvvvvvvおふvvvv"), "うは ʬ おふ ʬ ");
    is(unify_warai("ウェーイʬʬ"), "ウェーイ \x{1F60A} ");
    is(unify_warai("ウェーイʬʬʬʬʬ"), "ウェーイ ʬ ");
    is(unify_warai("ウェーイʬʬʬʬʬ" x 2), "ウェーイ ʬ " x 2);
    is(unify_warai("ウェーイｗｗウェーイ"), "ウェーイ \x{1F60A} ウェーイ");
    is(unify_warai("ウェーイｗｗｗウェーイ"), "ウェーイ \x{1F60A} ウェーイ");
    is(unify_warai("ウェーイｗｗｗｗウェーイ"), "ウェーイ ʬ ウェーイ");
    is(unify_warai("ウェーイｖｖウェーイ"), "ウェーイｖｖウェーイ");
    is(unify_warai("ウェーイｖｖｖウェーイ"), "ウェーイｖｖｖウェーイ");
    is(unify_warai("ウェーイｖｖｖｖウェーイ"), "ウェーイ ʬ ウェーイ");
    is(unify_warai("これはw"), "これは \x{1F60A}");
    is(unify_warai("これはwです"), "これはwです");
    is(unify_warai("やっぱwですね"), "やっぱwですね");
    is(unify_warai("やっぱwwですね"), "やっぱwwですね");
    is(unify_warai("やっぱwwwですね"), "やっぱwwwですね");
    is(unify_warai("やっぱwwwwですね"), "やっぱ ʬ ですね");
    is(unify_warai("やっぱvですね"), "やっぱvですね");
    is(unify_warai("やっぱvvですね"), "やっぱvvですね");
    is(unify_warai("やっぱvvvですね"), "やっぱvvvですね");
    is(unify_warai("やっぱvvvvですね"), "やっぱ ʬ ですね");
    is(unify_warai("abwcd"), "abwcd");
    is(unify_warai("ABWCD"), "ABWCD");
    is(unify_warai("ウェーイʬウェーイ"), "ウェーイ \x{1F60A} ウェーイ");
    is(unify_warai("ウェーイʬʬウェーイ"), "ウェーイ \x{1F60A} ウェーイ");
    is(unify_warai("ウェーイʬʬʬウェーイ"), "ウェーイ \x{1F60A} ウェーイ");
    is(unify_warai("ウェーイʬʬʬʬウェーイ"), "ウェーイ ʬ ウェーイ");
    is(unify_warai("wwwサーバ"), "wwwサーバ");
    is(unify_warai("WWWサーバ"), "WWWサーバ");
    is(unify_warai("wサーバ"), "wサーバ");
    is(unify_warai("wwサーバ"), "wwサーバ");
    is(unify_warai("vvvサーバ"), "vvvサーバ");
    is(unify_warai("VVVサーバ"), "VVVサーバ");
    is(unify_warai("vサーバ"), "vサーバ");
    is(unify_warai("vvサーバ"), "vvサーバ");
    is(unify_warai("abcw"), "abcw");
    is(unify_warai("abcv"), "abcv");
    is(unify_warai("やっほーwwww暇"), "やっほー ʬ 暇");
    is(unify_warai("😊" x 2), "");
};

subtest 'unify_url' => sub {
    is(unify_url("これ http://www.yahoo.co.jp/"), "これ XXXURLXXX");
    is(unify_url("これ https://www.yahoo.co.jp/"), "これ XXXURLXXX");
    is(unify_url("これ http://www.yahoo.co.jp/hoge"), "これ XXXURLXXX");
    is(unify_url("これ http://www.yahoo.co.jp/%20"), "これ XXXURLXXX");
    is(unify_url("これ http://www.yahoo.co.jp/%20 やで"), "これ XXXURLXXX やで");
    is(unify_url("これhttp://www.yahoo.co.jp/やで"), "これXXXURLXXX");
    is(unify_url("これ http://www.yahoo.co.jp/ やで" x 2), "これ XXXURLXXX やで" x 2);
};

subtest 'strip_hashtag' => sub {
    is(strip_hashtag("勝った #giants"), "勝った  ");
    is(strip_hashtag("勝った #巨人"), "勝った  ");
    is(strip_hashtag("#にゃー 勝った #巨人"), "  勝った  ");
    is(strip_hashtag("勝った#巨人"), "勝った ");
};

subtest 'strip_kao' => sub {
    is(strip_kao("(･ัω･ั）"), "");
    is(strip_kao("^^;"), "");
    is(strip_kao("(^^ゞ"), "");
    is(strip_kao("☆彡"), "");
    is(strip_kao("(^O^)"), "");
    is(strip_kao("m(__)m"), "");
    is(strip_kao("(・ω<)"), "");
    is(strip_kao("ヤッホー (^O^)"), "ヤッホー");
    is(strip_kao("ヤッホー (^O^) にゃ"), "ヤッホー にゃ");
    is(strip_kao("イエーイ (^O^)ﾔｯﾎｰ"), "イエーイ");
    is(strip_kao("イエーイ (^O^) ﾔｯﾎｰ"), "イエーイ");
    is(strip_kao("一日頑張ろうね！ξ(｀○ω○´)"), "一日頑張ろうね！");
    is(strip_kao("一日頑張ろうね！ξ(｀○ω○´"), "一日頑張ろうね！");
    is(strip_kao("荷物がおもい(´･_･`)笑"), "荷物がおもい \x{1F60A}");
    is(strip_kao("え、ダメなのﾟ(ﾟ´Д｀ﾟ)ﾟ｡"), "え、ダメなの");
    is(strip_kao("え、ダメなのﾟ(ﾟ´Д｀ﾟ)ﾟ｡"), "え、ダメなの");
    is(strip_kao("きんちょうだな... (ง •̀_•́)งがんばって"), "きんちょうだな がんばって");
    is(strip_kao("お早うございます。(￣▽￣)ノ パワー全開！"), "お早うございます パワー全開！");
    is(strip_kao("おはよーです(^o^)／ 今日も"), "おはよーです 今日も");
    is(strip_kao("千田!!!!! (」・ω・)よ!!"), "千田!!!!! よ!!");
    is(strip_kao("おぉ〜！笑"), "おぉ〜！ \x{1F60A}");
    is(strip_kao("おはようにゃー♪"), "おはようにゃー");
    is(strip_kao("行ってきます(*^^*)"), "行ってきます");
    is(strip_kao("参りました( ´ ▽ ` )ﾉ 相互希望なので"), "参りました 相互希望なので");
    is(strip_kao("おはよう＼(^o^)／やばいね"), "おはよう やばいね");
    is(strip_kao("ございます(＊˙O˙＊)やばいで"), "ございます やばいで");
    is(strip_kao("ます(^O^)／"), "ます");
    is(strip_kao("(`･ω･)ゞおはよ"), "おはよ");
    is(strip_kao("ございます٩(*´︶`*)۶♬"), "ございます");
    is(strip_kao("おっはよーヾ(＠⌒ー⌒＠)ノ"), "おっはよー");
    is(strip_kao("ます⊂((・x・))⊃ http"), "ます http");
    is(strip_kao("(*´∀`*)ﾉｵﾊﾖｳ♪けみさん"), "けみさん");
    is(strip_kao("弟？(ﾟ∀ﾟ)"), "弟？");
    is(strip_kao("弟?(ﾟ∀ﾟ)"), "弟?");
    is(strip_kao("ございます٩(๑❛ᴗ❛๑)۶朝はまだ"), "ございます 朝はまだ");
    is(strip_kao("このご恩わ仇で返します笑"), "このご恩わ仇で返します \x{1F60A}");
    is(strip_kao("がんばって٩(ˊᗜˋ*)و"), "がんばって");
    is(strip_kao("おはよー°₊·ˈ∗((  ॣ˃̶᷇ ‧̫ ˂̶᷆ ॣ))∗ˈ‧₊°"), "おはよー");
    is(strip_kao("つーーー♪o(^o^)o"), "つーーー");
    is(strip_kao("おはありー(*≧∇≦)/"), "おはありー");
    is(strip_kao("おはよーヾ(o´∀｀o)ﾉ そっちは"), "おはよー そっちは");
    is(strip_kao("入学式( :D)┸┓ﾜｧｰ"), "入学式");
    #is(strip_kao("ｏ(^ω^)〇おはようございます〇(^ω^)ｏ "), "おはようございます");
    is(strip_kao("おはおヾ(⌒(ﾉ'ω')ﾉ"), "おはお");
    is(strip_kao("ありがとう\( ˆoˆ )/ディズニー楽しんで♡"), "ありがとう ディズニー楽しんで");
    is(strip_kao("です！！(笑)でも"), "です！！ \x{1F60A} でも");
    is(strip_kao("です！！でも//// いや"), "です！！でも いや");
    is(strip_kao("【拡散希望】です"), "です");
    is(strip_kao("ですb いえい"), "です いえい");
};

subtest 'aaaa2aaa' => sub {
    is(aaaa2aaa("きゃー"), "きゃー");
    is(aaaa2aaa("きゃーー"), "きゃーー");
    is(aaaa2aaa("きゃーーー"), "きゃーーー");
    is(aaaa2aaa("きゃーーーー"), "きゃーーー");
    is(aaaa2aaa("きゃーーーー" x 2), "きゃーーー" x 2);
    is(aaaa2aaa("!!"), "!!");
    is(aaaa2aaa("!!!"), "!!");
    is(aaaa2aaa("Yeah!!!!" x 2), "Yeah!!" x 2);
    is(aaaa2aaa("Yeah!!!!OOOOQQPOPOPOP" x 2), "Yeah!!OOOQQPOPOPOP" x 2);
};

subtest 'ore2watashi' => sub {
    is(ore2watashi("俺流"), "私流");
    is(ore2watashi("俺流" x 2), "私流" x 2);
};

subtest 'unify_kakko' => sub {
    is(unify_kakko("『あああ』"), "「あああ」");
    is(unify_kakko("『あああ』" x 2), "「あああ」" x 2);
};

subtest 'unify_3dots' => sub {
    is(unify_3dots("え。。。"), "え……");
    is(unify_3dots("え…"), "え……");
    is(unify_3dots("ほ、、、、、、え。。"), "ほ……え……");
    is(unify_3dots("ほ…………"), "ほ…………");
};

subtest 'unify_kutouten' => sub {
    is(unify_kutouten("ああ，，"), "ああ、、");
    is(unify_kutouten("いい，，うう,."), "いい、、うう、。");
};

subtest 'strip_pictograph' => sub {
    is(strip_pictograph("\x{1F4A9}" x 2), "");
};

subtest 'combination' => sub {
    local $_ = Lingua::JA::NormalizeText->new([
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

    is($_->normalize("（あああ）"), "");
    is($_->normalize("お金と時間を無駄にした気分半端なかったwほんともう少しちゃんとみてくれてもよかったのに…"), "お金と時間を無駄にした気分半端なかったwほんともう少しちゃんとみてくれてもよかったのに……");
    is($_->normalize("おはよ〜ございます♪自分発信ですか？(笑)"), "おはよーございます♪自分発信ですか? \x{1F60A}");
    is($_->normalize("うっ、車内がニンニク臭い。おばよゔござりまずる"), "うっ、車内がニンニク臭い。おばよゔござりまずる");
    is($_->normalize("今日も元気に社畜ライフ☆ 朝はそんなセットがあるんやね〜"), "今日も元気に社畜ライフ 朝はそんなセットがあるんやねー");
    is($_->normalize("ちゅっちゅされたから！！！！！！！！！"), "ちゅっちゅされたから!!");
    is($_->normalize("モンストやってるの(*´ω｀*)？"), "モンストやってるの?");
    is($_->normalize("やってるよん(=ﾟωﾟ)ﾉそれほどハマっては無いけどねw"), "やってるよん それほどハマっては無いけどね \x{1F60A}");
    is($_->normalize("はあ？"), "はあ?");
    is($_->normalize("しかし16時ごろには大塚なので無理ですなー(￣▽￣)"), "しかし16時ごろには大塚なので無理ですなー");
    is($_->normalize("えへ♡ "), "えへ");
    is($_->normalize("みゆちゃんファイトー♪ ٩( ´ω` )و ♪"), "みゆちゃんファイトー");
    is($_->normalize("一時限目が救急医学なんでテンションあがりまくり。やっと私が医学部を志望した原点に辿り着いた。    \n     …でも遅刻しそう(´；ω；｀)"), "一時限目が救急医学なんでテンションあがりまくり。やっと私が医学部を志望した原点に辿り着いた ……でも遅刻しそう");
    is($_->normalize("フォロバありがとうございます♡ではタメで話しますねー*\(^o^)/* 何て呼んだらいいかな?♡♡"), "フォロバありがとうございます ではタメで話しますねー 何て呼んだらいいかな?");
    is($_->normalize("みんなからは、ろこちゃんって呼ばれてるよ～♡♡♡ 私はなんて呼んだらいい(つω`*)？？"), "みんなからは、ろこちゃんって呼ばれてるよー 私はなんて呼んだらいい??");
    is($_->normalize("YouTubeの叩いてみた見て あ然としたゆなです( *・ω・)ノ"), "youtubeの叩いてみた見て あ然としたゆなです");
    is($_->normalize("お世辞でも嬉しいです笑 中身がくずだから "), "お世辞でも嬉しいです \x{1F60A} 中身がくずだから");
    is($_->normalize("ｵﾊﾖ─ヽ(･∀･`o)(o´･∀･`o)(o´･∀･)ﾉ─ｩ♪"), "オハヨー o´・∀・`o");
    is($_->normalize("ぶーたって。笑"), "ぶーたって \x{1F60A}");
    is($_->normalize("ままんが勝手に名前つけたの(´･_･`)笑"), "ままんが勝手に名前つけたの \x{1F60A}");
    is($_->normalize("カワウソぉぉぉぉぉぉぉぉ！！！！かわいい！！こいつらかわいい！！！"), "カワウソぉぉぉ!!かわいい!!こいつらかわいい!!");
    is($_->normalize("おやつ探してるだけだからKENZENだーと主張してみる（笑顔）"), "おやつ探してるだけだからkenzenだーと主張してみる");
    is($_->normalize("調べときますかね、いい機会ですし。"), "調べときますかね、いい機会ですし");
    is($_->normalize("調べときますかね。いい機会ですし。"), "調べときますかね。いい機会ですし");
    is($_->normalize("精々月でも眺めてますかね～…"), "精々月でも眺めてますかねー……");
    is($_->normalize("寝違えた?( ᐛ👐)ﾊﾟｧ 大丈夫⁉︎( ᐛ👐)ﾊﾟｧ←顔文字これでもめちゃくちゃ心配してる"), "寝違えた? 大丈夫!? 顔文字これでもめちゃくちゃ心配してる");
    is($_->normalize("無理しうだ〜しうだしうだ〜無理しうだ〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜〜"), "無理しうだーしうだしうだー無理しうだーーー");
    is($_->normalize("おめでとー*\( ˆoˆ )/*"), "おめでとー");
    is($_->normalize("はるかちゃん！(笑) ありがとう❥❥❥ 松徳の子だよね？( ＾ω＾ )"), "はるかちゃん! \x{1F60A} ありがとう 松徳の子だよね?");
    is($_->normalize("ためにしよ(๑°ω°๑)❤❤ 岩橋玄樹担で同い年とか高まる💗りな玄樹くんだったのね♬♡じぐいわどっちかなって思ったの❀✿"), "ためにしよ 岩橋玄樹担で同い年とか高まるりな玄樹くんだったのね じぐいわどっちかなって思ったの");
    is($_->normalize("あ、そうだ！アイコンじぐいわだもんねｗｗ言われてみれば♡.°⑅一言には玄樹くんって書いたる😂😂😂ｗｗ"), "あ、そうだ!アイコンじぐいわだもんね \x{1F60A} 言われてみれば。°⑅一言には玄樹くんって書いたる \x{1F60A}");
    is($_->normalize("ご飯食べてきます〜｡･*･:≡(　ε:)"), "ご飯食べてきますー");
    is($_->normalize("めしてら～！ _(┐ 「ε:)_"), "めしてらー!");
    is($_->normalize("え??そんなに長いの……!?!?やばい嬉しすぎる……っ:;(∩˙︶˙∩);: ♡"), "え??そんなに長いの……!?!?やばい嬉しすぎる……");
    is($_->normalize("ごめんね(;_;)開場と開演時間見間違えてたからもっと短いや(;_;)(;_;)！ そしてあいちゃんぴこりん握手会あたったの！？"), "ごめんね 開場と開演時間見間違えてたからもっと短いや! そしてあいちゃんぴこりん握手会あたったの!?");
    is($_->normalize("お父さんがプレゼントしてくれました♡かわいいっ(*^_^*)これ履いてウォーキングしよう！"), "お父さんがプレゼントしてくれました かわいい これ履いてウォーキングしよう!");
    is($_->normalize("カワイイ…やったね!気持ちも上がるねo(^o^)o"), "カワイイ……やったね!気持ちも上がるね");
    is($_->normalize("ほえ ((((；ﾟДﾟ)))))))ｱﾜﾜ"), "ほえ");
    is($_->normalize("把握した…www  #推しごとお疲れ様でしたw"), "把握した…… \x{1F60A}");
    #is($_->normalize("おはよー！ って呟いても誰からもリプ来ないL(’ω’)┘三└(’ω’)」"), "おはよー！ って呟いても誰からもリプ来ない");
    is($_->normalize("ありがとんwあやたんは年上⁇下⁇"), "ありがとんwあやたんは年上??下??");
    is($_->normalize("あやたんいっこした！！！かな？？ 高3になりました─=≡Σ((( つ•̀ω•́)つ"), "あやたんいっこした!!かな?? 高3になりましたー");
    is($_->normalize("空想委員会＼(^o^)／  マフラー少女でゆったりしてる💓💓"), "空想委員会 マフラー少女でゆったりしてる");
    is($_->normalize("蓮メイ素敵ですぅ///"), "蓮メイ素敵ですぅ");
    is($_->normalize("なんでやｯ にゃ"), "なんでや にゃ");
};

done_testing;
