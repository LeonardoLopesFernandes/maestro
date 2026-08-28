package io.maestro.ui

import android.content.Intent
import android.graphics.drawable.TransitionDrawable
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.view.View
import android.view.animation.AccelerateDecelerateInterpolator
import android.view.animation.OvershootInterpolator
import android.widget.Button
import android.widget.EditText
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.core.content.ContextCompat
import io.maestro.R
import io.maestro.network.SessionManager
import io.maestro.utils.Colors
import io.maestro.utils.toast
import io.maestro.utils.toastLong
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.*

class LoginActivity : AppCompatActivity() {

    companion object {
        private const val TAG = "LoginActivity"
    }

    private lateinit var sessionManager: SessionManager
    private var autoLoginDisparado = false
    private var salvarCredenciaisMarcado = false
    private var reconnectEmAndamento = false
    private var webViewAberta = false
    private lateinit var imgCheckboxLogin: ImageView
    private lateinit var logoGrande: ImageView
    private lateinit var tvTitulo: TextView
    private lateinit var tvDescricao: TextView
    private lateinit var containerLogin: LinearLayout
    private lateinit var btnSalvarCredenciais: View
    private var entrarHandler: Handler? = null
    private var entrarPontos = 0

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        try {
            salvarLog("=== LoginActivity.onCreate INICIADO ===")
            
            // SETAR O LAYOUT
            setContentView(R.layout.activity_login)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                window.statusBarColor = android.graphics.Color.parseColor(Colors.RED_500)
            }
            salvarLog("setContentView OK")
            
            sessionManager = SessionManager(this)
            salvarLog("SessionManager criado")
            
            // VERIFICAR SE JÁ ESTÁ LOGADO LOGO NA ENTRADA
            if (verificarSessaoEIrParaMain()) {
                return
            }
            
            // ENCONTRAR O BOTÃO E DEFINIR CLIQUE
            val btnMicrosoft = findViewById<View>(R.id.btnMicrosoft)
            val btnEntrar = findViewById<Button>(R.id.btnEntrar)
            val etEmail = findViewById<EditText>(R.id.etEmail)
            val etSenha = findViewById<EditText>(R.id.etSenha)
            btnSalvarCredenciais = findViewById(R.id.btnSalvarCredenciais)
            imgCheckboxLogin = findViewById(R.id.imgCheckboxLogin)

            // Splash: logo gigante no centro -> volta ao lugar -> título/descrição -> card + checkbox
            logoGrande = findViewById(R.id.logoGrande)
            tvTitulo = findViewById(R.id.tvTitulo)
            tvDescricao = findViewById(R.id.tvDescricao)
            containerLogin = findViewById(R.id.containerLogin)

            // Preencher campos com credenciais salvas (se houver)
            etEmail.setText(sessionManager.getUserEmail() ?: "")
            etSenha.setText(sessionManager.getSavedPassword() ?: "")
            salvarCredenciaisMarcado = sessionManager.hasSavedCredentials()
            imgCheckboxLogin.setImageResource(
                if (salvarCredenciaisMarcado) R.drawable.ic_checkbox_checked else R.drawable.ic_checkbox_unchecked
            )
            configurarOlhoSenha(etSenha)

