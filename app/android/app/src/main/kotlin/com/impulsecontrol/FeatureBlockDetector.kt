package com.impulsecontrol

import android.accessibilityservice.AccessibilityService
import android.os.Build
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo

/**
 * Feature-level detection (Shorts, Reels, Stories, Feed) using:
 * - [AccessibilityEvent.getClassName] (activity / fragment hints)
 * - [AccessibilityEvent.getText] and content description
 * - Recursive [AccessibilityNodeInfo] tree walk via [containsText]
 */
object FeatureBlockDetector {

    const val PKG_YOUTUBE = "com.google.android.youtube"
    const val PKG_INSTAGRAM = "com.instagram.android"
    const val PKG_SNAPCHAT = "com.snapchat.android"

    private const val MAX_DEPTH = 48

    /** Lowercase substrings — language coverage for UI labels. */
    private val KEYWORDS_SHORTS = listOf(
        "shorts", "short", "kurzvideo", "kurzvideos", "cortos", "court métrage",
        "ショート", "쇼츠",
    )
    private val KEYWORDS_REELS = listOf(
        "reels", "reel", "рилс", "リール", "릴스",
    )
    private val KEYWORDS_STORIES = listOf(
        "stories", "story", "storie", "geschichten", "historias", "ストーリー",
        "스토리", "histoires",
    )
    private val KEYWORDS_FEED = listOf(
        "following", "for you", "für dich", "pour toi", "suggested", "explore",
        "subscriptions", "abos", "abonnements", "feed", "startseite", "inicio",
    )

    fun keywordsForFeature(featureKey: String): List<String> = when (featureKey) {
        "shorts" -> KEYWORDS_SHORTS
        "reels" -> KEYWORDS_REELS
        "stories" -> KEYWORDS_STORIES
        "feed" -> KEYWORDS_FEED
        else -> emptyList()
    }

    /**
     * Recursively checks [node]'s text, content description, and (API 26+) hint
     * for [keyword] (case-insensitive substring).
     */
    fun containsText(
        node: AccessibilityNodeInfo?,
        keyword: String,
        depth: Int = 0,
    ): Boolean {
        if (node == null || depth > MAX_DEPTH) return false
        val needle = keyword.lowercase()
        try {
            node.text?.toString()?.lowercase()?.let { if (it.contains(needle)) return true }
            node.contentDescription?.toString()?.lowercase()?.let {
                if (it.contains(needle)) return true
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                node.hintText?.toString()?.lowercase()?.let {
                    if (it.contains(needle)) return true
                }
            }
        } catch (_: Exception) {
        }
        val n = node.childCount
        for (i in 0 until n) {
            val child = node.getChild(i) ?: continue
            if (containsText(child, keyword, depth + 1)) return true
        }
        return false
    }

    fun containsAnyKeyword(node: AccessibilityNodeInfo?, keywords: Iterable<String>): Boolean {
        for (k in keywords) {
            if (containsText(node, k)) return true
        }
        return false
    }

    fun collectEventText(event: AccessibilityEvent): List<String> {
        val out = ArrayList<String>()
        try {
            val list = event.text
            if (list != null) {
                for (i in 0 until list.size) {
                    val cs = list[i]
                    if (cs != null && cs.isNotBlank()) out.add(cs.toString())
                }
            }
            event.contentDescription?.let { if (it.isNotBlank()) out.add(it.toString()) }
        } catch (_: Exception) {
        }
        return out
    }

    fun eventTextMatchesAnyFeature(event: AccessibilityEvent, feats: Set<String>): Boolean {
        val blob = collectEventText(event).joinToString(" ").lowercase()
        if (blob.isBlank()) return false
        for (f in feats) {
            for (kw in keywordsForFeature(f)) {
                if (blob.contains(kw)) return true
            }
        }
        return false
    }

    fun classNameSuggestsFeature(className: CharSequence?, featureKey: String): Boolean {
        val c = className?.toString()?.lowercase() ?: return false
        return when (featureKey) {
            "shorts" -> c.contains("shorts") || (c.contains("reel") && c.contains("watch"))
            "reels" -> c.contains("reel") || c.contains("clips") || c.contains("clipsviewer")
            "stories" -> c.contains("story") && !c.contains("history")
            "feed" -> c.contains("feed") || c.contains("timeline") || c.contains("mainfeed") ||
                c.contains("browse") || c.contains("home")
            else -> false
        }
    }

    fun classNameSuggestsAnyFeature(className: CharSequence?, feats: Set<String>): Boolean =
        feats.any { classNameSuggestsFeature(className, it) }

    /**
     * Instagram / Snapchat — view-id heuristics from reference apps
     * ([ReferenceBlockHeuristics]) plus class / text / keyword fallbacks.
     */
    fun shouldBlockGenericSocial(
        service: AccessibilityService,
        event: AccessibilityEvent,
        feats: Set<String>,
        packageName: String,
    ): Boolean {
        return when (packageName) {
            PKG_INSTAGRAM -> ReferenceBlockHeuristics.shouldBlockInstagram(service, event, feats)
            PKG_SNAPCHAT -> ReferenceBlockHeuristics.shouldBlockSnapchat(service, event, feats)
            else -> false
        }
    }
}
