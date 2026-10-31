package com.pokou.pokou.messaging

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.RemoteInput

/**
 * La réponse rapide depuis une notification de message.
 *
 * Le texte est MIS EN FILE, jamais envoyé d'ici — voir `ReplyQueue` pour la
 * raison, qui tient au chiffrement de bout en bout et n'est pas
 * négociable.
 *
 * La notification est mise à jour pour montrer ce qui a été écrit :
 * l'utilisateur doit voir sa réponse, même si elle n'est pas encore partie.
 * Sans ce retour, l'écran ne dit rien et on tape une seconde fois.
 */
class ReplyActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val texte = RemoteInput.getResultsFromIntent(intent)
            ?.getCharSequence(KEY_REPLY_TEXT)
            ?.toString()
            ?.trim()
            .orEmpty()
        if (texte.isEmpty()) return

        val contactUserId = intent.getStringExtra(EXTRA_CONTACT_USER_ID).orEmpty()
        ReplyQueue.enqueue(
            context.applicationContext,
            contactUserId,
            texte,
            intent.getStringExtra(EXTRA_REPLY_TOKEN),
        )

        // La notification disparaît : le geste est accompli du point de vue
        // de l'utilisateur, et la laisser ouverte avec son champ de saisie
        // inviterait à répondre deux fois.
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, -1)
        if (notificationId >= 0) {
            NotificationManagerCompat.from(context).cancel(notificationId)
        }
    }

    companion object {
        const val ACTION_REPLY = "com.pokou.pokou.REPLY_MESSAGE"
        const val KEY_REPLY_TEXT = "pokou_reply_text"
        const val EXTRA_CONTACT_USER_ID = "contact_user_id"
        const val EXTRA_REPLY_TOKEN = "reply_token"
        const val EXTRA_NOTIFICATION_ID = "notification_id"
    }
}
