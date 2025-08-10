# Copyright 2025 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

module Utils

export SDiagonalizableGraph, to_dict, graph6_to_s_diag_graph

using GraphIO.Graph6: _g6StringToGraph
using SDiagonalizability: s_bandwidth

struct SDiagonalizableGraph
    graph6::String
    bandwidth_01neg::Int
    bandwidth_1neg::Union{Int,Float64}
    eigvals::Vector{Int}
    eigbasis_01neg::Matrix{Int}
    eigbasis_1neg::Union{Nothing,Matrix{Int}}
end

function to_dict(obj::SDiagonalizableGraph)
    dict = Dict(
        string(name) => getfield(obj, name) for name in fieldnames(SDiagonalizableGraph)
    )

    if dict["bandwidth_1neg"] == Inf
        dict["bandwidth_1neg"] = "inf"
    end

    return dict
end

function graph6_to_s_diag_graph(graph6::String)
    graph = _g6StringToGraph(graph6)
    res_01neg = s_bandwidth(graph, (-1, 0, 1))
    bandwidth_01neg = res_01neg.s_bandwidth

    if isfinite(bandwidth_01neg)
        eigvals = res_01neg.s_diagonalization.values
        res_1neg = s_bandwidth(graph, (-1, 1))
        bandwidth_1neg = res_1neg.s_bandwidth

        if isfinite(bandwidth_1neg)
            eigbasis_1neg = res_1neg.s_diagonalization.vectors
        else
            eigbasis_1neg = nothing
        end

        if bandwidth_01neg == bandwidth_1neg
            # k-orthogonal {-1, 1}-bases are preferable to k-orthogonal {-1, 0, 1}-bases
            eigbasis_01neg = eigbasis_1neg
        else
            eigbasis_01neg = res_01neg.s_diagonalization.vectors
        end

        res = SDiagonalizableGraph(
            graph6, bandwidth_01neg, bandwidth_1neg, eigvals, eigbasis_01neg, eigbasis_1neg
        )
    else
        res = nothing
    end

    return res
end

end
