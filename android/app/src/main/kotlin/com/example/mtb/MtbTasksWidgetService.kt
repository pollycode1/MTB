package com.example.mtb

import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.widget.RemoteViews

import android.widget.RemoteViewsService
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray

class MtbTasksWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        TasksRemoteViewsFactory(applicationContext)
}

class TasksRemoteViewsFactory(private val ctx: Context) : RemoteViewsService.RemoteViewsFactory {
    private data class Row(val title: String, val done: Boolean, val idx: Int)
    private var rows = listOf<Row>()

    override fun onCreate() { reload() }
    override fun onDataSetChanged() { reload() }
    override fun onDestroy() {}

    private fun reload() {
        // Read from home_widget data store (written by Flutter _updateWidget & AddTaskActivity)
        val hw  = HomeWidgetPlugin.getData(ctx)
        var raw = hw.getString("tasks_json", null)
        // Fallback: Flutter's shared_preferences file
        if (raw == null) {
            raw = ctx.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
                .getString("flutter.tasks_json", null)
        }
        if (raw == null) { rows = emptyList(); return }
        try {
            val list = JSONArray(raw)
            val pending = mutableListOf<Row>()
            val done    = mutableListOf<Row>()
            for (i in 0 until list.length()) {
                val t = list.getJSONObject(i)
                if (t.optString("type", "task") != "task") continue
                val isDone = t.optBoolean("done", false)
                val row = Row(t.optString("title", ""), isDone, i)
                if (isDone) done.add(row) else pending.add(row)
            }
            rows = pending + done
        } catch (_: Exception) { rows = emptyList() }
    }

    override fun getCount() = rows.size
    override fun getViewTypeCount() = 1
    override fun getItemId(pos: Int) = pos.toLong()
    override fun hasStableIds() = false
    override fun getLoadingView() = null

    override fun getViewAt(pos: Int): RemoteViews {
        if (pos >= rows.size) return RemoteViews(ctx.packageName, R.layout.widget_task_item)
        val row = rows[pos]
        val rv = RemoteViews(ctx.packageName, R.layout.widget_task_item)
        rv.setTextViewText(R.id.task_title, row.title)
        if (row.done) {
            rv.setTextColor(R.id.task_title, Color.parseColor("#44888888"))
            rv.setImageViewResource(R.id.task_check, R.drawable.widget_checkbox_done)
        } else {
            rv.setTextColor(R.id.task_title, Color.parseColor("#E2E2E2"))
            rv.setImageViewResource(R.id.task_check, R.drawable.widget_checkbox_pending)
        }
        val fillIn = Intent().apply { putExtra(MtbTasksWidget.EXTRA_IDX, row.idx) }
        rv.setOnClickFillInIntent(R.id.task_row, fillIn)
        return rv
    }
}
