# cython: language_level=3

# Copyright 2025 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

import io
import textwrap
from collections import deque

import networkx as nx
import numpy as np
from networkx.algorithms.isomorphism import GraphMatcher

from libc.stdlib cimport malloc, free

cimport numpy as cnp
from cython cimport boundscheck, wraparound


P4 = nx.path_graph(4)


cpdef enum Layout:
    ROW_MAJOR
    COL_MAJOR


cdef class SDiagonalizableGraph:
    cdef:
        public int order, size, bandwidth_01neg
        public double density, average_degree
        public str graph6
        public cnp.ndarray eigvals, eigbasis_01neg
        public object bandwidth_1neg, eigbasis_1neg

    def __init__(
        self,
        graph6: str,
        bandwidth_01neg: int,
        bandwidth_1neg: int | float,
        eigvals: np.ndarray[int],
        eigbasis_01neg: np.ndarray[int],
        eigbasis_1neg: np.ndarray[int] | None,
    ) -> None:
        self.graph6 = graph6
        G = self._as_graph()
        self.order = G.order()

        self.bandwidth_01neg = bandwidth_01neg
        self.bandwidth_1neg = bandwidth_1neg
        self.eigvals = eigvals
        self.eigbasis_01neg = eigbasis_01neg
        self.eigbasis_1neg = eigbasis_1neg

        self.size = G.size()
        self.density = nx.density(G)
        self.average_degree = self.size / self.order

    def __repr__(self) -> str:
        indent = " " * 3

        buf = io.StringIO()

        buf.write(f"S-diagonalizable graph on {self.order} vertices:\n")
        buf.write(f" * graph6 String: {self.graph6}\n")

        buf.write(f" * {{-1, 0, 1}}-bandwidth: {self.bandwidth_01neg}\n")
        buf.write(f" * {{-1, 1}}-bandwidth: {self.bandwidth_1neg}\n")
        buf.write(f" * Eigenvalues:\n{indent}{self.eigvals}\n")
        buf.write(" * {-1, 0, 1}-eigenbasis:\n")
        buf.write(f"{textwrap.indent(str(self.eigbasis_01neg), indent)}\n")
        buf.write(" * {-1, 1}-eigenbasis:")

        if self.eigbasis_1neg is None:
            buf.write(" None\n")
        else:
            buf.write(f"\n{textwrap.indent(str(self.eigbasis_1neg), indent)}\n")

        buf.write(f" * Edge count: {self.size}\n")
        buf.write(f" * density: {self.density:.3f}\n")
        buf.write(f" * Average degree: {self.average_degree:.3f}\n")
        buf.write(f" * Is connected: {self.is_connected()}\n")
        buf.write(f" * Is regular: {self.is_regular()}\n")
        buf.write(f" * Is bipartite: {self.is_bipartite()}\n")
        buf.write(f" * Is cograph: {self.is_cograph()}\n")

        buf.write(f" * Prime graph factors:")
        factors = self.prime_factors()

        if factors is None:
            buf.write(" Unable to compute\n")
        else:
            buf.write(f"\n{indent}{factors}\n")

        buf.write(f" * Complement prime graph factors:")
        complement_factors = self.complement_prime_factors()

        if complement_factors is None:
            buf.write(" Not computable")
        else:
            buf.write(f"\n{indent}{complement_factors}")

        return buf.getvalue()

    cdef object _as_graph(self):
        return nx.from_graph6_bytes(self.graph6.encode("ascii"))

    cpdef bint is_connected(self):
        return nx.is_connected(self._as_graph())

    cpdef bint is_regular(self):
        return nx.is_regular(self._as_graph())

    cpdef bint is_bipartite(self):
        return nx.is_bipartite(self._as_graph())

    cpdef bint is_cograph(self):
        return is_cograph(self._as_graph())

    cpdef object prime_factors(self):
        return SDiagonalizableGraph._safe_prime_factors_as_g6(self._as_graph())

    cpdef object complement_prime_factors(self):
        return SDiagonalizableGraph._safe_prime_factors_as_g6(nx.complement(self._as_graph()))

    # TODO: Use nauty's labelg to convert to canonical form?
    @staticmethod
    def _safe_prime_factors_as_g6(G: nx.Graph) -> np.ndarray[str] | None:
        try:
            factors = np.array(
                [
                    nx.to_graph6_bytes(factor)
                    .decode("ascii")
                    .removeprefix(">>graph6<<")
                    .strip()
                    for factor in prime_graph_factors(G)
                ]
            )
        except ValueError as e:
            if str(e).startswith("Prime graph factorization is not implemented for "):
                factors = None
            else:
                raise

        return factors

    @staticmethod
    def from_json_dict(
        d: dict, layout: Layout = Layout.ROW_MAJOR
    ) -> SDiagonalizableGraph:
        graph6 = d["graph6"]
        bandwidth_01neg = d["bandwidth_01neg"]
        bandwidth_1neg = d["bandwidth_1neg"]
        eigvals = np.array(d["eigvals"], int)
        eigbasis_01neg = d["eigbasis_01neg"]
        eigbasis_1neg = d["eigbasis_1neg"]

        if layout == Layout.ROW_MAJOR:
            eigbasis_01neg = np.array(eigbasis_01neg, int)
        elif layout == Layout.COL_MAJOR:
            eigbasis_01neg = np.array(eigbasis_01neg, int).T
        else:
            raise ValueError(f"Unknown layout: {layout}")

        if bandwidth_1neg == "inf":
            bandwidth_1neg = float("inf")

            if eigbasis_1neg is not None:
                raise ValueError(
                    "`eigbasis_1neg` should be None when `bandwidth_1neg` is 'inf'"
                )

        if eigbasis_1neg is not None:
            if layout == Layout.ROW_MAJOR:
                eigbasis_1neg = np.array(eigbasis_1neg, int)
            elif layout == Layout.COL_MAJOR:
                eigbasis_1neg = np.array(eigbasis_1neg, int).T
            else:
                raise ValueError(f"Unknown layout: {layout}")
        elif bandwidth_1neg != float("inf"):
            raise ValueError(
                "`bandwidth_1neg` should be 'inf' when `eigbasis_1neg` is None"
            )

        return SDiagonalizableGraph(
            graph6,
            bandwidth_01neg,
            bandwidth_1neg,
            eigvals,
            eigbasis_01neg,
            eigbasis_1neg,
        )

    cpdef dict to_dict(self):
        return {
            "num_vertices": self.order,
            "graph6": self.graph6,
            "band_01neg": self.bandwidth_01neg,
            "band_1neg": self.bandwidth_1neg,
            "eigvals": self.eigvals,
            "eigbasis_01neg": self.eigbasis_01neg,
            "eigbasis_1neg": self.eigbasis_1neg,
            "num_edges": self.size,
            "density": self.density,
            "avg_degree": self.average_degree,
            "is_connected": self.is_connected(),
            "is_regular": self.is_regular(),
            "is_bipartite": self.is_bipartite(),
            "is_cograph": self.is_cograph(),
            "prime_factors": self.prime_factors(),
            "compl_prime_factors": self.complement_prime_factors(),
        }


