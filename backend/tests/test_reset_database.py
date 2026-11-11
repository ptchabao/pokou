"""La remise à zéro ne part que sur la phrase du jour, et une seule fois."""
from datetime import datetime, timezone

from sqlalchemy import create_engine, inspect, text

from scripts import reset_database


def _setup(tmp_path, monkeypatch):
    engine = create_engine(f"sqlite:///{tmp_path}/t.db")
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE users (id INTEGER PRIMARY KEY)"))
        conn.execute(text("CREATE TABLE groups (id INTEGER PRIMARY KEY)"))
    media = tmp_path / "data" / "media"
    (media / "sub").mkdir(parents=True)
    (media / "a.bin").write_text("a")
    (media / "sub" / "b.bin").write_text("b")
    monkeypatch.setattr(reset_database, "engine", engine)
    monkeypatch.setattr(reset_database.settings, "media_storage_dir", str(media))
    monkeypatch.setattr(reset_database.settings, "s3_endpoint_url", "")
    return engine, media


def _today():
    return "EFFACER-TOUT-" + datetime.now(timezone.utc).strftime("%Y-%m-%d")


def test_sans_phrase_rien_ne_bouge(tmp_path, monkeypatch):
    engine, media = _setup(tmp_path, monkeypatch)
    monkeypatch.delenv("POKOU_RESET_DATABASE", raising=False)
    assert reset_database.main() == 0
    assert len(inspect(engine).get_table_names()) == 2
    assert (media / "a.bin").exists()


def test_une_phrase_d_un_autre_jour_est_refusee(tmp_path, monkeypatch):
    engine, media = _setup(tmp_path, monkeypatch)
    monkeypatch.setenv("POKOU_RESET_DATABASE", "EFFACER-TOUT-2020-01-01")
    reset_database.main()
    assert len(inspect(engine).get_table_names()) == 2
    assert (media / "a.bin").exists()


def test_la_phrase_du_jour_efface_tout_une_seule_fois(tmp_path, monkeypatch):
    engine, media = _setup(tmp_path, monkeypatch)
    monkeypatch.setenv("POKOU_RESET_DATABASE", _today())
    assert reset_database.main() == 0
    assert inspect(engine).get_table_names() == []
    assert list(media.iterdir()) == []
    # Redémarrage avec la même phrase : la base recréée n'est pas réeffacée.
    with engine.begin() as conn:
        conn.execute(text("CREATE TABLE users (id INTEGER PRIMARY KEY)"))
    assert reset_database.main() == 0
    assert inspect(engine).get_table_names() == ["users"]
