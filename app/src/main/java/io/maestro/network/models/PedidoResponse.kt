package io.maestro.network.models

import com.google.gson.annotations.JsonAdapter
import com.google.gson.annotations.SerializedName
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import java.lang.reflect.Type

class StatusDeserializer : JsonDeserializer<String> {
    override fun deserialize(json: JsonElement?, typeOfT: Type?, context: JsonDeserializationContext?): String {
        return when {
            json?.isJsonPrimitive == true -> {
                val p = json.asJsonPrimitive
                when {
                    p.isString -> p.asString
                    p.isNumber -> p.asInt.toString()
                    else -> "0"
                }
            }
            else -> "0"
        }
    }
}

data class PedidoResponse(
    @JsonAdapter(StatusDeserializer::class)
    @SerializedName("status") val status: String = "0",
    @SerializedName("data") val data: PedidoData = PedidoData()
)

data class PedidoData(
    @SerializedName("records") val records: List<Pedido> = emptyList(),
    @SerializedName("total") val total: Int? = null,
    @SerializedName("count") val count: Int? = null,
    @SerializedName("counts") val counts: PedidoCounts? = null,
    @SerializedName("skip") val skip: Int? = null,
    @SerializedName("limit") val limit: Int? = null
)

data class PedidoCounts(
    @SerializedName("emAnalise") val emAnalise: Int = 0,
    @SerializedName("parado3Dias") val parado3Dias: Int = 0,
    @SerializedName("coletaTardia") val coletaTardia: Int = 0
)

// Resposta para pedido único (GET /pedido/{id}) - data vem direto como Pedido, não array records
data class PedidoSingleResponse(
    @JsonAdapter(StatusDeserializer::class)
    @SerializedName("status") val status: String = "0",
    @SerializedName("data") val data: Pedido = Pedido()
)
