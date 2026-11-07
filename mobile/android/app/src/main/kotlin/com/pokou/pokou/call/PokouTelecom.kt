package com.pokou.pokou.call

import android.content.ComponentName
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.telecom.Connection
import android.telecom.ConnectionRequest
import android.telecom.ConnectionService
import android.telecom.DisconnectCause
import android.telecom.PhoneAccount
import android.telecom.PhoneAccountHandle
import android.telecom.TelecomManager
import android.util.Log

/**
 * Intégration au système d'appels d'Android (Telecom), en mode
 * « self-managed » — le même mécanisme que WhatsApp.
 *
 * Pourquoi : sans elle, Android ignore qu'un appel Pokou est en cours. Si
 * l'on décroche un appel Pokou pendant un appel téléphonique ou WhatsApp,
 * les deux restent ouverts et se battent pour le micro. Déclaré au
 * système, l'appel Pokou devenu ACTIF fait mettre l'autre EN ATTENTE par
 * Android lui-même ; à la fin de l'appel Pokou, l'utilisateur reprend
 * l'autre.
 *
 * Tout est « au mieux » : un téléphone qui refuse (constructeur, Android
 * < 8) garde le comportement d'avant, sans erreur.
 */
object PokouTelecom {
    private const val TAG = "PokouTelecom"
    private const val ACCOUNT_ID = "pokou"

    @Volatile
    internal var connection: PokouConnection? = null

    private fun handle(context: Context) = PhoneAccountHandle(
        ComponentName(context, PokouConnectionService::class.java),
        ACCOUNT_ID,
    )

    private fun telecom(context: Context) =
        context.getSystemService(Context.TELECOM_SERVICE) as? TelecomManager

    fun register(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        runCatching {
            val account = PhoneAccount.builder(handle(context), "Pokou")
                .setCapabilities(PhoneAccount.CAPABILITY_SELF_MANAGED)
                .build()
            telecom(context)?.registerPhoneAccount(account)
        }.onFailure { Log.w(TAG, "registerPhoneAccount", it) }
    }

    /** L'appel Pokou est établi : on le déclare au système (actif). */
    fun activate(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        if (connection != null) return
        register(context)
        runCatching {
            val extras = Bundle().apply {
                putParcelable(
                    TelecomManager.EXTRA_INCOMING_CALL_ADDRESS,
                    Uri.fromParts("pokou", "call", null),
                )
            }
            telecom(context)?.addNewIncomingCall(handle(context), extras)
        }.onFailure { Log.w(TAG, "addNewIncomingCall", it) }
    }

    /** L'appel Pokou est terminé : le système peut reprendre l'autre. */
    fun end() {
        val current = connection ?: return
        connection = null
        runCatching {
            current.setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
            current.destroy()
        }
    }
}

class PokouConnection : Connection() {
    init {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N_MR1) {
            connectionProperties = PROPERTY_SELF_MANAGED
        }
        audioModeIsVoip = true
        connectionCapabilities = CAPABILITY_HOLD or CAPABILITY_SUPPORT_HOLD
    }

    override fun onAnswer() = setActive()
    override fun onHold() = setOnHold()
    override fun onUnhold() = setActive()
    override fun onDisconnect() {
        setDisconnected(DisconnectCause(DisconnectCause.LOCAL))
        destroy()
        if (PokouTelecom.connection === this) PokouTelecom.connection = null
    }
    override fun onAbort() = onDisconnect()
    override fun onReject() = onDisconnect()
}

class PokouConnectionService : ConnectionService() {
    override fun onCreateIncomingConnection(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ): Connection {
        // L'appel est DÉJÀ décroché côté Pokou : on le passe actif tout de
        // suite, ce qui fait mettre en attente l'appel des autres apps.
        val connection = PokouConnection()
        connection.setAddress(
            Uri.fromParts("pokou", "call", null),
            TelecomManager.PRESENTATION_ALLOWED,
        )
        connection.setActive()
        PokouTelecom.connection = connection
        return connection
    }

    override fun onCreateIncomingConnectionFailed(
        connectionManagerPhoneAccount: PhoneAccountHandle?,
        request: ConnectionRequest?,
    ) {
        // Refusé par le système (déjà trop d'appels, constructeur) : on
        // reste sur le comportement sans intégration.
        PokouTelecom.connection = null
    }
}
