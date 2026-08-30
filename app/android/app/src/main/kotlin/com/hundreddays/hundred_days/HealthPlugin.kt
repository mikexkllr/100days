package com.hundreddays.hundred_days

import android.app.Activity
import android.content.Intent
import androidx.activity.result.contract.ActivityResultContract
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.ExerciseSessionRecord
import androidx.health.connect.client.records.HydrationRecord
import androidx.health.connect.client.records.SleepSessionRecord
import androidx.health.connect.client.records.StepsRecord
import androidx.health.connect.client.request.AggregateGroupByPeriodRequest
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.Period

/**
 * Reads Health Connect for the app.
 *
 * The plugin stays deliberately thin. It hands Dart per-day totals for the two
 * things Health Connect aggregates better than we could — steps and hydration,
 * where its own de-duplication across writing apps is the whole point — and raw
 * intervals for everything session-shaped. Merging overlapping workouts,
 * deciding which calendar day a night's sleep belongs to and working out what
 * becomes a check-in all happen in Dart, where they are covered by tests.
 *
 * Nothing here writes to Health Connect. The app has read permissions only, so
 * a bug in it cannot corrupt the user's health record.
 */
class HealthPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.ActivityResultListener {

    private companion object {
        const val CHANNEL = "hundred_days/health"
        // Kept inside 16 bits: AndroidX activities reserve the upper half of
        // a request code, and this must not start throwing if MainActivity
        // ever changes base class.
        const val PERMISSION_REQUEST_CODE = 0x4831

        /**
         * Sessions a watch labels as lifting. Everything strength-shaped counts,
         * because the habit is "did you train", not "which split was it".
         */
        val STRENGTH_TYPES = setOf(
            ExerciseSessionRecord.EXERCISE_TYPE_STRENGTH_TRAINING,
            ExerciseSessionRecord.EXERCISE_TYPE_WEIGHTLIFTING,
            ExerciseSessionRecord.EXERCISE_TYPE_CALISTHENICS,
        )

        /**
         * Sessions that count as cardio. Plain walking is deliberately absent:
         * a walk to the shops is not a cardio session, and counting it as one
         * would hand out a streak day for commuting. Steps cover walking.
         */
        val CARDIO_TYPES = setOf(
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING,
            ExerciseSessionRecord.EXERCISE_TYPE_RUNNING_TREADMILL,
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING,
            ExerciseSessionRecord.EXERCISE_TYPE_BIKING_STATIONARY,
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_POOL,
            ExerciseSessionRecord.EXERCISE_TYPE_SWIMMING_OPEN_WATER,
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING,
            ExerciseSessionRecord.EXERCISE_TYPE_ROWING_MACHINE,
            ExerciseSessionRecord.EXERCISE_TYPE_ELLIPTICAL,
            ExerciseSessionRecord.EXERCISE_TYPE_HIKING,
            ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING,
            ExerciseSessionRecord.EXERCISE_TYPE_STAIR_CLIMBING_MACHINE,
            ExerciseSessionRecord.EXERCISE_TYPE_HIGH_INTENSITY_INTERVAL_TRAINING,
        )
    }

