import inspect

from app.db import BehavioralStateManager
from app.repository import Repository
from app.sqlite_db import SQLiteStateManager


def _public_methods(cls) -> dict[str, inspect.Signature]:
    return {
        name: inspect.signature(fn)
        for name, fn in inspect.getmembers(cls, predicate=inspect.isfunction)
        if not name.startswith("_")
    }


def _param_spec(sig: inspect.Signature) -> list[tuple[str, object, object]]:
    return [
        (param.name, param.kind, param.default)
        for param in sig.parameters.values()
    ]


def test_repository_protocol_has_all_32_methods():
    proto_methods = _public_methods(Repository)
    neo_methods = _public_methods(BehavioralStateManager)
    sql_methods = _public_methods(SQLiteStateManager)

    assert len(proto_methods) == 32
    assert set(proto_methods.keys()) == set(neo_methods.keys())
    assert set(proto_methods.keys()) == set(sql_methods.keys())


def test_neo4j_and_sqlite_signatures_match_repository_protocol():
    proto_methods = _public_methods(Repository)
    neo_methods = _public_methods(BehavioralStateManager)
    sql_methods = _public_methods(SQLiteStateManager)

    for name, proto_sig in proto_methods.items():
        expected = _param_spec(proto_sig)
        assert _param_spec(neo_methods[name]) == expected, f"Neo4j signature mismatch on {name}"
        assert _param_spec(sql_methods[name]) == expected, f"SQLite signature mismatch on {name}"


def test_sqlite_instance_satisfies_runtime_repository_protocol(tmp_path):
    db = SQLiteStateManager(str(tmp_path / "parity.db"))
    try:
        assert isinstance(db, Repository)
    finally:
        db.close()
