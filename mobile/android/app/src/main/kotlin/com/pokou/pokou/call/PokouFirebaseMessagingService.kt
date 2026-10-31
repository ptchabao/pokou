package com.pokou.pokou.call

import android.util.Log
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

/**
 * Le point d'entrée des notifications push, AVANT Flutter.
 *
 * ── Pourquoi hériter du service du greffon ──────────────────────────
 *
 * Android ne livre un message FCM qu'à UN seul service. Déclarer le nôtre
 * sans plus de précaution ferait disparaître tous les messages que le
 * greffon `firebase_messaging` traite aujourd'hui — les notifications de
 * message, l'enregistrement du jeton, l'isolate d'arrière-plan.
 *
 * On hérite donc de son service et on ne détourne QUE les appels, en
 * laissant tout le reste suivre son chemin habituel. C'est l'erreur la plus
 * fréquente de ce type d'intégration, et elle est silencieuse : les appels
 * marchent, et les messages cessent d'arriver sans que rien ne le dise.
 */
class PokouFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(message: RemoteMessage) {
        val data = message.data
        if (data["type"] == "call") {
            val call = IncomingCall.fromData(data)
            if (call != null) {
                Log.i(TAG, "Appel entrant — salon ${call.room}")
                CallManager.onIncoming(applicationContext, call)
                // On NE transmet PAS au greffon : sans quoi Flutter
                // construirait sa propre notification d'appel par-dessus
                // celle-ci, avec sa propre sonnerie. Deux appels pour un.
                return
            }
            Log.w(TAG, "Push d'appel sans salon exploitable — ignoré")
        }

        if (data["type"] == "call_end") {
            data["room"]?.let { CallManager.onRemoteEnded(applicationContext, it) }
            return
        }

        // Tout le reste — messages, statuts, chaînes — continue vers le
        // greffon, qui sait déjà le traiter.
        super.onMessageReceived(message)
    }

    companion object {
        private const val TAG = "PokouFcm"
    }
}
