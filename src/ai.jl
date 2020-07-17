mutable struct ActiveInfo <: InfoDist
    joint::Matrix{Int}
    future::Vector{Int}
    history::Vector{Int}
    b::Int
    k::Int
    N::Int
    function ActiveInfo(b::Int, k::Int)
        if b < 2
            throw(ArgumentError("the support of the future must be at least 2"))
        elseif k < 1
            throw(ArgumentError("history length must be at least 1"))
        end
        new(zeros(Int, b, b^k), zeros(Int, b), zeros(Int, b^k), b, k, 0)
    end
end

function ActiveInfo(xs::AbstractVector{Int}, k::Int)
    if k < 1
        throw(ArgumentError("history length must be at least 1"))
    elseif length(xs) ≤ k
        throw(ArgumentError("first argument's length must be greater than the history length"))
    end
    xmin, xmax = extrema(xs)
    if xmin < 1
        throw(ArgumentError("observations must be positive, nonzero"))
    end
    observe!(ActiveInfo(max(2, xmax), k), xs)
end

function estimate(dist::ActiveInfo)
    entropy(dist.future, dist.N) + entropy(dist.history, dist.N) - entropy(dist.joint, dist.N)
end

function observe!(dist::ActiveInfo, xs::AbstractVector{Int})
    if length(xs) ≤ dist.k
        throw(ArgumentError("data's length must be greater than the history length"))
    end
    dist.N += length(xs) - dist.k
    history, q = 0, 1
    for i in 1:dist.k
        q *= dist.b
        history = dist.b * history + xs[i] - 1
    end
    for i in dist.k+1:length(xs)
        dist.future[xs[i]] += 1
        dist.history[history + 1] += 1
        dist.joint[xs[i], history + 1] += 1
        history = dist.b * history - q * (xs[i - dist.k] - 1) + xs[i] - 1
    end
    dist
end

@inline function clear!(dist::ActiveInfo)
    dist.joint[:] .= 0
    dist.future[:] .= 0
    dist.history[:] .= 0
    dist.N = 0
    dist
end

function activeinfo!(dist::ActiveInfo, xs::AbstractVector{Int})
    estimate(observe!(dist, xs))
end

activeinfo(xs::AbstractVector{Int}, k::Int) = estimate(ActiveInfo(xs, k))

function activeinfo(::Type{Kraskov1}, xs::AbstractMatrix{Float64}, k::Int;
                    τ::Int=1, nn::Int=1, metric::Metric=Chebyshev())
    hs = history(xs, k, τ, 1)
    fs = xs[:, end-size(hs, 2)+1:end]
    mutualinfo(fs, hs; nn=nn, metric=metric)
end

function activeinfo(::Type{Kraskov}, xs::AbstractMatrix{Float64}, k::Int; kwargs...)
    activeinfo(Kraskov1, xs, k; kwargs...)
end

function activeinfo(xs::AbstractMatrix{Float64}, k::Int; kwargs...)
    activeinfo(Kraskov1, xs, k; kwargs...)
end

function activeinfo(xs::AbstractVector{Float64}, k::Int; kwargs...)
    activeinfo(reshape(xs, 1, length(xs)), k; kwargs...)
end
