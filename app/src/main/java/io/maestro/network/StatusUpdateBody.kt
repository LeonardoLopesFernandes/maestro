package io.maestro.network.models

import com.google.gson.annotations.SerializedName

data class StatusUpdateBody(
    @SerializedName("status")
    val status: String
)
