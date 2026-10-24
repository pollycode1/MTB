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
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

class MtbTasksWidget : AppWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE       = "com.example.mtb.TOGGLE_TASK"
        const val ACTION_SWITCH_TAB   = "com.example.mtb.SWITCH_TAB"
        const val EXTRA_ID            = "task_id" // TaskItem.id — ห้ามใช้ลำดับในลิสต์ (ลบ/เพิ่มงานแล้วลำดับเลื่อน)
        const val EXTRA_TAB           = "tab"
        const val EXTRA_WIDGET_ID     = "widget_id"
        const val EXTRA_ACTION        = "action"

        val TAB_IDS = mapOf(
            "task"    to R.id.tab_today,
            "idea"    to R.id.tab_idea,
        )

        fun indexOfId(list: JSONArray, id: Long): Int =
            (0 until list.length()).firstOrNull { list.getJSONObject(it).optLong("id", -1) == id } ?: -1

        // แบบเดียวกับ TaskItem._genId ใน models.dart · ไม่ซ้ำกับงานที่มีอยู่
        fun newId(list: JSONArray): Long {
            val used = (0 until list.length()).map { list.getJSONObject(it).optLong("id", -1) }.toSet()
            var id = 100000 + (System.currentTimeMillis() * 1000) % 1_000_000_000
            while (id in used) id++
            return id
        }

        // เพิ่มงานจากฝั่ง Kotlin (ปุ่ม + ของ widget / แชร์จากแอพอื่น) ลง tasks_json แล้วรีเฟรช widget
        // aiTodo = ให้แอพส่งให้ AI จัดหมวด/ความสำคัญตอนเปิดหรือกลับเข้าแอพครั้งถัดไป
        fun addTask(context: Context, task: JSONObject): Boolean {
            val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            return try {
                val list = JSONArray(flutterPrefs.getString("flutter.tasks_json", "[]") ?: "[]")
                task.put("id", newId(list)) // มี id ตั้งแต่แรก widget จะได้ติ๊ก/เปิดงานนี้ได้ก่อนเปิดแอพ
                if (!task.has("meta")) task.put("meta", "")
                task.put("done", false); task.put("warn", false)
                task.put("createdAt", SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.US).format(Date()))
                task.put("aiTodo", true)
                task.put("doneAt", JSONObject.NULL)
                list.put(task)
                val updated = list.toString()
                flutterPrefs.edit().putString("flutter.tasks_json", updated).apply()

                val pendingCount = (0 until list.length()).count { !list.getJSONObject(it).optBoolean("done") }
                val total = list.length()
                val done  = total - pendingCount
                HomeWidgetPlugin.getData(context).edit()
                    .putInt("pending_tasks", pendingCount)
                    .putInt("total_tasks", total)
                    .putString("tasks_json", updated)  // factory reads from here
                    .apply()

                val mgr = AppWidgetManager.getInstance(context)
                val ids = mgr.getAppWidgetIds(ComponentName(context, MtbTasksWidget::class.java))
                // partial update: only refresh count text + list data (no adapter reset → no flicker)
                val partial = RemoteViews(context.packageName, R.layout.mtb_widget_tasks)
                partial.setTextViewText(R.id.widget_task_count,
                    if (done > 0) "เสร็จ $done/$total" else "เหลือ $pendingCount งาน")
                for (id in ids) mgr.partiallyUpdateAppWidget(id, partial)
                mgr.notifyAppWidgetViewDataChanged(ids, R.id.widget_list)
                true
            } catch (_: Exception) { false }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TOGGLE -> {
                val id     = intent.getLongExtra(EXTRA_ID, -1)
                val action = intent.getStringExtra(EXTRA_ACTION)
                if (id >= 0) when (action) {
                    null -> toggleTask(context, id)               // ติ๊กช่องสี่เหลี่ยม
                    "open" -> openTaskInApp(context, id)
                    else -> handleItemAction(context, id, action) // ปุ่มของรายการรอคัดแยก
                }
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
        }
        super.onReceive(context, intent)
    }

    // เปิดหน้ารายละเอียดงานในแอพ: mtb://task?id=รหัสงาน (ใช้ launch action ของ home_widget ให้ widgetClicked ทำงาน)
    private fun openTaskInApp(context: Context, id: Long) {
        val uri = Uri.Builder().scheme("mtb").authority("task").appendQueryParameter("id", id.toString()).build()
        PendingIntent.getActivity(
            context, 9600 + id.hashCode(),
            Intent(context, MainActivity::class.java).apply {
                action = "es.antonborri.home_widget.action.LAUNCH"
                data   = uri
                flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        ).send()
    }

    // ── Item actions (inbox convert / delete) ─────────────────────────────────

    private fun handleItemAction(context: Context, id: Long, action: String) {
        val hw  = HomeWidgetPlugin.getData(context)
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = flutterPrefs.getString("flutter.tasks_json", null) ?: hw.getString("tasks_json", null) ?: return
        try {
            val list = JSONArray(raw)
            val idx  = indexOfId(list, id)
            if (idx < 0) return
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

    private fun toggleTask(context: Context, id: Long) {
        val flutterPrefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = flutterPrefs.getString("flutter.tasks_json", null) ?: return
        try {
            val list    = JSONArray(raw)
            val idx     = indexOfId(list, id)
            if (idx < 0) return
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
            val tab   = data.getString("widget_tab_$id", "task").let { if (it == "inbox" || it == null) "task" else it }
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
                else -> PendingIntent.getBroadcast(
                    context, 9000 + id,
                    Intent(context, MtbTasksWidget::class.java).apply { action = ACTION_TOGGLE },
                    PendingIntent.FLAG_UPDATE_CURRENT or mutFlag
                )
            }
            views.setPendingIntentTemplate(R.id.widget_list, template)

            // ปุ่มตาราง → เปิดแอพที่หน้าตารางเวลา (mtb://schedule ผ่าน launch action ของ home_widget)
            views.setOnClickPendingIntent(R.id.widget_schedule, PendingIntent.getActivity(
                context, 4500 + id,
                Intent(context, MainActivity::class.java).apply {
                    action = "es.antonborri.home_widget.action.LAUNCH"
                    setData(Uri.parse("mtb://schedule")) // ใช้ setData เพราะใน onUpdate มีตัวแปรชื่อ data อยู่แล้ว
                    flags  = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                },
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            ))

            views.setOnClickPendingIntent(R.id.widget_add, PendingIntent.getActivity(
                context, 4000 + id,
                Intent(context, AddTaskActivity::class.java).apply {
                    // ปิดอนิเมชั่นเปิดหน้าต่างของระบบ/launcher — ให้เหลือแค่ sheet เลื่อนขึ้น
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
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
                val inbox   = countByType(data, "inbox")
                val base    = if (done > 0) "เสร็จ $done/$total" else "เหลือ $pending งาน"
                if (inbox > 0) "รอคัดแยก $inbox · $base" else base
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
