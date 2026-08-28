package io.maestro.ui

import android.app.Application
import android.util.Log
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.google.gson.JsonNull
import io.maestro.network.ApiClient
import io.maestro.network.ApiService
import io.maestro.network.RecusaMotivo
import io.maestro.network.SessionManager
import io.maestro.network.models.DeliveryToken
import io.maestro.network.models.Pedido
import io.maestro.utils.Constants
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class PedidoViewModel(application: Application) : AndroidViewModel(application) {

    private val sessionManager = SessionManager(application)
    private val apiService: ApiService = ApiClient.getInstance(application).getApiService()

    private fun normalizarOrigem(origem: String): String {
        return origem.trim().replace(" ", "_").uppercase()
    }

    fun isLoggedIn(): Boolean = sessionManager.isLoggedIn()
    fun getToken(): String? = sessionManager.getToken()
    fun getLoja(): String = sessionManager.getUserStore() ?: Constants.DEFAULT_STORE

    fun saveDeliveryToken(numero: String?, token: String) = sessionManager.saveDeliveryToken(numero, token)
    fun getDeliveryToken(numero: String?): String? = sessionManager.getDeliveryToken(numero)

    // ============================================
    // SEPARAR PEDIDO
    // ============================================
    fun separarPedido(
        origem: String,
        codigoExterno: String,
        onResult: (isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false); return@launch }
                val response = apiService.separarPedido(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno
                )
                onResult(response.isSuccessful)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "separarPedido", e)
                onResult(false)
            }
        }
    }

    // ============================================
    // RETORNAR PARA ESTOQUE
    // ============================================
    fun retornarParaEstoque(
        origem: String,
        codigoExterno: String,
        body: Map<String, @JvmSuppressWildcards Any?>,
        onResult: (isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false); return@launch }
                val response = apiService.retornarParaEstoque(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    body = body
                )
                onResult(response.isSuccessful)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "retornarParaEstoque", e)
                onResult(false)
            }
        }
    }

    // ============================================
    // RETORNAR PARA ESTOQUE (com captchaToken)
    // ============================================
    fun retornarParaEstoque(
        origem: String,
        codigoExterno: String,
        captchaToken: String,
        onResult: (isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false); return@launch }
                val body = mapOf<String, Any>(
                    "editado" to "null",
                    "recusado" to "null",
                    "retry" to false,
                    "captchaToken" to captchaToken
                )
                val response = apiService.retornarParaEstoque(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    body = body
                )
                onResult(response.isSuccessful)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "retornarParaEstoque", e)
                onResult(false)
            }
        }
    }

    // ============================================
    // EXECUTAR DEVOLUÇÃO HISTÓRICO
    // ============================================
    fun executarDevolucaoHistorico(
        origem: String,
        codigoExterno: String,
        loja: String,
        captchaToken: String,
        onResult: (isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false); return@launch }
                val body = mapOf<String, Any>(
                    "editado" to "null",
                    "recusado" to "null",
                    "retry" to false,
                    "captchaToken" to captchaToken
                )
                val response = apiService.retornarParaEstoque(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    body = body
                )
                onResult(response.isSuccessful)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "executarDevolucaoHistorico", e)
                onResult(false)
            }
        }
    }

    // ============================================
    // GET DELIVERY TOKENS
    // ============================================
    fun getDeliveryTokens(
        numero: String,
        onResult: (tokenRetirada: String?, tokenInsucesso: String?, isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(null, null, false); return@launch }
                val response = apiService.getDeliveryTokens(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    numero = numero
                )
                Log.d("PedidoViewModel", "getDeliveryTokens url=${response.raw().request.url} code=${response.code()}")
                if (response.isSuccessful) {
                    val body = response.body()
                    Log.d("PedidoViewModel", "getDeliveryTokens body=$body")
                    val deliveryToken = body?.data
                        ?: DeliveryToken(
                            tokenRetirada = body?.tokenRetirada,
                            tokenInsucesso = body?.tokenInsucesso,
                            tokenCliente = body?.tokenCliente
                        )
                    onResult(deliveryToken?.tokenRetirada, deliveryToken?.tokenInsucesso, true)
                } else {
                    Log.e("PedidoViewModel", "getDeliveryTokens erro body=${response.errorBody()?.string()}")
                    onResult(null, null, false)
                }
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "getDeliveryTokens", e)
                onResult(null, null, false)
            }
        }
    }

    // ============================================
    // VERIFICAR CÓDIGO RETIRADA
    // ============================================
    fun verificarCodigoRetirada(
        codigo: String,
        numero: String?,
        onResult: (isValid: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false); return@launch }
                val response = apiService.verificarCodigoRetirada(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    codigo = codigo,
                    numero = numero ?: ""
                )
                onResult(response.isSuccessful && response.body()?.data?.codigoStatus == true)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "verificarCodigoRetirada", e)
                onResult(false)
            }
        }
    }

    // ============================================
    // RETIRAR PEDIDO - VERIFICAR ORIGEM
    // ============================================
    fun retirarPedido(
        pedido: Pedido,
        onResult: (isSuccess: Boolean, code: Int?) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false, null); return@launch }
                
                val codigoExterno = pedido.codigoExterno ?: ""
                val origem = pedido.origem ?: "SHIP_FROM_STORE"
                
                Log.d("PedidoViewModel", "retirarPedido: origem=$origem, codigoExterno=$codigoExterno")
                
                val response = when (origem) {
                    "PEGUE_NA_LOJA_HOJE" -> {
                        // ✅ Pegue na Loja Hoje
                        apiService.retirarPedidoPackk(
                            auth = "Bearer $token",
                            loja = getLoja(),
                            codigoExterno = codigoExterno,
                            body = emptyMap()
                        )
                    }
                    else -> {
                        // ✅ ShipFromStore (Delivery)
                        apiService.retirarPedidoShipFromStore(
                            auth = "Bearer $token",
                            loja = getLoja(),
                            codigoExterno = codigoExterno,
                            body = emptyMap()
                        )
                    }
                }
                
                val errorBody = response.errorBody()?.string()
                Log.d("PedidoViewModel", "retirarPedido: code=${response.code()} error=$errorBody")
                onResult(response.isSuccessful, response.code())
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "retirarPedido", e)
                onResult(false, null)
            }
        }
    }

    // ============================================
    // GET MOTIVOS INSUCESSO
    // ============================================
    fun getMotivosInsucesso(
        onResult: (motivos: List<io.maestro.network.Motivo>?, isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(null, false); return@launch }
                val response = apiService.getMotivosInsucesso(
                    auth = "Bearer $token",
                    loja = getLoja()
                )
                if (response.isSuccessful) {
                    onResult(response.body()?.data, true)
                } else {
                    onResult(null, false)
                }
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "getMotivosInsucesso", e)
                onResult(null, false)
            }
        }
    }

    // ============================================
    // DEVOLVER PEDIDO (ENTREGADOR VOLTOU)
    // ============================================
    fun devolverPedido(
        origem: String,
        codigoExterno: String,
        motivoId: String,
        motivoNome: String,
        observacao: String,
        captchaToken: String,
        onResult: (isSuccess: Boolean, tokenInsucesso: String?) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false, null); return@launch }
                val body = mapOf<String, Any>(
                    "motivoInsucesso" to mapOf(
                        "motivo" to motivoId,
                        "nome" to motivoNome
                    ),
                    "motivoDevolucao" to observacao,
                    "editado" to JsonNull.INSTANCE,
                    "recusado" to JsonNull.INSTANCE,
                    "retry" to false
                )
                val response = apiService.devolverPedido(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    body = body
                )
                if (response.isSuccessful) {
                    val json = response.body()
                    val tokenInsucesso = json?.getAsJsonObject("data")
                        ?.getAsJsonObject("deliveryToken")
                        ?.get("tokenInsucesso")?.asString
                    onResult(true, tokenInsucesso)
                } else {
                    Log.e("PedidoViewModel", "devolverPedido: code=${response.code()} body=${response.errorBody()?.string()}")
                    onResult(false, null)
                }
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "devolverPedido", e)
                onResult(false, null)
            }
        }
    }

    // ============================================
    // CARREGAR MOTIVOS RECUSA
    // ============================================
    fun carregarMotivosRecusa(
        origem: String,
        status: String,
        onResult: (motivos: List<RecusaMotivo>?, isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(null, false); return@launch }
                val response = apiService.getMotivosRecusa(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = origem,
                    status = status
                )
                if (response.isSuccessful) {
                    val motivos = response.body()?.data
                    Log.d("PedidoViewModel", "getMotivosRecusa origem=$origem status=$status -> ${motivos?.size} motivos: ${motivos?.map { "${it.code}:${it.description}" }}")
                    onResult(motivos, true)
                } else {
                    Log.e("PedidoViewModel", "getMotivosRecusa falhou ${response.code()} err=${response.errorBody()?.string()}")
                    onResult(null, false)
                }
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "carregarMotivosRecusa", e)
                onResult(null, false)
            }
        }
    }

    // ============================================
    // UPDATE INVENTORY
    // ============================================
    fun updateInventory(
        numero: String,
        itensAtualizados: List<Map<String, Any?>>,
        novoValorTotal: Double,
        corpoVazio: Boolean = false,
        onResult: (isSuccess: Boolean) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false); return@launch }
                val updateBody = if (corpoVazio) {
                    emptyMap<String, Any?>()
                } else {
                    mapOf<String, Any?>(
                        "itens" to itensAtualizados,
                        "valorTotal" to novoValorTotal
                    )
                }
                Log.d("PedidoViewModel", "updateInventory numero=$numero body=$updateBody")
                val response = apiService.updateInventory(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    numero = numero,
                    body = updateBody
                )
                val err = response.errorBody()?.string()
                Log.d("PedidoViewModel", "updateInventory response=${response.code()} err=$err")
                onResult(response.isSuccessful)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "updateInventory", e)
                onResult(false)
            }
        }
    }

    // ============================================
    // CONFIRMAR PEDIDO (PRONTO_PARA_SAIR)
    // ============================================
    fun confirmarPedido(
        origem: String,
        codigoExterno: String,
        houveAlteracao: Boolean,
        body: Map<String, Any?>,
        motivoQuery: String?,
        itensQuery: String?,
        onResult: (isSuccess: Boolean, code: Int, errorBody: String?) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false, -1, "auth"); return@launch }
                val response = apiService.confirmarPedido(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    editado = houveAlteracao,
                    recusado = "null",
                    retry = false,
                    motivo = motivoQuery,
                    itens = itensQuery,
                    body = body
                )
                val errorBody = response.errorBody()?.string()
                Log.d("PedidoViewModel", "confirmarPedido origem=$origem codigoExterno=$codigoExterno editado=$houveAlteracao motivo=$motivoQuery itens=$itensQuery body=$body -> ${response.code()} err=$errorBody")
                onResult(response.isSuccessful, response.code(), errorBody)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "confirmarPedido", e)
                onResult(false, -1, e.message)
            }
        }
    }

    // ============================================
    // CANCELAR PEDIDO (PRONTO >3 DIAS)
    // ============================================
    fun cancelarPedido(
        origem: String,
        codigoExterno: String,
        motivo: String,
        onResult: (isSuccess: Boolean, code: Int?) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false, null); return@launch }
                val response = apiService.cancelarPedido(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    motivo = motivo.ifEmpty { null },
                    body = mapOf("motivo" to motivo)
                )
                onResult(response.isSuccessful, response.code())
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "cancelarPedido", e)
                onResult(false, -1)
            }
        }
    }

    // ============================================
    // CANCELAR PEDIDO PRONTO RETIRADA (>3 dias ou com erro)
    // ============================================
    fun cancelarPedidoProntoRetirada(
        origem: String,
        codigoExterno: String,
        motivo: String,
        onResult: (isSuccess: Boolean, code: Int?, errorBody: String?) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false, null, "auth"); return@launch }
                val nome = sessionManager.getUserName()
                val email = sessionManager.getUserEmail()
                val response = apiService.cancelarPedidoProntoRetirada(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    motivo = motivo,
                    nomeAutorizador = nome,
                    emailAutorizador = email,
                    body = mapOf("motivo" to motivo)
                )
                val errorBody = response.errorBody()?.string()
                Log.d("PedidoViewModel", "cancelarPedidoProntoRetirada origem=$origem codigoExterno=$codigoExterno motivo=$motivo -> ${response.code()} err=$errorBody")
                onResult(response.isSuccessful, response.code(), errorBody)
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "cancelarPedidoProntoRetirada", e)
                onResult(false, -1, e.message)
            }
        }
    }

    // ============================================
    // RECUSAR PEDIDO (EM_SEPARACAO)
    // ============================================
    fun recusarPedido(
        origem: String,
        codigoExterno: String,
        motivoCode: String,
        onResult: (isSuccess: Boolean, code: Int?) -> Unit
    ) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(false, null); return@launch }
                val response = apiService.cancelarPedido(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    origem = normalizarOrigem(origem),
                    codigoExterno = codigoExterno,
                    motivo = motivoCode,
                    recusado = true,
                    retry = false,
                    editado = "null",
                    body = mapOf<String, Any?>(
                        "motivo" to motivoCode,
                        "editado" to null,
                        "recusado" to true,
                        "retry" to false
                    )
                )
                Log.d("PedidoViewModel", "recusarPedido origem=$origem codigoExterno=$codigoExterno motivo=$motivoCode -> ${response.code()} err=${response.errorBody()?.string()}")
                onResult(response.isSuccessful, response.code())
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "recusarPedido", e)
                onResult(false, -1)
            }
        }
    }

    fun getPedidoById(pedidoId: String, onResult: (Pedido?) -> Unit) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(null); return@launch }
                val response = apiService.getPedidoById(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    id = pedidoId
                )
                if (response.isSuccessful) {
                    val pedido = response.body()?.data
                    Log.d("PedidoViewModel", "getPedidoById OK: ${pedido?.numero}, itens: ${pedido?.itens?.size}")
                    onResult(pedido)
                } else {
                    val errorBody = response.errorBody()?.string() ?: "sem body"
                    Log.e("PedidoViewModel", "getPedidoById: ${response.code()} - $errorBody")
                    onResult(null)
                }
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "getPedidoById", e)
                onResult(null)
            }
        }
    }

    fun getPedidoByCodigoExterno(codigoExterno: String, onResult: (Pedido?) -> Unit) {
        viewModelScope.launch {
            try {
                val token = getToken()
                if (token.isNullOrEmpty()) { onResult(null); return@launch }
                val response = apiService.getPedidos(
                    auth = "Bearer $token",
                    loja = getLoja(),
                    status = "",
                    search = codigoExterno
                )
                if (response.isSuccessful) {
                    val records = response.body()?.data?.records
                    val pedido = records?.firstOrNull()
                    Log.d("PedidoViewModel", "getPedidoByCodigoExterno: ${pedido?.numero}, itens: ${pedido?.itens?.size}")
                    onResult(pedido)
                } else {
                    Log.e("PedidoViewModel", "getPedidoByCodigoExterno: ${response.code()}")
                    onResult(null)
                }
            } catch (e: Exception) {
                Log.e("PedidoViewModel", "getPedidoByCodigoExterno", e)
                onResult(null)
            }
        }
    }
}