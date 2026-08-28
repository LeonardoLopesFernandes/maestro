package io.maestro.utils

import android.app.Activity
import android.content.Intent
import io.maestro.ui.LoginActivity
import io.maestro.network.SessionManager

object SessionExpiredHandler {
    fun handleSessionExpired(activity: Activity) {
        val sessionManager = SessionManager(activity)
        sessionManager.clearTokenKeepUserInfo()
        
        val intent = Intent(activity, LoginActivity::class.java)
        intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
        activity.startActivity(intent)
        activity.finish()
    }
}