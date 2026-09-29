package com.hundreddays.hundred_days

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Registered as a real plugin rather than a bare method channel so it
        // gets the activity lifecycle callbacks the permission sheet needs.
        flutterEngine.plugins.add(HealthPlugin())
    }
}
