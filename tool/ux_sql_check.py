"""Teste isolado da consulta de contagem. Não executa o aplicativo Flutter."""
import sqlite3
with sqlite3.connect(':memory:') as db:
    db.execute('CREATE TABLE question (id INTEGER PRIMARY KEY, package_id INTEGER)')
    db.executemany('INSERT INTO question (package_id) VALUES (?)', [(1,), (1,), (3,), (None,)])
    rows = db.execute('SELECT package_id, COUNT(*) AS total FROM question WHERE package_id IS NOT NULL GROUP BY package_id').fetchall()
    assert dict(rows) == {1: 2, 3: 1}, rows
print('PASS: consulta SQL de contagem por matéria em SQLite isolado')
