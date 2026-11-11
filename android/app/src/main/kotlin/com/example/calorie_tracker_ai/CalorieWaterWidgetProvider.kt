package com.example.calorie_tracker_ai

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin
import java.text.NumberFormat
import java.util.Locale

class CalorieWaterWidgetProvider : AppWidgetProvider() {

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        val prefs = HomeWidgetPlugin.getData(context)
        val numFormat = NumberFormat.getIntegerInstance(Locale.ITALY)

        val kcalRemaining = prefs.getInt("kcal_remaining", 2906)
        val kcalTarget = prefs.getInt("kcal_target", 2906)
        val waterMl = prefs.getInt("water_ml", 0)
        val waterTarget = prefs.getInt("water_target", 2500)
        val coffeeCups = prefs.getInt("coffee_cups", 0)
        val proteinG = prefs.getInt("protein_g", 0)
        val carbsG = prefs.getInt("carbs_g", 0)
        val fatG = prefs.getInt("fat_g", 0)

        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_calorie_water)

            views.setTextViewText(R.id.widget_kcal_remaining, numFormat.format(kcalRemaining))
            views.setTextViewText(R.id.widget_kcal_label, "kcal rimanenti")
            views.setTextViewText(R.id.widget_macros_text, "P: ${proteinG}g  •  C: ${carbsG}g  •  G: ${fatG}g")
            views.setTextViewText(
                R.id.widget_water_header,
                "💧 Acqua: ${numFormat.format(waterMl)} / ${numFormat.format(waterTarget)} ml"
            )
            views.setTextViewText(R.id.widget_coffee_pill, "☕ $coffeeCups")

            // Click body -> Open App
            val openAppPendingIntent = WidgetHelper.createOpenAppPendingIntent(context, 100)
            views.setOnClickPendingIntent(R.id.widget_clickable_body, openAppPendingIntent)
            views.setOnClickPendingIntent(R.id.widget_container, openAppPendingIntent)

            // Click Buttons
            views.setOnClickPendingIntent(
                R.id.btn_water_sub,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_WATER_SUB, 101)
            )
            views.setOnClickPendingIntent(
                R.id.btn_water_add,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_WATER_ADD, 102)
            )
            views.setOnClickPendingIntent(
                R.id.btn_water_add500,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_WATER_ADD500, 103)
            )
            views.setOnClickPendingIntent(
                R.id.btn_coffee_add,
                WidgetHelper.createActionPendingIntent(context, WidgetHelper.ACTION_COFFEE_ADD, 104)
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
