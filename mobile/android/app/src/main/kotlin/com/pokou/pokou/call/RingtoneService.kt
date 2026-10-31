package com.pokou.pokou.call

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.util.Log
import com.pokou.pokou.R

/**
 * La sonnerie, jouée par un SERVICE DE PREMIER PLAN.
 *
 * C'est le remplacement de `RingtonePlayer` côté Flutter, et la raison est
 * structurelle : la sonnerie Flutter ne démarrait qu'une fois le moteur Dart
 * réveillé, l'activité ouverte et `CallScreen` construit. Sur un téléphone
 * en veille, cette chaîne prend plusieurs secondes — et si le système décide
 * de ne pas réveiller Flutter, elle ne démarre pas du tout.
 *
 * Un service de premier plan, lui, survit à l'absence d'interface et
 * continue de jouer tant que le système ne le tue pas — ce qu'il ne fait pas
 * pour un service de type `phoneCall`.
 *
 * ── Le flux audio ───────────────────────────────────────────────────
 *
 * `USAGE_NOTIFICATION_RINGTONE` et non `USAGE_NOTIFICATION` : c'est le flux
 * que porte le volume de SONNERIE du téléphone, celui que « Ne pas
 * déranger » traite comme un appel, et celui qui se route correctement vers
 * un casque Bluetooth. Le choisir n'est pas un détail — un appel qui sort
 * sur le flux notification se retrouve au volume des messages, souvent bien
 * plus bas.
 */
class RingtoneService : Service() {
    private var player: MediaPlayer? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // L'appel est relu depuis CallManager plutôt que reconstruit depuis
        // l'intent : une seule source de vérité, y compris ici.
        val call = CallManager.currentCall()
        if (call == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        // Le service DOIT publier sa notification dans les cinq secondes,
        // sinon Android le tue. On la pose donc avant toute autre chose.
        //
        // Et c'est LA notification d'appel — celle avec Refuser et Répondre
        // — pas une seconde. Un service qui publiait la sienne à part
        // faisait apparaître DEUX notifications pour un seul appel.
        startForegroundCompat(call)

        val mode = (getSystemService(Context.AUDIO_SERVICE) as? AudioManager)?.ringerMode
        when (mode) {
            // Silencieux : ni son ni vibration. Le respecter n'est pas
            // négociable — une application qui sonne en mode silencieux est
            // désinstallée.
            AudioManager.RINGER_MODE_SILENT -> Unit
            // Vibreur seul.
            AudioManager.RINGER_MODE_VIBRATE -> startVibration()
            else -> {
                startRingtone()
                startVibration()
            }
        }
        // START_NOT_STICKY : si le système nous tue, il ne doit PAS nous
        // relancer. Un service de sonnerie ressuscité ferait sonner le
        // téléphone pour un appel qui n'existe plus.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopRingtone()
        stopVibration()
        super.onDestroy()
    }

    private fun startForegroundCompat(call: IncomingCall) {
        val notification: Notification = CallNotification.buildIncoming(this, call)

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                CallNotification.NOTIFICATION_ID,
                notification,
                // `phoneCall` et non `mediaPlayback` : c'est ce type qui
                // autorise le service à tourner écran verrouillé et qui dit
                // au système de quoi il s'agit.
                ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL,
            )
        } else {
            startForeground(CallNotification.NOTIFICATION_ID, notification)
        }
    }

    private fun startRingtone() {
        try {
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                val descriptor = resources.openRawResourceFd(R.raw.pokou_ringtone) ?: return
                descriptor.use {
                    setDataSource(it.fileDescriptor, it.startOffset, it.length)
                }
                // Le fichier ne contient qu'UN cycle d'une seconde et demie
                // (voir tool/generate_ringtones.py) : c'est la boucle qui en
                // fait une sonnerie.
                isLooping = true
                prepare()
                start()
            }
        } catch (exception: Exception) {
            // Une sonnerie qui ne démarre pas ne doit pas empêcher l'appel :
            // la notification et l'écran plein restent, eux.
            Log.w(TAG, "Sonnerie impossible : ${exception.javaClass.simpleName}")
        }
    }

    private fun stopRingtone() {
        player?.runCatching {
            if (isPlaying) stop()
            release()
        }
        player = null
    }

    private fun startVibration() = RingVibration.start(this)

    private fun stopVibration() = RingVibration.stop()

    companion object {
        private const val TAG = "RingtoneService"

        fun start(context: Context, call: IncomingCall) {
            val intent = Intent(context, RingtoneService::class.java)
            // `startForegroundService` puis `startForeground` dans les cinq
            // secondes : c'est le contrat depuis Android 8, et le manquer
            // lève une ANR.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, RingtoneService::class.java))
        }
    }
}
