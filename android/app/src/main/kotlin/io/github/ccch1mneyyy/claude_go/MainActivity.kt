package io.github.ccch1mneyyy.claude_go

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.github.ccch1mneyyy.claude_go.runtime.ClaudeRuntime

class MainActivity : FlutterActivity() {
    private val channelName = "claude_go/native"
    private val requestCode = 4101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        ClaudeRuntime.init(this)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "runtimeStatus" -> result.success(ClaudeRuntime.status())

                    "installRuntime" -> {
                        ClaudeRuntime.installRuntime()
                        result.success(true)
                    }

                    "installClaudeCode" -> {
                        ClaudeRuntime.installClaudeCode()
                        result.success(true)
                    }

                    "startBridge" -> {
                        ClaudeRuntime.startBridge(
                            call.argument<String>("token") ?: "",
                        )
                        result.success(true)
                    }

                    "stopBridge" -> {
                        ClaudeRuntime.stopBridge()
                        result.success(true)
                    }

                    "startProtection" -> {
                        requestNotificationPermission()
                        val intent = Intent(this, ClaudeGoService::class.java)
                        if (Build.VERSION.SDK_INT >= 26) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        result.success(true)
                    }

                    "stopProtection" -> {
                        stopService(Intent(this, ClaudeGoService::class.java))
                        result.success(true)
                    }

                    "isIgnoringBatteryOptimizations" -> {
                        val power = getSystemService(POWER_SERVICE) as PowerManager
                        result.success(power.isIgnoringBatteryOptimizations(packageName))
                    }

                    "requestIgnoreBatteryOptimizations" -> {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } catch (_: Exception) {
                            // Some ROMs do not expose this screen.
                        }
                        result.success(true)
                    }

                    "isExternalStorageManager" -> {
                        val allowed = if (Build.VERSION.SDK_INT >= 30) {
                            Environment.isExternalStorageManager()
                        } else {
                            true
                        }
                        result.success(allowed)
                    }

                    "requestExternalStorage" -> {
                        if (Build.VERSION.SDK_INT >= 30) {
                            try {
                                startActivity(
                                    Intent(
                                        Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION,
                                        Uri.parse("package:$packageName"),
                                    ),
                                )
                            } catch (_: Exception) {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
                                )
                            }
                        }
                        result.success(true)
                    }

                    "openUrl" -> {
                        val url = call.argument<String>("url") ?: ""
                        try {
                            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
                        } catch (_: Exception) {
                            // No browser installed.
                        }
                        result.success(true)
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                requestCode,
            )
        }
    }
}
