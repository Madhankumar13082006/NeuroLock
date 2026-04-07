package com.impulsecontrol.viewmodel

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.impulsecontrol.api.RetrofitClient
import com.impulsecontrol.api.UnlockRequest
import com.impulsecontrol.data.TokenStore
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch

class LockViewModel(application: Application) : AndroidViewModel(application) {

    sealed class UiState {
        object Idle : UiState()
        data class Waiting(val requestId: String) : UiState()
        object Unlocked : UiState()
        data class Error(val message: String) : UiState()
    }

    private val _uiState = MutableStateFlow<UiState>(UiState.Idle)
    val uiState: StateFlow<UiState> = _uiState

    fun requestUnlock(packageName: String) {
        viewModelScope.launch {
            try {
                val token = TokenStore.getAccessToken(getApplication()).first()
                    ?: run {
                        _uiState.value = UiState.Error("Not logged in")
                        return@launch
                    }

                val response = RetrofitClient.api.requestUnlock(
                    "Bearer $token",
                    UnlockRequest(packageName)
                )
                _uiState.value = UiState.Waiting(response.requestId)
                pollStatus(response.requestId, token)
            } catch (e: Exception) {
                _uiState.value = UiState.Error(e.message ?: "Network error")
            }
        }
    }

    private fun pollStatus(requestId: String, token: String) {
        viewModelScope.launch {
            repeat(90) {
                delay(20_000)
                try {
                    val status = RetrofitClient.api.getStatus("Bearer $token", requestId)
                    if (status.status in listOf("APPROVED", "UNLOCKED", "FALLBACK")) {
                        _uiState.value = UiState.Unlocked
                        return@launch
                    }
                } catch (_: Exception) {
                }
            }
        }
    }
}
