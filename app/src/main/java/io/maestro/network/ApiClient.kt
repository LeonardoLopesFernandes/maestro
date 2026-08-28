package io.maestro.network

import android.content.Context
import com.google.gson.GsonBuilder
import io.maestro.network.models.Pedido
import io.maestro.utils.Constants
import okhttp3.Cache
import okhttp3.Interceptor
import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory
import java.io.File
import java.util.concurrent.TimeUnit

class ApiClient(private val context: Context) {

    private val sessionManager = SessionManager(context)

    private val okHttpClient: OkHttpClient by lazy {
        val loggingInterceptor = HttpLoggingInterceptor().apply {
            level = if (android.util.Log.isLoggable("OkHttp", android.util.Log.DEBUG))
                HttpLoggingInterceptor.Level.HEADERS else HttpLoggingInterceptor.Level.NONE
        }

        val authInterceptor = Interceptor { chain ->
            val original = chain.request()
            val token = sessionManager.getToken()
            val loja = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE
            val builder = original.newBuilder()

            if (!token.isNullOrEmpty()) {
                builder.header(Constants.HEADER_AUTHORIZATION, "Bearer $token")
            }
            builder.header(Constants.HEADER_LOJA, loja)
            builder.header(Constants.HEADER_MAESTRO_VERSION, Constants.MAESTRO_VERSION)

            chain.proceed(builder.build())
        }

        val sessionExpiryInterceptor = Interceptor { chain ->
            val response = chain.proceed(chain.request())
            if (response.code == 401) {
                sessionManager.clearTokenKeepUserInfo()
            }
            response
        }

        val cacheDir = File(context.cacheDir, "okhttp_cache")
        val cache = Cache(cacheDir, 10L * 1024 * 1024)

        OkHttpClient.Builder()
            .cache(cache)
            .addInterceptor(loggingInterceptor)
            .addInterceptor(authInterceptor)
            .addInterceptor(sessionExpiryInterceptor)
            .connectTimeout(30, TimeUnit.SECONDS)
            .readTimeout(30, TimeUnit.SECONDS)
            .writeTimeout(60, TimeUnit.SECONDS)
            .build()
    }

    private val retrofit: Retrofit by lazy {
        val gson = GsonBuilder()
            .registerTypeAdapter(Pedido::class.java, PedidoDeserializer())
            .setLenient()
            .create()

        Retrofit.Builder()
            .baseUrl(Constants.BASE_URL)
            .client(okHttpClient)
            .addConverterFactory(GsonConverterFactory.create(gson))
            .build()
    }

    fun getApiService(): ApiService {
        return retrofit.create(ApiService::class.java)
    }

    companion object {
        @Volatile
        private var instance: ApiClient? = null

        fun getInstance(context: Context): ApiClient {
            return instance ?: synchronized(this) {
                instance ?: ApiClient(context.applicationContext).also { instance = it }
            }
        }
    }
}
