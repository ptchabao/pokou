package com.pokou.pokou.call

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * La vibration d'un appel entrant — UN seul motif pour les deux chemins.
 *
 * Application fermée, c'est [RingtoneService] qui sonne ; application
 * ouverte, c'est l'écran Flutter, qui n'avait aucune vibration. Les deux
 * doivent se ressentir pareil : un appel qui ne vibre que selon l'état de
 * l'application est le critère le plus déroutant qui soit.
 *
 * Ne décide PAS du mode du téléphone : c'est à l'appelant de ne pas
 * l'appeler en silencieux.
 */
object RingVibration {
    private var vibrator: Vibrator? = null

    fun start(context: Context) {
        stop()
        val vib = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        } ?: return
        vibrator = vib

        // Motif : silence, vibre, silence, vibre… `repeat = 0` reprend au
        // début du tableau, donc indéfiniment jusqu'à `cancel()`.
        val motif = longArrayOf(0, 1000, 1000)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vib.vibrate(VibrationEffect.createWaveform(motif, 0))
        } else {
            @Suppress("DEPRECATION")
            vib.vibrate(motif, 0)
        }
    }

    fun stop() {
        vibrator?.cancel()
        vibrator = null
    }
}
