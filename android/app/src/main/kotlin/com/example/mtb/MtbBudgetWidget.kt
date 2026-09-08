package com.example.mtb

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class MtbBudgetWidget : AppWidgetProvider() {

    private fun openAppIntent(context: Context, uri: String, code: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(uri)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context, code, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        for (id in appWidgetIds) {
            val data     = HomeWidgetPlugin.getData(context)
            val views    = RemoteViews(context.packageName, R.layout.mtb_widget_budget)

            views.setInt(R.id.widget_root, "setBackgroundColor", Color.parseColor("#F7F3EA"))

            val spent    = data.getInt("spent_today", 0)
            val budget   = data.getInt("week_budget", 2500)
            val weekBase = data.getInt("week_base", 1180)
            val weekSpent = weekBase + spent
            val left     = (budget - weekSpent).coerceAtLeast(0)
            val pct      = ((weekSpent.toFloat() / budget) * 100).toInt().coerceIn(0, 100)

            views.setTextViewText(R.id.widget_spent, "฿$spent")
            views.setTextViewText(R.id.widget_remaining, "เหลือในงบสัปดาห์ ฿$left")
            views.setProgressBar(R.id.widget_progress, 100, pct, false)

            views.setOnClickPendingIntent(R.id.widget_root, openAppIntent(context, "mtb://expenses", 1000))

            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
