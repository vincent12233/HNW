package com.indiatrading.india_trading_app

import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.ProgressBar
import android.widget.TextView
import androidx.activity.ComponentActivity
import com.salesmartly.chatwidget.api.LoginInfo
import com.salesmartly.chatwidget.api.SalesmartlyCallback
import com.salesmartly.chatwidget.api.SalesmartlyChat

/**
 * Hosts the official SalesmartlyChat SDK.
 * Shows a loading state until onReady, then attaches native chat.
 * If the SDK never becomes ready, shows a controlled error with Retry/Close.
 */
class SaleSmartlyChatActivity : ComponentActivity() {
    private lateinit var root: FrameLayout
    private lateinit var chatContainer: FrameLayout
    private lateinit var statusPanel: LinearLayout
    private lateinit var progress: ProgressBar
    private lateinit var statusTitle: TextView
    private lateinit var statusMessage: TextView
    private lateinit var retryButton: Button
    private lateinit var closeButton: Button

    private val mainHandler = Handler(Looper.getMainLooper())
    private var attached = false
    private var initialMessageSent = false
    private var ready = false
    private var finished = false

    private val initTimeoutMs = 20_000L
    private val timeoutRunnable = Runnable {
        if (!ready && !finished) {
            showErrorState()
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        buildUi()
        setContentView(root)

        val scriptUrl = intent.getStringExtra("scriptUrl").orEmpty()
        if (scriptUrl.isBlank()) {
            showErrorState()
            return
        }

        startInitialization(scriptUrl)
    }

    override fun onDestroy() {
        mainHandler.removeCallbacks(timeoutRunnable)
        finished = true
        super.onDestroy()
    }

    private fun buildUi() {
        val density = resources.displayMetrics.density
        fun dp(value: Int) = (value * density).toInt()

        root = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            setBackgroundColor(Color.WHITE)
        }

        chatContainer = FrameLayout(this).apply {
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            visibility = View.GONE
        }

        statusPanel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(28), dp(28), dp(28), dp(28))
            layoutParams = FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
        }

        progress = ProgressBar(this).apply {
            isIndeterminate = true
        }

        statusTitle = TextView(this).apply {
            text = "Connecting to support"
            setTextColor(Color.parseColor("#101828"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            typeface = Typeface.create(Typeface.DEFAULT, Typeface.BOLD)
            gravity = Gravity.CENTER
            setPadding(0, dp(20), 0, dp(8))
        }

        statusMessage = TextView(this).apply {
            text = "Please wait…"
            setTextColor(Color.parseColor("#667085"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
            gravity = Gravity.CENTER
        }

        retryButton = Button(this).apply {
            text = "Retry"
            visibility = View.GONE
            setOnClickListener {
                val scriptUrl = intent.getStringExtra("scriptUrl").orEmpty()
                if (scriptUrl.isBlank()) {
                    showErrorState()
                } else {
                    startInitialization(scriptUrl)
                }
            }
        }

        closeButton = Button(this).apply {
            text = "Close"
            visibility = View.GONE
            setOnClickListener { finish() }
        }

        val buttonRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(24), 0, 0)
            addView(
                retryButton,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ).apply { marginEnd = dp(12) },
            )
            addView(
                closeButton,
                LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                ),
            )
        }

        statusPanel.addView(progress)
        statusPanel.addView(statusTitle)
        statusPanel.addView(statusMessage)
        statusPanel.addView(buttonRow)

        root.addView(chatContainer)
        root.addView(statusPanel)
    }

    private fun showLoadingState() {
        ready = false
        chatContainer.visibility = View.GONE
        statusPanel.visibility = View.VISIBLE
        progress.visibility = View.VISIBLE
        statusTitle.text = "Connecting to support"
        statusMessage.text = "Please wait…"
        retryButton.visibility = View.GONE
        closeButton.visibility = View.GONE
    }

    private fun showErrorState() {
        mainHandler.removeCallbacks(timeoutRunnable)
        chatContainer.visibility = View.GONE
        statusPanel.visibility = View.VISIBLE
        progress.visibility = View.GONE
        statusTitle.text = "Customer support is temporarily unavailable"
        statusMessage.text = "Please try again."
        retryButton.visibility = View.VISIBLE
        closeButton.visibility = View.VISIBLE
    }

    private fun showChatState() {
        statusPanel.visibility = View.GONE
        chatContainer.visibility = View.VISIBLE
    }

    private fun startInitialization(scriptUrl: String) {
        showLoadingState()
        mainHandler.removeCallbacks(timeoutRunnable)
        mainHandler.postDelayed(timeoutRunnable, initTimeoutMs)

        SalesmartlyChat.setLoginInfo(
            LoginInfo(
                user_id = intent.getStringExtra("userId").orEmpty(),
                user_name = intent.getStringExtra("userName").orEmpty(),
                language = "en",
                phone = intent.getStringExtra("phone").orEmpty(),
                email = "",
                description = "India Trading customer",
                label_names = listOf("hnw", "android"),
                custom_fields_ext = mapOf(
                    "source" to "india-trading-android",
                ),
            ),
        )

        SalesmartlyChat.push("onReady", SalesmartlyCallback {
            runOnUiThread {
                if (finished) return@runOnUiThread
                ready = true
                mainHandler.removeCallbacks(timeoutRunnable)
                attachAndOpen()
            }
        })

        try {
            SalesmartlyChat.initialize(applicationContext, scriptUrl)
        } catch (_: Throwable) {
            if (!finished) {
                showErrorState()
            }
        }
    }

    private fun attachAndOpen() {
        try {
            if (!attached) {
                SalesmartlyChat.attach(chatContainer)
                attached = true
            }
            showChatState()
            SalesmartlyChat.openChat()

            val initialMessage = intent.getStringExtra("initialMessage").orEmpty()
            if (!initialMessageSent && initialMessage.isNotBlank()) {
                SalesmartlyChat.sendTextMessage(initialMessage)
                initialMessageSent = true
            }
        } catch (_: Throwable) {
            showErrorState()
        }
    }
}
