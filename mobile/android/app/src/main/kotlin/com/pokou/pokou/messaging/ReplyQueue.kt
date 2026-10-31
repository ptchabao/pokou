package com.pokou.pokou.messaging

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

/**
 * Les réponses rapides écrites depuis une notification, EN ATTENTE DE
 * CHIFFREMENT.
 *
 * ── Pourquoi une file, et pas un envoi direct ───────────────────────
 *
 * Le natif ne peut pas chiffrer. Les clés de session vivent dans
 * `E2EEStore`, côté Dart, et les exposer à Kotlin reviendrait à élargir la
 * surface du chiffrement à un second langage, avec une seconde
 * implémentation à tenir juste — c'est-à-dire à la rendre fausse un jour.
 *
 * Envoyer en clair serait pire. Pokou vient de rendre son chiffrement
 * infalsifiable : un chiffrement impossible ARRÊTE l'envoi plutôt que de le
 * dégrader (voir `SealRefused` dans e2ee_outcome.dart). Ouvrir ici une porte
 * qui envoie du clair sans que l'utilisateur l'ait choisi défait exactement
 * ce travail — et personne ne le verrait, puisque le message partirait
 * normalement.
 *
 * Le texte est donc écrit ici, et Flutter le reprend à son prochain
 * démarrage : il le chiffre avec les clés qu'il est seul à détenir, puis
 * l'envoie. L'utilisateur voit « en attente d'envoi », ce qui est vrai.
 *
 * ── Ce que ça coûte, honnêtement ────────────────────────────────────
 *
 * La réponse ne part pas immédiatement si l'application est morte. Elle part
 * à sa prochaine ouverture. C'est un délai réel, et c'est le prix d'une
 * garantie qui, elle, ne se négocie pas.
 */
object ReplyQueue {
    private const val PREFS = "pokou_reply_queue"
    private const val KEY_PENDING = "pending"

    /**
     * Ajoute une réponse à la file.
     *
     * `replyToken` est le laissez-passer du push : Flutter s'en sert pour
     * prouver au serveur que cette réponse vient bien de la notification
     * qu'il a reçue, et il porte l'idempotence — deux appuis sur Envoyer ne
     * produisent qu'un message.
     */
    @Synchronized
    fun enqueue(
        context: Context,
        contactUserId: String,
        text: String,
        replyToken: String?,
    ) {
        if (text.isBlank()) return
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = JSONArray(prefs.getString(KEY_PENDING, "[]"))
        pending.put(
            JSONObject()
                .put("contact_user_id", contactUserId)
                .put("text", text)
                .put("reply_token", replyToken ?: JSONObject.NULL)
                .put("queued_at", System.currentTimeMillis())
        )
        prefs.edit().putString(KEY_PENDING, pending.toString()).apply()
    }

    /**
     * Rend la file à Flutter et la VIDE.
     *
     * Vider ici plutôt qu'après l'envoi est un choix : une réponse envoyée
     * deux fois est un défaut visible et embarrassant, une réponse perdue en
     * cas de plantage entre les deux est un incident rare. Flutter la
     * repose d'ailleurs aussitôt dans sa propre file d'envoi, qui elle
     * survit au redémarrage (voir outbox_service.dart).
     */
    @Synchronized
    fun drain(context: Context): String {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val pending = prefs.getString(KEY_PENDING, "[]") ?: "[]"
        prefs.edit().remove(KEY_PENDING).apply()
        return pending
    }
}
