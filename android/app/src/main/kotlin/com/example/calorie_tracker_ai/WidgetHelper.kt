package com.example.calorie_tracker_ai

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.max

object WidgetHelper {
    const val ACTION_WATER_SUB = "com.example.calorie_tracker_ai.ACTION_WATER_SUB"
    const val ACTION_WATER_ADD = "com.example.calorie_tracker_ai.ACTION_WATER_ADD"
    const val ACTION_WATER_ADD500 = "com.example.calorie_tracker_ai.ACTION_WATER_ADD500"
    const val ACTION_COFFEE_ADD = "com.example.calorie_tracker_ai.ACTION_COFFEE_ADD"

    fun getTodayDate(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return sdf.format(Date())
    }

    fun handleQuickAction(context: Context, action: String?) {
        val prefs = HomeWidgetPlugin.getData(context)
        var waterMl = prefs.getInt("water_ml", 0)
        var coffeeCups = prefs.getInt("coffee_cups", 0)

        when (action) {
            ACTION_WATER_SUB -> {
                waterMl = max(0, waterMl - 250)
            }
            ACTION_WATER_ADD -> {
                waterMl += 250
            }
            ACTION_WATER_ADD500 -> {
                waterMl += 500
            }
            ACTION_COFFEE_ADD -> {
                coffeeCups += 1
            }
            else -> return
        }

        prefs.edit()
            .putInt("water_ml", waterMl)
            .putInt("coffee_cups", coffeeCups)
            .apply()

        // Directly persist to SQLite so it's guaranteed saved
        updateDatabase(context, waterMl, coffeeCups)

        // Notify Flutter background callback
        notifyFlutterBackground(context, action, waterMl, coffeeCups)

        // Refresh all widgets
        updateAllWidgets(context)
    }

    private fun updateDatabase(context: Context, waterMl: Int, coffeeCups: Int) {
        try {
            val dbFile = File(context.filesDir.parentFile, "app_flutter/calorie_tracker_ai.sqlite")
            if (!dbFile.exists()) return

            val db = SQLiteDatabase.openDatabase(dbFile.path, null, SQLiteDatabase.OPEN_READWRITE)
            val today = getTodayDate()
            val nowIso = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS", Locale.getDefault()).format(Date())

            val cursor = db.rawQuery("SELECT date FROM daily_metrics WHERE date = ?", arrayOf(today))
            val exists = cursor.moveToFirst()
            cursor.close()

            if (exists) {
                db.execSQL(
                    "UPDATE daily_metrics SET water_ml = ?, coffee_cups = ?, updated_at = ? WHERE date = ?",
                    arrayOf(waterMl, coffeeCups, nowIso, today)
                )
            } else {
                db.execSQL(
                    "INSERT INTO daily_metrics (date, water_ml, coffee_cups, weight_kg, updated_at) VALUES (?, ?, ?, NULL, ?)",
                    arrayOf(today, waterMl, coffeeCups, nowIso)
                )
            }
            db.close()
        } catch (_: Exception) {
            // Ignore if DB is currently locked by WAL
        }
    }

    private fun notifyFlutterBackground(context: Context, action: String, waterMl: Int, coffeeCups: Int) {
        try {
            val intent = Intent("es.antonborri.home_widget.action.BACKGROUND").apply {
                component = ComponentName(context, "es.antonborri.home_widget.HomeWidgetBackgroundReceiver")
                data = Uri.parse("calorietracker://widget_action?action=$action&water=$waterMl&coffee=$coffeeCups")
            }
            context.sendBroadcast(intent)
        } catch (_: Exception) {}
    }

    fun updateAllWidgets(context: Context) {
        val appWidgetManager = AppWidgetManager.getInstance(context)

        val fullIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, CalorieWaterWidgetProvider::class.java)
        )
        if (fullIds.isNotEmpty()) {
            val intent = Intent(context, CalorieWaterWidgetProvider::class.java).apply {
                this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, fullIds)
            }
            context.sendBroadcast(intent)
        }

        val compactIds = appWidgetManager.getAppWidgetIds(
            ComponentName(context, HydrationCompactWidgetProvider::class.java)
        )
        if (compactIds.isNotEmpty()) {
            val intent = Intent(context, HydrationCompactWidgetProvider::class.java).apply {
                this.action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, compactIds)
            }
            context.sendBroadcast(intent)
        }
    }

    fun createActionPendingIntent(context: Context, action: String, requestCode: Int): PendingIntent {
        val intent = Intent(context, CalorieWaterWidgetProvider::class.java).apply {
            this.action = action
        }
        return PendingIntent.getBroadcast(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun createOpenAppPendingIntent(context: Context, requestCode: Int): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = Intent.ACTION_VIEW
            data = Uri.parse("calorietracker://open_today")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}
