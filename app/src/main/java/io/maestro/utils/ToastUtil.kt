package io.maestro.utils

import android.content.Context
import android.view.Gravity
import android.view.LayoutInflater
import android.widget.TextView
import android.widget.Toast
import io.maestro.R

fun Context.toast(msg: String, duration: Int = Toast.LENGTH_SHORT) {
    val t = Toast(this)
    val v = LayoutInflater.from(this).inflate(R.layout.toast_custom, null)
    v.findViewById<TextView>(android.R.id.message).text = msg
    t.view = v
    t.duration = duration
    t.setGravity(Gravity.BOTTOM, 0, dp(120))
    t.show()
}

fun Context.toastLong(msg: String) {
    toast(msg, Toast.LENGTH_LONG)
}

private fun Context.dp(v: Int): Int =
    (v * resources.displayMetrics.density).toInt()
