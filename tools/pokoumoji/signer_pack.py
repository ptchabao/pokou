"""Construit et signe le manifeste d'un pack Pokoumoji (contrat §6).

Usage :
    python tools/pokoumoji/signer_pack.py <dossier_du_pack> \
        [--cle ~/.pokoumoji/pokoumoji_prod_ed25519.pem] [--version 1.0.0]

Le dossier contient `64/`, `128/` et `256/assets/<catégorie>/<id>.webp`.
L'outil REFUSE de signer un fichier qui ne passerait pas la vérification de
l'application : chemin hors motif, plus de 100 Ko, pas un WebP, dimensions
différentes de la taille du dossier. Il écrit `manifest.json` (empreintes
SHA-256, octets, type) puis `manifest.sig` (signature Ed25519 des octets
exacts du manifeste, en base64).

La clé privée de production n'est JAMAIS dans le dépôt. La clé publique
correspondante est embarquée dans l'application
(mobile/lib/features/pokoumoji/data/pokoumoji_pack_verifier.dart).
"""
import argparse
import base64
import hashlib
import json
import re
import struct
import sys
from datetime import datetime, timezone
from pathlib import Path

from cryptography.hazmat.primitives.serialization import load_pem_private_key

PATH_RE = re.compile(r"^(64|128|256)/assets/[a-z0-9_]+/[a-z0-9_]+\.webp$")
MAX_BYTES = 100 * 1024


def webp_size(b: bytes):
    if len(b) < 30 or b[0:4] != b"RIFF" or b[8:12] != b"WEBP":
        return None
    chunk = b[12:16]
    if chunk == b"VP8X":
        return 1 + int.from_bytes(b[24:27], "little"), 1 + int.from_bytes(b[27:30], "little")
    if chunk == b"VP8L":
        bits = struct.unpack("<I", b[21:25])[0]
        return 1 + (bits & 0x3FFF), 1 + ((bits >> 14) & 0x3FFF)
    if chunk == b"VP8 ":
        return struct.unpack("<H", b[26:28])[0] & 0x3FFF, struct.unpack("<H", b[28:30])[0] & 0x3FFF
    return None


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("pack")
    ap.add_argument("--cle", default=str(Path.home() / ".pokoumoji" / "pokoumoji_prod_ed25519.pem"))
    ap.add_argument("--version", default=datetime.now(timezone.utc).strftime("%Y.%m.%d"))
    ap.add_argument("--catalogue-version", default="1.3.0")
    args = ap.parse_args()

    root = Path(args.pack).resolve()
    files, errors = [], []
    for f in sorted(root.rglob("*.webp")):
        rel = f.relative_to(root).as_posix()
        size = int(rel.split("/", 1)[0]) if rel.split("/", 1)[0].isdigit() else 0
        data = f.read_bytes()
        if not PATH_RE.match(rel):
            errors.append(f"{rel}: chemin refusé")
        elif len(data) > MAX_BYTES:
            errors.append(f"{rel}: plus de 100 Ko")
        elif webp_size(data) != (size, size):
            errors.append(f"{rel}: pas un WebP {size}×{size}")
        else:
            files.append({
                "id": f.stem, "size": size, "path": rel,
                "sha256": hashlib.sha256(data).hexdigest(),
                "bytes": len(data), "mime": "image/webp",
            })
    if errors:
        print("Pack refusé :", *errors[:30], sep="\n - ")
        return 1
    if not files:
        print("Aucun fichier à signer.")
        return 1

    manifest = {
        "schema_version": 1,
        "pack_id": "pokoumoji",
        "pack_version": args.version,
        "catalogue_version": args.catalogue_version,
        "status": "production",
        "created_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "signature": {"algorithm": "Ed25519", "file": "manifest.sig", "key_id": "pokoumoji-prod"},
        "files": files,
    }
    raw = json.dumps(manifest, ensure_ascii=False, indent=1).encode("utf-8")
    key = load_pem_private_key(Path(args.cle).expanduser().read_bytes(), None)
    (root / "manifest.json").write_bytes(raw)
    (root / "manifest.sig").write_text(base64.b64encode(key.sign(raw)).decode())
    print(f"{len(files)} fichiers signés ({args.version}).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
