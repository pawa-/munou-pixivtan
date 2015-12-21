$(function()
{
    var confidence_min      = 0.2;  // これより低ければ聞き直す
    var recog_error_cnt     = 0;    // 連続して認識エラーした回数
    var recog_error_cnt_max = 5;    // 音声認識を停止する連続認識エラー回数

    var msg_window_elem        = $("#app #msg-window");
    var recog_status_elem      = $("#recog-status", msg_window_elem);
    var user_text_elem         = $("#user",         msg_window_elem);
    var munou_text_elem        = $("#munou",        msg_window_elem);
    var munou_img_elem         = $("#app .chara img");
    var text_dialog_input_elem = $("#text-dialog input");

    var error_en2ja = { "no-speech": "何か話して", "not-allowed": "マイクの使用を許可して" };

    var recognition = new webkitSpeechRecognition();
    recognition.continuous     = true;  // 複数の連続した認識を有効にする
    recognition.interimResults = true;  // 途中結果を返す
    recognition.lang           = "ja";  // 指定しない場合はドキュメントルートのlangが使われる（BCP 47 を参照）（ja｜en-US）
    recognition.start();

    $(document).on("visibilitychange", function()
    {
        if (document.hidden)
        {
            recognition.stop();
        }
        else
        {
            if (recog_error_cnt < recog_error_cnt_max) recognition.start();
        }
    });

    recognition.onresult = function(event)
    {
        recog_status_elem.text("認識中...");

        user_text_elem.text("");
        munou_text_elem.text("");

        recog_error_cnt = 0;

        for (var i = event.resultIndex; i < event.results.length; i++)
        {
            //user_text_elem.text(event.results[i][0].transcript);
        }

        var result = event.results[ event.results.length - 1 ];

        if (result.isFinal)
        {
            var spoken     = result[0].transcript.trim();
            var confidence = result[0].confidence;

            console.log("音声認識結果：" + spoken);
            console.log("信頼度："       + confidence);

            if (result.isFinal && confidence < confidence_min)
            {
                recog_status_elem.text("聞き取れないよ");
                return;
            }

            user_text_elem.text(spoken);
            ajaxDialog(spoken);
        }

        recog_status_elem.text("マイクに向かって発声しよう");
    }

    recognition.onstart = function()
    {
        console.log("音声認識スタート！");
    };

    recognition.onaudiostart = function()
    {
        recog_status_elem.text("マイクに向かって発声しよう");
    };

    recognition.onerror = function(event)
    {
        var error = error_en2ja[event.error] || event.error;

        console.log("音声認識エラー：" + error);

        if (error === "何か話して")
        {
            recog_status_elem.text(error);
        }

        if (++recog_error_cnt >= recog_error_cnt_max)
        {
            recognition.abort();
        }
    };

    recognition.onend = function()
    {
        if (document.hidden) return false;

        if (recog_error_cnt < recog_error_cnt_max)
        {
            recog_status_elem.text("ちょっと待って...");
            recognition.start();
        }
        else
        {
            console.log("音声認識ストップ");
            recog_status_elem.text("停止してもうた");
        }
    };

    text_dialog_input_elem.on('keypress', function(e)
    {
        if (e.which == 13)
        {
            var spoken = $(this).val();
            user_text_elem.text(spoken);
            ajaxDialog(spoken);
        }
    });

    function ajaxDialog(spoken)
    {
        $.ajax({
            type: "POST",
            url: "/",
            dataType: "json",
            data: { "spoken": spoken },
        })
        .done(function(res, textStatus, jqXHR)
        {
            text_dialog_input_elem.val("");
            munou_text_elem.text(res.reply);
            munou_text_elem.html(twemoji.parse(munou_text_elem.text()));
            munou_img_elem.attr("src", res.face_img_path);
        })
        .fail(function(jqXHR, textStatus, errorThrown)
        {
            munou_text_elem.text("なんかエラーが発生したよ");
            console.log(textStatus);
            console.log(errorThrown.message);
        });
    }
});
