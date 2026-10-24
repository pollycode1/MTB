package com.example.mtb

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingVoice: MethodChannel.Result? = null

    // พิมพ์ด้วยเสียง: ใช้หน้าฟังเสียงของระบบ (Google) ไม่ต้องขอสิทธิ์ไมค์เอง · คืนข้อความหรือ null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mtb/voice").setMethodCallHandler { call, result ->
            if (call.method != "listen") return@setMethodCallHandler result.notImplemented()
            pendingVoice?.success(null)
            pendingVoice = result
            try {
                startActivityForResult(voiceIntent(), VOICE_REQUEST)
            } catch (_: ActivityNotFoundException) {
                pendingVoice = null
                result.error("no_recognizer", "เครื่องนี้ไม่มีระบบรับเสียงพูด", null)
            }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != VOICE_REQUEST) return
        pendingVoice?.success(if (resultCode == Activity.RESULT_OK) spokenText(data) else null)
        pendingVoice = null
    }

    companion object {
        const val VOICE_REQUEST = 7301

        fun voiceIntent() = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "th-TH")
            putExtra(RecognizerIntent.EXTRA_PROMPT, "พูดงานที่ต้องทำ (หลายงานได้)")
        }

        fun spokenText(data: Intent?): String? =
            data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)?.firstOrNull()?.trim()?.ifEmpty { null }
    }
}
