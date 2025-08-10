# Copyright 2025 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

import json
import os
import sqlite3 as sql
from re import fullmatch
from sys import argv

from helpers.utils import SDiagonalizableGraph, Layout
from helpers.sql_mapping import SQL_TYPES, SQL_COLUMNS


def main() -> None:
    source, dest, table_name = parse_cli_args()

    for sql_type in SQL_TYPES:
        sql.register_adapter(sql_type.local_type, sql_type.adapter)

    conn = None

    try:
        conn = sql.connect(dest, detect_types=sql.PARSE_DECLTYPES)
        cur = conn.cursor()

        if cur.execute(
            f"SELECT 1 FROM sqlite_master WHERE type='table' AND name='{table_name}'"
        ).fetchone():
            raise ValueError(f"Table '{table_name}' already exists in '{dest}'")

        with open(source, "r") as f:
            data_in = json.load(f)

        s_diag_graphs = [
            SDiagonalizableGraph.from_json_dict(graph_dict, Layout.COL_MAJOR)
            for graph_dict in data_in
        ]

        col_cmd_sep = ",\n"
        table_creation_cmd = f"CREATE TABLE {table_name} (\n{col_cmd_sep.join(f'{header} {type}' for header, type in SQL_COLUMNS.items())}\n)"
        cur.execute(table_creation_cmd)

        placeholder_values = ",".join("?" for _ in SQL_COLUMNS)

        for s_diag_graph in s_diag_graphs:
            graph_data = tuple(
                s_diag_graph.to_dict()[col] for col in SQL_COLUMNS.keys()
            )
            insert_cmd_w_params = (
                f"INSERT INTO {table_name} VALUES ({placeholder_values})"
            )
            cur.execute(insert_cmd_w_params, graph_data)

        conn.commit()
    finally:
        if isinstance(conn, sql.Connection):
            conn.close()


def parse_cli_args() -> tuple[str, str]:
    num_args = len(argv)

    if num_args != 4:
        args_fmtd = ", ".join([f"'{arg}'" for arg in argv[1:]])
        raise ValueError(f"Expected 3 arguments, got {num_args - 2}: {args_fmtd}")

    source, dest, table_name = argv[1:]

    if not os.path.isfile(source):
        raise FileNotFoundError(f"Source file does not exist: '{source}'")

    if not dest.endswith(".db"):
        raise ValueError(f"Destination file must have a '.db' extension: '{dest}'")

    if not fullmatch(r"[a-zA-Z_][a-zA-Z0-9_]*", table_name):
        raise ValueError(f"Invalid table name: '{table_name}'")

    dest_dir = os.path.dirname(dest)

    if dest_dir:
        os.makedirs(dest_dir, exist_ok=True)

    return source, dest, table_name


if __name__ == "__main__":
    main()
