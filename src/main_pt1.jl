# Copyright 2025 Luis M. B. Varona
#
# Licensed under the MIT license <LICENSE or
# http://opensource.org/licenses/MIT>. This file may not be copied, modified, or
# distributed except according to those terms.

using Base.Threads
using JSON

include("helpers/utils.jl")
using .Utils

function main()
    source, dest = parse_cli_args()
    graph6_iter = Iterators.filter(line -> !startswith(line, "#"), eachline(source))

    num_threads = nthreads()
    work_queue = Channel{Tuple{Int,String}}(num_threads)

    @spawn begin
        foreach(elem -> put!(work_queue, elem), enumerate(graph6_iter))
        close(work_queue)
    end

    num_threads = nthreads()
    results_disagg = map(_ -> Tuple{Int,SDiagonalizableGraph}[], 1:num_threads)

    @sync for i in 1:num_threads
        @spawn begin
            thread_results = results_disagg[i]

            for (j, graph6) in work_queue
                res = graph6_to_s_diag_graph(graph6)

                if !isnothing(res)
                    push!(thread_results, (j, res))
                end
            end
        end
    end

    results = sort!(vcat(results_disagg...))

    open(dest, "w") do file
        JSON.print(file, map(res -> to_dict(res[2]), results))
        return nothing
    end

    return nothing
end

function parse_cli_args()
    num_args = length(ARGS)

    if num_args != 2
        throw(
            ArgumentError(
                "Expected TWO args, got $num_args: $(join(map(arg -> "'$arg'", ARGS), ", "))",
            ),
        )
    end

    source, dest = ARGS

    if !isfile(source)
        throw(ArgumentError("Source file does not exist: '$source'"))
    end

    if ispath(dest)
        throw(ArgumentError("Destination already exists: '$dest'"))
    end

    if !endswith(dest, ".json")
        throw(ArgumentError("Destination file must have a '.json' extension: '$dest'"))
    end

    mkpath(dirname(dest))

    return source, dest
end

if abspath(PROGRAM_FILE) == @__FILE__
    main()
end
