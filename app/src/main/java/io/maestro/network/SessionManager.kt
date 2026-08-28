package io.maestro.network

import android.content.Context
import android.content.SharedPreferences
import io.maestro.utils.Constants

class SessionManager(context: Context) {
    private val prefs: SharedPreferences = context.getSharedPreferences(Constants.PREFS_NAME, Context.MODE_PRIVATE)
    
    companion object {
        private const val TOKEN_EXPIRY_DAYS = 14
    }
    
    fun saveToken(token: String) {
        try {
            val editor = prefs.edit()
            editor.putString(Constants.KEY_TOKEN, token)
            val expiry = System.currentTimeMillis() + (TOKEN_EXPIRY_DAYS * 24 * 60 * 60 * 1000L)
            editor.putLong(Constants.KEY_TOKEN_EXPIRY, expiry)
            editor.putBoolean(Constants.KEY_LOGGED_IN, true)
            editor.apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun getToken(): String? {
        return try {
            val token = prefs.getString(Constants.KEY_TOKEN, null)
            if (token.isNullOrEmpty()) return null
            if (isTokenExpired()) {
                clearToken()
                return null
            }
            token
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
    
    fun isLoggedIn(): Boolean {
        return try {
            val loggedIn = prefs.getBoolean(Constants.KEY_LOGGED_IN, false)
            val token = getToken()
            loggedIn && !token.isNullOrEmpty()
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
    
    private fun isTokenExpired(): Boolean {
        val expiry = prefs.getLong(Constants.KEY_TOKEN_EXPIRY, 0)
        if (expiry == 0L) return false
        return System.currentTimeMillis() > expiry
    }
    
    fun clearToken() {
        try {
            prefs.edit().apply {
                remove(Constants.KEY_TOKEN)
                remove(Constants.KEY_TOKEN_EXPIRY)
                putBoolean(Constants.KEY_LOGGED_IN, false)
            }.apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun saveUserInfo(email: String, name: String, store: String) {
        try {
            prefs.edit().apply {
                putString(Constants.KEY_USER_EMAIL, email)
                putString(Constants.KEY_USER_NAME, name)
                putString(Constants.KEY_USER_STORE, store)
            }.apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }
    
    fun getUserEmail(): String? = prefs.getString(Constants.KEY_USER_EMAIL, null)
    fun getUserName(): String? = prefs.getString(Constants.KEY_USER_NAME, null)
    fun getUserStore(): String? = prefs.getString(Constants.KEY_USER_STORE, Constants.DEFAULT_STORE)
    
    fun clearAll() {
        try {
            prefs.edit().clear().apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun clearTokenKeepUserInfo() {
        try {
            prefs.edit().apply {
                remove(Constants.KEY_TOKEN)
                remove(Constants.KEY_TOKEN_EXPIRY)
                putBoolean(Constants.KEY_LOGGED_IN, false)
            }.apply()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun saveDeliveryToken(numero: String?, token: String) {
        if (numero.isNullOrBlank()) return
        prefs.edit().putString("DELIVERY_TOKEN_${numero.trim()}", token).apply()
    }

    fun getDeliveryToken(numero: String?): String? {
        if (numero.isNullOrBlank()) return null
        return prefs.getString("DELIVERY_TOKEN_${numero.trim()}", null)
    }

    fun savePedidoItens(numero: String, itensJson: String) {
        prefs.edit().putString("PEDIDO_ITENS_${numero.trim()}", itensJson).apply()
    }

    fun getPedidoItens(numero: String): String? {
        return prefs.getString("PEDIDO_ITENS_${numero.trim()}", null)
    }

    fun salvarUltimoCountNovo(count: Int) {
        prefs.edit().putInt("ULTIMO_COUNT_NOVO", count).apply()
    }

    fun getUltimoCountNovo(): Int {
        return prefs.getInt("ULTIMO_COUNT_NOVO", -1)
    }

    fun saveEditFlag(numero: String) {
        prefs.edit().putBoolean("PEDIDO_EDITADO_${numero.trim()}", true).apply()
    }

    fun isPedidoEditado(numero: String): Boolean {
        return prefs.getBoolean("PEDIDO_EDITADO_${numero.trim()}", false)
    }

    fun getAllEditedPedidoNumbers(): Set<String> {
        val all = prefs.all
        val editPrefix = "PEDIDO_EDITADO_"
        val itensPrefix = "PEDIDO_ITENS_"
        val edited = all.filterKeys { it.startsWith(editPrefix) }
            .mapKeys { it.key.removePrefix(editPrefix) }
            .filterValues { it == true }
            .keys
        val withItens = all.filterKeys { it.startsWith(itensPrefix) }
            .mapKeys { it.key.removePrefix(itensPrefix) }
            .keys
        return edited + withItens
    }

    fun saveCredentials(email: String, password: String) {
        prefs.edit().putString(Constants.KEY_MS_PASSWORD, password).apply()
    }

    fun getSavedPassword(): String? = prefs.getString(Constants.KEY_MS_PASSWORD, null)

    fun hasSavedCredentials(): Boolean {
        return !getUserEmail().isNullOrBlank() && !getSavedPassword().isNullOrBlank()
    }

    fun clearCredentials() {
        prefs.edit().remove(Constants.KEY_MS_PASSWORD).apply()
    }
}