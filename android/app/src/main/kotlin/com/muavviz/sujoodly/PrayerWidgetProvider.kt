package com.muavviz.sujoodly

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.app.PendingIntent
import android.widget.RemoteViews
import android.content.SharedPreferences
import com.muavviz.sujoodly.MainActivity
import com.muavviz.sujoodly.R
import es.antonborri.home_widget.HomeWidgetPlugin

class PrayerWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        for (appWidgetId in appWidgetIds) {
            updateAppWidget(context, appWidgetManager, appWidgetId)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)

        // Handle "Next" Click (Tapping Background)
        if (intent.action == "ACTION_NEXT") {
            val widgetData = HomeWidgetPlugin.getData(context)
            val count = widgetData.getInt("fav_count", 0)
            var currentIndex = widgetData.getInt("current_index", 0)

            if (count > 1) {
                currentIndex = (currentIndex + 1) % count
                widgetData.edit().putInt("current_index", currentIndex).apply()

                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(android.content.ComponentName(context, PrayerWidgetProvider::class.java))
                onUpdate(context, manager, ids)
            }
        }
    }

    companion object {
        fun updateAppWidget(context: Context, appWidgetManager: AppWidgetManager, appWidgetId: Int) {
            val widgetData = HomeWidgetPlugin.getData(context)
            val count = widgetData.getInt("fav_count", 0)
            val index = widgetData.getInt("current_index", 0)

            val views = RemoteViews(context.packageName, R.layout.widget_layout)

            val safeIndex = if (index < count) index else 0

            val name = widgetData.getString("masjid_name_$safeIndex", "Sujoodly")
            val pName = widgetData.getString("prayer_name_$safeIndex", "No Favorites")
            val pTime = widgetData.getString("prayer_time_$safeIndex", "--:--")

            views.setTextViewText(R.id.masjid_name, name)
            views.setTextViewText(R.id.prayer_name, pName)
            views.setTextViewText(R.id.prayer_time, pTime)

            if (count > 1) {
                val sb = StringBuilder()
                for (i in 0 until count) {
                    if (i == safeIndex) sb.append("● ") else sb.append("○ ")
                }
                views.setTextViewText(R.id.dots_indicator, sb.toString())
            } else {
                views.setTextViewText(R.id.dots_indicator, "")
            }

            // 1. TAP BACKGROUND -> NEXT MASJID
            val nextIntent = Intent(context, PrayerWidgetProvider::class.java).apply { action = "ACTION_NEXT" }
            val nextPending = PendingIntent.getBroadcast(context, 0, nextIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.widget_root, nextPending)

            // 2. TAP NAME -> OPEN APP (Replaces the icon)
            val openIntent = Intent(context, MainActivity::class.java)
            val openPending = PendingIntent.getActivity(context, 0, openIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            views.setOnClickPendingIntent(R.id.masjid_name, openPending)

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}