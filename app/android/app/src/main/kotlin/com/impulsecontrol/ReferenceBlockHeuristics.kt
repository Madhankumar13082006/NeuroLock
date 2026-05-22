package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * View-id heuristics from `reffer for AI/` reference code:
 * - antiscroll [MyAccessibilityService]: IG `clips_video_container`, YT `reel_recycler`, home row ids
 * - xblockit [BlockAccessibility]: IG `clips_viewer_view_pager`, YT `reel_recycler`, SC `spotlight_container`
 *
 * Requires [android.accessibilityservice.AccessibilityServiceInfo.FLAG_REPORT_VIEW_IDS].
 */
object ReferenceBlockHeuristics {

    const val YT_REEL_RECYCLER = "com.google.android.youtube:id/reel_recycler"
    // Newer YouTube builds sometimes rename Shorts / Reel ids. Keep a small set of
    // alternatives and a substring fallback to avoid "Shorts not blocking" regressions.
    private val YT_REEL_LIKE_IDS = listOf(
        "com.google.android.youtube:id/reel_recycler",
        "com.google.android.youtube:id/reel_view_pager",
        "com.google.android.youtube:id/reel_player",
        "com.google.android.youtube:id/reel_pager",
        "com.google.android.youtube:id/shorts_player",
        "com.google.android.youtube:id/shorts_view_pager",
        "com.google.android.youtube:id/shorts_recycler",
    )

    const val IG_CLIPS_VIEW_PAGER = "com.instagram.android:id/clips_viewer_view_pager"
    const val IG_CLIPS_VIDEO_CONTAINER = "com.instagram.android:id/clips_video_container"
    const val IG_ROW_FEED_PROFILE = "com.instagram.android:id/row_feed_photo_profile_name"
    const val IG_SECONDARY_LABEL = "com.instagram.android:id/secondary_label"
    const val IG_ROW_FEED_SAVE = "com.instagram.android:id/row_feed_button_save"
    const val IG_SEARCH_EDIT = "com.instagram.android:id/action_bar_search_edit_text"
    const val IG_DIRECT_CONTAINER = "com.instagram.android:id/direct_container"
    const val IG_DIRECT_INBOX = "com.instagram.android:id/direct_inbox_fragment"

    const val SC_SPOTLIGHT_CONTAINER = "com.snapchat.android:id/spotlight_container"

    const val CHROME_URL_BAR = "com.android.chrome:id/url_bar"
    private val WEB_URL_VIEW_IDS = listOf(
        "com.android.chrome:id/url_bar",
        "com.android.chrome:id/omnibox_text",
        "com.android.chrome:id/location_bar_status",
        "com.android.chrome:id/url_bar_status",
        "com.google.android.googlequicksearchbox:id/url_bar",
        "com.google.android.googlequicksearchbox:id/search_box",
        "com.google.android.googlequicksearchbox:id/googleapp_browser_url_text",
        "org.mozilla.firefox:id/url_bar_title",
        "org.mozilla.firefox:id/mozac_browser_toolbar_url_view",
        "com.sec.android.app.sbrowser:id/location_bar_edit_text",
        "com.microsoft.emmx:id/url_bar",
        "com.brave.browser:id/url_bar",
        "com.opera.browser:id/url_field",
        "com.vivaldi.browser:id/url_bar",
        "com.duckduckgo.mobile.android:id/omnibarTextInput",
        "com.mi.globalbrowser:id/url_bar",
        "com.android.browser:id/url",
        "com.jio.web:id/url_bar",
        "com.jio.web:id/address_bar",
        "com.jio.jiosphere:id/url_bar",
        "com.jio.jiosphere:id/address_bar",
    )

    const val IG_EXPLORE_GRID = "com.instagram.android:id/explore_grid_media_container"

    fun hasViewId(root: AccessibilityNodeInfo?, fullViewId: String): Boolean {
        if (root == null) return false
        return try {
            val list = root.findAccessibilityNodeInfosByViewId(fullViewId)
            if (list == null || list.isEmpty()) false
            else {
                for (n in list) {
                    try {
                        n.recycle()
                    } catch (_: Exception) {
                    }
                }
                true
            }
        } catch (_: Exception) {
            false
        }
    }

    fun youtubeHasReelRecycler(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, YT_REEL_RECYCLER)

    fun youtubeHasReelSurface(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        for (id in YT_REEL_LIKE_IDS) {
            if (hasViewId(root, id)) return true
        }
        // Fallback: search tree for view-id containing reel/shorts + player/pager/recycler
        return containsYtReelLikeId(root, 0)
    }

