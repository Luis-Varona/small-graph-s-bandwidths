#!/bin/bash

set -euo pipefail

if [ "$#" -ne 3 ]; then
  echo >&2 "Usage: $0 <source_file> <destination_file> <table_name>"
  exit 1
fi

SRC="$1"
DST="$2"
TBL_NAME="$3"

if [ ! -f "$SRC" ]; then
  echo >&2 "Source file does not exist: '$SRC'"
  exit 1
fi

if [[ ! "$TBL_NAME" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
  echo >&2 "Invalid table name: '$TBL_NAME'"
  exit 1
fi

mkdir -p "$(dirname "$DST")"

TMP_JSON="$(mktemp).json"
trap 'rm -f "$TMP_JSON"' EXIT

python "$(dirname "$0")/../setup.py"
julia --project="$(dirname "$0")/../" -e 'using Pkg; Pkg.instantiate()'
julia --project="$(dirname "$0")/../" "$(dirname "$0")/main_pt1.jl" "$SRC" "$TMP_JSON"
python "$(dirname "$0")/main_pt2.py" "$TMP_JSON" "$DST" "$TBL_NAME"
