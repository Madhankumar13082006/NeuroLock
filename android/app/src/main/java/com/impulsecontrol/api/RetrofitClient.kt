package com.impulsecontrol.api

import okhttp3.OkHttpClient
import okhttp3.logging.HttpLoggingInterceptor
import retrofit2.Retrofit
import retrofit2.converter.gson.GsonConverterFactory

data class FcmTokenRequest(val fcmToken: String)

object RetrofitClient {
    private const val BASE_URL = "http://10.0.2.2:3000/" // Use device IP: http://172.31.98.207:3000/ for testing on physical device

    private var storedAccessToken: String = ""

    fun setAccessToken(token: String) {
        storedAccessToken = token
    }

    val api: ApiService by lazy {
        val logging = HttpLoggingInterceptor().apply { level = HttpLoggingInterceptor.Level.BODY }
        val client = OkHttpClient.Builder().addInterceptor(logging).build()
        Retrofit.Builder()
            .baseUrl(BASE_URL)
            .client(client)
            .addConverterFactory(GsonConverterFactory.create())
            .build()
            .create(ApiService::class.java)
    }

    suspend fun updateFcmToken(fcmToken: String) {
        if (storedAccessToken.isNotEmpty()) {
            api.updateFcmToken("Bearer $storedAccessToken", FcmTokenRequest(fcmToken))
        }
    }
}
