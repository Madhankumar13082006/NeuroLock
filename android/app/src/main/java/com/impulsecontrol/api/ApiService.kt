package com.impulsecontrol.api

import retrofit2.http.*

data class UnlockRequest(val packageName: String)
data class UnlockResponse(val requestId: String, val status: String)
data class StatusResponse(val id: String, val status: String, val expiresAt: String?)
data class LoginRequest(val email: String, val password: String)
data class TokenResponse(val accessToken: String, val refreshToken: String)
data class FcmTokenRequest(val fcmToken: String)

interface ApiService {
    @POST("auth/login")
    suspend fun login(@Body req: LoginRequest): TokenResponse

    @POST("unlock/request")
    suspend fun requestUnlock(
        @Header("Authorization") auth: String,
        @Body req: UnlockRequest
    ): UnlockResponse

    @GET("unlock/status/{id}")
    suspend fun getStatus(
        @Header("Authorization") auth: String,
        @Path("id") id: String
    ): StatusResponse

    @PUT("user/fcm-token")
    suspend fun updateFcmToken(
        @Header("Authorization") auth: String,
        @Body req: FcmTokenRequest
    ): Map<String, Boolean>
}
