package com.impulsecontrol

import org.json.JSONObject

/**
 * Major Android browsers / webviews that can open YouTube Shorts or Instagram Reels URLs.
 */
object WebBrowserHeuristics {

    val PACKAGES: Set<String> = setOf(
        FeatureBlockDetector.PKG_CHROME,
        "com.google.android.googlequicksearchbox",
        "org.mozilla.firefox",
        "org.mozilla.firefox_beta",
        "com.sec.android.app.sbrowser",
        "com.microsoft.emmx",
        "com.brave.browser",
        "com.opera.browser",
        "com.opera.mini.native",
        "com.vivaldi.browser",
        "com.duckduckgo.mobile.android",
        "com.mi.globalbrowser",
        "com.huawei.browser",
        "com.UCMobile.intl",
        "com.android.browser",
        "com.vivo.browser",
        "com.heytap.browser",
        "com.coloros.browser",
        // Jio / OEM browsers
        "com.jio.web",
        "com.jio.jiosphere",
        "com.jio.media.jioweb",
        "com.jio.browser",
        "com.jio.myjio.browser",
        "com.jio.media.jiospheresearch",
    )

    fun isWebBrowser(packageName: String): Boolean {
        if (packageName in PACKAGES) return true
        val p = packageName.lowercase()
        if (p.contains("jio") && (p.contains("web") || p.contains("browser") || p.contains("sphere"))) {
            return true
        }
        return false
    }

    fun rulesWantAdultWebBlock(rules: JSONObject): Boolean {
        val arr = rules.optJSONArray(AdultContentHeuristics.PKG_WEB_GUARD) ?: return false
        for (i in 0 until arr.length()) {
            if (arr.optString(i) == AdultContentHeuristics.FEATURE_ADULT_SITES) return true
        }
        return false
    }

    fun rulesWantYouTubeShortsWeb(rules: JSONObject): Boolean {
        val arr = rules.optJSONArray(FeatureBlockDetector.PKG_YOUTUBE) ?: return false
        for (i in 0 until arr.length()) {
            val f = arr.optString(i, "")
            if (f == "shorts" || f == "web_shorts") return true
        }
        return false
    }

    fun rulesWantInstagramReelsWeb(rules: JSONObject): Boolean {
        val arr = rules.optJSONArray(FeatureBlockDetector.PKG_INSTAGRAM) ?: return false
        for (i in 0 until arr.length()) {
            val f = arr.optString(i, "")
            if (f == "reels" || f == "web_reels") return true
        }
        return false
    }

    /** Feature key used for timed allowance on web Shorts blocks. */
    fun youtubeWebFeatureKey(rules: JSONObject): String {
        val arr = rules.optJSONArray(FeatureBlockDetector.PKG_YOUTUBE) ?: return "web_shorts"
        for (i in 0 until arr.length()) {
            if (arr.optString(i) == "web_shorts") return "web_shorts"
        }
        return "shorts"
    }

    /** Feature key used for timed allowance on web Reels blocks. */
    fun instagramWebFeatureKey(rules: JSONObject): String {
        val arr = rules.optJSONArray(FeatureBlockDetector.PKG_INSTAGRAM) ?: return "web_reels"
        for (i in 0 until arr.length()) {
            if (arr.optString(i) == "web_reels") return "web_reels"
        }
        return "reels"
    }
}
