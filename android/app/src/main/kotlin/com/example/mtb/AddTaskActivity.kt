package com.example.mtb

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsAnimation
import android.view.WindowManager
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject

class AddTaskActivity : Activity() {


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        window.apply {
            setBackgroundDrawableResource(android.R.color.transparent)
            setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_VISIBLE)
            val lp = attributes
            lp.width  = WindowManager.LayoutParams.MATCH_PARENT
            lp.height = WindowManager.LayoutParams.MATCH_PARENT
            attributes = lp
        }

        // ── Sheet ─────────────────────────────────────────────────────────────
        val sheet = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(20), dp(16), dp(20), dp(28))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#1C1C1C"))
                cornerRadii = floatArrayOf(dp(20).toFloat(), dp(20).toFloat(), dp(20).toFloat(), dp(20).toFloat(), 0f, 0f, 0f, 0f)
            }
        }

        val handle = View(this).apply {
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#3A3A3A"))
                cornerRadius = dp(3).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(dp(40), dp(4)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
                setMargins(0, 0, 0, dp(16))
            }
        }

        val titleView = TextView(this).apply {
            text = "เพิ่มงาน"
            textSize = 16f
            setTextColor(Color.parseColor("#888888"))
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, 0, dp(14)) }
        }

        val input = EditText(this).apply {
            hint = "พิมชื่องาน…"
            textSize = 16f
            setTextColor(Color.parseColor("#E2E2E2"))
            setHintTextColor(Color.parseColor("#55E2E2E2"))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#111111"))
                cornerRadius = dp(12).toFloat()
            }
            setPadding(dp(14), dp(14), dp(14), dp(14))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(0, 0, 0, dp(16)) }
            requestFocus()
            setOnEditorActionListener { _, _, _ ->
                val t = text.toString().trim()
                if (t.isNotEmpty()) saveTask(t)
                dismiss(); true
            }
        }

        val btnRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.END }
        // พูดแทนพิมพ์ → บันทึกทันที แอพให้ AI แยกเป็นหลายงานตอนเปิดครั้งถัดไป
        btnRow.addView(TextView(this).apply {
            text = "🎤 พูด"
            textSize = 14f
            setTextColor(Color.parseColor("#E2E2E2"))
            setPadding(dp(14), dp(10), dp(14), dp(10))
            setOnClickListener {
                try { startActivityForResult(MainActivity.voiceIntent(), MainActivity.VOICE_REQUEST) }
                catch (_: android.content.ActivityNotFoundException) {
                    android.widget.Toast.makeText(this@AddTaskActivity, "เครื่องนี้ไม่มีระบบรับเสียงพูด", android.widget.Toast.LENGTH_SHORT).show()
                }
            }
        })
        btnRow.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))
        btnRow.addView(TextView(this).apply {
            text = "ยกเลิก"
            textSize = 14f
            setTextColor(Color.parseColor("#55E2E2E2"))
            setPadding(dp(14), dp(10), dp(14), dp(10))
            setOnClickListener { dismiss() }
        })
        btnRow.addView(TextView(this).apply {
            text = "เพิ่ม"
            textSize = 14f
            setTextColor(Color.parseColor("#E2E2E2"))
            setPadding(dp(18), dp(10), dp(18), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.RECTANGLE
                setColor(Color.parseColor("#2A2A2A"))
                cornerRadius = dp(12).toFloat()
                setStroke(dp(1), Color.parseColor("#333333"))
            }
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply { setMargins(dp(8), 0, 0, 0) }
            setOnClickListener {
                val t = input.text.toString().trim()
                if (t.isNotEmpty()) saveTask(t)
                dismiss()
            }
        })

        sheet.addView(handle)
        sheet.addView(titleView)
        sheet.addView(input)
        sheet.addView(btnRow)

        // ── Root: พื้นที่แตะเพื่อปิด | sheet | keyboardSpacer ─────────────────────
        // ไม่มีพื้นหลังมืด/เฟด — มีแค่ sheet เลื่อนขึ้นอย่างเดียว
        val dimView = View(this).apply {
            setOnClickListener { dismiss() }
        }
        val keyboardSpacer = View(this)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(dimView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(sheet,   LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(keyboardSpacer, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0))

        setContentView(root)
        if (Build.VERSION.SDK_INT >= 34) {
            overrideActivityTransition(OVERRIDE_TRANSITION_OPEN, 0, 0)
            overrideActivityTransition(OVERRIDE_TRANSITION_CLOSE, 0, 0)
        } else {
            overridePendingTransition(0, 0)
        }

        // Keyboard spacer
        fun setSpacer(h: Int) {
            val lp = keyboardSpacer.layoutParams as LinearLayout.LayoutParams
            if (lp.height != h) { lp.height = h; keyboardSpacer.requestLayout() }
        }
        if (Build.VERSION.SDK_INT >= 30) {
            // ขยับตามคีย์บอร์ดทีละเฟรม (ไม่กระตุกตอนคีย์บอร์ดเด้งขึ้น/ลง)
            window.setDecorFitsSystemWindows(false)
            val bottomTypes = WindowInsets.Type.ime() or WindowInsets.Type.navigationBars()
            var animating = false
            root.setOnApplyWindowInsetsListener { _, insets ->
                if (!animating) setSpacer(insets.getInsets(bottomTypes).bottom)
                insets
            }
            root.setWindowInsetsAnimationCallback(object : WindowInsetsAnimation.Callback(DISPATCH_MODE_STOP) {
                override fun onPrepare(animation: WindowInsetsAnimation) { animating = true }
                override fun onProgress(insets: WindowInsets, running: MutableList<WindowInsetsAnimation>): WindowInsets {
                    setSpacer(insets.getInsets(bottomTypes).bottom)
                    return insets
                }
                override fun onEnd(animation: WindowInsetsAnimation) { animating = false; root.requestApplyInsets() }
            })
        } else {
            root.viewTreeObserver.addOnGlobalLayoutListener {
                val rect = Rect()
                root.getWindowVisibleDisplayFrame(rect)
                setSpacer(maxOf(0, root.height - rect.bottom))
            }
        }

    }

    // ไม่มีอนิเมชั่น — sheet โผล่/หายทันที
    private fun dismiss() {
        finish()
        if (Build.VERSION.SDK_INT < 34) overridePendingTransition(0, 0)
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { dismiss() }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != MainActivity.VOICE_REQUEST || resultCode != RESULT_OK) return
        val text = MainActivity.spokenText(data) ?: return
        MtbTasksWidget.addTask(this, JSONObject().apply {
            put("title", text)
            put("type", "inbox")
            put("aiSplit", true) // แอพให้ AI แยกเป็นงานย่อยตอนเปิด
        })
        android.widget.Toast.makeText(this, "เพิ่มแล้ว: $text", android.widget.Toast.LENGTH_SHORT).show()
        dismiss()
    }

    // เพิ่มจาก widget = งานของวันนี้โดยตรง ไม่ผ่านกล่องรับ (plannedFor = วันนี้ 00:00 เวลาท้องถิ่น)
    private fun saveTask(title: String) {
        val cal = java.util.Calendar.getInstance()
        val today = String.format("%04d-%02d-%02dT00:00:00",
            cal.get(java.util.Calendar.YEAR), cal.get(java.util.Calendar.MONTH) + 1, cal.get(java.util.Calendar.DAY_OF_MONTH))
        MtbTasksWidget.addTask(this, JSONObject().apply {
            put("title", title)
            put("type", "task")
            put("plannedFor", today)
        })
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
