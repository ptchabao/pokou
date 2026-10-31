package com.pokou.pokou.call

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Les boutons Répondre et Refuser de la notification d'appel.
 *
 * Un `BroadcastReceiver` et NON une activité : c'est toute la différence.
 * Une activité démarre le moteur Flutter, ce qui prend des secondes sur un
 * téléphone en veille — et le chemin « notification → activité → Flutter
 * démarre → cherche l'appel → répond » est précisément celui qu'il faut
 * éviter. Un receveur, lui, s'exécute immédiatement dans le processus
 * existant, sans interface.
 *
 * Refuser ne lance donc JAMAIS Flutter. Répondre ne le lance qu'APRÈS avoir
 * arrêté la sonnerie et prévenu le serveur.
 *
 * ── Les dix secondes ─────────────────────────────────────────────────
 *
 * Android tue un receveur qui dépasse dix secondes. `CallManager` fait donc
 * le travail synchrone — arrêter la sonnerie, fermer la notification — et
 * délègue l'appel réseau à un fil. On ne passe pas par `WorkManager` : il
 * planifie, et un appel n'attend pas.
 */
class CallActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            CallNotification.ACTION_ANSWER -> CallManager.answer(context.applicationContext)
            CallNotification.ACTION_DECLINE -> CallManager.decline(context.applicationContext)
        }
    }
}
