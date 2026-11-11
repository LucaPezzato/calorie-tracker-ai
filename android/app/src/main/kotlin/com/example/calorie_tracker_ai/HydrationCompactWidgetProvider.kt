package com.example.calorie_tracker_ai

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class HydrationCompactWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        val numFormat = NumberFormat.getIntegerInstance(Locale.ITALY)

        val waterMl = prefs.getInt("water_ml", 0)
        val waterTarget = prefs.getInt("water_target", 2500)
        val coffeeCups = prefs.getInt("coffee_cups", 0)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_hydration_compact)

            views.setTextViewText(R.id.widget_compact_water_val, numFormat.format(waterMl))
            views.setTextViewText(R.id.widget_compact_water_target, "ml su ${numFormat.format(waterTarget)} ml")
            views.setTextViewText(R.id.widget_compact_coffee_pill, "☕ $coffeeCups")

            // Click body -> Open App
            val openAppPendingIntent = WidgetHelper.createOpenAppPendingIntent(context, 200)
            views.setOnClickPendingIntent(R.id.widget_compact_clickable_body, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_compact_container, openAppPendingIntent)

            // Click Buttons
            views.setOnClickPendingIntent(
                R.id.btn_compact_water_sub,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_WATER_SUB, 201)
            )
            views.setOnClickPendingIntent(
                R.id.btn_compact_water_add,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_WATER_ADD, 202)
            )
            views.setOnClickPendingIntent(
                R.id.btn_compact_water_add500,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_WATER_ADD500, 203)
            )
            views.setOnClickPendingIntent(
                R.id.btn_compact_coffee_add,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_COFFEE_ADD, 204)
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == WidgetHelper.ACTION_WATER_SUB ||
            action == WidgetHelper.ACTION_WATER_ADD ||
            action == WidgetHelper.ACTION_WATER_ADD500 ||
            action == WidgetHelper.ACTION_COFFEE_ADD
        ) {
            WidgetHelper.handleQuickAction(context, action)
            return
        }
        super.onReceive(context, intent)
    }
}
