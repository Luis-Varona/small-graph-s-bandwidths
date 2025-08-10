#!/bin/bash

module load python/3.13.2
python -m venv ~/.venv_313
source ~/.venv_313/bin/activate
pip install --upgrade pip
pip install setuptools wheel cython
pip install networkx numpy pandas polars
