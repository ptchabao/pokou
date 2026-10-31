package com.pokou.pokou

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.os.Bundle
import android.telephony.TelephonyManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

import com.pokou.pokou.call.CallManager
import com.pokou.pokou.call.CallNotification
import com.pokou.pokou.call.OngoingCallService
import com.pokou.pokou.call.CallState
import com.pokou.pokou.call.IncomingCall
import com.pokou.pokou.call.RingVibration
import com.pokou.pokou.call.PokouApi
import com.pokou.pokou.messaging.ReplyQueue

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE a été RETIRÉ, sur demande.
        //
        // Il interdisait au système toute capture d'écran, noircissait les
        // enregistrements vidéo et les partages d'écran, et masquait l'aperçu
        // de l'application dans le sélecteur des récentes. Ce qui protégeait
        // les conversations protégeait aussi mal tout le reste : on ne
        // pouvait plus envoyer la capture d'une annonce du marché, ni montrer
        // un écran à quelqu'un pour se faire aider.
        //
        // Ce qu'on perd, pour mémoire : un téléphone déverrouillé entre les
        // mains d'un tiers peut désormais photographier une conversation, et
        // l'aperçu des récentes montre le dernier écran ouvert. La vue unique
        // (view_once) devient donc une promesse de convenance, pas une
        // garantie technique — elle l'était déjà à moitié, iOS n'offrant
        // aucun équivalent de ce drapeau.
        super.onCreate(savedInstanceState)
        // Ouverte par « Répondre » : on répond d'ici, une seule fois — pas
        // lors d'une recréation (rotation), où l'intention est rejouée.
        if (savedInstanceState == null) answerIfAsked(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Le pays de la carte SIM, pour préremplir l'indicatif téléphonique.
        //
        // Un canal de quelques lignes plutôt qu'un paquet : la seule donnée
        // dont Flutter a besoin ici est un code pays à deux lettres, et
        // ajouter une dépendance pour cela coûterait plus en maintenance
        // qu'elle n'apporte.
        //
        // AUCUNE permission n'est requise : getSimCountryIso() et
        // getNetworkCountryIso() sont lisibles sans READ_PHONE_STATE, parce
        // qu'ils ne révèlent ni le numéro ni l'identité de l'abonné — juste
        // le pays de l'opérateur. C'est ce qui rend cette source acceptable
        // là où demander la localisation ne le serait pas.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.pokou.pokou/sim")
            .setMethodCallHandler { call, result ->
                if (call.method != "countryIso") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                result.success(simCountryIso())
            }

        configureCallBridge(flutterEngine)
    }

    /**
     * Le pont entre la couche d'appel native et Flutter.
     *
     * Deux canaux, et la distinction compte :
     *
     * - un `EventChannel` pour ce que le NATIF annonce — il est la source de
     *   vérité, Flutter écoute ;
     * - un `MethodChannel` pour ce que Flutter DEMANDE : l'état au
     *   démarrage, la file des réponses à chiffrer, l'URL de l'API.
     *
     * Flutter ne doit jamais supposer qu'ouvrir l'écran d'appel signifie que
     * l'appel est connecté. Il observe `CallManager`.
     */
    private fun configureCallBridge(flutterEngine: FlutterEngine) {
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CALL_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                private var listener: ((CallState, IncomingCall?) -> Unit)? = null

                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    val sink = events ?: return
                    val observer: (CallState, IncomingCall?) -> Unit = { state, call ->
                        sink.success(eventFor(state, call))
                    }
                    listener = observer
                    // `addListener` rejoue l'état COURANT : Flutter peut
                    // démarrer après le début de l'appel, et un observateur
                    // qui n'apprend rien tant que rien ne change ouvrirait
                    // l'écran sur un état vide.
                    CallManager.addListener(observer)
                }

                override fun onCancel(arguments: Any?) {
                    listener?.let { CallManager.removeListener(it) }
                    listener = null
                }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL_CALL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getCurrentCall" -> result.success(
                        eventFor(CallManager.currentState(), CallManager.currentCall())
                    )
                    // Flutter annonce que le média est établi, ou terminé.
                    // C'est LUI qui parle à LiveKit ; le natif n'en sait
                    // rien et n'a pas à le savoir.
                    "onConnected" -> {
                        CallManager.onConnected(applicationContext)
                        result.success(null)
                    }
                    "onEnded" -> {
                        CallManager.onEnded(applicationContext)
                        result.success(null)
                    }
                    "startOngoingCall" -> {
                        OngoingCallService.start(applicationContext, call.arguments == true)
                        result.success(null)
                    }
                    "stopOngoingCall" -> {
                        OngoingCallService.stop(applicationContext)
                        result.success(null)
                    }
                    // Les réponses rapides écrites depuis une notification,
                    // que Flutter va chiffrer puis envoyer — le natif ne
                    // peut pas chiffrer, voir ReplyQueue.
                    "drainPendingReplies" -> result.success(
                        ReplyQueue.drain(applicationContext)
                    )
                    // L'URL de l'API, pour que le natif la connaisse sans
                    // qu'elle soit codée en dur à deux endroits.
                    "setApiBaseUrl" -> {
                        (call.arguments as? String)?.let {
                            PokouApi.rememberBaseUrl(applicationContext, it)
                        }
                        result.success(null)
                    }
                    // La vibration de l'écran d'appel Flutter, application
                    // OUVERTE — même motif que RingtoneService. Rien en mode
                    // silencieux : le son, lui, est coupé par Android dès
                    // lors qu'il passe sur le flux sonnerie.
                    "startRingVibration" -> {
                        val audio = getSystemService(Context.AUDIO_SERVICE) as? AudioManager
                        if (audio?.ringerMode != AudioManager.RINGER_MODE_SILENT) {
                            RingVibration.start(applicationContext)
                        }
                        result.success(null)
                    }
                    "stopRingVibration" -> {
                        RingVibration.stop()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        answerIfAsked(intent)
    }

    /** Le bouton « Répondre » de la notification ouvre cette activité. */
    private fun answerIfAsked(intent: Intent?) {
        if (intent?.action != CallNotification.ACTION_ANSWER) return
        // Consommée : une intention relue ne doit pas répondre deux fois.
        intent.action = null
        CallManager.answer(applicationContext)
    }

    override fun onDestroy() {
        // Filet : une activité détruite pendant un appel entrant ne doit pas
        // laisser le téléphone vibrer sans écran pour l'arrêter.
        RingVibration.stop()
        super.onDestroy()
    }

    private fun eventFor(state: CallState, call: IncomingCall?): Map<String, Any?> = mapOf(
        "state" to state.name,
        "room" to call?.room,
        "from_user_id" to call?.fromUserId,
        "caller_name" to call?.callerName,
        "is_video" to call?.isVideo,
        "group_id" to call?.groupId,
        "group_name" to call?.groupName,
    )

    /// Le pays de la SIM, puis celui du réseau visité, ou `null`.
    ///
    /// La SIM d'abord : c'est le pays de l'abonnement, donc celui du numéro
    /// qu'on s'apprête à saisir. Le réseau ensuite, utile quand la SIM ne
    /// répond pas — il désigne le pays où l'on se trouve, ce qui reste un
    /// meilleur indice que la langue du téléphone.
    private companion object {
        const val CHANNEL_CALL_EVENTS = "com.pokou.pokou/call_events"
        const val CHANNEL_CALL = "com.pokou.pokou/call"
    }

    private fun simCountryIso(): String? {
        return try {
            val telephony = getSystemService(Context.TELEPHONY_SERVICE) as? TelephonyManager
                ?: return null
            telephony.simCountryIso?.takeIf { it.length == 2 }
                ?: telephony.networkCountryIso?.takeIf { it.length == 2 }
        } catch (exception: Exception) {
            // Téléphone sans module radio, émulateur, constructeur qui
            // restreint l'accès : pas de pays, et l'appelant retombe sur la
            // locale. Jamais une exception remontée à Flutter pour un
            // préremplissage.
            null
        }
    }
}
