package com.pokou.pokou.call

import android.content.Context
import android.util.Log
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject

/**
 * Le strict minimum pour parler au serveur depuis la couche native.
 *
 * `HttpURLConnection` et non OkHttp : ce client émet DEUX requêtes dans
 * toute la vie de l'application — accepter, refuser. Ajouter une
 * dépendance pour cela coûterait plus en maintenance et en poids qu'elle
 * n'apporte, et l'API de la bibliothèque standard suffit largement pour un
 * POST JSON.
 *
 * ── Aucun jeton de session ici, et c'est le point ─────────────────────
 *
 * Ce client ne connaît pas l'utilisateur. Il rend le laissez-passer que le
 * push lui a donné, qui n'autorise qu'une action, sur un salon, pour un
 * destinataire. Lire `FlutterSecureStorage` depuis Kotlin aurait voulu dire
 * dépendre de l'implémentation interne d'un greffon tiers ; recopier le
 * jeton de session dans un stockage natif aurait dupliqué un secret longue
 * durée. Voir docs/native-call-layer.md §3.
 */
object PokouApi {
    private const val TAG = "PokouApi"

    /**
     * Où joindre l'API.
     *
     * Écrite par Flutter au démarrage (voir MainActivity) plutôt que codée
     * en dur : l'URL se change par `--dart-define` au build, et deux
     * constantes à tenir d'accord finiraient par diverger. Le défaut ne
     * sert qu'au tout premier lancement, avant que Flutter n'ait jamais
     * tourné.
     */
    private const val PREFS = "pokou_native"
    private const val KEY_BASE_URL = "api_base_url"
    private const val DEFAULT_BASE_URL = "https://api.mahizu.com/api/v1"

    fun baseUrl(context: Context): String =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_BASE_URL, DEFAULT_BASE_URL) ?: DEFAULT_BASE_URL

    fun rememberBaseUrl(context: Context, url: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_BASE_URL, url)
            .apply()
    }

    /**
     * Accepter ou refuser un appel.
     *
     * Renvoie `true` si le serveur a pris acte. Un échec réseau renvoie
     * `false` SANS lever : l'appelant a déjà arrêté la sonnerie et fermé la
     * notification, et lever ici ne ferait que tuer le receveur sans rien
     * réparer.
     *
     * Le serveur répond 200 même pour une action déjà appliquée — voir
     * routes/calls.py::call_action. Un double appui n'est donc pas une
     * erreur, et ce client n'a pas à le distinguer d'un premier appui.
     */
    fun callAction(context: Context, token: String, event: String): Boolean {
        val body = JSONObject()
            .put("token", token)
            .put("event", event)
            .toString()
        return post(context, "/calls/action", body)
    }

    private fun post(context: Context, path: String, body: String): Boolean {
        var connection: HttpURLConnection? = null
        return try {
            connection = (URL(baseUrl(context) + path).openConnection() as HttpURLConnection).apply {
                requestMethod = "POST"
                setRequestProperty("Content-Type", "application/json")
                doOutput = true
                // Court, et volontairement : on est dans un BroadcastReceiver,
                // qu'Android tue au-delà de dix secondes. Mieux vaut échouer
                // vite et laisser Flutter rattraper l'état à son démarrage.
                connectTimeout = 5_000
                readTimeout = 5_000
            }
            connection.outputStream.use { it.write(body.toByteArray()) }
            val code = connection.responseCode
            if (code !in 200..299) {
                // Le corps, pas le jeton : il est dans `body`, qu'on ne
                // journalise pas.
                Log.w(TAG, "POST $path → HTTP $code")
            }
            code in 200..299
        } catch (exception: Exception) {
            Log.w(TAG, "POST $path injoignable : ${exception.javaClass.simpleName}")
            false
        } finally {
            connection?.disconnect()
        }
    }
}
