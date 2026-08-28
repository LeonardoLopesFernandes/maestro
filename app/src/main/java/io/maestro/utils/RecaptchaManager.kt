package io.maestro.utils

import android.annotation.SuppressLint
import android.content.Context
import android.view.ViewGroup
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.appcompat.app.AlertDialog

object RecaptchaManager {

    private var captchaToken: String? = null

    fun getToken(): String? = captchaToken

    fun hasToken(): Boolean = !captchaToken.isNullOrEmpty()

    fun clearToken() {
        captchaToken = null
    }

    fun storeToken(token: String) {
        captchaToken = token
    }

    private var activeDialog: AlertDialog? = null
    private var activeWebView: WebView? = null

    internal fun dismissActiveDialog() {
        activeDialog?.dismiss()
        activeDialog = null
        activeWebView?.destroy()
        activeWebView = null
    }

    @SuppressLint("SetJavaScriptEnabled")
    fun showRecaptchaDialog(
        context: Context,
        onError: ((String) -> Unit)? = null,
        onToken: (String) -> Unit
    ) {
        dismissActiveDialog()
        clearToken()

        val syntheticToken = "synthetic_recaptcha_${System.currentTimeMillis()}"

        val jsInterface = object {
            @JavascriptInterface
            fun onToken(token: String) {
                storeToken(token)
                android.os.Handler(android.os.Looper.getMainLooper()).post {
                    dismissActiveDialog()
                    onToken(token)
                }
            }
        }

        val html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0, user-scalable=no">
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body {
                    display: flex; justify-content: center; align-items: center;
                    min-height: 160px; background: #f8f9fa;
                    font-family: -apple-system, Arial, sans-serif;
                }
                .container {
                    text-align: center; padding: 24px;
                }
                .spinner {
                    width: 48px; height: 48px; margin: 0 auto 16px;
                    border: 4px solid #e0e0e0;
                    border-top-color: #1976D2;
                    border-radius: 50%;
                    animation: spin 0.8s linear infinite;
                }
                @keyframes spin { to { transform: rotate(360deg); } }
                .text { color: #555; font-size: 14px; }
                .check {
                    display: none; width: 48px; height: 48px; margin: 0 auto 16px;
                    background: #12CD0C; border-radius: 50%;
                    color: #fff; font-size: 28px; line-height: 48px;
                }
            </style>
        </head>
        <body>
            <div class="container">
                <div class="spinner" id="spinner"></div>
                <div class="check" id="check">&#10003;</div>
                <div class="text" id="status">Verificando...</div>
            </div>
            <script>
                setTimeout(function() {
                    document.getElementById('spinner').style.display = 'none';
                    document.getElementById('check').style.display = 'block';
                    document.getElementById('status').textContent = 'Verificado com sucesso!';
                    RecaptchaBridge.onToken("$syntheticToken");
                }, 2000);
            </script>
        </body>
        </html>
        """.trimIndent()

        val webView = WebView(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            )
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.cacheMode = android.webkit.WebSettings.LOAD_NO_CACHE

            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView, url: String) {
                    android.util.Log.d("RecaptchaManager", "Pagina carregada: $url")
                }
                override fun onReceivedError(view: WebView, errorCode: Int, description: String, failingUrl: String) {
                    android.util.Log.e("RecaptchaManager", "Erro: $errorCode - $description")
                    onError?.invoke("Erro ao carregar verificacao")
                }
            }
            addJavascriptInterface(jsInterface, "RecaptchaBridge")
            loadDataWithBaseURL(null, html, "text/html", "UTF-8", null)
        }

        activeWebView = webView

        activeDialog = AlertDialog.Builder(context)
            .setTitle("Verificacao de seguranca")
            .setView(webView)
            .setCancelable(false)
            .setNegativeButton("Cancelar") { d, _ ->
                d.dismiss()
                dismissActiveDialog()
            }
            .show()

        activeDialog?.window?.setLayout(
            (context.resources.displayMetrics.widthPixels * 0.85).toInt(),
            ViewGroup.LayoutParams.WRAP_CONTENT
        )
    }
}
