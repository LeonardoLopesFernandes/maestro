package io.maestro.utils

import android.content.Context
import android.os.Environment
import android.util.Log
import java.io.File
import java.io.PrintWriter
import java.io.StringWriter
import java.text.SimpleDateFormat
import java.util.*

class CrashHandler(private val context: Context) : Thread.UncaughtExceptionHandler {
    
    private val defaultHandler = Thread.getDefaultUncaughtExceptionHandler()
    
    companion object {
        private const val TAG = "CrashHandler"
        
        fun init(context: Context) {
            Thread.setDefaultUncaughtExceptionHandler(CrashHandler(context))
            Log.d(TAG, "CrashHandler inicializado")
        }
    }
    
    override fun uncaughtException(thread: Thread, throwable: Throwable) {
        try {
            salvarCrash(throwable)
            defaultHandler?.uncaughtException(thread, throwable)
        } catch (e: Exception) {
            defaultHandler?.uncaughtException(thread, throwable)
        }
    }
    
    private fun salvarCrash(throwable: Throwable) {
        try {
            val sw = StringWriter()
            val pw = PrintWriter(sw)
            throwable.printStackTrace(pw)
            val stackTrace = sw.toString()
            
            val timestamp = SimpleDateFormat("yyyy-MM-dd_HH-mm-ss", Locale.getDefault()).format(Date())
            val fileName = "crash_$timestamp.txt"
            
            val content = """
                ============================================
                CRASH REPORT - MAESTRO APP
                ============================================
                Data: ${Date()}
                App: Maestro
                Package: io.maestro
                
                MENSAGEM: ${throwable.message}
                
                STACK TRACE:
                $stackTrace
                ============================================
            """.trimIndent()
            
            // Salvar no Download
            try {
                val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                if (downloadDir != null) {
                    if (!downloadDir.exists()) {
                        downloadDir.mkdirs()
                    }
                    val downloadFile = File(downloadDir, fileName)
                    downloadFile.writeText(content)
                    Log.d(TAG, "Crash salvo em: ${downloadFile.absolutePath}")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao salvar no Download", e)
            }
            
            // Salvar no cache do app
            try {
                val cacheFile = File(context.cacheDir, fileName)
                cacheFile.writeText(content)
                Log.d(TAG, "Crash salvo em: ${cacheFile.absolutePath}")
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao salvar no cache", e)
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao salvar crash", e)
        }
    }
}