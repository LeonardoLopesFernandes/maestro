package io.maestro.utils

object Constants {
    // URLs
    const val BASE_URL = "https://maestro-backend.americanas.io/"
    const val WEB_BASE_URL = "https://maestro.americanas.io/"
    
    // URL de login - redireciona para o login da Microsoft
    const val LOGIN_URL = "https://maestro.americanas.io/unauthorized"
    
    // Status dos pedidos
    const val STATUS_NOVO = "NOVO_PEDIDO"
    const val STATUS_PREVISTO = "PREVISTO"
    const val STATUS_EM_SEPARACAO = "EM_SEPARACAO,EDITADO"
    const val STATUS_PRONTO_PARA_SAIR = "PRONTO_PARA_SAIR"
    const val STATUS_SAIU_PARA_ENTREGA = "SAIU_PARA_ENTREGA"
    const val STATUS_RETORNAR_ESTOQUE = "RETORNAR_PARA_ESTOQUE"
    const val STATUS_HISTORICO = "FINALIZADO,CANCELADO,DEVOLVIDO"
    
    // Headers
    const val HEADER_AUTHORIZATION = "Authorization"
    const val HEADER_LOJA = "loja"
    const val HEADER_MAESTRO_VERSION = "maestro_version"
    const val MAESTRO_VERSION = "v2"
    
    // SharedPreferences
    const val PREFS_NAME = "MaestroPrefs"
    const val KEY_TOKEN = "BEARER_TOKEN"
    const val KEY_TOKEN_EXPIRY = "TOKEN_EXPIRY"
    const val KEY_USER_EMAIL = "USER_EMAIL"
    const val KEY_USER_NAME = "USER_NAME"
    const val KEY_USER_STORE = "USER_STORE"
    const val KEY_LOGGED_IN = "LOGGED_IN"
    const val KEY_MS_PASSWORD = "MS_PASSWORD"
    
    // Paginação
    const val DEFAULT_LIMIT = 20
    const val DEFAULT_STORE = "L291"
    
    // reCAPTCHA - Site Key extraída do frontend web do Maestro
    const val RECAPTCHA_SITE_KEY = "6LcGCN4aAAAAACBn8w45pz5foZB7yf7RO_bZUJl6"
}