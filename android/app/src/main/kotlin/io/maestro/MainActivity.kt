package io.maestro

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.webkit.CookieManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "io.maestro/media"
    private val COOKIES_CHANNEL = "io.maestro/cookies"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "saveToDownloads") {
                    try {
                        val fileName = call.argument<String>("fileName") ?: "arquivo"
                        val mimeType = call.argument<String>("mimeType")
                            ?: "application/octet-stream"
                        val bytes = call.argument<ByteArray>("bytes")
                        if (bytes == null) {
                            result.error("NO_BYTES", "bytes nulo", null)
                            return@setMethodCallHandler
                        }
                        val uri = saveToDownloads(fileName, mimeType, bytes)
                        result.success(uri?.toString())
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
        // Lê os cookies de um domínio (inclui HttpOnly) — essencial para
        // capturar o token de login do maestro, que o document.cookie do
        // WebView não expõe via JavaScript.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COOKIES_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getCookies") {
                    val url = call.argument<String>("url") ?: ""
                    try {
                        val cookies = CookieManager.getInstance().getCookie(url)
                        result.success(cookies ?: "")
                    } catch (e: Exception) {
                        result.error("COOKIES_FAILED", e.message, null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }

    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): Uri? {
        val resolver = contentResolver
        val collection: Uri = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            MediaStore.Downloads.EXTERNAL_CONTENT_URI
        } else {
            MediaStore.Files.getContentUri("external")
        }
        val values = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fileName)
            put(MediaStore.Downloads.MIME_TYPE, mimeType)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Downloads.IS_PENDING, 1)
                put(MediaStore.Downloads.RELATIVE_PATH, "Download/Maestro")
            } else {
                val dir = android.os.Environment
                    .getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_DOWNLOADS)
                val file = java.io.File(dir, fileName)
                put(MediaStore.Files.FileColumns.DATA, file.absolutePath)
            }
        }
        val uri = resolver.insert(collection, values) ?: return null
        resolver.openOutputStream(uri)?.use { os: OutputStream ->
            os.write(bytes)
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Downloads.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri
    }
}
