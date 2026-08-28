package io.maestro.ui

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Environment
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.*

class MyApplication : Application() {
    
    override fun onCreate() {
        super.onCreate()
        criarCanalNotificacao()
        
        try {
            // SALVAR LOG DE INICIALIZAÇÃO
            salvarLog("=== APPLICATION INICIADO ===")
            
            // Capturar qualquer erro no Application
            Thread.setDefaultUncaughtExceptionHandler { thread, throwable ->
                salvarErro(throwable)
                try {
                    android.widget.Toast.makeText(
                        this,
                        "Erro: ${throwable.message}",
                        android.widget.Toast.LENGTH_LONG
                    ).show()
                } catch (e: Exception) { }
            }
            
            salvarLog("=== APPLICATION FINALIZADO ===")
            
        } catch (e: Exception) {
            salvarErro(e)
        }
    }

    private fun criarCanalNotificacao() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "pedidos_novos",
                "Novos Pedidos",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notificações de novos pedidos"
                enableVibration(true)
            }
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
    
    private fun salvarLog(mensagem: String) {
        try {
            val file = File(getExternalFilesDir(null), "app_log.txt")
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
            val fileName = "crash_$timestamp.txt"
            
            val content = """
                ============================================
                CRASH REPORT
                ============================================
                Data: ${Date()}
                App: Maestro
                
                MENSAGEM: ${throwable.message}
                
                STACK TRACE:
                $stackTrace
                ============================================
            """.trimIndent()
            
            // Salvar no armazenamento externo do app
            val file = File(getExternalFilesDir(null), fileName)
            file.writeText(content)
            
            // Tentar salvar no Download também
            try {
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (downloadDir != null) {
                    val downloadFile = File(downloadDir, fileName)
                    downloadFile.writeText(content)
                }
            } catch (e: Exception) { }
            
        } catch (e: Exception) { }
    }
}