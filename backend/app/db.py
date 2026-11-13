"""
Lightweight MySQL access layer.

We deliberately avoid a heavy ORM (kept out of scope per project rules) and
use PyMySQL with dict cursors directly. All queries live in app/models/*.py
so route handlers stay thin.
"""
import pymysql
import pymysql.cursors
import pymysql.converters
from flask import current_app, g

# PyMySQL returns DECIMAL/NEWDECIMAL columns as Python Decimal by default.
# That silently breaks plain float arithmetic anywhere those values flow
# (e.g. the pest-risk engine doing `weight * value`). Since this app has
# no need for exact-decimal precision, convert those columns to float at
# the driver level instead of scattering float(...) casts through every
# service that touches a numeric DB column.
_CONVERSIONS = pymysql.converters.conversions.copy()
_CONVERSIONS[pymysql.FIELD_TYPE.DECIMAL] = float
_CONVERSIONS[pymysql.FIELD_TYPE.NEWDECIMAL] = float


def get_db():
    if "db" not in g:
        cfg = current_app.config
        g.db = pymysql.connect(
            host=cfg["DB_HOST"],
            port=cfg["DB_PORT"],
            user=cfg["DB_USER"],
            password=cfg["DB_PASSWORD"],
            database=cfg["DB_NAME"],
            cursorclass=pymysql.cursors.DictCursor,
            autocommit=True,
            conv=_CONVERSIONS,
        )
    return g.db


def close_db(e=None):
    db = g.pop("db", None)
    if db is not None:
        db.close()


def init_app(app):
    app.teardown_appcontext(close_db)


def query_one(sql, params=None):
    db = get_db()
    with db.cursor() as cur:
        cur.execute(sql, params or ())
        return cur.fetchone()


def query_all(sql, params=None):
    db = get_db()
    with db.cursor() as cur:
        cur.execute(sql, params or ())
        return cur.fetchall()


def execute(sql, params=None):
    """INSERT/UPDATE/DELETE. Returns lastrowid for inserts."""
    db = get_db()
    with db.cursor() as cur:
        cur.execute(sql, params or ())
        return cur.lastrowid
