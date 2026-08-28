package io.maestro.network

import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName
import io.maestro.network.models.CountResponse
import io.maestro.network.models.DeliveryToken
import io.maestro.network.models.PedidoResponse
import io.maestro.network.models.PedidoSingleResponse
import okhttp3.ResponseBody
import retrofit2.Response
import retrofit2.http.*

interface ApiService {
    
    // ========== PEDIDOS ==========
    
    @GET("v2/backend/pedido/count")
    suspend fun getCounts(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Query("status") status: String = "PREVISTO,NOVO_PEDIDO,EDITADO,EM_SEPARACAO,PRONTO_PARA_SAIR,SAIU_PARA_ENTREGA,RETORNAR_PARA_ESTOQUE,FINALIZADO,CANCELADO,DEVOLVIDO"
    ): Response<CountResponse>
    
    @GET("v2/backend/pedido/{id}")
    suspend fun getPedidoById(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("id") id: String
    ): Response<PedidoSingleResponse>
    
    @GET("v2/backend/pedido/skip/{skip}/limit/{limit}")
    suspend fun getPedidosPaged(
        @Path("skip") skip: Int,
        @Path("limit") limit: Int,
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Query("status") status: String,
        @Query("minDias") minDias: Int = 0,
        @Query("ordemDataInclusao") ordem: String = "asc",
        @Query("find") search: String? = null,
        @Query("aba") aba: String? = null
    ): Response<PedidoResponse>
    
    @GET("v2/backend/pedido/skip/0/limit/20")
    suspend fun getPedidos(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Query("status") status: String,
        @Query("minDias") minDias: Int = 0,
        @Query("ordemDataInclusao") ordem: String = "asc",
        @Query("find") search: String? = null
    ): Response<PedidoResponse>
    
    @GET("v2/backend/pedido/skip/0/limit/40")
    suspend fun getPedidosLimit40(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Query("status") status: String,
        @Query("minDias") minDias: Int = 0,
        @Query("ordemDataInclusao") ordem: String = "desc"
    ): Response<PedidoResponse>
    
    // ========== AÇÕES DO PEDIDO ==========
    
    // Separar Pedido (NOVO_PEDIDO -> EM_SEPARACAO)
    @PUT("v2/backend/api/pedidos/{origem}/{codigoExterno}/emSeparacao")
    suspend fun separarPedido(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("origem") origem: String,
        @Path("codigoExterno") codigoExterno: String,
        @Body body: Map<String, @JvmSuppressWildcards Any> = mapOf("editado" to "null", "recusado" to "null", "retry" to "false")
    ): Response<PedidoResponse>
    
    // Atualizar Inventário (EM_SEPARACAO -> EM_SEPARACAO com inventário atualizado)
    @PUT("v2/backend/pedido/{numero}/update-inventory")
    suspend fun updateInventory(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("numero") numero: String,
        @Body body: Map<String, Any?>
    ): Response<PedidoResponse>
    
    // Confirmar Pedido (EM_SEPARACAO -> PRONTO_PARA_SAIR)
    @PUT("v2/backend/api/pedidos/{origem}/{codigoExterno}/prontoParaSair")
    suspend fun confirmarPedido(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("origem") origem: String,
        @Path("codigoExterno") codigoExterno: String,
        @Query("editado") editado: Boolean = false,
        @Query("recusado") recusado: String? = null,
        @Query("retry") retry: Boolean = false,
        @Query("motivo") motivo: String? = null,
        @Query("itens") itens: String? = null,
        @Body body: Map<String, @JvmSuppressWildcards Any?>
    ): Response<PedidoResponse>
    
    // ============================================
    // RETIRAR PEDIDO - SHIP_FROM_STORE (Delivery)
    // ============================================
    @PUT("v2/backend/api/pedidos/SHIP_FROM_STORE/{codigoExterno}/saiuParaEntrega")
    suspend fun retirarPedidoShipFromStore(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("codigoExterno") codigoExterno: String,
        @Body body: Map<String, @JvmSuppressWildcards Any?> = emptyMap()
    ): Response<PedidoResponse>
    
    // ============================================
    // RETIRAR PEDIDO - PEGUE NA LOJA HOJE
    // ============================================
    @PUT("v2/backend/api/pedidos/PEGUE_NA_LOJA_HOJE/{codigoExterno}/finalizado")
    suspend fun retirarPedidoPackk(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("codigoExterno") codigoExterno: String,
        @Body body: Map<String, @JvmSuppressWildcards Any> = emptyMap()
    ): Response<PedidoResponse>
    
