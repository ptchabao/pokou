package com.pokou.pokou.call

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log

/**
 * La source UNIQUE de vérité de l'état d'un appel entrant.
 *
 * Ni la notification, ni le service de sonnerie, ni Flutter ne détiennent
 * d'état propre : tous observent celui-ci. C'est la condition pour que
 * l'interface ne se désynchronise pas du réseau — le défaut classique étant
 * qu'ouvrir l'écran d'appel soit pris pour « l'appel est connecté ».
 *
 * `object` et non une instance injectée : un appel entrant traverse un
 * service FCM, un service de premier plan, un receveur de diffusion et une
 * activité, tous créés et détruits indépendamment par le système. Un état
 * porté par l'un d'eux disparaîtrait avec lui. Le processus, lui, survit à
 * ces quatre-là.
 *
 * ── L'ordre des opérations, qui n'est pas négociable ─────────────────
 *
 * À CHAQUE transition hors de RINGING, on arrête la sonnerie et la
 * vibration AVANT tout appel réseau. L'utilisateur ne doit pas entendre son
 * téléphone sonner pendant que le réseau réfléchit — c'est la différence la
 * plus perceptible entre une application qui semble native et une qui ne
 * l'est pas.
 */
object CallManager {
    private const val TAG = "CallManager"

    /**
     * La sonnerie s'arrête d'elle-même au bout de ce délai.
     *
     * Une sonnerie qui ne s'arrête jamais est un défaut, pas une
     * fonctionnalité : le téléphone d'une personne absente sonnerait jusqu'à
     * la batterie vide.
     */
    private const val RING_TIMEOUT_MS = 45_000L

    @Volatile
    private var current: IncomingCall? = null

    @Volatile
    private var state: CallState = CallState.ENDED

    private val mainHandler = Handler(Looper.getMainLooper())
    private var timeoutRunnable: Runnable? = null

    /** Les observateurs — en pratique le pont vers Flutter. */
    private val listeners = mutableSetOf<(CallState, IncomingCall?) -> Unit>()

    @Synchronized
    fun addListener(listener: (CallState, IncomingCall?) -> Unit) {
        listeners.add(listener)
        // L'état COURANT tout de suite : Flutter peut démarrer après le
        // début de l'appel, et un observateur qui n'apprend rien tant que
        // rien ne change ouvrirait l'écran d'appel sur un état vide.
        listener(state, current)
    }

    @Synchronized
    fun removeListener(listener: (CallState, IncomingCall?) -> Unit) {
        listeners.remove(listener)
    }

    fun currentCall(): IncomingCall? = current

    fun currentState(): CallState = state

    /** Un push d'appel vient d'arriver. */
    @Synchronized
    fun onIncoming(context: Context, call: IncomingCall) {
        // Un second appel pendant qu'un premier sonne : on garde le premier.
        // Empiler deux sonneries et deux notifications plein écran serait
        // ingérable pour l'utilisateur, et le serveur marquera le second
        // comme manqué de lui-même.
        if (state == CallState.RINGING && current?.room != call.room) {
            Log.i(TAG, "Appel ignoré : un autre sonne déjà")
            return
        }
        current = call
        transition(context, CallState.RINGING)
        // Le service porte LA notification — celle avec Refuser et Répondre
        // — en même temps que la sonnerie. En poser une seconde ici faisait
        // apparaître DEUX notifications pour un seul appel.
        RingtoneService.start(context, call)
        scheduleTimeout(context, call.room)
    }