    private var channel: MethodChannel? = null
    private var activity: Activity? = null
    private var context: android.content.Context? = null
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)

    private var permissionContract:
        ActivityResultContract<Set<String>, Set<String>>? = null
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingPermissionMetrics: List<String> = emptyList()

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
        scope.cancel()
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onDetachedFromActivity() {
        activity = null
    }

    // ---------------------------------------------------------------- channel

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "available" -> result.success(isAvailable())
            "access" -> grantedFor(call.argument<List<String>>("metrics").orEmpty(), result)
            "request" -> requestPermissions(
                call.argument<List<String>>("metrics").orEmpty(),
                result,
            )
            "read" -> read(call, result)
            "openSettings" -> openSettings(result)
            else -> result.notImplemented()
        }
    }

    private fun isAvailable(): Boolean {
        val ctx = context ?: return false
        return HealthConnectClient.getSdkStatus(ctx) == HealthConnectClient.SDK_AVAILABLE
    }

    private fun client(): HealthConnectClient? {
        val ctx = context ?: return null
        if (!isAvailable()) return null
        return runCatching { HealthConnectClient.getOrCreate(ctx) }.getOrNull()
    }

    private fun grantedFor(metrics: List<String>, result: MethodChannel.Result) {
        val client = client()
        if (client == null) {
            result.success(unavailable())
            return
        }
        scope.launch {
            try {
                val granted = client.permissionController.getGrantedPermissions()
                result.success(statusFor(metrics, granted))
            } catch (error: Exception) {
                result.success(unavailable())
            }
        }
    }

    private fun requestPermissions(metrics: List<String>, result: MethodChannel.Result) {
        val current = activity
        if (current == null || client() == null) {
            result.success(unavailable())
            return
        }
        if (pendingPermissionResult != null) {
            // A second sheet on top of the first would leave one of the two
            // results with nobody to hand an answer to.
            result.success(unavailable())
            return
        }

        val permissions = metrics.mapNotNull(::permissionFor).toSet()
        if (permissions.isEmpty()) {
            result.success(unavailable())
            return
        }

        val contract = PermissionController.createRequestPermissionResultContract()
        permissionContract = contract
        pendingPermissionResult = result
        pendingPermissionMetrics = metrics
        try {
            current.startActivityForResult(
                contract.createIntent(current, permissions),
                PERMISSION_REQUEST_CODE,
            )
        } catch (error: Exception) {
            pendingPermissionResult = null
            result.success(unavailable())
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val result = pendingPermissionResult ?: return true
        pendingPermissionResult = null

        val granted = runCatching {
            permissionContract?.parseResult(resultCode, data).orEmpty()
        }.getOrDefault(emptySet())
        result.success(statusFor(pendingPermissionMetrics, granted))
        return true
    }

    private fun openSettings(result: MethodChannel.Result) {
        val current = activity
        if (current == null) {
            result.success(null)
            return
        }
        // The settings screen is the user's, not ours: revoking here has to be
        // possible without the app being able to argue about it.
        val intent = Intent(HealthConnectClient.ACTION_HEALTH_CONNECT_SETTINGS)
        try {
            current.startActivity(intent)
        } catch (error: Exception) {
            // Nothing to open — Health Connect is missing, which the screen
            // already says.
        }
        result.success(null)
    }

    // ------------------------------------------------------------------ reads

    private fun read(call: MethodCall, result: MethodChannel.Result) {
        val client = client()
        val from = call.argument<String>("from")
        val to = call.argument<String>("to")
        val metrics = call.argument<List<String>>("metrics").orEmpty().toSet()
        if (client == null || from == null || to == null) {
            result.success(mapOf("daily" to emptyList<Any>(), "sessions" to emptyList<Any>()))
            return
        }

        scope.launch {
            try {
                val payload = withContext(Dispatchers.IO) {
                    readWindow(client, LocalDate.parse(from), LocalDate.parse(to), metrics)
                }
                result.success(payload)
            } catch (error: Exception) {
                result.error("read_failed", error.message, null)
            }
        }
    }

    private suspend fun readWindow(
        client: HealthConnectClient,
        from: LocalDate,
        to: LocalDate,
        metrics: Set<String>,
    ): Map<String, Any> {
        val daily = mutableListOf<Map<String, Any?>>()
        val sessions = mutableListOf<Map<String, Any?>>()

        // Local dates, not instants: a "day" is the user's calendar day, and
        // Health Connect slices it correctly across a daylight-saving change
        // only if it is asked in local time.
        val start = from.atStartOfDay()
        val end = to.plusDays(1).atStartOfDay()

        val aggregates = buildSet {
            if (metrics.contains("steps")) add(StepsRecord.COUNT_TOTAL)
            if (metrics.contains("water")) add(HydrationRecord.VOLUME_TOTAL)
        }
        if (aggregates.isNotEmpty()) {
            // Each read is isolated: permission is granted per record type, so
            // a user who allowed steps but refused hydration must still get
            // their steps rather than an empty round.
            ignoringRefusal {
                val buckets = client.aggregateGroupByPeriod(
                    AggregateGroupByPeriodRequest(
                        metrics = aggregates,
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                        timeRangeSlicer = Period.ofDays(1),
                    )
                )
                for (bucket in buckets) {
                    val day = bucket.startTime.toLocalDate().toString()
                    bucket.result[StepsRecord.COUNT_TOTAL]?.let { count ->
                        daily += mapOf("metric" to "steps", "day" to day, "value" to count)
                    }
                    bucket.result[HydrationRecord.VOLUME_TOTAL]?.let { volume ->
                        daily += mapOf(
                            "metric" to "water",
                            "day" to day,
                            "value" to volume.inMilliliters,
                        )
                    }
                }
            }
        }

        val wantsStrength = metrics.contains("strengthMinutes")
        val wantsCardio = metrics.contains("cardioMinutes")
        if (wantsStrength || wantsCardio) {
            ignoringRefusal {
                val response = client.readRecords(
                    ReadRecordsRequest(
                        recordType = ExerciseSessionRecord::class,
                        timeRangeFilter = TimeRangeFilter.between(start, end),
                    )
                )
                for (record in response.records) {
                    val metric = when (record.exerciseType) {
                        in STRENGTH_TYPES -> if (wantsStrength) "strengthMinutes" else null
                        in CARDIO_TYPES -> if (wantsCardio) "cardioMinutes" else null
                        else -> null
                    } ?: continue
                    sessions += session(
                        metric,
                        record.startTime.toEpochMilli(),
                        record.endTime.toEpochMilli(),
                        deviceName(record.metadata),
                    )
                }
            }
        }

        if (metrics.contains("sleepMinutes")) {
            ignoringRefusal {
                val response = client.readRecords(
                    ReadRecordsRequest(
                        recordType = SleepSessionRecord::class,
                        // A night that began the evening before the window
                        // still belongs to the first day in it, so reach back
                        // far enough to catch it.
                        timeRangeFilter = TimeRangeFilter.between(start.minusDays(1), end),
                    )
                )
                for (record in response.records) {
                    sessions += session(
                        "sleepMinutes",
                        record.startTime.toEpochMilli(),
                        record.endTime.toEpochMilli(),
                        deviceName(record.metadata),
                    )
                }
            }
        }

        return mapOf("daily" to daily, "sessions" to sessions)
    }

    /**
     * Swallows a refusal for one record type. Permission in Health Connect is
     * per type and can be revoked at any moment from the system settings, so
     * "you may not read sleep" has to mean exactly that and not "you get
     * nothing today".
     */
    private inline fun ignoringRefusal(body: () -> Unit) {
        try {
            body()
        } catch (error: SecurityException) {
            // Nothing to report: the settings screen already tells the user
            // where access is granted and revoked.
        } catch (error: IllegalStateException) {
            // Health Connect went away mid-round — same handling.
        }
    }

    private fun session(
        metric: String,
        start: Long,
        end: Long,
        device: String?,
    ): Map<String, Any?> = mapOf(
        "metric" to metric,
        "start" to start,
        "end" to end,
        "device" to device,
    )

    /**
     * A name a person recognises. The watch model beats the package name of
     * whatever app forwarded the data — "Pixel Watch" means something,
     * "com.google.android.apps.fitness" does not.
     */
    private fun deviceName(
        metadata: androidx.health.connect.client.records.metadata.Metadata,
    ): String? {
        val model = metadata.device?.model
        if (!model.isNullOrBlank()) return model
        val manufacturer = metadata.device?.manufacturer
        if (!manufacturer.isNullOrBlank()) return manufacturer
        return metadata.dataOrigin.packageName.substringAfterLast('.')
            .takeIf { it.isNotBlank() }
    }

    // --------------------------------------------------------------- statuses

    private fun permissionFor(metric: String): String? = when (metric) {
        "steps" -> HealthPermission.getReadPermission(StepsRecord::class)
        "water" -> HealthPermission.getReadPermission(HydrationRecord::class)
        "strengthMinutes",
        "cardioMinutes",
        -> HealthPermission.getReadPermission(ExerciseSessionRecord::class)
        "sleepMinutes" -> HealthPermission.getReadPermission(SleepSessionRecord::class)
        // mindfulMinutes has no Health Connect record type at all.
        else -> null
    }

    private fun statusFor(
        metrics: List<String>,
        granted: Set<String>,
    ): Map<String, Any> {
        val wanted = metrics.mapNotNull { metric ->
            permissionFor(metric)?.let { metric to it }
        }
        val allowed = wanted.filter { granted.contains(it.second) }.map { it.first }
        // Unlike HealthKit, Health Connect answers plainly, so the app can say
        // "denied" instead of hedging. Nothing requestable at all is neither
        // granted nor denied — it is simply not a thing this platform has.
        val status = when {
            wanted.isEmpty() -> "unavailable"
            allowed.isEmpty() -> "denied"
            else -> "granted"
        }
        return mapOf("status" to status, "granted" to allowed)
    }

    private fun unavailable(): Map<String, Any> =
        mapOf("status" to "unavailable", "granted" to emptyList<String>())
}
