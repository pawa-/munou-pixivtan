$(function()
{
    // ブラウザにより異なるAPIを統一
    window.AudioContext = window.AudioContext || window.webkitAudioContext || window.mozAudioContext || window.msAudioContext;
    window.URL          = window.URL || window.webkitURL;

    var audioContext = new AudioContext();            // サンプリングレート、バッファサイズ等
    var analyser     = audioContext.createAnalyser(); // 音量解析用

    // 音声可視化用
    var WIDTH       = 128;
    var HEIGHT      = 128;
    var canvas      = document.querySelector('canvas');
    var drawContext = canvas.getContext('2d');

    canvas.width  = WIDTH;
    canvas.height = HEIGHT;

    // 音声処理開始
    initialize();

    function didntGetUserMedia(e)
    {
        console.log(e);
    }

    var animation = function ()
    {
        /* -------------------- *
         * 音を可視化する       *
         * -------------------- */
        drawContext.clearRect(0, 0, WIDTH, HEIGHT); // 前回の描画結果をクリア

        // 周波数領域の描画
        var freqDomain = new Uint8Array(analyser.frequencyBinCount);
        analyser.getByteFrequencyData(freqDomain);

        for (var i = 0; i < analyser.frequencyBinCount; i++)
        {
            var value    = freqDomain[i];
            var percent  = value / 256;
            var height   = HEIGHT * percent;
            var offset   = HEIGHT - height - 1;
            var barWidth = WIDTH / analyser.frequencyBinCount;
            var hue      = i / analyser.frequencyBinCount * 360;

            drawContext.fillStyle = 'hsl(' + hue + ', 100%, 50%)';
            drawContext.fillRect(i * barWidth, offset, barWidth, height);
        }

        // 時間領域の描画
        var timeDomain = new Uint8Array(analyser.frequencyBinCount);
        analyser.getByteTimeDomainData(timeDomain);

        for (var i = 0; i < analyser.frequencyBinCount; i++)
        {
            var value    = timeDomain[i];
            var percent  = value / 256;
            var height   = HEIGHT * percent;
            var offset   = HEIGHT - height - 1;
            var barWidth = WIDTH / analyser.frequencyBinCount;

            drawContext.fillStyle = 'deeppink';
            drawContext.fillRect(i * barWidth, offset, 1, 1);
        }
        // -- 音の可視化処理 終了

        requestAnimationFrame(animation);
    };

    function gotUserMedia(stream)
    {
        animation();

        var mediastreamsource = audioContext.createMediaStreamSource(stream);
        mediastreamsource.connect(analyser);
    }

    function initialize()
    {
        // audio:true で音声取得を有効にする
        getUserMedia({ "audio": true }, gotUserMedia, didntGetUserMedia);
    }
});
