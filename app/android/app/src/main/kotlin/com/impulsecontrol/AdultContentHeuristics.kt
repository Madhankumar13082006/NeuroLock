package com.impulsecontrol

import android.view.accessibility.AccessibilityNodeInfo

/**
 * Detects adult / pornographic URLs in browser URL bars and page content trees.
 */
object AdultContentHeuristics {

    const val PKG_WEB_GUARD = "com.impulsecontrol.web_guard"
    const val FEATURE_ADULT_SITES = "adult_sites"

    /**
     * Host fragments for major adult sites and obvious adult TLD patterns.
     * Matched against the URL host (not arbitrary page text) to limit false positives.
     */
    private val ADULT_HOST_MARKERS = listOf(
        "pornhub",
        "xvideos",
        "xnxx",
        "xhamster",
        "redtube",
        "youporn",
        "spankbang",
        "eporner",
        "chaturbate",
        "onlyfans",
        "fansly",
        "brazzers",
        "bangbros",
        "beeg",
        "fuq.com",
        "literotica",
        "rule34",
        "nhentai",
        "hentai",
        "hanime",
        "missav",
        "jav.guru",
        "porntrex",
        "tnaflix",
        "drtuber",
        "motherless",
        "imagefap",
        "efukt",
        "4tube",
        "xtube",
        "porn.com",
        "xxx.com",
        "sex.com",
        "adultfriendfinder",
        "cam4.com",
        "bongacams",
        "stripchat",
        "livejasmin",
        "myfreecams",
        "xvideo",
        "youjizz",
        "porndig",
        "perfectgirls",
        "faphouse",
        "noodlemagazine",
        "hqporner",
        "pornone",
        "ixxx.com",
        "thumbzilla",
        "tubegalore",
        "lobstertube",
        "fapality",
    )

    private val ADULT_HOST_SUFFIXES = listOf(
        ".xxx",
        ".porn",
        ".sex",
        ".adult",
    )

    /** Benign hosts that must not match generic needles like "sex" in the middle of a word. */
    private val BENIGN_HOST_EXACT = setOf(
        "sussex.ac.uk",
        "essex.edu",
        "middlesex.edu",
    )

    fun urlLooksLikeAdultContent(raw: String): Boolean {
        val host = extractHost(raw)
        if (host.isBlank()) return false
        if (host in BENIGN_HOST_EXACT) return false
        return isAdultHost(host)
    }

    fun browserHasAdultContent(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        val url = ReferenceBlockHeuristics.chromeCurrentUrl(root)
        if (url.isNotBlank() && urlLooksLikeAdultContent(url)) return true
        return treeContainsAdultUrl(root, 0)
    }

    private fun extractHost(raw: String): String {
        var s = raw.lowercase().trim()
        if (s.isBlank()) return ""
        s = s.removePrefix("https://").removePrefix("http://")
        val host = s.substringBefore('/').substringBefore('?').substringBefore('#').substringBefore(':')
        return host.removePrefix("www.").removePrefix("m.")
    }

    private fun isAdultHost(host: String): Boolean {
        if (host.isBlank()) return false
        for (suffix in ADULT_HOST_SUFFIXES) {
            if (host.endsWith(suffix) || host.contains(suffix)) return true
        }
        for (marker in ADULT_HOST_MARKERS) {
            val m = marker.lowercase()
            if (host == m || host.endsWith(".$m") || host.startsWith("$m.")) return true
            if (host.contains(m)) {
                // Require marker to align with a domain label boundary.
                val idx = host.indexOf(m)
                val before = if (idx > 0) host[idx - 1] else '.'
                val afterIdx = idx + m.length
                val after = if (afterIdx < host.length) host[afterIdx] else '.'
                if (before == '.' || idx == 0) {
                    if (after == '.' || after == '/' || afterIdx >= host.length) return true
                }
            }
        }
        // Obvious adult path-only URLs when host is a shortener/CDN (last resort).
        return false
    }

    private fun treeContainsAdultUrl(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 56) return false
        try {
            val chunks = listOfNotNull(
                node.text?.toString(),
                node.contentDescription?.toString(),
            )
            for (chunk in chunks) {
                if (chunk.isBlank()) continue
                val lower = chunk.lowercase()
                if (looksLikeUrlBlob(lower) && urlLooksLikeAdultContent(lower)) return true
                // Page titles often include site names without full URL.
                if (containsAdultSiteName(lower)) return true
            }
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            if (treeContainsAdultUrl(node.getChild(i), depth + 1)) return true
        }
        return false
    }

    private fun looksLikeUrlBlob(s: String): Boolean =
        s.contains("http") || s.contains(".com") || s.contains(".xxx") || s.contains(".net/")

    private fun containsAdultSiteName(s: String): Boolean {
        val needles = listOf(
            "pornhub", "xvideos", "xnxx", "xhamster", "onlyfans", "hentai",
        )
        return needles.any { s.contains(it) }
    }
}
