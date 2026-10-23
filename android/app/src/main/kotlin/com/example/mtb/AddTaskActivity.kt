package com.example.mtb

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.graphics.Color
import android.graphics.Rect
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewTreeObserver
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import org.json.JSONObject

class AddTaskActivity : Activity() {

    private lateinit var sheetView: View
    private lateinit var dimView2: View

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
                dismissWithAnimation(); true
            }
        }

        val btnRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.END }
        btnRow.addView(TextView(this).apply {
            text = "ยกเลิก"
            textSize = 14f
            setTextColor(Color.parseColor("#55E2E2E2"))
            setPadding(dp(14), dp(10), dp(14), dp(10))
            setOnClickListener { dismissWithAnimation() }
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
                dismissWithAnimation()
            }
        })

        sheet.addView(handle)
        sheet.addView(titleView)
        sheet.addView(input)
        sheet.addView(btnRow)

        // ── Root: dim | sheet | keyboardSpacer ───────────────────────────────
        val dimView = View(this).apply {
            setBackgroundColor(Color.parseColor("#80000000"))
            alpha = 0f
            setOnClickListener { dismissWithAnimation() }
        }
        val keyboardSpacer = View(this)
        val root = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(dimView, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0, 1f))
        root.addView(sheet,   LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT))
        root.addView(keyboardSpacer, LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, 0))

        setContentView(root)
        overridePendingTransition(0, 0)

        // Slide up from bottom
        sheet.viewTreeObserver.addOnGlobalLayoutListener(object : ViewTreeObserver.OnGlobalLayoutListener {
            override fun onGlobalLayout() {
                sheet.viewTreeObserver.removeOnGlobalLayoutListener(this)
                sheet.translationY = sheet.height.toFloat()
                sheet.animate().translationY(0f).setDuration(300)
                    .setInterpolator(DecelerateInterpolator(1.5f)).start()
                dimView.animate().alpha(1f).setDuration(250).start()
            }
        })

        // Keyboard spacer
        root.viewTreeObserver.addOnGlobalLayoutListener {
            val rect = Rect()
            root.getWindowVisibleDisplayFrame(rect)
            val kbHeight = maxOf(0, root.height - rect.bottom)
            val lp = keyboardSpacer.layoutParams as LinearLayout.LayoutParams
            if (lp.height != kbHeight) { lp.height = kbHeight; keyboardSpacer.requestLayout() }
        }

        this.sheetView = sheet
        this.dimView2  = dimView
    }

    private fun dismissWithAnimation() {
        sheetView.animate().translationY(sheetView.height.toFloat())
            .setDuration(240).setInterpolator(DecelerateInterpolator()).start()
        dimView2.animate().alpha(0f).setDuration(200).withEndAction {
            finish(); overridePendingTransition(0, 0)
        }.start()
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() { dismissWithAnimation() }

    private fun saveTask(title: String) {
        val flutterPrefs = getSharedPreferences("FlutterSharedPreferences", MODE_PRIVATE)
        val raw   = flutterPrefs.getString("flutter.tasks_json", "[]") ?: "[]"
        try {
            val list = JSONArray(raw)
            list.put(JSONObject().apply {
                put("title", title); put("meta", "inbox")
                put("done", false);  put("warn", false)
                put("type", "inbox")
                put("doneAt", JSONObject.NULL)
                put("tag", JSONObject.NULL); put("tagBg", JSONObject.NULL); put("tagColor", JSONObject.NULL)
            })
            val updated = list.toString()
            flutterPrefs.edit().putString("flutter.tasks_json", updated).apply()

            val pendingCount = (0 until list.length()).count { !list.getJSONObject(it).optBoolean("done") }
            val total = list.length()
            val done  = total - pendingCount
            HomeWidgetPlugin.getData(this).edit()
                .putInt("pending_tasks", pendingCount)
                .putInt("total_tasks", total)
                .putString("tasks_json", updated)  // factory reads from here
                .apply()

            val mgr = AppWidgetManager.getInstance(this)
            val ids = mgr.getAppWidgetIds(ComponentName(this, MtbTasksWidget::class.java))
            // partial update: only refresh count text + list data (no adapter reset → no flicker)
            val partial = android.widget.RemoteViews(packageName, R.layout.mtb_widget_tasks)
            partial.setTextViewText(R.id.widget_task_count,
                if (done > 0) "เสร็จ $done/$total" else "เหลือ $pendingCount งาน")
            for (id in ids) mgr.partiallyUpdateAppWidget(id, partial)
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        } catch (_: Exception) {}
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
