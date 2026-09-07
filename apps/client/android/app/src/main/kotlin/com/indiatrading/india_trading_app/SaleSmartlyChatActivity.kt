package com.indiatrading.india_trading_app

import android.os.Bundle
import android.view.ViewGroup
import android.widget.FrameLayout
import androidx.activity.ComponentActivity
import com.salesmartly.chatwidget.api.LoginInfo
import com.salesmartly.chatwidget.api.SalesmartlyCallback
import com.salesmartly.chatwidget.api.SalesmartlyChat

class SaleSmartlyChatActivity : ComponentActivity() {
    private lateinit var container: FrameLayout
    private var attached = false
    private var initialMessageSent = false

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        container = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }
        setContentView(container)

        val scriptUrl = intent.getStringExtra("scriptUrl").orEmpty()
        if (scriptUrl.isBlank()) {
            finish()
            return
        }

        SalesmartlyChat.setLoginInfo(
            LoginInfo(
                user_id = intent.getStringExtra("userId").orEmpty(),
                user_name = intent.getStringExtra("userName").orEmpty(),
                language = "en",
                phone = intent.getStringExtra("phone").orEmpty(),
                email = "",
                description = "India Trading customer",
                label_names = listOf("mobile-app", "android"),
                custom_fields_ext = mapOf(
                    "account_number" to intent.getStringExtra("accountNumber").orEmpty(),
                    "source" to "india-trading-android",
                ),
            ),
        )

        SalesmartlyChat.push("onReady", SalesmartlyCallback {
            runOnUiThread { attachAndOpen() }
        })
        SalesmartlyChat.initialize(applicationContext, scriptUrl)
    }

    private fun attachAndOpen() {
        if (!attached) {
            SalesmartlyChat.attach(container)
            attached = true
        }
        SalesmartlyChat.openChat()

        val initialMessage = intent.getStringExtra("initialMessage").orEmpty()
        if (!initialMessageSent && initialMessage.isNotBlank()) {
            SalesmartlyChat.sendTextMessage(initialMessage)
            initialMessageSent = true
        }
    }
}