    /** L'utilisateur a touché « Répondre ». */
    @Synchronized
    fun answer(context: Context) {
        val call = current ?: return
        if (state != CallState.RINGING) return

        // Le silence D'ABORD, le réseau ensuite.
        stopRinging(context)
        transition(context, CallState.ANSWERING)

        val token = call.answerToken
        if (token == null) {
            // Pas de laissez-passer : le push vient d'un serveur qui n'en
            // émet pas encore. On laisse Flutter prendre le relais plutôt
            // que d'échouer — c'est le repli décrit au §7 de la
            // spécification, et il disparaîtra avec lui.
            Log.i(TAG, "Aucun jeton d'action : reprise par Flutter")
            transition(context, CallState.CONNECTING)
            launchFlutter(context, call)
            return
        }

        Thread {
            val ok = PokouApi.callAction(context, token, "accept")
            synchronized(this) {
                if (current?.room != call.room) return@synchronized
                transition(context, if (ok) CallState.CONNECTING else CallState.FAILED)
            }
            if (ok) launchFlutter(context, call) else CallNotification.dismiss(context)
        }.start()
    }

    /** L'utilisateur a touché « Refuser ». */
    @Synchronized
    fun decline(context: Context) {
        val call = current ?: return
        if (state.isTerminal) return

        stopRinging(context)
        CallNotification.dismiss(context)
        transition(context, CallState.ENDED)

        val token = call.declineToken ?: return
        // En arrière-plan, et SANS lancer Flutter : c'est tout l'intérêt du
        // refus depuis l'écran verrouillé. Rien de ce qui suit n'a besoin
        // d'une interface.
        Thread { PokouApi.callAction(context, token, "decline") }.start()
    }

    /** L'appelant a raccroché, ou le serveur a clos l'appel. */
    @Synchronized
    fun onRemoteEnded(context: Context, room: String) {
        if (current?.room != room) return
        stopRinging(context)
        CallNotification.dismiss(context)
        transition(context, CallState.ENDED)
    }

    /** Flutter signale que le média est établi. */
    @Synchronized
    fun onConnected(context: Context) {
        if (state == CallState.CONNECTING || state == CallState.ANSWERING) {
            transition(context, CallState.CONNECTED)
        }
    }

    /** Flutter signale la fin de l'appel. */
    @Synchronized
    fun onEnded(context: Context) {
        stopRinging(context)
        CallNotification.dismiss(context)
        transition(context, CallState.ENDED)
    }

    private fun scheduleTimeout(context: Context, room: String) {
        cancelTimeout()
        val runnable = Runnable {
            synchronized(this) {
                if (current?.room != room || state != CallState.RINGING) return@synchronized
                stopRinging(context)
                CallNotification.showMissed(context, current)
                transition(context, CallState.MISSED)
            }
        }
        timeoutRunnable = runnable
        mainHandler.postDelayed(runnable, RING_TIMEOUT_MS)
    }

    private fun cancelTimeout() {
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
    }

    private fun stopRinging(context: Context) {
        cancelTimeout()
        RingtoneService.stop(context)
    }

    private fun transition(context: Context, next: CallState) {
        if (state == next) return
        Log.i(TAG, "$state → $next")
        state = next
        // Ceinture et bretelles : même si une transition future oubliait
        // d'arrêter la sonnerie, `isSilent` la fait taire ici.
        if (next.isSilent) RingtoneService.stop(context)
        val call = current
        val snapshot = listeners.toList()
        mainHandler.post { snapshot.forEach { it(next, call) } }
        if (next.isTerminal) current = null
    }

    /**
     * Lance Flutter — APRÈS avoir répondu, jamais avant.
     *
     * Le chemin interdit serait : notification → activité → Flutter démarre
     * → cherche l'appel → répond. L'appel aurait sonné pendant tout ce
     * temps, et un démarrage lent l'aurait fait manquer.
     */
    private fun launchFlutter(context: Context, call: IncomingCall) {
        val intent = Intent(context, Class.forName("com.pokou.pokou.MainActivity")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(IncomingCall.KEY_ROOM, call.room)
            putExtra(IncomingCall.KEY_FROM_USER_ID, call.fromUserId)
            putExtra(IncomingCall.KEY_IS_VIDEO, call.isVideo)
        }
        context.startActivity(intent)
    }
}
