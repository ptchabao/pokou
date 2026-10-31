#!/usr/bin/env python3
"""Générateur des sons d'appel de Pokou (ringback appelant / sonnerie
appelé) — voir le bug "aucune sonnerie pendant un appel en attente ou lancée".

POURQUOI un générateur plutôt que des fichiers téléchargés : on veut des sons
synthétiques, sans dépendance réseau ni question de droits d'auteur, et
qu'on puisse régénérer/ajuster (fréquence, cadence, volume) sans redemander
à quelqu'un — d'où ce script, gardé dans le dépôt plutôt que jeté après usage.

Ne dépend que de la bibliothèque standard (`wave` + `math`) : aucune
installation requise pour le relancer.

Chaque fichier ne contient QU'UN SEUL cycle du motif : c'est
`RingtonePlayer` (côté Dart, voir
pokou/lib/features/calls/presentation/ringtone_player.dart) qui le boucle
en continu via `LoopMode.one` de just_audio. Chaque bip/note est enveloppé
d'un fondu (raised-cosine) de quelques millisecondes en entrée/sortie pour
qu'il n'y ait ni "clic" au démarrage/arrêt du ton, ni au point de bouclage
(le fichier commence et finit à une amplitude quasi nulle).

Usage : python3 pokou/tool/generate_ringtones.py
        (régénère pokou/assets/audio/ringback.wav et ringtone.wav)
"""

from __future__ import annotations

import math
import os
import struct
import wave

SAMPLE_RATE = 44100
AMPLITUDE = 0.5  # fraction de la pleine échelle — marge pour éviter l'écrêtage
FADE_MS = 8  # fondu en entrée/sortie de CHAQUE bip/note, pas seulement du fichier

_OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")


def _silence(duration_s: float) -> list[float]:
    return [0.0] * int(SAMPLE_RATE * duration_s)


def _tone(freq_hz: float, duration_s: float, fade_ms: float = FADE_MS) -> list[float]:
    """Un ton sinusoïdal avec fondu raised-cosine en entrée/sortie — un fondu
    linéaire suffirait à éviter le clic le plus grossier, mais la dérivée
    discontinue qu'il laisse au raccord reste parfois audible ; le
    raised-cosine (fondu "en S") a une dérivée nulle aux deux bouts, donc un
    raccord silence→ton→silence réellement sans accroc."""
    n_total = int(SAMPLE_RATE * duration_s)
    n_fade = min(int(SAMPLE_RATE * fade_ms / 1000), n_total // 2)
    samples = []
    for i in range(n_total):
        t = i / SAMPLE_RATE
        value = math.sin(2 * math.pi * freq_hz * t)
        if i < n_fade:
            envelope = 0.5 * (1 - math.cos(math.pi * i / n_fade))
        elif i >= n_total - n_fade:
            j = n_total - 1 - i
            envelope = 0.5 * (1 - math.cos(math.pi * j / n_fade))
        else:
            envelope = 1.0
        samples.append(value * envelope)
    return samples


def _write_wav(path: str, segments: list[list[float]]) -> None:
    samples: list[float] = []
    for segment in segments:
        samples.extend(segment)
    frames = b"".join(
        struct.pack("<h", max(-32768, min(32767, int(s * AMPLITUDE * 32767))))
        for s in samples
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as wav_file:
        wav_file.setnchannels(1)
        wav_file.setsampwidth(2)
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(frames)


def generate_ringback() -> str:
    """Tonalité de retour d'appel (côté appelant, pendant que ça sonne chez
    le destinataire) : deux bips de 400ms à 440Hz séparés d'un court silence,
    puis 2s de silence — cadence télécom "double bip" classique en Afrique
    de l'Ouest, bien distincte d'une tonalité continue."""
    segments = [
        _tone(440.0, 0.4),
        _silence(0.2),
        _tone(440.0, 0.4),
        _silence(2.0),
    ]
    path = os.path.join(_OUTPUT_DIR, "ringback.wav")
    _write_wav(path, segments)
    return path


def generate_ringtone() -> str:
    """Sonnerie d'appel entrant : motif "dring-dring" à deux tons alternés
    (quinte E5/B5, plus mélodique qu'un simple bip) répété deux fois, puis
    silence — volontairement différent du ringback (notes plus aiguës,
    cadence plus rapide) pour qu'on distingue à l'oreille appel sortant vs
    entrant."""
    note_a, note_b = 659.25, 987.77  # E5, B5 (quinte juste)
    note_duration = 0.15
    segments = [
        _tone(note_a, note_duration),
        _tone(note_b, note_duration),
        _tone(note_a, note_duration),
        _tone(note_b, note_duration),
        _silence(0.9),
    ]
    path = os.path.join(_OUTPUT_DIR, "ringtone.wav")
    _write_wav(path, segments)
    return path


if __name__ == "__main__":
    for generated in (generate_ringback(), generate_ringtone()):
        size_kb = os.path.getsize(generated) / 1024
        print(f"écrit : {os.path.abspath(generated)} ({size_kb:.1f} Ko)")
