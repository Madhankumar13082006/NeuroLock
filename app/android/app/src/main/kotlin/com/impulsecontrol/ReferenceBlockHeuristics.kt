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

    const val IG_CLIPS_VIEW_PAGER = "com.instagram.android:id/clips_viewer_view_pager"
    const val IG_CLIPS_VIDEO_CONTAINER = "com.instagram.android:id/clips_video_container"
    const val IG_ROW_FEED_PROFILE = "com.instagram.android:id/row_feed_photo_profile_name"
    const val IG_SECONDARY_LABEL = "com.instagram.android:id/secondary_label"
    const val IG_ROW_FEED_SAVE = "com.instagram.android:id/row_feed_button_save"
    const val IG_SEARCH_EDIT = "com.instagram.android:id/action_bar_search_edit_text"

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

    fun instagramReelsOrClipsSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, IG_CLIPS_VIEW_PAGER) || hasViewId(root, IG_CLIPS_VIDEO_CONTAINER)

    fun instagramHomeFeedSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, IG_ROW_FEED_PROFILE) ||
            hasViewId(root, IG_SECONDARY_LABEL) ||
            hasViewId(root, IG_ROW_FEED_SAVE)

    fun instagramSearchSurface(root: AccessibilityNodeInfo?): Boolean =
        hasViewId(root, IG_SEARCH_EDIT)

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
            val reelsOn = feats.contains("reels") || feats.contains("shorts")
            val feedOn = feats.contains("feed")
            val storiesOn = feats.contains("stories")

            val clips = instagramReelsOrClipsSurface(root)
            val home = instagramHomeFeedSurface(root)
            val search = instagramSearchSurface(root)

            if (reelsOn && clips) return true
            if (feedOn && (home || search) && !clips) return true
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
            val vertical = feats.contains("reels") || feats.contains("shorts")
            if (vertical && snapchatSpotlightSurface(root)) return true
            keywordTreeFallback(service, feats)
        } finally {
            root.recycle()
        }
    }
}