    private fun containsYtReelLikeId(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 56) return false
        val id = try {
            node.viewIdResourceName?.lowercase().orEmpty()
        } catch (_: Exception) {
            ""
        }
        if (id.contains("youtube") && (id.contains("reel") || id.contains("shorts"))) {
            if (id.contains("player") || id.contains("pager") || id.contains("recycler") || id.contains("viewer")) {
                // Avoid false positives from shelves/thumbnails.
                if (!id.contains("shelf") && !id.contains("thumbnail") && !id.contains("chip")) {
                    return true
                }
            }
        }
        for (i in 0 until node.childCount) {
            if (containsYtReelLikeId(node.getChild(i), depth + 1)) return true
        }
        return false
    }

    fun instagramReelsOrClipsSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, IG_CLIPS_VIEW_PAGER) || hasViewId(root, IG_CLIPS_VIDEO_CONTAINER)

    private fun instagramReelsStrictSurface(root: AccessibilityNodeInfo?): Boolean =
        instagramReelsOrClipsSurface(root)

    fun instagramHomeFeedSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, IG_ROW_FEED_PROFILE) ||
            hasViewId(root, IG_SECONDARY_LABEL) ||
            hasViewId(root, IG_ROW_FEED_SAVE)

    fun instagramSearchSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, IG_SEARCH_EDIT)

    fun instagramMessagesSurface(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        if (hasViewId(root, IG_DIRECT_CONTAINER) || hasViewId(root, IG_DIRECT_INBOX)) return true
        return try {
            // Fallback for OEM / version variance: match any view-id containing direct/inbox/thread.
            containsViewIdSubstring(root, setOf("direct", "inbox", "thread"), 0)
        } catch (_: Exception) {
            false
        }
    }

    private fun containsViewIdSubstring(
        node: AccessibilityNodeInfo?,
        needles: Set<String>,
        depth: Int,
    ): Boolean {
        if (node == null || depth > 56) return false
        val id = try {
            node.viewIdResourceName?.lowercase().orEmpty()
        } catch (_: Exception) {
            ""
        }
        for (n in needles) {
            if (n.isNotBlank() && id.contains(n)) return true
        }
        for (i in 0 until node.childCount) {
            if (containsViewIdSubstring(node.getChild(i), needles, depth + 1)) return true
        }
        return false
    }

    fun snapchatSpotlightSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, SC_SPOTLIGHT_CONTAINER)

    fun chromeCurrentUrl(root: AccessibilityNodeInfo?): String {
        if (root == null) return ""
        return try {
            // Primary path: known URL view ids from Chrome + Google app web surfaces.
            val byId = extractUrlFromKnownIds(root)
            if (byId.isNotBlank()) return byId

            val byBar = extractUrlFromUrlBarLikeNodes(root, 0)
            if (byBar.isNotBlank()) return byBar

            // Fallback: walk visible text and pick a likely URL token.
            extractLikelyUrlFromTree(root)
        } catch (_: Exception) {
            ""
        }
    }

    private fun extractUrlFromUrlBarLikeNodes(node: AccessibilityNodeInfo?, depth: Int): String {
        if (node == null || depth > 48) return ""
        try {
            val id = node.viewIdResourceName?.lowercase().orEmpty()
            val isBar = id.contains("url") || id.contains("omnibox") || id.contains("address") ||
                id.contains("location_bar") || id.contains("search_box") || id.contains("toolbar")
            if (isBar) {
                val text = node.text?.toString().orEmpty()
                if (text.isNotBlank() && (looksLikeWebUrl(text) || urlIndicatesInstagramWeb(text))) {
                    return text
                }
                val cd = node.contentDescription?.toString().orEmpty()
                if (cd.isNotBlank() && (looksLikeWebUrl(cd) || urlIndicatesInstagramWeb(cd))) {
                    return cd
                }
            }
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            val found = extractUrlFromUrlBarLikeNodes(node.getChild(i), depth + 1)
            if (found.isNotBlank()) return found
        }
        return ""
    }

    private fun extractUrlFromKnownIds(root: AccessibilityNodeInfo): String {
        for (id in WEB_URL_VIEW_IDS) {
            try {
                val list = root.findAccessibilityNodeInfosByViewId(id)
                if (list != null) {
                    for (node in list) {
                        val text = node.text?.toString().orEmpty()
                        if (looksLikeWebUrl(text)) {
                            for (n in list) {
                                try { n.recycle() } catch (_: Exception) {}
                            }
                            return text
                        }
                    }
                    for (n in list) {
                        try { n.recycle() } catch (_: Exception) {}
                    }
                }
            } catch (_: Exception) {
            }
        }
        return ""
    }

    private fun extractLikelyUrlFromTree(root: AccessibilityNodeInfo?): String {
        if (root == null) return ""
        return extractLikelyUrlNode(root, 0)
    }

    private fun extractLikelyUrlNode(node: AccessibilityNodeInfo?, depth: Int): String {
        if (node == null || depth > 56) return ""
        try {
            val text = node.text?.toString().orEmpty()
            if (looksLikeWebUrl(text)) return text
            val contentDesc = node.contentDescription?.toString().orEmpty()
            if (looksLikeWebUrl(contentDesc)) return contentDesc
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            val found = extractLikelyUrlNode(node.getChild(i), depth + 1)
            if (found.isNotBlank()) return found
        }
        return ""
    }

    private fun looksLikeWebUrl(raw: String): Boolean {
        val text = raw.lowercase().trim()
        if (text.isBlank()) return false
        if (urlIndicatesInstagramWeb(text)) return true
        if (text.contains("youtube.com") || text.contains("youtu.be")) return true
        return text.startsWith("http://") || text.startsWith("https://") ||
            (text.contains(".com") && !text.contains(" "))
    }

    /** Any Instagram web surface (feed, reels, profile, explore) — not only /reels paths. */
    private fun urlIndicatesInstagramWeb(raw: String): Boolean {
        val u = raw.lowercase().trim()
        if (u.isBlank()) return false
        if (u.contains("instagram.com") || u.contains("instagr.am")) return true
        if (u == "instagram" || u.startsWith("instagram ")) return false
        if (u == "instagram.com" || u.startsWith("instagram.com/") ||
            u == "www.instagram.com" || u.startsWith("www.instagram.com/")
        ) {
            return true
        }
        return false
    }

    fun browserHasYouTubeShorts(root: AccessibilityNodeInfo?): Boolean {
        val url = chromeCurrentUrl(root).lowercase()
        if (url.isNotBlank()) {
            if (!url.contains("youtube.com") && !url.contains("youtu.be")) return false
            return url.contains("/shorts") ||
                url.contains("shorts/") ||
                url.contains("shorts?") ||
                (url.contains("youtu.be/") && url.contains("short"))
        }
        return treeContainsWebFeatureUrl(root, isYoutubeShorts = true)
    }

    /**
     * True when the browser is showing Instagram on the web (any path: feed, reels, profile, etc.).
     * Matched when Reels / web_reels blocking is enabled in rules.
     */
    fun browserHasInstagramReels(root: AccessibilityNodeInfo?): Boolean {
        val url = chromeCurrentUrl(root).lowercase()
        if (url.isNotBlank() && urlIndicatesInstagramWeb(url)) return true
        return treeIndicatesInstagramWeb(root, 0)
    }

    private fun treeIndicatesInstagramWeb(node: AccessibilityNodeInfo?, depth: Int): Boolean {
        if (node == null || depth > 56) return false
        try {
            val blob = buildString {
                node.text?.toString()?.let { append(it).append(' ') }
                node.contentDescription?.toString()?.let { append(it) }
            }.lowercase()
            if (blob.isNotBlank()) {
                if (urlIndicatesInstagramWeb(blob)) return true
                // Login / home PWA when the URL bar only shows "Instagram".
                if (blob.contains("instagram") &&
                    (blob.contains("log in") || blob.contains("sign up") ||
                        blob.contains("create account") || blob.contains("meta") ||
                        blob.contains("from meta") || blob.contains("phone number"))
                ) {
                    return true
                }
            }
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            if (treeIndicatesInstagramWeb(node.getChild(i), depth + 1)) return true
        }
        return false
    }

    private fun treeContainsWebFeatureUrl(
        root: AccessibilityNodeInfo?,
        isYoutubeShorts: Boolean,
    ): Boolean {
        if (root == null) return false
        return walkWebUrlNodes(root, 0, isYoutubeShorts)
    }

    private fun walkWebUrlNodes(
        node: AccessibilityNodeInfo?,
        depth: Int,
        isYoutubeShorts: Boolean,
    ): Boolean {
        if (node == null || depth > 56) return false
        try {
            val blob = buildString {
                node.text?.toString()?.let { append(it).append(' ') }
                node.contentDescription?.toString()?.let { append(it) }
            }.lowercase()
            if (blob.isNotBlank()) {
                if (isYoutubeShorts) {
                    if ((blob.contains("youtube.com") || blob.contains("youtu.be")) &&
                        (blob.contains("/shorts") || blob.contains("shorts/"))
                    ) {
                        return true
                    }
                } else {
                    if (urlIndicatesInstagramWeb(blob)) return true
                }
            }
        } catch (_: Exception) {
        }
        for (i in 0 until node.childCount) {
            if (walkWebUrlNodes(node.getChild(i), depth + 1, isYoutubeShorts)) return true
        }
        return false
    }

    /** @deprecated Use [browserHasYouTubeShorts] */
    fun chromeHasYouTubeShorts(root: AccessibilityNodeInfo?): Boolean = browserHasYouTubeShorts(root)

    /** @deprecated Use [browserHasInstagramReels] */
    fun chromeHasInstagramReels(root: AccessibilityNodeInfo?): Boolean = browserHasInstagramReels(root)

    fun instagramExploreSurface(root: AccessibilityNodeInfo?): Boolean {
        if (root == null) return false
        if (hasViewId(root, IG_EXPLORE_GRID)) return true
        return containsViewIdSubstring(
            root,
            setOf("explore_fragment", "explore_grid", "explore_media"),
            0,
        )
    }

    private fun keywordTreeFallback(
        service: AccessibilityService,
        feats: Set<String>,
    ): Boolean {
        val root = service.rootInActiveWindow ?: return false
        return try {
            for (f in feats) {
                for (kw in FeatureBlockDetector.keywordsForFeature(f)) {
                    if (FeatureBlockDetector.containsText(root, kw)) return true
                }
            }
            false
        } finally {
            root.recycle()
        }
    }

    /**
     * Reels / Shorts on IG use the Clips viewer; home feed uses row ids from reference.
     */
    fun shouldBlockInstagram(
        service: AccessibilityService,
        event: AccessibilityEvent,
        feats: Set<String>,
    ): Boolean {
        if (feats.isEmpty()) return false

        val root = service.rootInActiveWindow ?: return keywordTreeFallback(service, feats)
        return try {
            val reelsOn = feats.contains("reels")
            val storiesOn = feats.contains("stories")
            val messagesOn = feats.contains("messages")
            val reelsOnly = feats.size == 1 && reelsOn

            // Reels-only mode must never block the whole Instagram app based on
            // nav labels/text ("Reels" tab text appears on non-reels surfaces).
            if (reelsOnly) {
                return instagramReelsStrictSurface(root)
            }

            if (FeatureBlockDetector.classNameSuggestsAnyFeature(event.className, feats)) return true
            if (FeatureBlockDetector.eventTextMatchesAnyFeature(event, feats)) return true

            val clips = instagramReelsOrClipsSurface(root)
            val home = instagramHomeFeedSurface(root)
            val search = instagramSearchSurface(root)
            val inbox = instagramMessagesSurface(root)

            if (reelsOn && clips) return true
            if (messagesOn && inbox) return true
            if (storiesOn && FeatureBlockDetector.containsAnyKeyword(
                    root,
                    FeatureBlockDetector.keywordsForFeature("stories"),
                )
            ) {
                return true
            }

            val storiesOnly = feats.size == 1 && storiesOn
            val messagesOnly = feats.size == 1 && messagesOn
            // Do not scan the whole tree for feature keywords when only one surface is enabled —
            // e.g. bottom-nav "Reels" label on the home feed caused false blocks.
            if (reelsOnly || storiesOnly || messagesOnly) return false

            keywordTreeFallback(service, feats)
        } finally {
            root.recycle()
        }
    }

    fun shouldBlockSnapchat(
        service: AccessibilityService,
        event: AccessibilityEvent,
        feats: Set<String>,
    ): Boolean {
        if (feats.isEmpty()) return false
        if (FeatureBlockDetector.classNameSuggestsAnyFeature(event.className, feats)) return true
        if (FeatureBlockDetector.eventTextMatchesAnyFeature(event, feats)) return true

        val root = service.rootInActiveWindow ?: return keywordTreeFallback(service, feats)
        return try {
            val snaps = feats.contains("snaps")
            val stories = feats.contains("stories")
            if (snaps && snapchatSpotlightSurface(root)) return true
            if (stories && FeatureBlockDetector.containsAnyKeyword(
                    root,
                    FeatureBlockDetector.keywordsForFeature("stories"),
                )
            ) {
                return true
            }
            val snapsOnly = feats.size == 1 && snaps
            val storiesOnly = feats.size == 1 && stories
            if (snapsOnly || storiesOnly) return false

            keywordTreeFallback(service, feats)
        } finally {
            root.recycle()
        }
    }
}
