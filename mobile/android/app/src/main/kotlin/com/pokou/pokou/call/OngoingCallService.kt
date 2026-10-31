package com.pokou.pokou.call

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * L'appel EN COURS, tenu par un service de premier plan.
 *
 * Le service de sonnerie s'arrête dès qu'on répond. Pendant la conversation,
 * plus rien ne disait au système qu'un appel avait lieu : appuyer sur
 * Accueil ou verrouiller l'écran laissait l'application en arrière-plan, et
 * depuis Android 9 une application en arrière-plan reçoit du SILENCE du
 * micro — l'autre cessait d'entendre l'utilisateur sans que rien ne
 * l'indique (audit des appels du 23 octobre 2026, A5).
 *
 * Démarré par Flutter une fois le média établi (l'application est alors au
 * premier plan, condition pour démarrer un service de type micro ou
 * caméra), arrêté au raccroché. Il ne fait rien d'autre que d'exister et
 * d'afficher « Appel en cours » : c'est cette existence qui garde le micro.
 *
 * Non vérifié sur appareil au moment de son écriture : voir
 * docs/REMEDIATION_APPELS_POKOU.md, protocole de test Android.
 */
class OngoingCallService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val isVideo = intent?.getBooleanExtra(EXTRA_VIDEO, false) ?: false
        val notification = buildNotification(this, isVideo)
        try {
            ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, typesFor(isVideo))
        } catch (exception: Exception) {
            // Permission micro ou caméra retirée entre-temps : on garde au
            // moins le type « appel », plutôt que de ne rien tenir du tout.
            Log.w(TAG, "Types micro/caméra refusés : ${exception.javaClass.simpleName}")
            try {
                ServiceCompat.startForeground(this, NOTIFICATION_ID, notification, phoneCallType())
            } catch (fallback: Exception) {
                Log.w(TAG, "Service d'appel impossible : ${fallback.javaClass.simpleName}")
                stopSelf()
            }
        }
        // Tué par le système, il ne doit pas revenir : l'appel n'existerait plus.
        return START_NOT_STICKY
    }

    private fun phoneCallType(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL else 0

    private fun typesFor(isVideo: Boolean): Int {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return phoneCallType()
        var types = ServiceInfo.FOREGROUND_SERVICE_TYPE_PHONE_CALL or ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE
        if (isVideo) types = types or ServiceInfo.FOREGROUND_SERVICE_TYPE_CAMERA
        return types
    }

    companion object {
        private const val TAG = "OngoingCallService"
        private const val CHANNEL = "pokou_calls_ongoing_v1"
        private const val NOTIFICATION_ID = 424244
        private const val EXTRA_VIDEO = "is_video"

        fun start(context: Context, isVideo: Boolean) {
            val intent = Intent(context, OngoingCallService::class.java).putExtra(EXTRA_VIDEO, isVideo)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
            } catch (exception: Exception) {
                // Démarrage refusé (application déjà en arrière-plan) : l'appel
                // continue, sans la protection — à défaut de mieux.
                Log.w(TAG, "Démarrage refusé : ${exception.javaClass.simpleName}")
            }
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OngoingCallService::class.java))
        }

        private fun buildNotification(context: Context, isVideo: Boolean): Notification {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.getSystemService(NotificationManager::class.java)?.createNotificationChannel(
                    NotificationChannel(CHANNEL, "Appel en cours", NotificationManager.IMPORTANCE_LOW).apply {
                        description = "Affichée pendant un appel Pokou"
                        setSound(null, null)
                        enableVibration(false)
                        setShowBadge(false)
                    }
                )
            }
            val open = PendingIntent.getActivity(
                context,
                1,
                Intent(context, Class.forName("com.pokou.pokou.MainActivity"))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            return NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(android.R.drawable.sym_action_call)
                .setColor(CallNotification.accent(context))
                .setContentTitle("Pokou")
                .setContentText(if (isVideo) "Appel vidéo en cours" else "Appel en cours")
                .setCategory(NotificationCompat.CATEGORY_CALL)
                .setOngoing(true)
                .setContentIntent(open)
                .build()
        }
    }
}
