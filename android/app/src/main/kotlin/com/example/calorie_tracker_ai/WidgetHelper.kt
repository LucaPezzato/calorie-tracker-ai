package com.example.calorie_tracker_ai

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.net.Uri
import android.os.Build
import es.antonborri.home_widget.HomeWidgetPlugin
import java.io.File
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import kotlin.math.max

object WidgetHelper {
    const val ACTION_WATER_SUB = "com.example.calorie_tracker_ai.ACTION_WATER_SUB"
    const val ACTION_WATER_ADD = "com.example.calorie_tracker_ai.ACTION_WATER_ADD"
    const val ACTION_WATER_ADD500 = "com.example.calorie_tracker_ai.ACTION_WATER_ADD500"
    const val ACTION_COFFEE_ADD = "com.example.calorie_tracker_ai.ACTION_COFFEE_ADD"
    const val ACTION_MIDNIGHT_REFRESH = "com.example.calorie_tracker_ai.ACTION_MIDNIGHT_REFRESH"

    fun getTodayDate(): String {
        val sdf = SimpleDateFormat("yyyy-MM-dd", Locale.getDefault())
        return sdf.format(Date())
    }

    /**
     * Resets cached widget counters if the stored date is from a previous day,
     * and schedules the next midnight alarm so widgets auto-refresh at 00:01.
     */
    fun ensureCurrentDay(context: Context) {
        val prefs = HomeWidgetPlugin.getData(context)
        val today = getTodayDate()
        val storedDate = prefs.getString("widget_date", null)

        if (storedDate != null && storedDate != today) {
            val kcalTarget = prefs.getInt("kcal_target", 2400)
            prefs.edit()
                .putString("widget_date", today)
                .putInt("kcal_remaining", kcalTarget)
                .putInt("protein_g", 0)
                .putInt("carbs_g", 0)
                .putInt("fat_g", 0)
                .putInt("water_ml", 0)
                .putInt("coffee_cups", 0)
                .apply()
        } else if (storedDate == null) {
            prefs.edit().putString("widget_date", today).apply()
        }

        scheduleMidnightRefresh(context)
    }

    fun scheduleMidnightRefresh(context: Context) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val intent = Intent(context, CalorieWaterWidgetProvider::class.java).apply {
                action = ACTION_MIDNIGHT_REFRESH
            }
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                9001,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )

            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 1)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }

            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    cal.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.set(
                    AlarmManager.RTC_WAKEUP,
                    cal.timeInMillis,
                    pendingIntent
                )
            }
        } catch (_: Exception) {}
    }

    fun handleQuickAction(context: Context, action: String?) {
        ensureCurrentDay(context)
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

    fun createOpenAppPendingIntent(
        context: Context,
        requestCode: Int,
        uriString: String = "calorietracker://open_today"
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = Intent.ACTION_VIEW
            data = Uri.parse(uriString)
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
