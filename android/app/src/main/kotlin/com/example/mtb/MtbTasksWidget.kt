package com.example.mtb

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
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
        const val ACTION_TOGGLE       = "com.example.mtb.TOGGLE_TASK"
        const val ACTION_SWITCH_TAB   = "com.example.mtb.SWITCH_TAB"
        const val ACTION_INBOX_ACTION = "com.example.mtb.INBOX_ACTION"
        const val ACTION_IDEA_ACTION  = "com.example.mtb.IDEA_ACTION"
        const val EXTRA_IDX           = "task_idx"
        const val EXTRA_TAB           = "tab"
        const val EXTRA_WIDGET_ID     = "widget_id"
        const val EXTRA_ACTION        = "action"
        const val EXTRA_TITLE         = "title"

        val TAB_IDS = mapOf(
            "task"    to R.id.tab_today,
            "inbox"   to R.id.tab_inbox,
            "idea"    to R.id.tab_idea,
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TOGGLE -> {
                val idx = intent.getIntExtra(EXTRA_IDX, -1)
                if (idx >= 0) toggleTask(context, idx)
            }
            ACTION_SWITCH_TAB -> {
                val tab      = intent.getStringExtra(EXTRA_TAB) ?: "task"
                val widgetId = intent.getIntExtra(EXTRA_WIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
                if (widgetId != AppWidgetManager.INVALID_APPWIDGET_ID) {
                    HomeWidgetPlugin.getData(context).edit()
                        .putString("widget_tab_$widgetId", tab).apply()
                    onUpdate(context, AppWidgetManager.getInstance(context), intArrayOf(widgetId))
                }
            }
            ACTION_INBOX_ACTION -> {
                val idx    = intent.getIntExtra(EXTRA_IDX, -1)
                val action = intent.getStringExtra(EXTRA_ACTION) ?: return
                if (idx >= 0) handleItemAction(context, idx, action)
            }
            ACTION_IDEA_ACTION -> {
                val idx    = intent.getIntExtra(EXTRA_IDX, -1)
                val action = intent.getStringExtra(EXTRA_ACTION) ?: return
                when (action) {
                    "open" -> {
                        val title = intent.getStringExtra(EXTRA_TITLE)
                        val uri = if (!title.isNullOrEmpty())
                            Uri.Builder().scheme("mtb").authority("idea")
                                .appendQueryParameter("t", title).build()
                        else Uri.parse("mtb://idea")
                        // ใช้ PendingIntent.send() เลี่ยง background activity launch block (Android 12+)
                        PendingIntent.getActivity(
                            context, (9500 + (title?.hashCode() ?: 0)),
                            Intent(context, MainActivity::class.java).apply {
                                this.action = Intent.ACTION_VIEW
                                data  = uri
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                            },
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        ).send()
                    }
                    "delete" -> if (idx >= 0) handleItemAction(context, idx, "delete")
                }
            }
        }
        super.onReceive(context, intent)
    }

    // ── Item actions (inbox convert / delete) ─────────────────────────────────

    private fun handleItemAction(context: Context, idx: Int, action: String) {
        // อ่านจาก HW data (ตรงกับ idx ที่ widget ใช้)
        val hw  = HomeWidgetPlugin.getData(context)
        val raw = hw.getString("tasks_json", null) ?: return
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        try {
            val list = JSONArray(raw)
            if (idx >= list.length()) return
            when (action) {
                "to_task", "to_idea" -> {
                    val task = list.getJSONObject(idx)
                    task.put("type", if (action == "to_task") "task" else "idea")
                    task.put("lastUpdatedAt",
                        SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()))
                    saveAndRefresh(context, hw, flutterPrefs, list)
                }
                "delete" -> {
                    val newList = JSONArray()
                    for (i in 0 until list.length()) if (i != idx) newList.put(list.get(i))
                    saveAndRefresh(context, hw, flutterPrefs, newList)
                }
            }
        } catch (_: Exception) {}
    }

    private fun saveAndRefresh(
        context: Context,
        hw: android.content.SharedPreferences,
        flutterPrefs: android.content.SharedPreferences,
        list: JSONArray,
    ) {
        val updated = list.toString()
        val pendingCount = (0 until list.length()).count {
            val t = list.getJSONObject(it)
            t.optString("type") == "task" && !t.optBoolean("done")
        }
        hw.edit()
            .putString("tasks_json", updated)
            .putInt("pending_tasks", pendingCount)
            .putInt("total_tasks", list.length())
            .apply()
        flutterPrefs.edit().putString("flutter.tasks_json", updated).apply()
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, MtbTasksWidget::class.java))
        onUpdate(context, mgr, ids)
    }

    // ── Toggle task ───────────────────────────────────────────────────────────

    private fun toggleTask(context: Context, idx: Int) {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = flutterPrefs.getString("flutter.tasks_json", null) ?: return
        try {
            val list    = JSONArray(raw)
            if (idx >= list.length()) return
            val task    = list.getJSONObject(idx)
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
                .putString("tasks_json", updated)
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

    // ── onUpdate ──────────────────────────────────────────────────────────────

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            val data  = HomeWidgetPlugin.getData(context)
            val tab   = data.getString("widget_tab_$id", "task") ?: "task"
            val views = RemoteViews(context.packageName, R.layout.mtb_widget_tasks)

            val dayFmt = SimpleDateFormat("EEE d MMM", Locale("th"))
            views.setTextViewText(R.id.widget_date_label, dayFmt.format(Date()))
            views.setTextViewText(R.id.widget_task_count, countLabel(data, tab))

            // Tab highlights + click intents
            val activeColor   = Color.parseColor("#E2E2E2")
            val inactiveColor = Color.parseColor("#555555")
            for ((tabKey, viewId) in TAB_IDS) {
                views.setTextColor(viewId, if (tabKey == tab) activeColor else inactiveColor)
                val reqCode = when (tabKey) {
                    "inbox"   -> 6000
                    "idea"    -> 7000
                    else      -> 5500
                } + id
                views.setOnClickPendingIntent(viewId, PendingIntent.getBroadcast(
                    context, reqCode,
                    Intent(context, MtbTasksWidget::class.java).apply {
                        action = ACTION_SWITCH_TAB
                        putExtra(EXTRA_TAB, tabKey)
                        putExtra(EXTRA_WIDGET_ID, id)
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                ))
            }

            // Remote list adapter — URI includes tab เพื่อบังคับ factory ใหม่เมื่อสลับแท็บ
            val svcIntent = Intent(context, MtbTasksWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id)
                setData(Uri.fromParts("content", "${id}_$tab", null))
            }
            views.setRemoteAdapter(R.id.widget_list, svcIntent)

            // Template ต่างกันตามแท็บ
            val mutFlag = if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0
            val template: PendingIntent = when (tab) {
                "idea" -> {
                    // ponytail: must use home_widget's launch action — ACTION_VIEW ไม่ทริกเกอร์ widgetClicked stream
                    PendingIntent.getActivity(
                        context, 9100 + id,
                        Intent(context, MainActivity::class.java).apply {
                            action = "es.antonborri.home_widget.action.LAUNCH"
                            flags  = Intent.FLAG_ACTIVITY_NEW_TASK or
                                     Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                     Intent.FLAG_ACTIVITY_SINGLE_TOP
                        },
                        PendingIntent.FLAG_UPDATE_CURRENT or mutFlag
                    )
                }
                "inbox" -> PendingIntent.getBroadcast(
                    context, 9000 + id,
                    Intent(context, MtbTasksWidget::class.java).apply { action = ACTION_INBOX_ACTION },
                    PendingIntent.FLAG_UPDATE_CURRENT or mutFlag
                )
                else -> PendingIntent.getBroadcast(
                    context, 9000 + id,
                    Intent(context, MtbTasksWidget::class.java).apply { action = ACTION_TOGGLE },
                    PendingIntent.FLAG_UPDATE_CURRENT or mutFlag
                )
            }
            views.setPendingIntentTemplate(R.id.widget_list, template)

            views.setOnClickPendingIntent(R.id.widget_add, PendingIntent.getActivity(
                context, 4000 + id,
                Intent(context, AddTaskActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

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

    // ── Helpers ───────────────────────────────────────────────────────────────

    private fun countLabel(data: android.content.SharedPreferences, tab: String): String {
        return when (tab) {
            "task" -> {
                val pending = data.getInt("pending_tasks", 0)
                val total   = data.getInt("total_tasks", 0)
                val done    = total - pending
                if (done > 0) "เสร็จ $done/$total" else "เหลือ $pending งาน"
            }
            "inbox"   -> "${countByType(data, "inbox")} รายการ"
            "idea"    -> "${countByType(data, "idea")} ไอเดีย"
            else -> ""
        }
    }

    private fun countByType(data: android.content.SharedPreferences, type: String): Int {
        val raw = data.getString("tasks_json", null) ?: return 0
        return try {
            val list = JSONArray(raw)
            (0 until list.length()).count {
                val t = list.getJSONObject(it)
                t.optString("type") == type && t.isNull("archivedAt")
            }
        } catch (_: Exception) { 0 }
    }
}
