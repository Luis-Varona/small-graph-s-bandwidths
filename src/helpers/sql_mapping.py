# Copyright 2025 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

import sqlite3 as sql
from dataclasses import dataclass
from io import BytesIO

import numpy as np
import pandas as pd
import polars as pl


@dataclass
class SQLType:
    name: str
    local_type: type
    adapter: callable
    converter: callable


def adapt_array(array: np.ndarray) -> sql.Binary:
    out = BytesIO()
    np.save(out, array)
    return sql.Binary(out.getvalue())


def convert_array(obj) -> np.ndarray:
    out = BytesIO(obj)
    return np.load(out, allow_pickle=True)


def adapt_boolean(value: bool) -> str:
    if value is True:
        res = "true"
    elif value is False:
        res = "false"
    else:
        raise ValueError(f"Invalid boolean value: {value}")

    return res


def convert_boolean(value: str | bytes) -> bool:
    if isinstance(value, bytes):
        value = value.decode("ascii")

    if value == "true":
        res = True
    elif value == "false":
        res = False
    else:
        raise ValueError(f"Invalid boolean value: {value}")

    return res


SQL_TYPES = [
    SQLType("ARRAY", np.ndarray, adapt_array, convert_array),
    SQLType("BOOLEAN", bool, adapt_boolean, convert_boolean),
]

SQL_COLUMNS = {
    "num_vertices": "TINYINT",
    "graph6": "VARCHAR(83)",
    "band_01neg": "TINYINT",
    "band_1neg": "REAL",
    "eigvals": "ARRAY",
    "eigbasis_01neg": "ARRAY",
    "eigbasis_1neg": "ARRAY",
    "num_edges": "SMALLINT",
    "density": "REAL",
    "avg_degree": "REAL",
    "is_connected": "BOOLEAN",
    "is_regular": "BOOLEAN",
    "is_bipartite": "BOOLEAN",
    "is_cograph": "BOOLEAN",
    "prime_factors": "ARRAY",
    "compl_prime_factors": "ARRAY",
}


def read_table_as_pandas_df(path_to_db: str, table_name: str) -> pd.DataFrame:
    for sql_type in SQL_TYPES:
        sql.register_converter(sql_type.name, sql_type.converter)

    conn = None

    try:
        conn = sql.connect(path_to_db, detect_types=sql.PARSE_DECLTYPES)
        df = pd.read_sql_query(f"SELECT * FROM {table_name}", conn)
    finally:
        if isinstance(conn, sql.Connection):
            conn.close()

    return df


def read_table_as_polars_df(path_to_db: str, table_name: str) -> pl.DataFrame:
    for sql_type in SQL_TYPES:
        sql.register_converter(sql_type.name, sql_type.converter)

    conn = None

    try:
        conn = sql.connect(path_to_db, detect_types=sql.PARSE_DECLTYPES)
        cur = conn.cursor()
        cur.execute(f"SELECT * FROM {table_name}")
        data = cur.fetchall()
        cols = [desc[0] for desc in cur.description]
    finally:
        if isinstance(conn, sql.Connection):
            conn.close()

    columns_dict = {}

    for i, col in enumerate(cols):
        col_data = [row[i] for row in data]

        if any(isinstance(x, np.ndarray) for x in col_data):
            columns_dict[col] = pl.Series(col, col_data, pl.Object)
        else:
            columns_dict[col] = pl.Series(col, col_data)

    return pl.DataFrame(columns_dict)
