# ピクシブたんとおしゃべりしようよ

## 事前に必要なもの

- Tokyo Cabinet
- Tokyo Cabinet の Perl用API
- MeCab

### 背景画像

以下からダウンロードして public/img/back/heya\_hiru.jpg に配置してください。

http://www.studio-74.net/material/10background/10023_iinchoheya_a.jpg


## 学習

config.conf の [twitter\_api] をあなたが取得したもの書き換えて

```
./learning
```

してください。

## 起動

事前に

```
cpanm Carton
```

```
carton install
```

して

```
./munou
```

で起動してください。

## 補足

### インストールしたのに carton がないと怒られる

plenv を使っている場合は、plenv rehash するといいかも。
