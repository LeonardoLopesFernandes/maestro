package io.maestro.ui

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Base64
import android.util.Log
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.webkit.CookieManager
import android.webkit.WebResourceRequest
import android.webkit.WebView
import android.webkit.WebViewClient
import android.widget.ImageView
import android.widget.LinearLayout
import androidx.appcompat.app.AppCompatActivity
import io.maestro.R
import io.maestro.network.SessionManager
import io.maestro.utils.Colors
import io.maestro.utils.toast
import io.maestro.utils.toastLong
import io.maestro.utils.Constants
import org.json.JSONObject

class LoginWebViewActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "LoginWebView"
        const val EXTRA_AUTO_LOGIN = "extra_auto_login"
        const val EXTRA_EMAIL = "extra_email"
        const val EXTRA_SENHA = "extra_senha"
        const val EXTRA_SILENCIOSO = "extra_silencioso"
        private const val TIMEOUT_RECONNECT_MS = 15_000L
        private const val MS_LOGIN_URL = "https://login.microsoftonline.com/e316d1ac-42c8-4d30-817c-12c7a71f8ab2/oauth2/authorize?resource=883c90b2-f8df-4308-a4d4-c91e11bc989f&response_type=code&redirect_uri=https%3A%2F%2Fmaestro-auth.americanas.io%2Fad%2Freply&client_id=883c90b2-f8df-4308-a4d4-c91e11bc989f"
    }

    private lateinit var webView: WebView
    private lateinit var layoutCarregamentoCustom: LinearLayout
    private lateinit var imgLogoPreenchimento: ImageView
    private lateinit var tvStatusCarregamento: android.widget.TextView
    
    private var tokenSalvo = false
    private var loginConcluido = false
    private var pulsoAnimator: ValueAnimator? = null
    private var autoLogin = false
    private var silencioso = false
    private var handlerTimeout: Runnable? = null
    private var emailCredencial = ""
    private var senhaCredencial = ""
    private var ultimaInjecao = 0L
    private var tentativasMesmaPagina = 0
    private var ultimaUrlPreenchida = ""

    private fun setStatusBarColor(cor: Int, iconesClaras: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            window.statusBarColor = cor
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            window.decorView.systemUiVisibility = if (iconesClaras) {
                window.decorView.systemUiVisibility and android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR.inv()
            } else {
                window.decorView.systemUiVisibility or android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_login_webview)

        autoLogin = intent.getBooleanExtra(EXTRA_AUTO_LOGIN, false)
        if (autoLogin) {
            val sessionManager = SessionManager(applicationContext)
            emailCredencial = intent.getStringExtra(EXTRA_EMAIL) ?: sessionManager.getUserEmail() ?: ""
            senhaCredencial = intent.getStringExtra(EXTRA_SENHA) ?: sessionManager.getSavedPassword() ?: ""
            if (emailCredencial.isBlank() || senhaCredencial.isBlank()) autoLogin = false
            Log.d(TAG, "Auto-login: email=${emailCredencial.take(3)}***, senha salva=${senhaCredencial.isNotBlank()}")
        }

        webView = findViewById(R.id.webView)
        layoutCarregamentoCustom = findViewById(R.id.layoutCarregamentoCustom)
        imgLogoPreenchimento = findViewById(R.id.imgLogoPreenchimento)
        tvStatusCarregamento = findViewById(R.id.tvStatusCarregamento)

        silencioso = autoLogin && intent.getBooleanExtra(EXTRA_SILENCIOSO, false)

        if (silencioso) {
            // Reconexão automática: WebView oculto, mostra apenas a logo pulsando
            webView.visibility = View.INVISIBLE
            layoutCarregamentoCustom.visibility = View.VISIBLE
            tvStatusCarregamento.text = "Reconectando automaticamente..."
            setStatusBarColor(android.graphics.Color.parseColor(Colors.RED_500), false)
            iniciarAnimacaoPulse()
            iniciarTimeoutReconnect()
        } else {
            layoutCarregamentoCustom.visibility = View.GONE
            webView.visibility = View.VISIBLE
            setStatusBarColor(android.graphics.Color.WHITE, true)
        }

        configurarWebView()
        webView.loadUrl(MS_LOGIN_URL)
    }

    private fun iniciarTimeoutReconnect() {
        handlerTimeout = Runnable {
            if (!loginConcluido && !isFinishing && !isDestroyed) {
                Log.d(TAG, "Reconnect: tempo esgotado, mostrando WebView para conclusão manual")
                revelarWebViewManual("Não foi possível reconectar automaticamente. Conclua o login manualmente.")
            }
        }
        Handler(Looper.getMainLooper()).postDelayed(handlerTimeout!!, TIMEOUT_RECONNECT_MS)
    }

    private fun cancelarTimeoutReconnect() {
        handlerTimeout?.let { Handler(Looper.getMainLooper()).removeCallbacks(it) }
        handlerTimeout = null
    }

    private fun revelarWebViewManual(mensagem: String) {
        if (!silencioso || loginConcluido || isFinishing || isDestroyed) return
        silencioso = false
        runOnUiThread {
            webView.visibility = View.VISIBLE
            layoutCarregamentoCustom.visibility = View.GONE
            setStatusBarColor(android.graphics.Color.WHITE, true)
            pararAnimacaoPulse()
            toast(mensagem)
        }
    }

    private fun iniciarAnimacaoPulse() {
        try {
            if (pulsoAnimator != null && pulsoAnimator!!.isRunning) return
            runOnUiThread {
                pulsoAnimator = ValueAnimator.ofFloat(1.0f, 0.2f).apply {
                    duration = 900
                    repeatCount = ValueAnimator.INFINITE
                    repeatMode = ValueAnimator.REVERSE
                    interpolator = AccelerateDecelerateInterpolator()
                    addUpdateListener { animator ->
                        imgLogoPreenchimento.alpha = animator.animatedValue as Float
                    }
                    start()
                }
            }
        } catch (e: Exception) { }
    }

    private fun exibirCarregamento(exibir: Boolean) {
        try {
            if (isFinishing || isDestroyed) return
            if (silencioso && !loginConcluido) {
                // No modo silencioso o overlay fica sempre visível até concluir ou revelar o WebView
                return
            }
            runOnUiThread {
                if (exibir) {
                    layoutCarregamentoCustom.visibility = View.VISIBLE
                    setStatusBarColor(android.graphics.Color.parseColor(Colors.RED_500), false)
                    iniciarAnimacaoPulse()
                } else {
                    layoutCarregamentoCustom.visibility = View.GONE
                    setStatusBarColor(android.graphics.Color.WHITE, true)
                    pararAnimacaoPulse()
                }
            }
        } catch (e: Exception) { }
    }

    private fun pararAnimacaoPulse() {
        try {
            runOnUiThread {
                pulsoAnimator?.cancel()
                pulsoAnimator = null
                imgLogoPreenchimento.alpha = 1.0f
            }
        } catch (e: Exception) { }
    }

    @SuppressLint("SetJavaScriptEnabled")
    private fun configurarWebView() {
        try {
            CookieManager.getInstance().setAcceptCookie(true)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                CookieManager.getInstance().setAcceptThirdPartyCookies(webView, true)
                CookieManager.getInstance().flush()
            }

            webView.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = true
                allowContentAccess = true
                loadWithOverviewMode = true
                useWideViewPort = true
                userAgentString = "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/137.0.0.0 Mobile Safari/537.36"
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    mixedContentMode = android.webkit.WebSettings.MIXED_CONTENT_ALWAYS_ALLOW
                }
            }

            webView.webViewClient = object : WebViewClient() {

                override fun shouldOverrideUrlLoading(view: WebView?, request: WebResourceRequest?): Boolean {
                    val url = request?.url.toString()
                    Log.d(TAG, "shouldOverride: $url")

                    val token = extrairTokenDaUrl(url)
                    if (token != null && token.length > 50) {
                        salvarToken(token)
                        return true
                    }

                    return super.shouldOverrideUrlLoading(view, request)
                }

                override fun onPageStarted(view: WebView?, url: String?, favicon: android.graphics.Bitmap?) {
                    super.onPageStarted(view, url, favicon)
                    Log.d(TAG, "onPageStarted: $url")
                    if (url != null && !loginConcluido && !tokenSalvo) {
                        val token = extrairTokenDaUrl(url)
                        if (token != null && token.length > 50) {
                            salvarToken(token)
                            return
                        }
                        verificarCookies()
                    }
                }

                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    Log.d(TAG, "onPageFinished: $url")
                    if (loginConcluido || tokenSalvo) return
                    verificarCookies()
                    if (url != null && (url.contains("maestro.americanas.io") || url.contains("minhaloja.americanas.io") || url.contains("maestro-auth"))) {
                        verificarTokenViaJavaScript()
                        Handler(Looper.getMainLooper()).postDelayed({
                            if (!tokenSalvo && !loginConcluido) {
                                verificarTokenViaJavaScript()
                            }
                        }, 2000)
                        Handler(Looper.getMainLooper()).postDelayed({
                            if (!tokenSalvo && !loginConcluido) {
                                verificarTokenViaJavaScript()
                            }
                        }, 5000)
                    }
                    preencherLoginAutomatico()
                }
            }
        } catch (e: Exception) {
            this.toastLong("Erro ao configurar WebView: ${e.message}")
        }
    }

    private fun extrairTokenDaUrl(url: String): String? {
        val patterns = listOf("token=", "newToken=", "bearer=", "access_token=", "id_token=", "auth_token=", "jwt=")
        for (pattern in patterns) {
            if (url.contains(pattern)) {
                try {
                    val token = url.substringAfter(pattern).substringBefore("&")
                    if (token.isNotEmpty() && token.length > 50) return token
                } catch (e: Exception) { }
            }
        }
        return null
    }

    private fun extrairTokenDosCookies(cookies: String): String? {
        val patterns = listOf("token=", "newToken=", "bearer=", "access_token=", "id_token=", "auth_token=", "jwt=")
        for (pattern in patterns) {
            if (cookies.contains(pattern)) {
                try {
                    val token = cookies.substringAfter(pattern).substringBefore(";")
                    if (token.isNotEmpty() && token.length > 50) return token
                } catch (e: Exception) { }
            }
        }
        return null
    }

    private fun verificarCookies() {
        try {
            if (loginConcluido || tokenSalvo) return
            val cookieManager = CookieManager.getInstance()
            val cookies = cookieManager.getCookie("https://maestro.americanas.io")
                ?: cookieManager.getCookie("https://minhaloja.americanas.io")
                ?: cookieManager.getCookie("https://maestro-auth.americanas.io")
            if (cookies != null) {
                Log.d(TAG, "Cookies: $cookies")
                val token = extrairTokenDosCookies(cookies)
                if (token != null && token.length > 50) salvarToken(token)
            }
        } catch (e: Exception) { }
    }

    private fun verificarTokenViaJavaScript() {
        try {
            if (loginConcluido || tokenSalvo) return
            val script = """
                (function() { 
                    var keys = ['newToken', 'token', 'bearer', 'access_token', 'id_token', 'auth_token', 'jwt', 'session_token'];
                    for (var i = 0; i < keys.length; i++) {
                        var val = localStorage.getItem(keys[i]);
                        if (val && val.length > 50) return val;
                    }
                    for (var i = 0; i < keys.length; i++) {
                        var val = sessionStorage.getItem(keys[i]);
                        if (val && val.length > 50) return val;
                    }
                    for (var i = 0; i < keys.length; i++) {
                        if (window[keys[i]] && window[keys[i]].length > 50) return window[keys[i]];
                    }
                    return null;
                })();
            """.trimIndent()
            webView.evaluateJavascript(script) { result ->
                try {
                    if (result != null && result != "null" && result.length > 10) {
                        val token = result.trim().replace("\"", "")
                        if (token.length > 50) {
                            Log.d(TAG, "Token via JS: ${token.substring(0, 20)}...")
                            salvarToken(token)
                        }
                    }
                } catch (e: Exception) { }
            }
        } catch (e: Exception) { }
    }

    private fun extrairEmailDoToken(token: String): String? {
        return try {
            val parts = token.split(".")
            if (parts.size < 2) return null
            val payload = parts[1]
            val jsonStr = String(Base64.decode(payload, Base64.URL_SAFE), Charsets.UTF_8)
            val json = JSONObject(jsonStr)
            val campos = listOf("email", "upn", "preferred_username", "unique_name")
            for (campo in campos) {
                val valor = json.optString(campo)
                if (valor.isNotEmpty()) return valor
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    private fun extrairNomeDoToken(token: String): String? {
        return try {
            val parts = token.split(".")
            if (parts.size < 2) return null
            val payload = parts[1]
            val jsonStr = String(Base64.decode(payload, Base64.URL_SAFE), Charsets.UTF_8)
            val json = JSONObject(jsonStr)
            val campos = listOf("nome", "name")
            for (campo in campos) {
                val valor = json.optString(campo)
                if (valor.isNotEmpty()) return valor
            }
            null
        } catch (e: Exception) {
            null
        }
    }

    private fun salvarToken(token: String) {
        synchronized(this) {
            if (loginConcluido || tokenSalvo) return
            loginConcluido = true
            tokenSalvo = true
        }
        cancelarTimeoutReconnect()
        runOnUiThread {
            try {
                exibirCarregamento(true)
                val sessionManager = SessionManager(this)
                sessionManager.saveToken(token)
                val email = extrairEmailDoToken(token) ?: "usuario@americanas.io"
                val nome = extrairNomeDoToken(token) ?: email.substringBefore("@").split(".").joinToString(" ") { parte ->
                    parte.replaceFirstChar { it.uppercase() }
                }
                sessionManager.saveUserInfo(email, nome, Constants.DEFAULT_STORE)
                if (senhaCredencial.isNotBlank() && emailCredencial.isNotBlank()) {
                    sessionManager.saveCredentials(emailCredencial, senhaCredencial)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    CookieManager.getInstance().flush()
                }
                applicationContext.toast("Login realizado com sucesso!")
                Handler(Looper.getMainLooper()).postDelayed({
                    startActivity(Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                    })
                    finish()
                }, 600)
            } catch (e: Exception) {
                loginConcluido = false
                tokenSalvo = false
                this.toastLong("Erro: ${e.message}")
            }
        }
    }

    private fun preencherLoginAutomatico() {
        if (!autoLogin || loginConcluido || tokenSalvo || isFinishing || isDestroyed) return
        val urlAtual = webView.url ?: return
        if (!urlAtual.contains("login.microsoftonline.com")) return
        if (System.currentTimeMillis() - ultimaInjecao < 1200) return

        if (urlAtual == ultimaUrlPreenchida) {
            tentativasMesmaPagina++
        } else {
            tentativasMesmaPagina = 0
            ultimaUrlPreenchida = urlAtual
        }
        if (tentativasMesmaPagina >= 8) {
            autoLogin = false
            Log.d(TAG, "Auto-login falhou após $tentativasMesmaPagina tentativas. Preencha manualmente.")
            if (silencioso) {
                revelarWebViewManual("Login automático falhou. Preencha manualmente.")
            } else {
                toast("Login automático falhou. Preencha manualmente.")
            }
            return
        }

        ultimaInjecao = System.currentTimeMillis()
        val script = montarScriptPreenchimento(emailCredencial, senhaCredencial)
        webView.evaluateJavascript(script) { resultado ->
            val r = resultado?.trim()?.trim('"') ?: ""
            if (r == "no-field" || r == "email-no-btn" || r == "pwd-no-btn" || r == "kmsi-no-btn") {
                Handler(Looper.getMainLooper()).postDelayed({
                    if (!isFinishing && !isDestroyed) preencherLoginAutomatico()
                }, 1000)
            }
        }
    }

    private fun montarScriptPreenchimento(email: String, senha: String): String {
        val e = jsString(email)
        val s = jsString(senha)
        return "(function(){" +
            "var setV=function(el,v){var d=Object.getOwnPropertyDescriptor(window.HTMLInputElement.prototype,'value');" +
            "if(d&&d.set){d.set.call(el,v);}else{el.value=v;}" +
            "el.dispatchEvent(new Event('input',{bubbles:true}));" +
            "el.dispatchEvent(new Event('change',{bubbles:true}));};" +
            "var btn=document.getElementById('idSIButton9');" +
            "var em=document.getElementById('i0116');" +
            "if(em){setV(em,$e);if(btn){btn.click();return 'email-clicked';}return 'email-no-btn';}" +
            "var pw=document.getElementById('i0118');" +
            "if(pw){setV(pw,$s);if(btn){btn.click();return 'pwd-clicked';}return 'pwd-no-btn';}" +
            "var km=document.getElementById('KmsiCheckboxField');" +
            "if(km){if(btn){btn.click();return 'kmsi-clicked';}return 'kmsi-no-btn';}" +
            "return 'no-field';" +
            "})()"
    }

    private fun jsString(s: String): String =
        "\"" + s.replace("\\", "\\\\").replace("\"", "\\\"").replace("\n", "\\n").replace("\r", "") + "\""

    override fun onBackPressed() {
        if (!silencioso && webView.canGoBack() && !loginConcluido) {
            webView.goBack()
        } else {
            super.onBackPressed()
        }
    }

    override fun onDestroy() {
        cancelarTimeoutReconnect()
        pararAnimacaoPulse()
        try { webView.destroy() } catch (e: Exception) { }
        super.onDestroy()
    }
}
