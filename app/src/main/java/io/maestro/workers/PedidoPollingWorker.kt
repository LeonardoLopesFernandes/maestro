package io.maestro.workers

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.work.*
import io.maestro.R
import io.maestro.network.ApiClient
import io.maestro.network.SessionManager
import io.maestro.ui.MainActivity
import io.maestro.utils.Constants
import java.util.concurrent.TimeUnit

class PedidoPollingWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val sessionManager = SessionManager(applicationContext)
        val token = sessionManager.getToken() ?: return Result.success()
        val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE

        return try {
            val apiService = ApiClient.getInstance(applicationContext).getApiService()
            val response = apiService.getCounts(
                auth = "Bearer $token",
                loja = loja
            )

            if (!response.isSuccessful) return Result.retry()

            val counts = response.body() ?: return Result.retry()
            val countAtual = counts.data?.find { it.status == "NOVO_PEDIDO" }?.count ?: 0
            val ultimoCount = sessionManager.getUltimoCountNovo()

            if (countAtual > ultimoCount && ultimoCount >= 0) {
                val novos = countAtual - ultimoCount
                mostrarNotificacao(novos)
            }

            sessionManager.salvarUltimoCountNovo(countAtual)
            agendarProximoPolling(applicationContext)
            Result.success()
        } catch (e: Exception) {
            agendarProximoPolling(applicationContext)
            Result.retry()
        }
    }

    private fun mostrarNotificacao(quantidade: Int) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    applicationContext,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) return
        }

        val intent = Intent(applicationContext, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            applicationContext, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(applicationContext, "pedidos_novos")
            .setSmallIcon(R.drawable.ic_notifica_pedido)
            .setContentTitle("Novos Pedidos")
            .setContentText("$quantidade novo(s) pedido(s) recebido(s)")
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        NotificationManagerCompat.from(applicationContext).notify(1001, notification)
    }

    companion object {
        private const val WORK_NAME = "pedido_polling"
        private const val INTERVALO_MINUTOS = 5L

        fun iniciar(context: Context) {
            val workRequest = OneTimeWorkRequestBuilder<PedidoPollingWorker>()
                .setInitialDelay(1, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                workRequest
            )
        }

        fun parar(context: Context) {
            WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
        }

        fun agendarProximoPolling(context: Context) {
            val workRequest = OneTimeWorkRequestBuilder<PedidoPollingWorker>()
                .setInitialDelay(INTERVALO_MINUTOS, TimeUnit.MINUTES)
                .build()

            WorkManager.getInstance(context).enqueueUniqueWork(
                WORK_NAME,
                ExistingWorkPolicy.REPLACE,
                workRequest
            )
        }
    }
}
