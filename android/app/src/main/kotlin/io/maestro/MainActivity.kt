package io.maestro

import android.content.ContentValues
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import com.google.android.gms.auth.api.phone.SmsRetriever
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Status
import io.flutter.plugin.common.EventChannel
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

    private val SMS_CHANNEL = "maestro.io/sms_consent"
    private val SMS_EVENTS_CHANNEL = "maestro.io/sms_consent_events"
    private val SMS_CONSENT_REQUEST = 9101
    private var smsEvents: EventChannel.EventSink? = null
    private var smsReceiver: BroadcastReceiver? = null

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            startSmsConsent()
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("SMS_START_FAILED", e.message, null)
                        }
                    }
                    "stop" -> {
                        stopSmsConsent()
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_EVENTS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    smsEvents = events
                }
                override fun onCancel(arguments: Any?) {
                    smsEvents = null
                }
            })
    }


    private fun startSmsConsent() {
        if (smsReceiver == null) {
            val receiver = object : BroadcastReceiver() {
                override fun onReceive(context: Context?, intent: Intent?) {
                    if (intent?.action != SmsRetriever.SMS_RETRIEVED_ACTION) return
                    val extras = intent.extras ?: return
                    @Suppress("DEPRECATION")
                    val status = extras.get(SmsRetriever.EXTRA_STATUS) as? Status
                    when (status?.statusCode) {
                        CommonStatusCodes.SUCCESS -> {
                            @Suppress("DEPRECATION")
                            val consentIntent = extras.getParcelable<Intent>(
                                SmsRetriever.EXTRA_CONSENT_INTENT
                            )
                            if (consentIntent != null) {
                                try {
                                    startActivityForResult(consentIntent, SMS_CONSENT_REQUEST)
                                } catch (_: Exception) {}
                            }
                        }
                        CommonStatusCodes.TIMEOUT -> {
                            // O Flutter reinicia ao abrir/trocar a pagina Microsoft.
                        }
                    }
                }
            }
            smsReceiver = receiver
            val filter = IntentFilter(SmsRetriever.SMS_RETRIEVED_ACTION)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                registerReceiver(receiver, filter, Context.RECEIVER_EXPORTED)
            } else {
                registerReceiver(receiver, filter)
            }
        }
        SmsRetriever.getClient(this).startSmsUserConsent(null)
            .addOnSuccessListener { }
            .addOnFailureListener { }
    }

    private fun stopSmsConsent() {
        try {
            smsReceiver?.let { unregisterReceiver(it) }
        } catch (_: Exception) {}
        smsReceiver = null
        smsEvents = null
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != SMS_CONSENT_REQUEST) return
        if (resultCode == Activity.RESULT_OK) {
            val message = data?.getStringExtra(SmsRetriever.EXTRA_SMS_MESSAGE)
            val code = extractSmsCode(message)
            if (code != null) smsEvents?.success(code)
        }
    }

    private fun extractSmsCode(message: String?): String? {
        if (message.isNullOrBlank()) return null
        val seis = Regex("""\b(\d{6})\b""").find(message)?.groupValues?.get(1)
        if (seis != null) return seis
        return Regex("""\b(\d{4,8})\b""").find(message)?.groupValues?.get(1)
    }

    override fun onDestroy() {
        stopSmsConsent()
        super.onDestroy()
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
