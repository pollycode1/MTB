package com.example.mtb

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.speech.RecognizerIntent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingVoice: MethodChannel.Result? = null

    // บันทึกแอพเด้งลง Download/MTB/mtb-crash.txt (และในโฟลเดอร์แอพ) เพื่อส่งให้ดูได้โดยไม่ต้องต่อคอม
    override fun onCreate(savedInstanceState: Bundle?) {
        // ครั้งก่อนปิดไปเอง → เปิดหน้ารายงาน (คนละ process) ให้คัดลอกส่งได้
        try {
            CrashReportActivity.pending(this)?.let {
                startActivity(Intent(this, CrashReportActivity::class.java)
                    .putExtra(CrashReportActivity.EXTRA_TEXT, it)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            }
        } catch (_: Throwable) {}
        super.onCreate(savedInstanceState)
    }

    // ระหว่างซักผ้า: ตั้งเสียงปลุกเป็น x% (จำค่าเดิม) · restore = คืนค่าเดิม
    private fun alarmVolume(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val prefs = getSharedPreferences("mtb_alarm", Context.MODE_PRIVATE)
            val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            when (call.method) {
                "boost" -> {
                    if (!prefs.contains("saved")) prefs.edit().putInt("saved", am.getStreamVolume(AudioManager.STREAM_ALARM)).apply()
                    val pct = (call.arguments as? Int) ?: 80
                    am.setStreamVolume(AudioManager.STREAM_ALARM, Math.round(max * pct / 100f).coerceIn(1, max), 0)
                }
                "restore" -> if (prefs.contains("saved")) {
                    am.setStreamVolume(AudioManager.STREAM_ALARM, prefs.getInt("saved", max).coerceIn(0, max), 0)
                    prefs.edit().remove("saved").apply()
                }
                else -> return result.notImplemented()
            }
            result.success(null)
        } catch (e: Throwable) {
            result.error("volume", e.toString(), null)
        }
    }

    // พิมพ์ด้วยเสียง: ใช้หน้าฟังเสียงของระบบ (Google) ไม่ต้องขอสิทธิ์ไมค์เอง · คืนข้อความหรือ null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mtb/alarm").setMethodCallHandler(::alarmVolume)
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