            // Botão ENTRAR: cinza (desabilitado) até preencher email e senha -> preto (habilitado)
            val textWatcherEntrar = object : android.text.TextWatcher {
                override fun beforeTextChanged(s: CharSequence?, start: Int, count: Int, after: Int) {}
                override fun onTextChanged(s: CharSequence?, start: Int, before: Int, count: Int) {}
                override fun afterTextChanged(s: android.text.Editable?) {
                    atualizarEstadoBotaoEntrar(btnEntrar, etEmail, etSenha)
                }
            }
            etEmail.addTextChangedListener(textWatcherEntrar)
            etSenha.addTextChangedListener(textWatcherEntrar)
            atualizarEstadoBotaoEntrar(btnEntrar, etEmail, etSenha)
            btnEntrar.setOnClickListener {
                try {
                    btnEntrar.isEnabled = false
                    btnEntrar.text = "ENTRANDO"
                    autoLoginDisparado = true

                    iniciarAnimacaoEntrar(btnEntrar)

                    salvarLog("Botão ENTRAR clicado -> Abrindo LoginWebViewActivity com credenciais")
                    val email = etEmail.text.toString().trim()
                    val senha = etSenha.text.toString()
                    val intent = Intent(this, LoginWebViewActivity::class.java).apply {
                        putExtra(LoginWebViewActivity.EXTRA_AUTO_LOGIN, true)
                        putExtra(LoginWebViewActivity.EXTRA_EMAIL, email)
                        putExtra(LoginWebViewActivity.EXTRA_SENHA, senha)
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    pararAnimacaoEntrar()
                    btnEntrar.text = "ENTRAR"
                    salvarErro(e)
                    this.toastLong("Erro: ${e.message}")
                }
            }

            if (sessionManager.hasSavedCredentials()) {
                // Sessão expirada: reconexão automática silenciosa, sem passar pela tela de login
                reconnectEmAndamento = true
                containerLogin.visibility = View.INVISIBLE
                btnSalvarCredenciais.visibility = View.INVISIBLE
                tvDescricao.text = "Sessão expirada. Reconectando automaticamente..."
                animarSplash(mostrarFormulario = false)
                Handler(Looper.getMainLooper()).postDelayed({
                    if (!isFinishing && reconnectEmAndamento) {
                        webViewAberta = true
                        salvarLog("Credenciais salvas -> Reconexão automática silenciosa")
                        abrirLoginMicrosoft(silencioso = true)
                    }
                }, 1000)
            } else {
                animarSplash(mostrarFormulario = true)
            }

            btnMicrosoft.setOnClickListener {
                try {
                    autoLoginDisparado = true
                    salvarLog("Botão clicado -> Abrindo LoginWebViewActivity com credenciais")
                    val email = etEmail.text.toString().trim()
                    val senha = etSenha.text.toString()
                    val intent = Intent(this, LoginWebViewActivity::class.java).apply {
                        putExtra(LoginWebViewActivity.EXTRA_AUTO_LOGIN, true)
                        putExtra(LoginWebViewActivity.EXTRA_EMAIL, email)
                        putExtra(LoginWebViewActivity.EXTRA_SENHA, senha)
                    }
                    startActivity(intent)
                } catch (e: Exception) {
                    salvarErro(e)
                    this.toastLong("Erro: ${e.message}")
                }
            }

            btnSalvarCredenciais.setOnClickListener {
                salvarCredenciaisMarcado = !salvarCredenciaisMarcado
                animarCheckbox()
                if (!salvarCredenciaisMarcado) {
                    toast("Login automático desativado")
                    return@setOnClickListener
                }
                val email = etEmail.text.toString().trim()
                val senha = etSenha.text.toString()
                if (email.isEmpty() || senha.isEmpty()) {
                    toast("Preencha email e senha para salvar")
                    return@setOnClickListener
                }
                sessionManager.saveUserInfo(email, sessionManager.getUserName() ?: email.substringBefore("@"), sessionManager.getUserStore() ?: io.maestro.utils.Constants.DEFAULT_STORE)
                sessionManager.saveCredentials(email, senha)
                toast("Credenciais salvas! Iniciando login automático...")
                autoLoginDisparado = true
                startActivity(Intent(this, LoginWebViewActivity::class.java).apply {
                    putExtra(LoginWebViewActivity.EXTRA_AUTO_LOGIN, true)
                })
            }

            // Se já houver credenciais salvas e a sessão expirou, dispara login automático
            salvarLog("=== LoginActivity.onCreate FINALIZADO ===")
            
        } catch (e: Exception) {
            salvarErro(e)
            this.toastLong("Erro: ${e.message}")
        }
    }

    override fun onResume() {
        super.onResume()
        salvarLog("LoginActivity.onResume chamado -> Verificando se retornou autenticado do WebView")
        // Caso o usuário volte da LoginWebViewActivity, verifica se o token entrou no SharedPreferences
        verificarSessaoEIrParaMain()
        // Voltou do WebView sem concluir o login: mostra o formulário manual
        if (reconnectEmAndamento && webViewAberta) {
            reconnectEmAndamento = false
            containerLogin.visibility = View.VISIBLE
            containerLogin.alpha = 1f
            containerLogin.translationY = 0f
            btnSalvarCredenciais.visibility = View.VISIBLE
            btnSalvarCredenciais.alpha = 1f
            btnSalvarCredenciais.translationY = 0f
            tvTitulo.visibility = View.VISIBLE
            tvTitulo.alpha = 1f
            tvDescricao.visibility = View.VISIBLE
            tvDescricao.alpha = 0.9f
            tvDescricao.text = "Para ter acesso ao portal, vamos manter os fluxos de autenticação segura."
            this.toast("Login automático falhou. Faça login manualmente.")
        }
    }

    /**
     * Valida se a sessão existe e direciona o fluxo para a MainActivity limpando o histórico.
     * @return true se o usuário já estava logado e a transição foi iniciada.
     */
    private fun verificarSessaoEIrParaMain(): Boolean {
        if (::sessionManager.isInitialized && sessionManager.isLoggedIn()) {
            val token = sessionManager.getToken()
            salvarLog("Verificação de sessão: isLoggedIn=true, Token preenchido=${!token.isNullOrEmpty()}")
            
            if (!token.isNullOrEmpty()) {
                salvarLog("Sucesso! Redirecionando de forma limpa para MainActivity")
                val intent = Intent(this, MainActivity::class.java).apply {
                    // Impede que o usuário consiga clicar em 'Voltar' e ver a tela de login de novo
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
                }
                startActivity(intent)
                finish()
                return true
            }
        }
        return false
    }

    private fun abrirLoginMicrosoft(silencioso: Boolean = false) {
        if (autoLoginDisparado || isFinishing || isDestroyed) return
        autoLoginDisparado = true
        try {
            startActivity(Intent(this, LoginWebViewActivity::class.java).apply {
                putExtra(LoginWebViewActivity.EXTRA_AUTO_LOGIN, true)
                putExtra(LoginWebViewActivity.EXTRA_SILENCIOSO, silencioso)
            })
        } catch (e: Exception) {
            autoLoginDisparado = false
            salvarErro(e)
            this.toastLong("Erro: ${e.message}")
        }
    }

    private fun atualizarEstadoBotaoEntrar(btnEntrar: Button, etEmail: EditText, etSenha: EditText) {
        val preenchido = etEmail.text.toString().trim().isNotEmpty() &&
                etSenha.text.toString().isNotEmpty()
        btnEntrar.isEnabled = preenchido
        btnEntrar.setTextColor(
            ContextCompat.getColor(this,
                if (preenchido) android.R.color.white else R.color.btn_disabled_text)
        )
    }

    private fun animarSplash(mostrarFormulario: Boolean) {
        logoGrande.post {
            val loc = IntArray(2)
            logoGrande.getLocationOnScreen(loc)
            val finalCenterY = loc[1] + logoGrande.height / 2f
            val screenCenterY = resources.displayMetrics.heightPixels / 2f
            logoGrande.translationY = (screenCenterY - finalCenterY).coerceAtLeast(0f)
            logoGrande.scaleX = 2.0f
            logoGrande.scaleY = 2.0f

            Handler(Looper.getMainLooper()).postDelayed({
                logoGrande.animate()
                    .scaleX(1.0f)
                    .scaleY(1.0f)
                    .translationY(0f)
                    .setDuration(450)
                    .setInterpolator(AccelerateDecelerateInterpolator())
                    .withEndAction {
                        tvTitulo.visibility = View.VISIBLE
                        tvTitulo.alpha = 0f
                        tvTitulo.animate()
                            .alpha(1f)
                            .setDuration(250)
                            .start()

                        tvDescricao.visibility = View.VISIBLE
                        tvDescricao.alpha = 0f
                        tvDescricao.animate()
                            .alpha(0.90f)
                            .setDuration(250)
                            .start()

                        if (mostrarFormulario) {
                            containerLogin.translationY = 50f
                            containerLogin.animate()
                                .alpha(1f)
                                .translationY(0f)
                                .setDuration(300)
                                .setInterpolator(OvershootInterpolator(0.8f))
                                .start()

                            btnSalvarCredenciais.translationY = 50f
                            btnSalvarCredenciais.animate()
                                .alpha(1f)
                                .translationY(0f)
                                .setDuration(300)
                                .setInterpolator(OvershootInterpolator(0.8f))
                                .start()
                        }
                    }
                    .start()
            }, 400)
        }
    }

    private fun animarCheckbox() {
        try {
            val de = if (salvarCredenciaisMarcado) R.drawable.ic_checkbox_unchecked else R.drawable.ic_checkbox_checked
            val para = if (salvarCredenciaisMarcado) R.drawable.ic_checkbox_checked else R.drawable.ic_checkbox_unchecked
            val transition = TransitionDrawable(
                arrayOf(
                    ContextCompat.getDrawable(this, de),
                    ContextCompat.getDrawable(this, para)
                )
            )
            transition.isCrossFadeEnabled = true
            imgCheckboxLogin.setImageDrawable(transition)
            transition.startTransition(250)
        } catch (e: Exception) {
            imgCheckboxLogin.setImageResource(
                if (salvarCredenciaisMarcado) R.drawable.ic_checkbox_checked else R.drawable.ic_checkbox_unchecked
            )
        }
    }

    private fun iniciarAnimacaoEntrar(btn: Button) {
        pararAnimacaoEntrar()
        entrarPontos = 0
        btn.text = "ENTRANDO"
        val handler = Handler(Looper.getMainLooper())
        entrarHandler = handler
        handler.post(object : Runnable {
            override fun run() {
                if (isFinishing || isDestroyed) return
                entrarPontos = (entrarPontos % 3) + 1
                btn.text = "ENTRANDO" + ".".repeat(entrarPontos)
                handler.postDelayed(this, 350)
            }
        })
    }

    private fun pararAnimacaoEntrar() {
        entrarHandler?.removeCallbacksAndMessages(null)
        entrarHandler = null
    }

    private fun configurarOlhoSenha(et: EditText) {
        var visivel = false
        fun atualizarIcone() {
            et.setCompoundDrawablesRelativeWithIntrinsicBounds(
                0, 0,
                if (visivel) R.drawable.ic_eye_hide else R.drawable.ic_eye_show,
                0
            )
        }
        atualizarIcone()
        et.setOnTouchListener { _, event ->
            val drawables = et.getCompoundDrawablesRelative()
            if (event.actionMasked == android.view.MotionEvent.ACTION_UP && drawables[2] != null) {
                val icone = drawables[2]
                val dentroIcone = event.x >= et.width - et.totalPaddingRight - icone.intrinsicWidth - 8
                if (dentroIcone) {
                    visivel = !visivel
                    val selection = et.selectionEnd.coerceAtLeast(0)
                    et.inputType = if (visivel) {
                        android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_VISIBLE_PASSWORD
                    } else {
                        android.text.InputType.TYPE_CLASS_TEXT or android.text.InputType.TYPE_TEXT_VARIATION_PASSWORD
                    }
                    et.setSelection(selection)
                    atualizarIcone()
                    return@setOnTouchListener true
                }
            }
            false
        }
    }
    
    private fun salvarLog(mensagem: String) {
        try {
            val file = File(getExternalFilesDir(null), "login_log.txt")
            file.appendText("${Date()}: $mensagem\n")
        } catch (e: Exception) { }
    }
    
    private fun salvarErro(throwable: Throwable) {
        try {
            val sw = StringWriter()
            val pw = PrintWriter(sw)
            throwable.printStackTrace(pw)
            val stackTrace = sw.toString()
            
            val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
            val fileName = "login_crash_$timestamp.txt"
            
            val content = """
                ============================================
                LOGIN CRASH
                ============================================
                Data: ${Date()}
                App: Maestro
                
                MENSAGEM: ${throwable.message}
                
                STACK TRACE:
                $stackTrace
                ============================================
            """.trimIndent()
            
            val file = File(getExternalFilesDir(null), fileName)
            file.writeText(content)
            
            try {
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (downloadDir != null) {
                    val downloadFile = File(downloadDir, fileName)
                    downloadFile.writeText(content)
                }
            } catch (e: Exception) { }
            
        } catch (e: Exception) { }
    }

    override fun onDestroy() {
        pararAnimacaoEntrar()
        super.onDestroy()
    }
}
