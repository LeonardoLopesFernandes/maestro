package io.maestro.network

import android.util.Log
import com.google.gson.Gson
import com.google.gson.JsonArray
import com.google.gson.JsonDeserializationContext
import com.google.gson.JsonDeserializer
import com.google.gson.JsonElement
import com.google.gson.JsonObject
import io.maestro.network.models.Item
import io.maestro.network.models.Pedido
import java.lang.reflect.Type

class PedidoDeserializer : JsonDeserializer<Pedido> {
    override fun deserialize(json: JsonElement?, typeOfT: Type?, context: JsonDeserializationContext?): Pedido {
        val jsonObject = json?.asJsonObject ?: JsonObject()

        // ✅ REMOVIDO: jsonObject.remove("motivo") - NÃO REMOVA O MOTIVO!

        val itensBackup = jsonObject.remove("itens")

        val gsonPadrao = Gson()
        val pedidoBase = gsonPadrao.fromJson(jsonObject, Pedido::class.java)

        if (itensBackup != null && itensBackup.isJsonArray) {
            val itensArray = itensBackup.asJsonArray
            val itensList = mutableListOf<Item>()

            for (itemElement in itensArray) {
                if (itemElement.isJsonObject) {
                    val itemObj = itemElement.asJsonObject
                    if (itemObj.has("imeis")) {
                        itemObj.add("imeis", itemObj.get("imeis").asJsonArray)
                    } else {
                        itemObj.add("imeis", JsonArray())
                    }
                    try {
                        val item = context?.deserialize<Item>(itemElement, Item::class.java)
                        if (item != null) {
                            itensList.add(item)
                        } else {
                            val fallback = parseItemFallback(itemObj)
                            if (fallback != null) itensList.add(fallback)
                        }
                    } catch (e: Exception) {
                        Log.w("PedidoDeserializer", "Erro ao parsear item, tentando fallback", e)
                        val fallback = parseItemFallback(itemObj)
                        if (fallback != null) itensList.add(fallback)
                    }
                }
            }

            return pedidoBase.copy(itens = itensList)
        }

        return pedidoBase
    }

    private fun parseItemFallback(obj: JsonObject): Item? {
        return try {
            val codigoEAN = obj.get("codigoEAN")?.asString
            val codigoSAP = obj.get("codigoSAP")?.asString
            val descricao = obj.get("descricao")?.asString

            val quantidade = safeGetInt(obj, "quantidade") ?: 0
            val quantidadeTotal = safeGetInt(obj, "quantidadeTotal")
            val valorUnitario = safeGetDouble(obj, "valorUnitario") ?: 0.0
            val valorTotal = safeGetDouble(obj, "valorTotal") ?: 0.0
            val precoVenda = safeGetDouble(obj, "precoVenda")
            val peso = safeGetDouble(obj, "peso")
            val estoque = safeGetInt(obj, "estoque")
            val estoqueInicial = safeGetInt(obj, "estoqueInicial")

            val imeis = if (obj.has("imeis") && obj.get("imeis").isJsonArray) {
                val jsonArray = obj.get("imeis").asJsonArray
                jsonArray.mapNotNull { groupElement ->
                    if (groupElement.isJsonArray) {
                        groupElement.asJsonArray.mapNotNull { it.asString }
                    } else null
                }.ifEmpty { null }
            } else null

            Item(
                codigoEAN = codigoEAN,
                codigoSAP = codigoSAP,
                descricao = descricao,
                quantidade = quantidade,
                quantidadeTotal = quantidadeTotal,
                valorUnitario = valorUnitario,
                valorTotal = valorTotal,
                estoque = estoque,
                estoqueInicial = estoqueInicial,
                precoVenda = precoVenda,
                peso = peso,
                imeis = imeis
            )
        } catch (e: Exception) {
            Log.w("PedidoDeserializer", "Fallback parse falhou", e)
            null
        }
    }

    private fun safeGetDouble(obj: JsonObject, key: String): Double? {
        val el = obj.get(key) ?: return null
        return when {
            el.isJsonNull -> null
            el.isJsonPrimitive -> {
                val p = el.asJsonPrimitive
                if (p.isNumber) p.asDouble
                else p.asString.toDoubleOrNull()
            }
            else -> null
        }
    }

    private fun safeGetInt(obj: JsonObject, key: String): Int? {
        val el = obj.get(key) ?: return null
        return when {
            el.isJsonNull -> null
            el.isJsonPrimitive -> {
                val p = el.asJsonPrimitive
                if (p.isNumber) p.asInt
                else p.asString.toIntOrNull()
            }
            else -> null
        }
    }
}