package com.example.calorie_tracker_ai

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "app_updater"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getAppVersion" -> {
                        try {
                            val info = packageManager.getPackageInfo(packageName, 0)
                            result.success(info.versionName ?: "0.0.0")
                        } catch (e: Exception) {
                            result.error("VERSION_ERR", e.message, null)
                        }
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.error("ARG_ERR", "Percorso APK mancante", null)
                            return@setMethodCallHandler
                        }
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                                !packageManager.canRequestPackageInstalls()
                            ) {
                                val intent = Intent(
                                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                                    Uri.parse("package:$packageName")
                                ).apply {
                                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                }
                                startActivity(intent)
                                result.success("needs_permission")
                                return@setMethodCallHandler
                            }
                            val file = File(path)
                            val uri = FileProvider.getUriForFile(
                                this,
                                "$packageName.update_fileprovider",
                                file
                            )
                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(installIntent)
                            result.success("started")
                        } catch (e: Exception) {
                            result.error("INSTALL_ERR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
