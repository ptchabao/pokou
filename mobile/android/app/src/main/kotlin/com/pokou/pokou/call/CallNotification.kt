package com.pokou.pokou.call

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.Person
import androidx.core.content.ContextCompat
import com.pokou.pokou.R

/**
 * La notification d'un appel entrant.
 *
 * `Notification.CallStyle` et non une notification ordinaire : c'est ce qui
 * fait qu'Android la traite comme un ÉVÉNEMENT TÉLÉPHONIQUE — placement en
 * tête, boutons Répondre/Refuser dessinés par le système, affichage plein
 * écran sur un téléphone verrouillé. C'est la différence entre « Pokou vous
 * notifie » et « Pokou vous appelle ».
 *
 * ── Le canal SILENCIEUX ─────────────────────────────────────────────
 *
 * Cette notification ne porte PAS de son. C'est `RingtoneService` qui sonne,
 * en boucle, jusqu'à une action. Si le canal portait lui aussi la sonnerie,
 * les deux joueraient en même temps et se décaleraient — un défaut
 * particulièrement désagréable, puisqu'il se produit au moment précis où
 * l'utilisateur essaie de comprendre ce qui se passe.
 *
 * Le canal `pokou_calls_v2` créé côté Flutter garde sa sonnerie : il sert
 * aux appareils où la couche native n'a pas pris la main (le repli du §7).
 */
object CallNotification {
    const val CHANNEL_SILENT = "pokou_calls_silent_v1"
    const val CHANNEL_MISSED = "pokou_calls_missed_v1"

    /** Un identifiant fixe : il n'y a qu'un appel entrant à la fois. */
    const val NOTIFICATION_ID = 424242

    const val ACTION_ANSWER = "com.pokou.pokou.ANSWER_CALL"
    const val ACTION_DECLINE = "com.pokou.pokou.DECLINE_CALL"

    fun ensureChannels(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_SILENT,
                "Appels entrants",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "L'appel en cours de sonnerie"
                // Aucun son : RingtoneService s'en charge, en boucle.
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
        )

        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_MISSED,
                "Appels manqués",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Les appels auxquels vous n'avez pas répondu"
            }
        )
    }

    /**
     * Construit LA notification d'appel entrant.
     *
     * Elle est rendue plutôt que posée, parce que c'est `RingtoneService`
     * qui doit la publier : un service de premier plan DOIT fournir sa
     * propre notification, et s'il en posait une seconde, l'utilisateur en
     * verrait deux — c'est exactement la régression constatée. Une seule
     * notification, un seul identifiant, portée par le service qui vit
     * aussi longtemps que la sonnerie.
     */
    fun buildIncoming(context: Context, call: IncomingCall): Notification {
        ensureChannels(context)

        val caller = Person.Builder()
            .setName(call.groupName ?: call.callerName)
            .setImportant(true)
            .build()

        val builder = NotificationCompat.Builder(context, CHANNEL_SILENT)
            .setSmallIcon(android.R.drawable.sym_call_incoming)
            .setColor(accent(context))
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            // Non balayable : un appel qui sonne ne se congédie pas d'un
            // geste distrait.
            .setOngoing(true)
            .setAutoCancel(false)
            // L'écran plein sur un téléphone verrouillé. Android 14+ ne
            // l'accorde qu'aux applications d'appel ou d'alarme — la fiche
            // Play Store doit déclarer Pokou comme telle, sinon
            // l'autorisation est retirée et cet appel ne s'affiche plus.
            .setFullScreenIntent(fullScreenIntent(context, call), true)
            .setStyle(
                NotificationCompat.CallStyle.forIncomingCall(
                    caller,
                    actionIntent(context, ACTION_DECLINE),
                    answerIntent(context),
                ).setAnswerButtonColorHint(accent(context))
            )

        if (call.groupName != null) {
            builder.setContentText("${call.callerName} — appel de groupe")
        }

        return builder.build()
    }

    fun showMissed(context: Context, call: IncomingCall?) {
        ensureChannels(context)
        dismiss(context)
        if (call == null) return

        val builder = NotificationCompat.Builder(context, CHANNEL_MISSED)
            .setSmallIcon(android.R.drawable.sym_call_missed)
            .setColor(accent(context))
            .setContentTitle(call.groupName ?: call.callerName)
            .setContentText("Appel manqué")
            .setCategory(NotificationCompat.CATEGORY_MISSED_CALL)
            .setAutoCancel(true)
            .setContentIntent(fullScreenIntent(context, call))

        NotificationManagerCompat.from(context)
            .notify(NOTIFICATION_ID + 1, builder.build())
    }

    /** La teinte de marque, et non le vert que le système met par défaut. */
    fun accent(context: Context): Int =
        ContextCompat.getColor(context, R.color.pokou_notification_accent)

    fun dismiss(context: Context) {
        NotificationManagerCompat.from(context).cancel(NOTIFICATION_ID)
    }

    /**
     * L'intention plein écran — elle ouvre l'application.
     *
     * À ne pas confondre avec les boutons : ceux-là passent par un
     * `BroadcastReceiver` et n'ouvrent RIEN. C'est la distinction qui permet
     * de refuser un appel sans jamais démarrer Flutter.
     */
    private fun fullScreenIntent(context: Context, call: IncomingCall): PendingIntent {
        val intent = Intent(context, Class.forName("com.pokou.pokou.MainActivity")).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            putExtra(IncomingCall.KEY_ROOM, call.room)
            putExtra(IncomingCall.KEY_FROM_USER_ID, call.fromUserId)
            putExtra(IncomingCall.KEY_IS_VIDEO, call.isVideo)
        }
        return PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    /**
     * « Répondre » ouvre l'ACTIVITÉ, qui répond elle-même.
     *
     * Il passait par le récepteur, qui démarrait ensuite l'activité : depuis
     * Android 12, une activité lancée depuis un récepteur déclenché par une
     * notification est bloquée (« notification trampoline »). Le serveur
     * enregistrait donc l'acceptation, l'appelant croyait l'appel décroché,
     * et l'application de l'appelé ne s'ouvrait pas (audit, A7).
     *
     * « Refuser » reste un récepteur : il n'a aucune interface à ouvrir.
     */
    private fun answerIntent(context: Context): PendingIntent {
        val intent = Intent(context, Class.forName("com.pokou.pokou.MainActivity")).apply {
            action = ACTION_ANSWER
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        return PendingIntent.getActivity(
            context,
            ACTION_ANSWER.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun actionIntent(context: Context, action: String): PendingIntent {
        val intent = Intent(context, CallActionReceiver::class.java).setAction(action)
        return PendingIntent.getBroadcast(
            context,
            action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
