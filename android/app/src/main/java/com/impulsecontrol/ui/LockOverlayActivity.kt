package com.impulsecontrol.ui

import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.TextView
import androidx.activity.viewModels
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import com.impulsecontrol.R
import com.impulsecontrol.viewmodel.LockViewModel
import kotlinx.coroutines.launch

class LockOverlayActivity : AppCompatActivity() {

    private val viewModel: LockViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_lock_overlay)

        val packageName = intent.getStringExtra("packageName") ?: run {
            finish()
            return
        }

        val statusText: TextView = findViewById(R.id.statusText)
        val requestBtn: Button = findViewById(R.id.requestUnlockBtn)
        val timerText: TextView = findViewById(R.id.timerText)

        requestBtn.setOnClickListener {
            requestBtn.isEnabled = false
            lifecycleScope.launch {
                viewModel.requestUnlock(packageName)
            }
        }

        lifecycleScope.launch {
            viewModel.uiState.collect { state ->
                when (state) {
                    is LockViewModel.UiState.Idle -> {
                        statusText.text = "This app is blocked"
                        requestBtn.visibility = View.VISIBLE
                        requestBtn.isEnabled = true
                        timerText.visibility = View.GONE
                    }
                    is LockViewModel.UiState.Waiting -> {
                        statusText.text = "Waiting for approval…\nFallback in 20 min"
                        requestBtn.visibility = View.GONE
                        timerText.visibility = View.VISIBLE
                    }
                    is LockViewModel.UiState.Unlocked -> {
                        finish()
                    }
                    is LockViewModel.UiState.Error -> {
                        statusText.text = "Error: ${state.message}"
                        requestBtn.isEnabled = true
                        timerText.visibility = View.GONE
                    }
                }
            }
        }
    }
}
