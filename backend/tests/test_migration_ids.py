"""Les identifiants de révision tiennent dans alembic_version.version_num.

Sur Postgres, cette colonne est un VARCHAR(32) : une révision plus longue
fait échouer la migration au démarrage du serveur (SQLite ne vérifie rien).
"""
import re
from pathlib import Path

VERSIONS = Path(__file__).resolve().parent.parent / "alembic" / "versions"


def test_revision_ids_fit_postgres_column():
    too_long = []
    for path in VERSIONS.glob("*.py"):
        match = re.search(r'^revision\s*(?::[^=]*)?=\s*["\']([^"\']+)["\']', path.read_text(), re.M)
        assert match, f"{path.name} : pas de révision"
        if len(match.group(1)) > 32:
            too_long.append(match.group(1))
    assert too_long == []
