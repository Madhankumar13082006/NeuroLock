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
        if (FeatureBlockDetector.classNameSuggestsAnyFeature(event.className, feats)) return true
        if (FeatureBlockDetector.eventTextMatchesAnyFeature(event, feats)) return true

        val root = service.rootInActiveWindow ?: return keywordTreeFallback(service, feats)
        return try {
            val reelsOn = feats.contains("reels")
            val storiesOn = feats.contains("stories")
            val messagesOn = feats.contains("messages")

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
            keywordTreeFallback(service, feats)
        } finally {
            root.recycle()
        }
    }
}