    // Delivery Tokens
    @GET("v2/backend/api/pedidos/delivery-tokens/{numero}")
    suspend fun getDeliveryTokens(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("numero") numero: String
    ): Response<DeliveryTokensResponse>

    // Verificar Código Retirada
    @GET("v2/backend/pedido/codigo/{codigo}")
    suspend fun verificarCodigoRetirada(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("codigo") codigo: String,
        @Query("numero") numero: String
    ): Response<CodigoResponse>
    
    // Motivos Insucesso
    @GET("v2/backend/pedido/motivo/insucesso")
    suspend fun getMotivosInsucesso(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2"
    ): Response<MotivosResponse>
    
    // Motivos Recusa (com filtros por origem e status)
    @GET("v2/backend/pedido/motivo/recusa")
    suspend fun getMotivosRecusa(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Query("origem") origem: String? = null,
        @Query("status") status: String? = null
    ): Response<RecusaResponse>
    
    // Cancelar Pedido (PRONTO >3 dias) / Recusar (EM_SEPARACAO)
    @PUT("v2/backend/api/pedidos/{origem}/{codigoExterno}/cancelado")
    suspend fun cancelarPedido(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("origem") origem: String,
        @Path("codigoExterno") codigoExterno: String,
        @Query("motivo") motivo: String? = null,
        @Query("recusado") recusado: Boolean? = null,
        @Query("retry") retry: Boolean? = null,
        @Query("editado") editado: String? = null,
        @Query("nomeAutorizador") nomeAutorizador: String? = null,
        @Query("emailAutorizador") emailAutorizador: String? = null,
        @Body body: Map<String, @JvmSuppressWildcards Any?>
    ): Response<PedidoResponse>
    
    // Cancelar Pedido Pronto Retirada (aba PRONTO PARA RETIRADA - >3 dias ou com erro)
    @PUT("v2/backend/api/pedidos/{origem}/{codigoExterno}/cancelado")
    suspend fun cancelarPedidoProntoRetirada(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("origem") origem: String,
        @Path("codigoExterno") codigoExterno: String,
        @Query("motivo") motivo: String? = null,
        @Query("editado") editado: String? = "null",
        @Query("recusado") recusado: Boolean? = false,
        @Query("retry") retry: Boolean? = false,
        @Query("nomeAutorizador") nomeAutorizador: String? = null,
        @Query("emailAutorizador") emailAutorizador: String? = null,
        @Body body: Map<String, @JvmSuppressWildcards Any?>
    ): Response<ResponseBody>
    
    // Retornar para Estoque
    @PUT("v2/backend/api/pedidos/{origem}/{codigoExterno}/retornarParaEstoque")
    suspend fun retornarParaEstoque(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("origem") origem: String,
        @Path("codigoExterno") codigoExterno: String,
        @Body body: Map<String, @JvmSuppressWildcards Any?>
    ): Response<PedidoResponse>
    
    // Confirmar Devolução
    @POST("v2/backend/api/pedidos/loja/devolucao")
    suspend fun confirmarDevolucao(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Body body: Map<String, Any>
    ): Response<DevolucaoResponse>

    // Atualizar Pedido para DEVOLVIDO
    @PUT("v2/backend/api/pedidos/{origem}/{codigoExterno}/devolvido")
    suspend fun devolverPedido(
        @Header("Authorization") auth: String,
        @Header("loja") loja: String,
        @Header("maestro_version") version: String = "v2",
        @Path("origem") origem: String,
        @Path("codigoExterno") codigoExterno: String,
        @Body body: Map<String, @JvmSuppressWildcards Any>
    ): Response<JsonObject>
    
    // ========== ETIQUETAS (PRICE TAGS) ==========
    
    @GET("web/price-tag/store/{loja}")
    suspend fun getPriceTagSummary(
        @Header("Authorization") auth: String,
        @Header("user-store") userStore: String,
        @Header("platform-version") platformVersion: String = "minhaloja/4.0.5",
        @Path("loja") loja: String,
        @Query("startDate") startDate: String
    ): Response<PriceTagSummaryResponse>
    
    @GET("web/price-tag/store/{loja}/filter")
    suspend fun getPriceTagFilters(
        @Header("Authorization") auth: String,
        @Header("user-store") userStore: String,
        @Header("platform-version") platformVersion: String = "minhaloja/4.0.5",
        @Path("loja") loja: String,
        @Query("startDate") startDate: String
    ): Response<PriceTagFilterResponse>
    
