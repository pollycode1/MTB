package com.example.mtb

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class MtbTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        val widgetId = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, -1)
        return TasksRemoteViewsFactory(applicationContext, widgetId)
    }
}

class TasksRemoteViewsFactory(
    private val ctx: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    private data class Row(val title: String, val done: Boolean, val idx: Int, val isTask: Boolean)
    private var rows = listOf<Row>()
    private var currentTab = "task"

    override fun onCreate()         { reload() }
    override fun onDataSetChanged() { reload() }
    override fun onDestroy()        {}

    private fun reload() {
        val hw = HomeWidgetPlugin.getData(ctx)
        currentTab = hw.getString("widget_tab_$widgetId", "task") ?: "task"
        loadTasksByType(hw, currentTab)
    }

    private fun loadTasksByType(hw: android.content.SharedPreferences, type: String) {
        var raw = hw.getString("tasks_json", null)
        if (raw == null) {
            raw = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.tasks_json", null)
        }
        if (raw == null) { rows = emptyList(); return }
        try {
            val list    = JSONArray(raw)
            val pending = mutableListOf<Row>()
            val done    = mutableListOf<Row>()
            for (i in 0 until list.length()) {
                val t = list.getJSONObject(i)
                if (t.optString("type", "task") != type) continue
                if (!t.isNull("archivedAt")) continue
                val isDone = t.optBoolean("done", false)
                val row = Row(t.optString("title", ""), isDone, i, type == "task")
                if (isDone) done.add(row) else pending.add(row)
            }
            rows = pending + done
        } catch (_: Exception) { rows = emptyList() }
    }

    override fun getCount()          = rows.size
    override fun getViewTypeCount()  = 1
    override fun getItemId(pos: Int) = pos.toLong()
    override fun hasStableIds()      = false
    override fun getLoadingView()    = null

    override fun getViewAt(pos: Int): RemoteViews {
        if (pos >= rows.size) return RemoteViews(ctx.packageName, R.layout.widget_task_item)
        val row = rows[pos]

        return when {
            // ── Inbox: ชื่อ + [→งาน] [→ไอเดีย] [ลบ✕] ──────────────────────────
            currentTab == "inbox" -> {
                val rv = RemoteViews(ctx.packageName, R.layout.widget_inbox_item)
                rv.setTextViewText(R.id.task_title, row.title)
                rv.setOnClickFillInIntent(R.id.inbox_btn_task, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_IDX, row.idx)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "to_task")
                })
                rv.setOnClickFillInIntent(R.id.inbox_btn_idea, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_IDX, row.idx)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "to_idea")
                })
                rv.setOnClickFillInIntent(R.id.inbox_btn_delete, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_IDX, row.idx)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "delete")
                })
                // แตะชื่อ = no-op (ให้ใช้ปุ่มแทน)
                rv.setOnClickFillInIntent(R.id.task_row, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_IDX, -1)
                })
                rv
            }

            // ── Idea: 💡 ชื่อ (กดเปิดแอพ) + [✕] ──────────────────────────────
            // Template เป็น Activity → fill-in ใส่ data URI
            currentTab == "idea" -> {
                val rv = RemoteViews(ctx.packageName, R.layout.widget_idea_item)
                rv.setTextViewText(R.id.task_title, row.title)
                val openUri = Uri.Builder().scheme("mtb").authority("idea")
                    .appendQueryParameter("t", row.title).build()
                val openFill = Intent().apply { data = openUri }
                // ตั้งทั้ง row และ title TextView (บาง device LinearLayout ไม่กิน click)
                rv.setOnClickFillInIntent(R.id.task_row, openFill)
                rv.setOnClickFillInIntent(R.id.task_title, openFill)
                // กด ✕ → mtb://idea-del?t=TITLE
                val delUri = Uri.Builder().scheme("mtb").authority("idea-del")
                    .appendQueryParameter("t", row.title).build()
                rv.setOnClickFillInIntent(R.id.idea_btn_delete, Intent().apply { data = delUri })
                rv
            }

            // ── Task: checkbox + toggle ─────────────────────────────────────────
            else -> {
                val rv = RemoteViews(ctx.packageName, R.layout.widget_task_item)
                rv.setTextViewText(R.id.task_title, row.title)
                rv.setViewVisibility(R.id.task_check, View.VISIBLE)
                if (row.done) {
                    rv.setTextColor(R.id.task_title, Color.parseColor("#44888888"))
                    rv.setImageViewResource(R.id.task_check, R.drawable.widget_checkbox_done)
                } else {
                    rv.setTextColor(R.id.task_title, Color.parseColor("#E2E2E2"))
                    rv.setImageViewResource(R.id.task_check, R.drawable.widget_checkbox_pending)
                }
                rv.setOnClickFillInIntent(R.id.task_row, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_IDX, row.idx)
                })
                rv
            }
        }
    }
}
