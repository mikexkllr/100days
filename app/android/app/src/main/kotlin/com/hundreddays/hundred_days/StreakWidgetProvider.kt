package com.hundreddays.hundred_days

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.os.Bundle
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetPlugin
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/**
 * The streak on the home screen.
 *
 * Everything shown here was decided and translated by the app: it leaves a
 * two-week timetable (lib/data/streak_widget.dart) and this provider only
 * picks today's row. Midnight and eight in the evening are the two moments
 * the picture changes, and the app schedules a redraw for both.
 */
class StreakWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(
                id,
                render(context, widgetData, appWidgetManager.getAppWidgetOptions(id)),
            )
        }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        appWidgetManager.updateAppWidget(
            appWidgetId,
            render(context, HomeWidgetPlugin.getData(context), newOptions),
        )
    }

    private fun render(context: Context, data: SharedPreferences, options: Bundle?): RemoteViews {
        val minWidth = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) ?: 0
        val medium = minWidth >= MEDIUM_MIN_WIDTH_DP
        val views = RemoteViews(
            context.packageName,
            if (medium) R.layout.streak_widget_medium else R.layout.streak_widget_small,
        )
        views.setOnClickPendingIntent(
            R.id.widget_root,
            HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
        )

        val outlook = data.getString(OUTLOOK_KEY, null)?.let {
            try {
                JSONObject(it)
            } catch (e: Exception) {
                null
            }
        }
        if (outlook == null) {
            // Installed, never opened: nothing to show but an invitation.
            views.setTextViewText(R.id.streak_number, "0")
            views.setTextViewText(R.id.streak_label, "")
            views.setTextViewText(R.id.status, context.getString(R.string.streak_widget_open_app))
            views.setTextColor(R.id.status, COLD)
            views.setViewVisibility(R.id.countdown_row, View.GONE)
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.widget_bg_cold)
            if (medium) views.setTextViewText(R.id.line, "")
            return views
        }

        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val days = outlook.getJSONArray("days")
        var row: JSONObject? = null
        for (i in 0 until days.length()) {
            val candidate = days.getJSONObject(i)
            if (candidate.getString("day") == today) {
                row = candidate
                break
            }
        }
        // Two weeks without opening the app: whatever streak there was is gone.
        val fallback = outlook.getJSONObject("fallback")
        val state = row?.getString("state") ?: "cold"
        val late = state == "open" && Calendar.getInstance().get(Calendar.HOUR_OF_DAY) >= LATE_HOUR

        val image = when {
            row == null -> fallback.getString("image")
            late -> row.optString("lateImage", row.getString("image"))
            else -> row.getString("image")
        }
        data.getString(image, null)?.let { path ->
            BitmapFactory.decodeFile(path)?.let { views.setImageViewBitmap(R.id.flame, it) }
        }

        val streak = row?.getInt("streak") ?: 0
        views.setTextViewText(R.id.streak_number, streak.toString())
        views.setTextViewText(
            R.id.streak_label,
            (row ?: fallback).getString("streakLabel"),
        )
        views.setTextViewText(R.id.status, (row ?: fallback).getString("status"))

        val color = when {
            late -> DANGER
            state == "done" -> SUCCESS
            state == "open" -> ATTENTION
            state == "rest" || state == "frozen" -> COOL
            else -> COLD
        }
        views.setTextColor(R.id.status, color)
        views.setTextColor(R.id.streak_number, if (state == "done") PLASMA else color)
        views.setInt(
            R.id.widget_root,
            "setBackgroundResource",
            when {
                late -> R.drawable.widget_bg_late
                state == "done" -> R.drawable.widget_bg_done
                state == "open" -> R.drawable.widget_bg_open
                state == "rest" || state == "frozen" -> R.drawable.widget_bg_rest
                else -> R.drawable.widget_bg_cold
            },
        )

        if (state == "open") {
            // The same clock as in the app: the streak really ends at midnight.
            val midnight = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, 1)
                set(Calendar.HOUR_OF_DAY, 0)
                set(Calendar.MINUTE, 0)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            val base = SystemClock.elapsedRealtime() + (midnight - System.currentTimeMillis())
            views.setViewVisibility(R.id.countdown_row, View.VISIBLE)
            views.setTextViewText(R.id.countdown_label, outlook.getString("goesOutIn"))
            views.setChronometer(R.id.countdown, base, null, true)
            views.setChronometerCountDown(R.id.countdown, true)
            views.setTextColor(R.id.countdown, color)
        } else {
            views.setViewVisibility(R.id.countdown_row, View.GONE)
        }

        if (medium) {
            val line = when {
                row == null -> fallback.getString("line")
                late -> row.optString("lateLine", row.getString("line"))
                else -> row.getString("line")
            }
            views.setTextViewText(R.id.line, line)
            renderWeek(views, outlook, row)
        }
        return views
    }

    private fun renderWeek(views: RemoteViews, outlook: JSONObject, row: JSONObject?) {
        val letters = outlook.getJSONArray("weekdays")
        val marks = row?.optJSONArray("week")
        for (i in 0 until 7) {
            views.setTextViewText(WEEK_LETTERS[i], letters.getString(i))
            val mark = marks?.getString(i) ?: "upcoming"
            val (glyph, color) = when (mark) {
                "done" -> "\u25C6" to PLASMA
                "frozen" -> "\u2744" to COOL
                "missed" -> "✕" to DANGER
                "rest" -> "☾" to MUTED
                "open" -> "\u25C7" to ATTENTION
                "none" -> " " to MUTED
                else -> "·" to MUTED
            }
            views.setTextViewText(WEEK_MARKS[i], glyph)
            views.setTextColor(WEEK_MARKS[i], color)
        }
    }

    companion object {
        private const val OUTLOOK_KEY = "streak_outlook"
        private const val MEDIUM_MIN_WIDTH_DP = 220
        private const val LATE_HOUR = 20

        private const val PLASMA = 0xFFC084FC.toInt()
        private const val ATTENTION = 0xFFE879F9.toInt()
        private const val SUCCESS = 0xFF34E0B5.toInt()
        private const val COOL = 0xFF7DD3FC.toInt()
        private const val DANGER = 0xFFFB7185.toInt()
        private const val COLD = 0xFFB9B3DB.toInt()
        private const val MUTED = 0xFF7A73A6.toInt()

        private val WEEK_LETTERS = intArrayOf(
            R.id.week_letter_0, R.id.week_letter_1, R.id.week_letter_2, R.id.week_letter_3,
            R.id.week_letter_4, R.id.week_letter_5, R.id.week_letter_6,
        )
        private val WEEK_MARKS = intArrayOf(
            R.id.week_mark_0, R.id.week_mark_1, R.id.week_mark_2, R.id.week_mark_3,
            R.id.week_mark_4, R.id.week_mark_5, R.id.week_mark_6,
        )
    }
}