    @GET("web/price-tag/store/{loja}/printing")
    suspend fun getPriceTags(
        @Header("Authorization") auth: String,
        @Header("user-store") userStore: String,
        @Header("platform-version") platformVersion: String = "minhaloja/4.0.5",
        @Path("loja") loja: String,
        @Query("status") status: String = "IMPRESSAS,NAO_IMPRESSAS"
    ): Response<PriceTagListResponse>
    
    @POST("web/price-tag/store/{loja}/printer/{printerId}/tag/{tagId}/send")
    suspend fun sendPriceTags(
        @Header("Authorization") auth: String,
        @Header("user-store") userStore: String,
        @Header("platform-version") platformVersion: String = "minhaloja/4.0.5",
        @Path("loja") loja: String,
        @Path("printerId") printerId: String,
        @Path("tagId") tagId: String,
        @Body body: Map<String, Any>
    ): Response<PriceTagSendResponse>
    
    @GET("web/price-tag/store/{loja}/printing/report")
    suspend fun getPriceTagReport(
        @Header("Authorization") auth: String,
        @Header("user-store") userStore: String,
        @Header("platform-version") platformVersion: String = "minhaloja/4.0.5",
        @Path("loja") loja: String,
        @Query("status") status: String = "IMPRESSAS,NAO_IMPRESSAS"
    ): Response<ResponseBody>
}

// ========== MODELOS ==========

data class CodigoResponse(
    @SerializedName("status") val status: String? = null,
    @SerializedName("data") val data: CodigoData = CodigoData(false)
)

data class CodigoData(
    @SerializedName("codigoStatus") val codigoStatus: Boolean = false
)

data class MotivosResponse(
    @SerializedName("status") val status: String? = null,
    @SerializedName("data") val data: List<Motivo> = emptyList()
)

data class Motivo(
    @SerializedName("motivo") val id: String = "",
    @SerializedName("nome") val nome: String = ""
)

data class RecusaResponse(
    @SerializedName("status") val status: Int? = null,
    @SerializedName("data") val data: List<RecusaMotivo> = emptyList()
)

data class RecusaMotivo(
    @SerializedName("code") val code: String = "",
    @SerializedName("description") val description: String = "",
    @SerializedName("subItems") val subItems: List<RecusaSubItem> = emptyList()
)

data class RecusaSubItem(
    @SerializedName("code") val code: String = "",
    @SerializedName("description") val description: String = ""
)

data class DeliveryTokensResponse(
    @SerializedName("status") val status: Int? = null,
    @SerializedName("data") val data: DeliveryToken? = null,
    @SerializedName("tokenRetirada") val tokenRetirada: String? = null,
    @SerializedName("tokenInsucesso") val tokenInsucesso: String? = null,
    @SerializedName("tokenCliente") val tokenCliente: String? = null
)

data class DevolucaoResponse(
    @SerializedName("status") val status: String? = null,
    @SerializedName("message") val message: String? = null,
    @SerializedName("data") val data: DevolucaoData? = null
)

data class DevolucaoData(
    @SerializedName("insucesso") val insucesso: String? = null,
    @SerializedName("codigo") val codigo: String? = null
)

// ========== MODELOS DE ETIQUETAS ==========

data class PriceTagSummaryResponse(
    @SerializedName("menu") val menu: PriceTagMenu = PriceTagMenu(0),
    @SerializedName("page") val page: PriceTagPage = PriceTagPage(PriceTagInfo(PriceTagDate("", ""), 0, 0, 0, false), emptyList())
)

data class PriceTagMenu(
    @SerializedName("totalChanges") val totalChanges: Int = 0
)

data class PriceTagPage(
    @SerializedName("infoTag") val infoTag: PriceTagInfo = PriceTagInfo(PriceTagDate("", ""), 0, 0, 0, false),
    @SerializedName("items") val items: List<PriceTagDepartment> = emptyList()
)

data class PriceTagInfo(
    @SerializedName("date") val date: PriceTagDate = PriceTagDate("", ""),
    @SerializedName("printedTags") val printedTags: Int = 0,
    @SerializedName("unprintedTags") val unprintedTags: Int = 0,
    @SerializedName("totalTags") val totalTags: Int = 0,
    @SerializedName("nextDayPricingEnabled") val nextDayPricingEnabled: Boolean = false
)

