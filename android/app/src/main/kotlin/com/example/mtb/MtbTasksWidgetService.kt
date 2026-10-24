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

    private data class Row(
        // id = TaskItem.id ใช้ระบุงานตอนกด · idx ใช้เรียงข้อมูลเก่าที่ไม่มี createdAt เท่านั้น
        val title: String, val done: Boolean, val idx: Int, val kind: String, // kind: inbox | idea | task
        val id: Long = -1,
        val doneAt: String = "", val meta: String = "", val overdue: Boolean = false, val createdAt: String = "",
    )
    private var rows = listOf<Row>()
    private var currentTab = "task"

    override fun onCreate()         { reload() }
    override fun onDataSetChanged() { reload() }
    override fun onDestroy()        {}

    private fun reload() {
        val hw = HomeWidgetPlugin.getData(ctx)
        currentTab = hw.getString("widget_tab_$widgetId", "task").let { if (it == "inbox" || it == null) "task" else it }
        loadTasksByType(hw, currentTab)
    }

    private fun loadTasksByType(hw: android.content.SharedPreferences, tab: String) {
        var raw = hw.getString("tasks_json", null)
        if (raw == null) {
            raw = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.tasks_json", null)
        }
        if (raw == null) { rows = emptyList(); return }
        try {
            val list    = JSONArray(raw)
            val inbox   = mutableListOf<Row>()
            val pending = mutableListOf<Row>()
            val done    = mutableListOf<Row>()
            for (i in 0 until list.length()) {
                val t = list.getJSONObject(i)
                if (!t.isNull("archivedAt")) continue
                val type = t.optString("type", "task")
                val title = t.optString("title", "")
                val isDone = t.optBoolean("done", false)
                val id = t.optLong("id", -1)
                when {
                    tab == "idea" && type == "idea" -> pending.add(Row(title, isDone, i, "idea", id))
                    tab == "task" && type == "inbox" -> inbox.add(Row(title, false, i, "inbox", id))
                    tab == "task" && type == "task" ->
                        if (isDone) done.add(Row(title, true, i, "task", id, t.optString("doneAt", "")))
                        else {
                            val (due, overdue) = dueLabel(t)
                            val area = if (t.isNull("area")) "" else t.optString("area", "")
                            pending.add(Row(title, false, i, "task", id, meta = listOf(area, due).filter { it.isNotEmpty() }.joinToString(" · "), overdue = overdue,
                                createdAt = t.optString("createdAt", "")))
                        }
                }
            }
            // งานที่เสร็จล่าสุดอยู่บนสุดของกลุ่มเสร็จแล้ว (doneAt เป็น ISO จึงเทียบเป็นข้อความได้)
            // งานใหม่ล่าสุดบนสุด (เหมือนในแอพ) · ข้อมูลเก่าไม่มี createdAt ใช้ลำดับในลิสต์แทน
            rows = inbox + pending.sortedWith(compareByDescending<Row> { it.createdAt }.thenByDescending { it.idx }) +
                done.sortedByDescending { it.doneAt }
        } catch (_: Exception) { rows = emptyList() }
    }

    // วันที่ที่ต้องทำ = plannedFor ?? deadline (เหมือนในแอพ) → "เกินกำหนด" / "วันนี้" / "พรุ่งนี้" / "อีก N วัน" / "12 พ.ย."
    private fun dueLabel(t: org.json.JSONObject): Pair<String, Boolean> {
        val raw = listOf("plannedFor", "deadline").map { if (t.isNull(it)) "" else t.optString(it, "") }
            .firstOrNull { it.length >= 10 } ?: return "" to false
        return try {
            val y = raw.substring(0, 4).toInt(); val m = raw.substring(5, 7).toInt(); val d = raw.substring(8, 10).toInt()
            val due = java.util.Calendar.getInstance().apply { clear(); set(y, m - 1, d) }
            val now = java.util.Calendar.getInstance()
            val today = java.util.Calendar.getInstance().apply {
                clear(); set(now.get(java.util.Calendar.YEAR), now.get(java.util.Calendar.MONTH), now.get(java.util.Calendar.DAY_OF_MONTH))
            }
            val days = Math.round((due.timeInMillis - today.timeInMillis) / 86_400_000.0).toInt()
            val months = arrayOf("ม.ค.","ก.พ.","มี.ค.","เม.ย.","พ.ค.","มิ.ย.","ก.ค.","ส.ค.","ก.ย.","ต.ค.","พ.ย.","ธ.ค.")
            when {
                days < 0  -> "เกินกำหนด" to true
                days == 0 -> "วันนี้" to false
                days == 1 -> "พรุ่งนี้" to false
                days <= 6 -> "อีก $days วัน" to false
                else      -> "$d ${months[m - 1]}" to false
            }
        } catch (_: Exception) { "" to false }
    }

    override fun getCount()          = rows.size
    override fun getViewTypeCount()  = 3
    override fun getItemId(pos: Int) = pos.toLong()
    override fun hasStableIds()      = false
    override fun getLoadingView()    = null

    override fun getViewAt(pos: Int): RemoteViews {
        if (pos >= rows.size) return RemoteViews(ctx.packageName, R.layout.widget_task_item)
        val row = rows[pos]

        return when {
            // ── Inbox: ชื่อ + [→งาน] [→ไอเดีย] [ลบ✕] ──────────────────────────
            row.kind == "inbox" -> {
                val rv = RemoteViews(ctx.packageName, R.layout.widget_inbox_item)
                rv.setTextViewText(R.id.task_title, row.title)
                rv.setOnClickFillInIntent(R.id.inbox_btn_task, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_ID, row.id)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "to_task")
                })
                rv.setOnClickFillInIntent(R.id.inbox_btn_idea, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_ID, row.id)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "to_idea")
                })
                rv.setOnClickFillInIntent(R.id.inbox_btn_delete, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_ID, row.id)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "delete")
                })
                // แตะชื่อ = no-op (ให้ใช้ปุ่มแทน)
                rv.setOnClickFillInIntent(R.id.task_row, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_ID, -1L)
                })
                rv
            }

            // ── Idea: 💡 ชื่อ (กดเปิดแอพ) + [✕] ──────────────────────────────
            // Template เป็น Activity → fill-in ใส่ data URI
            row.kind == "idea" -> {
                val rv = RemoteViews(ctx.packageName, R.layout.widget_idea_item)
                rv.setTextViewText(R.id.task_title, row.title)
                val openUri = Uri.Builder().scheme("mtb").authority("idea")
                    .appendQueryParameter("id", row.id.toString()).build()
                val openFill = Intent().apply { data = openUri }
                // ตั้งทั้ง row และ title TextView (บาง device LinearLayout ไม่กิน click)
                rv.setOnClickFillInIntent(R.id.task_row, openFill)
                rv.setOnClickFillInIntent(R.id.task_title, openFill)
                // กด ✕ → mtb://idea-del?id=ID
                val delUri = Uri.Builder().scheme("mtb").authority("idea-del")
                    .appendQueryParameter("id", row.id.toString()).build()
                rv.setOnClickFillInIntent(R.id.idea_btn_delete, Intent().apply { data = delUri })
                rv
            }

            // ── Task: checkbox + toggle ─────────────────────────────────────────
            else -> {
                val rv = RemoteViews(ctx.packageName, R.layout.widget_task_item)
                rv.setTextViewText(R.id.task_title, row.title)
                rv.setViewVisibility(R.id.task_check, View.VISIBLE)
                if (row.meta.isEmpty()) {
                    rv.setViewVisibility(R.id.task_meta, View.GONE)
                } else {
                    rv.setViewVisibility(R.id.task_meta, View.VISIBLE)
                    rv.setTextViewText(R.id.task_meta, row.meta)
                    rv.setTextColor(R.id.task_meta, Color.parseColor(if (row.overdue) "#D06050" else "#888888"))
                }
                if (row.done) {
                    rv.setTextColor(R.id.task_title, Color.parseColor("#44888888"))
                    rv.setImageViewResource(R.id.task_check, R.drawable.widget_checkbox_done)
                } else {
                    rv.setTextColor(R.id.task_title, Color.parseColor("#E2E2E2"))
                    rv.setImageViewResource(R.id.task_check, R.drawable.widget_checkbox_pending)
                }
                // ติ๊กได้เฉพาะช่องสี่เหลี่ยม · แตะชื่อ/แถว = เปิดหน้ารายละเอียดงานในแอพ
                rv.setOnClickFillInIntent(R.id.task_check, Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_ID, row.id)
                })
                val openFill = Intent().apply {
                    putExtra(MtbTasksWidget.EXTRA_ID, row.id)
                    putExtra(MtbTasksWidget.EXTRA_ACTION, "open")
                }
                rv.setOnClickFillInIntent(R.id.task_row, openFill)
                rv.setOnClickFillInIntent(R.id.task_title, openFill)
                rv
            }
        }
    }
}
