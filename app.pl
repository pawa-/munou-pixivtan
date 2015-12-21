#!/usr/bin/env perl

use Mojolicious::Lite;
use FindBin ();
use lib "$FindBin::Bin/lib";
use Munou::Responder ();
use Config::Tiny;
use Log::Handler;

my $CONFIG             = Config::Tiny->read('config.conf', 'encoding(utf-8)') // die '設定の読み込みに失敗しました';
my $MUNOU_NAME         = $CONFIG->{munou}{name};
my $MUNOU_IMG_DIR_PATH = $CONFIG->{munou}{chara_img_dir_path};
my $MUNOU_IMG_PREFIX   = '.png';

my $log = Log::Handler->new(
    file   => $CONFIG->{log_file},
    screen => $CONFIG->{log_screen},
);

get '/' => sub {
    my $c = shift;
    $c->stash(munou_name => $MUNOU_NAME, munou_img_dir_path => $MUNOU_IMG_DIR_PATH);
    $c->render(template => 'index');
};

post '/' => sub {
    my $c = shift;

    my $spoken = $c->param('spoken') // '';

    # 更新を反映
    Munou::Responder::db_reopen();

    my ($reply, $emotion) = Munou::Responder::respond($spoken, 'あなた');

    $log->notice("emotion: $emotion");

    $c->render(json => { reply => $reply, face_img_path => "$MUNOU_IMG_DIR_PATH$emotion$MUNOU_IMG_PREFIX" });
};

END {
    $log->notice('DBを閉じて終了しました');
    Munou::Responder::db_close();
}

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title "${munou_name}とおしゃべりしようよ";
<style>
body {
  margin: 0px;
}

#app {
  z-index: 0;
  position: absolute;
  top: 0px;
  left: 0px;
  width: 640px;
  height: 480px;
  background-image: url("/img/back/heya_hiru.jpg");
}

.chara img {
  z-index: 10;
  position: absolute;
  bottom: 0px;
  left: 170px;
}

#msg-window {
  z-index: 20;
  position: absolute;
  bottom: 0px;
  right: 0px;
  width: 100%;
  height: 100px;
  opacity: 0.8;
  background-color: #000;
}

#msg-window #textarea {
  padding: 7px;
}

#msg-window .recog-status {
  color: #fff;
  padding: 4px 0px 8px 0px;
}

#msg-window .text {
  color: #fff;
  padding: 5px 0px;
}

#msg-window .name {
  display: inline-block;
  width: 100px;
  text-align: right;
}

.voice-volume {
  z-index: 20;
  position: absolute;
  bottom: 100px;
  left: 0px;
  width: 128px;
  height: 128px;
  opacity: 0.9;
  background-color: #fff;
}

img.emoji {
  height: 1em;
  width: 1em;
  margin: 0 .05em 0 .1em;
  vertical-align: -0.1em;
}

#text-dialog {
  position: absolute;
  top: 500px;
  left: 20px;
}

#text-dialog input {
  width: 333px;
  padding: 2px;
}
</style>

<div id="app">
  <div class="chara">
    <img src="<%= $munou_img_dir_path %>normal.png" width="300" height="400" alt="">
  </div>
  <div id="msg-window">
    <div id="textarea">
      <div class="recog-status">音声認識：「<span id="recog-status">起動中...</span>」</div>
      <div class="text"><span class="name">あなた：</span>「<span id="user"></span>」</div>
      <div class="text"><span class="name"><%= $munou_name %>：</span>「<span id="munou"></span>」</div>
    </div>
  </div>
  <div class="voice-volume"><canvas></canvas></div>
</div>

<div id="text-dialog">
  デバッグ用：<input type="text" name="spoken" placeholder="メッセージを入力してエンターキーを押して送信できます。" style="width:333px;">
</div>

<script src="//twemoji.maxcdn.com/twemoji.min.js"></script>
<script src="/js/adapter.js"></script>
<script src="http://code.jquery.com/jquery-1.11.1.min.js"></script>
<script src="/js/sound_visualization.js"></script>
<script src="/js/dialog.js"></script>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html lang="ja">
  <meta charset="utf-8">
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