cpdef bint is_cograph(object G):
    if G.is_directed():
        raise ValueError("Cograph recognition is not implemented for digraphs")

    if G.is_multigraph():
        raise ValueError("Cograph recognition is not implemented for multigraphs")

    if G.order() < 4:
        return True

    if nx.density(G) > 0.5:
        G = nx.complement(G)

    for cc in nx.connected_components(G):
        if len(cc) >= 4:
            H = G.subgraph(cc)

            if nx.density(H) > 0.5:
                H = nx.complement(H)

            if GraphMatcher(H, P4).subgraph_is_isomorphic():
                return False

    return True


@boundscheck(False)
@wraparound(False)
cpdef list prime_graph_factors(object G):
    cdef int n = G.order()

    if not is_valid_cart_prod_order(n):
        return [G.copy()]

    if G.is_directed():
        raise ValueError(
            "Prime graph factorization is not implemented for digraphs with vertex counts that may admit Cartesian products"
        )

    if G.is_multigraph():
        raise ValueError(
            "Prime graph factorization is not implemented for multigraphs with vertex counts that may admit Cartesian products"
        )

    if not nx.is_connected(G):
        raise ValueError(
            "Prime graph factorization is not implemented for disconnected graphs with vertex counts that may admit Cartesian products"
        )

    cdef char *visited = <char *> malloc(n * sizeof(char))

    if visited == NULL:
        raise MemoryError("Failed to allocate memory for `visited` array")

    cdef:
        list int_to_vertex = list(G.nodes())
        dict vertex_to_int = {int_to_vertex[i]: i for i in range(n)}
        object G_int = nx.relabel_nodes(G, vertex_to_int, copy=True)
        int m = G.size()
        int *vis = <int *> malloc(m * sizeof(int))

    if vis == NULL:
        free(visited)
        raise MemoryError("Failed to allocate memory for `vis` array")

    cdef:
        object queue
        list adj, edges, h_adj, path, intersect_list, components, component, stack
        set un, intersect
        dict edge_to_idx, dd
        int[:, :] dist
        int u, v, x, y, idx1, idx2, current, depth, neighbor, i, j, uu, vv

        list factors = []
        list edge_list, orig_edge_list, ccs
        object tmp, first_cc, factor

    try:
        adj = [list(G_int.neighbors(i)) for i in range(n)]
        h_adj = [set() for _ in range(m)]
        edges = [(min(u, v), max(u, v)) for u, v in G_int.edges()]
        edge_to_idx = {edges[i]: i for i in range(m)}
        dist = np.full((n, n), n, np.int32)

        for u in range(n):
            dd = nx.shortest_path_length(G_int, source=u)

            for v in range(n):
                dist[u, v] = dd[v]

        for u in range(n):
            un = set(adj[u])

            for i in range(n):
                visited[i] = 0

            queue = deque()
            queue.append((u, 0))
            visited[u] = 1

            while queue:
                current, depth = queue.popleft()

                if depth > 0:
                    v = current
                    intersect = un & set(adj[v])

                    if intersect:
                        has_edge = (depth == 1)

                        if has_edge:
                            path = []

                            for x in intersect:
                                ex = (u, x) if u < x else (x, u)
                                path.append(edge_to_idx[ex])
                                ex = (v, x) if v < x else (x, v)
                                path.append(edge_to_idx[ex])

                            add_path(h_adj, path)
                        elif len(intersect) == 1:
                            x = next(iter(intersect))
                            ex = (u, x) if u < x else (x, u)
                            idx1 = edge_to_idx[ex]
                            ex = (v, x) if v < x else (x, v)
                            idx2 = edge_to_idx[ex]
                            add_edge(h_adj, idx1, idx2)
                        elif len(intersect) == 2:
                            intersect_list = list(intersect)
                            x = intersect_list[0]
                            y = intersect_list[1]
                            ex = (u, x) if u < x else (x, u)
                            idx1 = edge_to_idx[ex]
                            ex = (v, y) if v < y else (y, v)
                            idx2 = edge_to_idx[ex]
                            add_edge(h_adj, idx1, idx2)
                            ex = (v, x) if v < x else (x, v)
                            idx1 = edge_to_idx[ex]
                            ex = (u, y) if u < y else (y, u)
                            idx2 = edge_to_idx[ex]
                            add_edge(h_adj, idx1, idx2)
                        else:
                            path = []

                            for x in intersect:
                                ex = (u, x) if u < x else (x, u)
                                path.append(edge_to_idx[ex])

                            for x in intersect:
                                ex = (v, x) if v < x else (x, v)
                                path.append(edge_to_idx[ex])

                            add_path(h_adj, path)

                if depth < 2:
                    for neighbor in adj[current]:
                        if visited[neighbor] == 0:
                            visited[neighbor] = 1
                            queue.append((neighbor, depth + 1))

        for i in range(m):
            u, v = edges[i]

            for j in range(i + 1, m):
                uu, vv = edges[j]

                if dist[u, uu] + dist[v, vv] != dist[u, vv] + dist[v, uu]:
                    add_edge(h_adj, i, j)

        for i in range(m):
            vis[i] = 0

        components = []

        for i in range(m):
            if not vis[i]:
                component = []
                stack = [i]
                vis[i] = 1

                while stack:
                    current = stack.pop()
                    component.append(current)

                    for neighbor in h_adj[current]:
                        if not vis[neighbor]:
                            vis[neighbor] = 1
                            stack.append(neighbor)

                components.append(component)

        for component in components:
            edge_list = [edges[i] for i in component]
            orig_edge_list = [
                (int_to_vertex[u], int_to_vertex[v]) for u, v in edge_list
            ]
            tmp = nx.Graph()
            tmp.add_edges_from(orig_edge_list)
            ccs = list(nx.connected_components(tmp))
            first_cc = ccs[0]
            factor = tmp.subgraph(first_cc).copy()
            factors.append(factor)

        return factors

    finally:
        free(vis)
        free(visited)


cpdef bint is_valid_cart_prod_order(int n):
    return n >= 4 and not is_prime(n)


cdef bint is_prime(int n):
    if n > 1_373_653:
        raise ValueError(
            f"1,373,653 is the smallest strong pseudoprime to 2 and 3, got n > 1,373,653: {n}"
        )

    cdef bint res
    cdef int d

    if n < 2:
        res = False
    elif n < 4:
        res = True
    elif n % 2 == 0:
        res = False
    else:
        d = n - 1

        while d % 2 == 0:
            d //= 2

        if witness(n, d, 2) or witness(n, d, 3):
            res = False
        else:
            res = True

    return res


cdef inline bint witness(int n, int d, int a):
    cdef int x = pow(a, d, n)
    cdef bint res = True

    while res and d != n - 1:
        x = pow(x, 2, n)
        d <<= 1

        if x in (1, n - 1):
            res = False

    return res


cdef void add_path(list h_adj, list path):
    cdef int i
    for i in range(len(path) - 1):
        add_edge(h_adj, path[i], path[i + 1])


cdef void add_edge(list h_adj, int a, int b):
    if a != b:
        h_adj[a].add(b)
        h_adj[b].add(a)
