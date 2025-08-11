# Small Graph *S*-Bandwidths

![License: MIT](https://img.shields.io/badge/License-MIT-pink.svg)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/JuliaDiff/BlueStyle)
[![Code Style: Ruff](https://img.shields.io/badge/code%20style-ruff-rebeccapurple.svg)](https://github.com/astral-sh/ruff)

## Overview

Recall that an undirected, possibly weighted graph *G* is said to be "*S*-diagonalizable" for some finite set of integers *S* &subset; **Z** if there exists some diagonal matrix *D* and matrix *P* with all entries from *S* such that *G*'s Laplacian matrix *L*(*G*) = *PDP*<sup>-1</sup>. If *G* is *S*-diagonalizable, then its "*S*-bandwidth" is the minimum integer *k* &isin; {1, 2, &hellip;, |*V*(*G*)|} such that there exists some diagonal matrix *D* and matrix *P* with all entries from *S* such that *L*(*G*) = *PDP*<sup>-1</sup> and [*P*<sup>T</sup>*P*]<sub>*i,j*</sub> = 0 whenever |*i* - *j*| &ge; *k*; otherwise, its *S*-bandwidth is simply &infin;.[^JP25]

For specific choices of *S* (namely {-1, 1} and {-1, 0, 1}), the *S*-bandwidth of a quantum network has been shown to be an indicator of high state transfer fidelity due to automorphic properties of the graph, a topic of interest in the broader context of quantum information theory. As such, I present a computational survey of the *S*-bandwidths of some small simple connected graphs. More precisely, I identify all {-1, 0, 1}-diagonalizable graphs, along with their precise {-1, 0, 1}- and {-1, 1}-bandwidths, in the following categories:

- simple connected graphs on up to 11 vertices;
- simple connected regular graphs on up to 14 vertices; and
- simple connected bipartite graphs on up to 15 vertices.

## Methodology

Only graphs whose Laplacian eigenvalues are all integers ("Laplacian integral graphs") can be *S*-diagonalizable for *S* = {-1, 0, 1} or *S* = {-1, 1}.[^JP25] Therefore, I started with precomputed lists of all Laplacian integral graphs in each of the three aforementioned categories (available in the `data/input/` directory in the form of graph6 strings), taken from a previous survey I had performed on the [Cedar supercomputer](https://www.sfu.ca/research/institutes-centres-facilities/other-facilities/supercomputer-cedar.html) located at Simon Fraser University.[^Var25]

I then used the Julia package *SDiagonalizability.jl*, written by myself in collaboration with [Dr. Nathaniel Johnston](https://github.com/nathanieljohnston) and Dr. Sarah Plosker, to determine which of these graphs are {-1, 0, 1}-diagonalizable and minimize their {-1, 0, 1}- and {-1, 1}-bandwidths.[^VJP25] The results for each category were then saved as a separate table in a single SQLite database file: `data/small_graph_s_bandwidths.db`.

These computations were also performed on Cedar; see the `jobs/` directory for the job scripts used, as well as `jobs/setup_pyenv.sh` for the Python environment setup script. Summaries of the running time, maximum resident set size, etc. for each job are available in `benchmark/`.

## Database schema and access

### Schema

The schema for the SQLite database includes the custom data types `ARRAY` and `BOOLEAN`, which are defined in `src/helpers/sql_mapping.py` (which also contains the serialization/deserialization logic for NumPy arrays). For a given graph *G* = (*V*, *E*) with Laplacian matrix *L*, the following columns are included:

- `TINYINT num_vertices`: The order of *G* (i.e., |*V*|).
- `VARCHAR(83) graph6`: The graph6 string representation of *G*.
- `TINYINT band_01neg`: The {-1, 0, 1}-bandwidth of *G*.
- `REAL band_1neg`: The {-1, 1}-bandwidth of *G*. (If *G* is {-1, 1}-diagonalizable, this is an integer-valued float; otherwise, it is simply &infin;.)
- `ARRAY eigvals`: The eigenvalues of *L*, sorted first by ascending multiplicity then by ascending value. (Serialized as a 1D NumPy array of integers in NPY binary format.)
- `ARRAY eigbasis_01neg`: An ordered spanning set of {-1, 0, 1}-eigenvectors of *L* that minimizes the {-1, 0, 1}-bandwidth. (Serialized as a 2D NumPy array of integers in NPY binary format.)
- `ARRAY eigbasis_1neg`: An ordered spanning set of {-1, 1}-eigenvectors of *L* that minimizes the {-1, 1}-bandwidth, if one exists. (If *G* is {-1, 1}-diagonalizable, this is serialized as a 2D NumPy array of integers in NPY binary format; otherwise, it is simply `NULL`.)
- `SMALLINT num_edges`: The size of *G* (i.e., |*E*|).
- `REAL density`: The density of *G* (i.e., 2|*E*| / (|*V*|<sup>2</sup> - |*V*|)).
- `REAL avg_degree`: The average vertex degree of *G* (i.e., 2|*E*| / |*V*|).
- `BOOLEAN is_connected`: Whether *G* is bipartite. (All graphs in the database are connected, but this column allows the schema to be extended to disconnected graphs in the future.)
- `BOOLEAN is_bipartite`: Whether *G* is bipartite.
- `BOOLEAN is_regular`: Whether *G* is regular.
- `BOOLEAN is_cograph`: Whether *G* is a cograph (i.e., a graph that does not contain the path graph on 4 vertices as an induced subgraph).
- `ARRAY prime_factors`: The prime factorization of *G* into graphs *G*<sub>1</sub>, *G*<sub>2</sub>, &hellip;, *G*<sub>*k*</sub> such that *G* is isomorphic to the Cartesian product *G*<sub>1</sub> &squ; *G*<sub>2</sub> &squ; &hellip; &squ; *G*<sub>*k*</sub> and each *G*<sub>*i*</sub> is not itself a nontrivial Cartesian product. (If *G* is connected, this is serialized as a 1D NumPy array of graph6 strings in NPY binary format; otherwise, it is simply left as `NULL` due to difficulties with disconnected Cartesian product recognition.)
- `ARRAY compl_prime_factors`: The prime factorization of the complement *G*' into graphs *H*<sub>1</sub>, *H*<sub>2</sub>, &hellip;, *H*<sub>*k*</sub> such that *G*' is isomorphic to the Cartesian product *H*<sub>1</sub> &squ; *H*<sub>2</sub> &squ; &hellip; &squ; *H*<sub>*k*</sub> and each *H*<sub>*i*</sub> is not itself a nontrivial Cartesian product. (If *G*' is connected, this is serialized as a 1D NumPy array of graph6 strings in NPY binary format; otherwise, it is simply left as `NULL` due to difficulties with disconnected Cartesian product recognition.)

### Access

Should one wish to access non-binary data in the SQLite database, it is fairly straightforward to establish a connection to
`data/small_graph_s_bandwidths.db` and query the tables directly. In cases when the NPY binary data is needed, however, one may use the utility functions `read_table_as_pandas_df(path_to_db: str, table_name: str)` and `read_table_as_polars_df(path_to_db: str, table_name: str)` in `src/helpers/sql_mapping.py`. For instance, if one is working from the root directory and wishes to access the data on connected bipartite graphs in the form of a Polars DataFrame, one could run the following command (without even needing to import `sqlite3` or `polars`):

```python
>>> from src.helpers.sql_mapping import read_table_as_polars_df
>>> 
>>> s_diag_con_bip_graphs_1to15 = read_table_as_polars_df(
...     "data/small_graph_s_bandwidths.db", "con_bip_graphs_1to15"
... )
>>> 
>>> print(s_diag_con_bip_graphs_1to15)
shape: (16, 16)
┌─────────┬─────────┬─────────┬────────┬───┬────────┬────────┬────────┬────────┐
│ num_ver ┆ graph6  ┆ band_01 ┆ band_1 ┆ … ┆ is_bip ┆ is_cog ┆ prime_ ┆ compl_ │
│ tices   ┆ ---     ┆ neg     ┆ neg    ┆   ┆ artite ┆ raph   ┆ factor ┆ prime_ │
│ ---     ┆ str     ┆ ---     ┆ ---    ┆   ┆ ---    ┆ ---    ┆ s      ┆ factor │
│ i64     ┆         ┆ i64     ┆ f64    ┆   ┆ bool   ┆ bool   ┆ ---    ┆ s      │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ object ┆ ---    │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆        ┆ object │
╞═════════╪═════════╪═════════╪════════╪═══╪════════╪════════╪════════╪════════╡
│ 1       ┆ @       ┆ 1       ┆ 1.0    ┆ … ┆ true   ┆ true   ┆ ['@']  ┆ ['@']  │
│ 2       ┆ A_      ┆ 1       ┆ 1.0    ┆ … ┆ true   ┆ true   ┆ ['A_'] ┆ ['A?'] │
│ 4       ┆ Cr      ┆ 1       ┆ 1.0    ┆ … ┆ true   ┆ true   ┆ ['A_'  ┆ null   │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ 'A_']  ┆        │
│ 6       ┆ EoSo    ┆ 2       ┆ inf    ┆ … ┆ true   ┆ false  ┆ ['E`YO ┆ ['A_'  │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ ']     ┆ 'Bw']  │
│ 6       ┆ Es\o    ┆ 2       ┆ inf    ┆ … ┆ true   ┆ true   ┆ ['ErYW ┆ null   │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ ']     ┆        │
│ …       ┆ …       ┆ …       ┆ …      ┆ … ┆ …      ┆ …      ┆ …      ┆ …      │
│ 12      ┆ Ks_?BLU ┆ 2       ┆ inf    ┆ … ┆ true   ┆ false  ┆ ['A_'  ┆ ['KvlI │
│         ┆ R`wFO   ┆         ┆        ┆   ┆        ┆        ┆ 'ElUg' ┆ I]}\\t │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ ]      ┆ v[y']  │
│ 12      ┆ Ksa?Btu ┆ 2       ┆ 5.0    ┆ … ┆ true   ┆ false  ┆ ['K`Xc ┆ ['A_'  │
│         ┆ Za{Fo   ┆         ┆        ┆   ┆        ┆        ┆ kyWfBD ┆ 'E~~w' │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ k[']   ┆ ]      │
│ 12      ┆ KsaCB|} ┆ 1       ┆ 1.0    ┆ … ┆ true   ┆ true   ┆ ['KrXb ┆ null   │
│         ┆ ^b{No   ┆         ┆        ┆   ┆        ┆        ┆ C}]fbB ┆        │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ rp']   ┆        │
│ 14      ┆ MsaC?@| ┆ 2       ┆ inf    ┆ … ┆ true   ┆ false  ┆ ['M`Xb ┆ ['A_'  │
│         ┆ ]rmLwVo ┆         ┆        ┆   ┆        ┆        ┆ Cy]WSk ┆ 'F~~~w │
│         ┆ No?     ┆         ┆        ┆   ┆        ┆        ┆ rQfcWZ ┆ ']     │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ ?']    ┆        │
│ 14      ┆ MsaCC@~ ┆ 2       ┆ inf    ┆ … ┆ true   ┆ true   ┆ ['MrXb ┆ null   │
│         ┆ ^r}Nw^o ┆         ┆        ┆   ┆        ┆        ┆ BA^fs} ┆        │
│         ┆ ^o?     ┆         ┆        ┆   ┆        ┆        ┆ RwWNfo ┆        │
│         ┆         ┆         ┆        ┆   ┆        ┆        ┆ _']    ┆        │
└─────────┴─────────┴─────────┴────────┴───┴────────┴────────┴────────┴────────┘
```

(As you can see, the function automatically deserializes the binary-encoded data to the original NumPy arrays.)

## Dependencies

The scripts in `jobs/` are designed specifically for multithreaded execution on a high-performance computing cluster, but they are not too computationally intensive and could be adapted to run on a single machine with fewer threads should one aim to confirm reproducibility. (Do note that the file paths listed in the scripts are still specific to my personal account on Cedar, so they would need to be modified accordingly.) The only requirements are working installations of Julia (v1.10 or later), Python (v3.11 or later), and several registered Julia and Python packages listed in `Project.toml` and `pyproject.toml`, respectively.

## References

[^JP25]: N. Johnston and S. Plosker. Laplacian {−1,0,1}- and {−1,1}-diagonalizable graphs. *Linear Algebra and its Applications*, 704:309&ndash;339, 2025. [10.1016/j.laa.2024.10.016](https://doi.org/10.1016/j.laa.2024.10.016).
[^Var25]: L. M. B. Varona. Luis-Varona/small-laplacian-integral-graphs: A computational survey of small simple connected graphs with integer Laplacian eigenvalues. *GitHub*, 2025. [Luis-Varona/small-laplacian-integral-graphs](https://github.com/Luis-Varona/small-laplacian-integral-graphs).
[^VJP25]: L. M. B. Varona, N. Johnston, and S. Plosker. GraphQuantum/SDiagonalizability.jl: A dynamic algorithm to minimize or recognize the *S*-bandwidth of an undirected graph. *GitHub*, 2025. [GraphQuantum/SDiagonalizability.jl](https://github.com/GraphQuantum/SDiagonalizability.jl).
