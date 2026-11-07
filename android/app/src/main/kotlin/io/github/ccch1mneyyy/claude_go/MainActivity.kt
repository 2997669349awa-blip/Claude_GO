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

class MainActivity : FlutterActivity() {
    private val channelName = "claude_go/native"
    private val requestCode = 4101

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "termuxInstalled" -> result.success(isTermuxInstalled())

                    "hasTermuxPermission" -> result.success(hasTermuxPermission())

                    "requestTermuxPermission" -> {
                        if (!hasTermuxPermission()) {
                            requestPermissions(
                                arrayOf("com.termux.permission.RUN_COMMAND"),
                                requestCode,
                            )
                        }
                        result.success(hasTermuxPermission())
                    }

                    "runTermux" -> {
                        val command = call.argument<String>("command") ?: ""
                        val background = call.argument<Boolean>("background") ?: true
                        try {
                            runTermux(command, background)
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("termux_failed", error.message, null)
                        }
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

    private fun isTermuxInstalled(): Boolean = try {
        packageManager.getPackageInfo("com.termux", 0)
        true
    } catch (_: PackageManager.NameNotFoundException) {
        false
    }

    private fun hasTermuxPermission(): Boolean {
        if (Build.VERSION.SDK_INT < 23) return true
        return checkSelfPermission("com.termux.permission.RUN_COMMAND") ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                requestCode + 1,
            )
        }
    }

    private fun runTermux(command: String, background: Boolean) {
        val intent = Intent("com.termux.RUN_COMMAND").apply {
            setClassName("com.termux", "com.termux.app.RunCommandService")
            putExtra(
                "com.termux.RUN_COMMAND_PATH",
                "/data/data/com.termux/files/usr/bin/bash",
            )
            putExtra(
                "com.termux.RUN_COMMAND_ARGUMENTS",
                arrayOf("-lc", command),
            )
            putExtra(
                "com.termux.RUN_COMMAND_WORKDIR",
                "/data/data/com.termux/files/home",
            )
            putExtra("com.termux.RUN_COMMAND_BACKGROUND", background)
            putExtra("com.termux.RUN_COMMAND_SESSION_ACTION", "0")
        }
        startService(intent)
    }
}
