package com.example.mtb

import android.app.Activity
import android.app.ActivityManager
import android.app.ApplicationExitInfo
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast
import java.io.File
import java.util.Date

/**
 * Shows why the app last closed unexpectedly (Android's own exit record plus our crash log),
 * so it can be copied and sent without adb. Runs in its own process (":report"), so it stays
 * up even if the main process crashes again right after.
 */
class CrashReportActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // จากไอคอน "MTB รายงาน" ไม่มีข้อความแนบ → แสดงทุกครั้งที่ปิดเองล่าสุด
        val text = intent.getStringExtra(EXTRA_TEXT) ?: report(this, 0L).first
        val pad = (16 * resources.displayMetrics.density).toInt()
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(pad, pad * 2, pad, pad)
            setBackgroundColor(Color.parseColor("#111111"))
        }
        root.addView(TextView(this).apply {
            this.text = "MTB ปิดไปเองครั้งก่อน\nกด \"คัดลอก\" แล้ววางส่งให้ Claude"
            setTextColor(Color.WHITE)
            textSize = 18f
        })
        val buttons = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        buttons.addView(Button(this).apply {
            this.text = "คัดลอก"
            setOnClickListener {
                val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                cm.setPrimaryClip(ClipData.newPlainText("mtb-crash", text))
                Toast.makeText(this@CrashReportActivity, "คัดลอกแล้ว", Toast.LENGTH_SHORT).show()
            }
        })
        buttons.addView(Button(this).apply {
            this.text = "เปิดแอพ"
            setOnClickListener {
                startActivity(Intent(this@CrashReportActivity, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                finish()
            }
        })
        root.addView(buttons)
        root.addView(ScrollView(this).apply {
            addView(TextView(this@CrashReportActivity).apply {
                this.text = text
                setTextColor(Color.LTGRAY)
                textSize = 11f
                setTextIsSelectable(true)
            })
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f))
        setContentView(root)
    }

    companion object {
        const val EXTRA_TEXT = "text"
        private const val PREFS = "mtb_crash_report"
        private const val KEY_SHOWN = "shown_until"

        fun logFile(context: Context) = File(context.filesDir, "mtb-crash.txt")

        /** Report text for unexpected exits since the last report shown, or null. Marks them shown. */
        fun pending(context: Context): String? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val shownUntil = prefs.getLong(KEY_SHOWN, 0L)
            val (text, found) = report(context, shownUntil)
            if (!found) return null
            prefs.edit().putLong(KEY_SHOWN, System.currentTimeMillis()).commit()
            return text
        }

        fun report(context: Context, shownUntil: Long): Pair<String, Boolean> {
            val sb = StringBuilder()
            sb.append("device: ${Build.MANUFACTURER} ${Build.MODEL} · Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT})\n")
            try {
                val pi = context.packageManager.getPackageInfo(context.packageName, 0)
                sb.append("app: ${pi.versionName}\n")
            } catch (_: Throwable) {}
            var found = false
            if (Build.VERSION.SDK_INT >= 30) {
                try {
                    val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
                    for (e in am.getHistoricalProcessExitReasons(context.packageName, 0, 5)) {
                        if (e.timestamp <= shownUntil || e.processName != context.packageName) continue
                        if (e.reason in setOf(ApplicationExitInfo.REASON_EXIT_SELF, ApplicationExitInfo.REASON_USER_REQUESTED,
                                ApplicationExitInfo.REASON_USER_STOPPED)) continue
                        found = true
                        sb.append("\n--- exit ${Date(e.timestamp)} reason=${e.reason} status=${e.status} importance=${e.importance}\n")
                        sb.append("description: ${e.description}\n")
                        try {
                            e.traceInputStream?.use { sb.append(printable(it.readBytes(), 6000)).append('\n') }
                        } catch (_: Throwable) {}
                    }
                } catch (t: Throwable) {
                    sb.append("exit info error: $t\n")
                }
            }
            val log = logFile(context)
            if (log.exists() && log.lastModified() > shownUntil) {
                found = true
                sb.append("\n--- log\n").append(log.readText().takeLast(8000))
            }
            if (!found) sb.append("\nไม่พบการปิดเองที่ระบบจดไว้\n")
            return sb.toString() to found
        }

        // Native crash traces are binary tombstones; keep the readable runs (abort message, frames).
        private fun printable(bytes: ByteArray, max: Int): String {
            val out = StringBuilder()
            val run = StringBuilder()
            for (b in bytes) {
                val c = b.toInt() and 0xff
                if (c in 0x20..0x7e || c == 0x0a) run.append(c.toChar()) else {
                    if (run.length >= 6) out.append(run).append('\n')
                    run.setLength(0)
                }
                if (out.length > max) break
            }
            if (run.length >= 6) out.append(run)
            return out.toString().take(max)
        }
    }
}
