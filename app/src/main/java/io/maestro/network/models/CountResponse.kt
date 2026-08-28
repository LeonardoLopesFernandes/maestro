package io.maestro.network.models

import com.google.gson.annotations.JsonAdapter
import com.google.gson.annotations.SerializedName

data class CountResponse(
    @JsonAdapter(StatusDeserializer::class)
    @SerializedName("status") val status: String = "0",
    @SerializedName("data") val data: List<CountItem> = emptyList()
)

data class CountItem(
    @SerializedName("_id") val status: String = "",
    @SerializedName("count") val count: Int = 0
)