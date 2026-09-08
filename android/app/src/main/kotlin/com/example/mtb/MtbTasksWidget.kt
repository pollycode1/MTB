package com.example.mtb

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import org.json.JSONArray
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MtbTasksWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "com.example.mtb.TOGGLE_TASK"
        const val EXTRA_IDX    = "task_idx"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE) {
            val idx = intent.getIntExtra(EXTRA_IDX, -1)
            if (idx >= 0) toggleTask(context, idx)
        }
        super.onReceive(context, intent)
    }

    private fun toggleTask(context: Context, idx: Int) {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw   = flutterPrefs.getString("flutter.tasks_json", null) ?: return
        try {
            val list  = JSONArray(raw)
            if (idx >= list.length()) return
            val task  = list.getJSONObject(idx)
            val wasDone = task.optBoolean("done", false)
            task.put("done", !wasDone)
            task.put("doneAt", if (!wasDone)
                SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()) else null)
            val updated = list.toString()
            flutterPrefs.edit().putString("flutter.tasks_json", updated).apply()

            val pendingCount = (0 until list.length()).count { !list.getJSONObject(it).optBoolean("done") }
            HomeWidgetPlugin.getData(context).edit()
                .putInt("pending_tasks", pendingCount)
                .putInt("total_tasks", list.length())
                .putString("tasks_json", updated)  // factory reads from here
                .apply()

            val mgr  = AppWidgetManager.getInstance(context)
            val ids  = mgr.getAppWidgetIds(ComponentName(context, MtbTasksWidget::class.java))
            val done = list.length() - pendingCount
            val partial = RemoteViews(context.packageName, R.layout.mtb_widget_tasks)
            partial.setTextViewText(R.id.widget_task_count,
                if (done > 0) "เสร็จ $done/${list.length()}" else "เหลือ $pendingCount งาน")
            for (id in ids) mgr.partiallyUpdateAppWidget(id, partial)
            mgr.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
        } catch (_: Exception) {}
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            val data  = HomeWidgetPlugin.getData(context)
            val views = RemoteViews(context.packageName, R.layout.mtb_widget_tasks)

            val pending = data.getInt("pending_tasks", 0)
            val total   = data.getInt("total_tasks", 0)
            val done    = total - pending

            val dayFmt = SimpleDateFormat("EEE d MMM", Locale("th"))
            views.setTextViewText(R.id.widget_date_label, dayFmt.format(Date()))
            views.setTextViewText(R.id.widget_task_count,
                if (done > 0) "เสร็จ $done/$total" else "เหลือ $pending งาน")

            // Remote adapter for scrollable list
            val svcIntent = Intent(context, MtbTasksWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                setData(Uri.fromParts("content", id.toString(), null))
            }
            views.setRemoteAdapter(R.id.widget_list, svcIntent)

            // Mutable template so fill-in intent can merge task index
            val mutFlag = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
            val toggleTemplate = PendingIntent.getBroadcast(
                context, id,
                Intent(context, MtbTasksWidget::class.java).apply { action = ACTION_TOGGLE },
                PendingIntent.FLAG_UPDATE_CURRENT or mutFlag
            )
            views.setPendingIntentTemplate(R.id.widget_list, toggleTemplate)

            // + opens AddTaskActivity
            views.setOnClickPendingIntent(R.id.widget_add, PendingIntent.getActivity(
                context, 4000 + id,
                Intent(context, AddTaskActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            // Header opens app
            views.setOnClickPendingIntent(R.id.widget_date_label, PendingIntent.getActivity(
                context, 5000 + id,
                Intent(context, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    setData(Uri.parse("mtb://open"))
                    flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            appWidgetManager.updateAppWidget(id, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(id, R.id.widget_list)
        }
    }
}