data class PriceTagDate(
    @SerializedName("day") val day: String = "",
    @SerializedName("weekday") val weekday: String = ""
)

data class PriceTagDepartment(
    @SerializedName("department") val department: String = "",
    @SerializedName("printed") val printed: Int = 0,
    @SerializedName("unprinted") val unprinted: Int = 0
)

data class PriceTagFilterResponse(
    @SerializedName("tags") val tags: List<PriceTagPrinter> = emptyList(),
    @SerializedName("departments") val departments: List<PriceTagFilterDepartment> = emptyList(),
    @SerializedName("status") val status: List<PriceTagFilterStatus> = emptyList(),
    @SerializedName("printedTags") val printedTags: Int = 0,
    @SerializedName("unprintedTags") val unprintedTags: Int = 0
)

data class PriceTagPrinter(
    @SerializedName("printerId") val printerId: String = "",
    @SerializedName("tagId") val tagId: String = "",
    @SerializedName("label") val label: String = ""
)

data class PriceTagFilterDepartment(
    @SerializedName("id") val id: String = "",
    @SerializedName("label") val label: String = ""
)

data class PriceTagFilterStatus(
    @SerializedName("id") val id: String = "",
    @SerializedName("label") val label: String = ""
)

data class PriceTagListResponse(
    @SerializedName("priceTags") val priceTags: List<PriceTagItem> = emptyList()
)

data class PriceTagItem(
    @SerializedName("id") val id: String = "",
    @SerializedName("sap") val sap: String = "",
    @SerializedName("department") val department: String = "",
    @SerializedName("ean") val ean: String = "",
    @SerializedName("description") val description: String = "",
    @SerializedName("startDate") val startDate: String = "",
    @SerializedName("endDate") val endDate: String? = null,
    @SerializedName("duration") val duration: String? = null,
    @SerializedName("price") val price: String = "",
    @SerializedName("movement") val movement: String = "",
    @SerializedName("status") val status: String = "",
    @SerializedName("checkbox") val checkbox: Boolean = false,
    @SerializedName("quantity") val quantity: Int = 1,
    @SerializedName("_printingData") val printingData: PriceTagPrintingData? = null
)

data class PriceTagPrintingData(
    @SerializedName("ean") val ean: String = "",
    @SerializedName("description") val description: String = "",
    @SerializedName("department") val department: String = "",
    @SerializedName("displayPrice") val displayPrice: Double = 0.0,
    @SerializedName("price") val price: PriceTagPrice = PriceTagPrice(0.0, 0, "", ""),
    @SerializedName("promotionalPrice") val promotionalPrice: PriceTagPromotionalPrice? = null,
    @SerializedName("quantity") val quantity: Int = 0,
    @SerializedName("movementType") val movementType: String = "",
    @SerializedName("unit") val unit: String = "",
    @SerializedName("unitQty") val unitQty: Double = 0.0,
    @SerializedName("unitValue") val unitValue: Double = 0.0,
    @SerializedName("printUnitValue") val printUnitValue: Boolean = false,
    @SerializedName("codSap") val codSap: String = "",
    @SerializedName("takeAndWin") val takeAndWin: PriceTagTakeAndWin? = null,
    @SerializedName("installments") val installments: PriceTagInstallments? = null,
    @SerializedName("referenceDate") val referenceDate: String = ""
)

data class PriceTagPrice(
    @SerializedName("value") val value: Double = 0.0,
    @SerializedName("discountPercent") val discountPercent: Int = 0,
    @SerializedName("startAt") val startAt: String = "",
    @SerializedName("endAt") val endAt: String = ""
)

data class PriceTagPromotionalPrice(
    @SerializedName("value") val value: Double = 0.0,
    @SerializedName("discountPercent") val discountPercent: Int = 0,
    @SerializedName("startAt") val startAt: String = "",
    @SerializedName("endAt") val endAt: String = ""
)

data class PriceTagTakeAndWin(
    @SerializedName("discountValue") val discountValue: Double = 0.0,
    @SerializedName("qty") val qty: Int = 0,
    @SerializedName("totalValue") val totalValue: Double = 0.0
)

data class PriceTagInstallments(
    @SerializedName("installmentQuantity") val installmentQuantity: Int = 0,
    @SerializedName("installmentValue") val installmentValue: Double = 0.0
)

data class PriceTagSendResponse(
    @SerializedName("status") val status: String? = null,
    @SerializedName("message") val message: String? = null
)