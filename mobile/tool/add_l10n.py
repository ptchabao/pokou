#!/usr/bin/env python3
"""Ajoute des textes aux six fichiers ARB, puis régénère les traductions.

    python3 tool/add_l10n.py textes.json

`textes.json` :

    {
      "koryRaised": {
        "fr": "{amount} collectés", "en": "{amount} raised", "es": "…",
        "it": "…", "ar": "…", "ru": "…",
        "@": {"placeholders": {"amount": {"type": "String"}}}
      }
    }

Les six langues sont obligatoires ; `@` (métadonnées, pour les textes à
paramètres) ne va que dans le fichier de référence, le français. Une clé
déjà présente est remplacée. Un verrou sérialise les appels : plusieurs
personnes (ou agents) peuvent ajouter des textes en même temps.
"""
import fcntl
import json
import subprocess
import sys
from collections import OrderedDict
from pathlib import Path

LANGS = ["fr", "en", "es", "it", "ar", "ru"]
ROOT = Path(__file__).resolve().parent.parent
ARB = ROOT / "lib" / "l10n"


def main() -> int:
    entries = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    for key, value in entries.items():
        missing = [lang for lang in LANGS if not value.get(lang)]
        if missing:
            print(f"{key} : langues manquantes {missing}")
            return 1
    with open(ROOT / ".l10n.lock", "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        for lang in LANGS:
            path = ARB / f"app_{lang}.arb"
            data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=OrderedDict)
            for key, value in entries.items():
                data[key] = value[lang]
                if lang == "fr" and "@" in value:
                    data[f"@{key}"] = value["@"]
            path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        result = subprocess.run(["flutter", "gen-l10n"], cwd=ROOT, capture_output=True, text=True)
        print((result.stdout + result.stderr).strip()[-600:])
        return result.returncode


if __name__ == "__main__":
    sys.exit(main())
