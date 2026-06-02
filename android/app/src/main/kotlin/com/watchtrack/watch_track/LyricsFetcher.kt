package com.watchtrack.watch_track

import android.util.Log
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/**
 * Utility class for fetching lyrics from the Lyrics.ovh API.
 * Handles cleaning YouTube video titles to extract the song title and artist,
 * and implements retry logic with multiple variations if the exact match fails.
 */
object LyricsFetcher {
    private const val TAG = "LyricsFetcher"
    private const val API_BASE_URL = "https://api.lyrics.ovh/v1"

    data class LyricsResult(
        val success: Boolean,
        val lyrics: String?,
        val errorMessage: String?
    )

    data class SearchQuery(val artist: String, val title: String)

    /**
     * Cleans the YouTube title and generates a list of search queries to try.
     */
    fun generateSearchQueries(youtubeTitle: String): List<SearchQuery> {
        val queries = mutableListOf<SearchQuery>()
        
        // Remove content in brackets/parentheses e.g. (Official Video), [4K]
        val cleanTitle = youtubeTitle.replace(Regex("\\(.*?\\)"), "")
                                     .replace(Regex("\\[.*?\\]"), "")
        
        // Split by typical separators
        val segments = cleanTitle.split("-", "|", "~").map { it.trim() }.filter { it.isNotEmpty() }
        
        if (segments.isEmpty()) return emptyList()
        
        // The first part is almost always the song title (or occasionally the artist)
        val baseTitle = segments[0]
        
        val noiseWords = listOf(
            "official", "video", "4k", "8k", "lyrical", "audio", "full song", "full video", 
            "hd", "hq", "remix", "cover", "live", "feat", "ft.", "ft ", "director", "music",
            "ost", "soundtrack"
        )
        
        // Filter out segments that look like noise
        val potentialArtists = segments.drop(1).filter { segment ->
            val lower = segment.lowercase()
            noiseWords.none { lower.contains(it) }
        }
        
        // 1. Try potential artists exactly as extracted
        for (artist in potentialArtists) {
            queries.add(SearchQuery(artist, baseTitle))
            
            // If artist string has multiple artists like "Arijit Singh, Shreya Ghoshal"
            val splitArtists = artist.split(Regex("[,&]|(?i)\\s+and\\s+"))
            if (splitArtists.size > 1) {
                queries.add(SearchQuery(splitArtists[0].trim(), baseTitle))
            }
        }
        
        // 2. Format could be "Artist - Title", try swapping the first two segments
        if (potentialArtists.isNotEmpty()) {
            queries.add(SearchQuery(artist = baseTitle, title = potentialArtists.first()))
        }
        
        // 3. Variations on title (e.g. without extra words like 'song')
        val titleWithoutSong = baseTitle.lowercase().replace("song", "").trim()
        if (titleWithoutSong != baseTitle.lowercase() && titleWithoutSong.isNotEmpty() && potentialArtists.isNotEmpty()) {
            queries.add(SearchQuery(potentialArtists.first(), titleWithoutSong))
        }

        // 4. Fallback if no potential artist is found in the title
        if (potentialArtists.isEmpty()) {
            val commonArtists = listOf("Arijit Singh", "Atif Aslam", "Taylor Swift", "The Weeknd")
            for (artist in commonArtists) {
                queries.add(SearchQuery(artist, baseTitle))
            }
        }
        
        // Return up to 5 distinct queries
        return queries.distinct().take(5)
    }

    /**
     * Fetches lyrics with retry logic over generated variations.
     * Call this from a coroutine.
     */
    suspend fun fetchLyrics(youtubeTitle: String): LyricsResult = withContext(Dispatchers.IO) {
        val queries = generateSearchQueries(youtubeTitle)
        
        if (queries.isEmpty()) {
            return@withContext LyricsResult(false, null, "Could not parse title to generate queries.")
        }

        Log.d(TAG, "Generated queries for '$youtubeTitle': $queries")

        for ((index, query) in queries.withIndex()) {
            Log.d(TAG, "Attempt ${index + 1}: Fetching lyrics for Artist='${query.artist}', Title='${query.title}'")
            
            try {
                val encodedArtist = URLEncoder.encode(query.artist, "UTF-8")
                val encodedTitle = URLEncoder.encode(query.title, "UTF-8")
                
                val url = URL("$API_BASE_URL/$encodedArtist/$encodedTitle")
                val connection = url.openConnection() as HttpURLConnection
                connection.requestMethod = "GET"
                connection.connectTimeout = 5000
                connection.readTimeout = 5000
                
                val responseCode = connection.responseCode
                if (responseCode == HttpURLConnection.HTTP_OK) {
                    val response = connection.inputStream.bufferedReader().use { it.readText() }
                    val json = JSONObject(response)
                    if (json.has("lyrics")) {
                        val lyrics = json.getString("lyrics")
                        if (lyrics.isNotBlank()) {
                            Log.d(TAG, "Successfully found lyrics on attempt ${index + 1}")
                            return@withContext LyricsResult(true, lyrics, null)
                        }
                    }
                } else {
                    Log.d(TAG, "Attempt ${index + 1} failed with response code: $responseCode")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Attempt ${index + 1} failed with exception: ${e.message}")
            }
        }
        
        return@withContext LyricsResult(false, null, "Lyrics not found, please try again.")
    }
}
