mutable struct MutualInfo{D,E} <: InfoDist
    joint::Matrix{Int}
    m1::Vector{Int}
    m2::Vector{Int}
    b1::NTuple{D,Int}
    b2::NTuple{E,Int}
    N::Int
    lag::Int
    function MutualInfo(b1::NTuple{D, <:Integer}, b2::NTuple{E, <:Integer}; lag::Int=0) where {D, E}
        if D == 0 || E == 0
            throw(MethodError(MutualInfo, (b1, b2)))
        end
        if any(b -> b < 2, b1) || any(b -> b < 2, b2)
            throw(ArgumentError("the support of each random variable must be at least 2"))
        end
        B1, B2 = prod(b1), prod(b2)
        new{D,E}(zeros(Int, B1, B2), zeros(Int, B1), zeros(Int, B2), b1, b2, 0, lag)
    end
end
MutualInfo(b1::Integer, b2::Integer; kwargs...) = MutualInfo((b1,), (b2,))
MutualInfo(b1::Integer, b2::NTuple; kwargs...) = MutualInfo((b1,), b2)
MutualInfo(b1::NTuple, b2::Integer; kwargs...) = MutualInfo(b1, (b2,))

function MutualInfo(xs::AbstractArray{Int,3}, ys::AbstractArray{Int,3}; kwargs...)
    if isempty(xs) || isempty(ys)
        throw(ArgumentError("arguments must not be empty"))
    end
    xmax = max.(2, maximum(xs; dims=(2,3)))
    ymax = max.(2, maximum(ys; dims=(2,3)))
    observe!(MutualInfo(tuple(xmax...), tuple(ymax...); kwargs...), xs, ys)
end

function MutualInfo(xs::AbstractArray{Int,2}, ys::AbstractArray{Int,2}; kwargs...)
    if isempty(xs) || isempty(ys)
        throw(ArgumentError("arguments must not be empty"))
    end
    xmax = max.(2, maximum(xs; dims=2))
    ymax = max.(2, maximum(ys; dims=2))
    observe!(MutualInfo(tuple(xmax...), tuple(ymax...); kwargs...), xs, ys)
end

function MutualInfo(xs::AbstractArray{Int,1}, ys::AbstractArray{Int,1}; kwargs...)
    if isempty(xs) || isempty(ys)
        throw(ArgumentError("arguments must not be empty"))
    end
    xmax = max(2, maximum(xs))
    ymax = max(2, maximum(ys))
    observe!(MutualInfo(tuple(xmax...), tuple(ymax...); kwargs...), xs, ys)
end

function estimate(dist::MutualInfo)
    entropy(dist.m1, dist.N) + entropy(dist.m2, dist.N) - entropy(dist.joint, dist.N)
end

function observe!(dist::MutualInfo, xs::AbstractArray{Int,3}, ys::AbstractArray{Int,3})
    if size(xs, 3) != size(ys, 3)
        throw(ArgumentError("time series should have the same number of replicates"))
    end

    @views for i in 1:size(xs, 3)
        observe!(dist, xs[:,:,i], ys[:,:,i])
    end

    dist
end

function observe!(dist::MutualInfo, xs::AbstractArray{Int,2}, ys::AbstractArray{Int,2})
    if size(xs, 2) != size(ys, 2)
        throw(ArgumentError("time series should have the same number of timesteps"))
    elseif any(b -> b < 1, xs) || any(b -> b < 1, ys)
        throw(ArgumentError("observations must be positive, nonzero"))
    end

    N = size(xs, 2) - abs(dist.lag)

    dist.N += N
    @views for t in 1:N
        x, y = if dist.lag < zero(dist.lag)
            index(xs[:,t-dist.lag], dist.b1), index(ys[:,t], dist.b2)
        else
            index(xs[:,t], dist.b1), index(ys[:,t+dist.lag], dist.b2)
        end
        dist.m1[x] += 1
        dist.m2[y] += 1
        dist.joint[x, y] += 1
    end
    dist
end

function observe!(dist::MutualInfo, xs::AbstractArray{Int,1}, ys::AbstractArray{Int,1})
    if length(xs) != length(ys)
        throw(ArgumentError("time series should have the same number of timesteps"))
    elseif any(b -> b < 1, xs) || any(b -> b < 1, ys)
        throw(ArgumentError("observations must be positive, nonzero"))
    end

    N = length(xs) - abs(dist.lag)

    dist.N += N
    @views for t in 1:N
        x, y = if dist.lag < zero(dist.lag)
            xs[t-dist.lag], ys[t]
        else
            xs[t], ys[t+dist.lag]
        end
        dist.m1[x] += 1
        dist.m2[y] += 1
        dist.joint[x, y] += 1
    end
    dist
end

@inline function clear!(dist::MutualInfo)
    dist.joint[:] .= 0
    dist.m1[:] .= 0
    dist.m2[:] .= 0
    dist.N = 0
    dist
end

function mutualinfo!(dist::MutualInfo, xs::AbstractArray{Int}, ys::AbstractArray{Int}; kwargs...)
    estimate(observe!(dist, xs, ys, kwargs...))
end

function mutualinfo(xs::AbstractArray{Int}, ys::AbstractArray{Int}; kwargs...)
    estimate(MutualInfo(xs, ys; kwargs...))
end

function mutualinfo(::Type{Kraskov1}, xs::AbstractMatrix{Float64}, ys::AbstractMatrix{Float64};
                    nn::Int=1, metric::Metric=Chebyshev())
    data = [xs; ys]
    joint = BallTree(data, metric)
    m1 = BallTree(xs, metric)
    m2 = BallTree(ys, metric)
    mi = zero(Float64)
    N = size(data, 2)

    δs = prevfloat.(last.(last(knn(joint, data, nn + 1, true))))
    for i in 1:N
        nx = length(inrange(m1, xs[:, i], δs[i]))
        ny = length(inrange(m2, ys[:, i], δs[i]))
        mi += digamma(nx) + digamma(ny)
    end
    digamma(nn) - (mi/N) + digamma(N)
end

function mutualinfo(::Type{Kraskov1}, xs::AbstractMatrix{Float64}, ys::AbstractMatrix{Float64},
                    cond::AbstractMatrix{Float64}, conds::AbstractMatrix{Float64}...;
                    nn::Int=1, metric::Metric=Chebyshev())
    data = [xs; ys; cond; conds...]
    var1 = [xs; cond; conds...]
    var2 = [ys; cond; conds...]
    varcond = [cond; conds...]

    joint = BallTree(data, metric)
    m1 = BallTree(var1, metric)
    m2 = BallTree(var2, metric)
    mcond = BallTree(varcond, metric)

    mi = zero(Float64)
    N = size(data, 2)

    δs = prevfloat.(last.(last(knn(joint, data, nn + 1, true))))
    for i in 1:N
        n1 = length(inrange(m1, var1[:, i], δs[i]))
        n2 = length(inrange(m2, var2[:, i], δs[i]))
        ncond = length(inrange(mcond, varcond[:, i], δs[i]))
        mi += digamma(ncond) - digamma(n1) - digamma(n2)
    end
    digamma(nn) + (mi/N)
end

function mutualinfo(::Type{Kraskov}, xs::AbstractMatrix{Float64}, ys::AbstractMatrix{Float64},
                    cond::AbstractMatrix{Float64}...; kwargs...)
    mutualinfo(Kraskov1, xs, ys, cond...; kwargs...)
end

function mutualinfo(xs::AbstractMatrix{Float64}, ys::AbstractMatrix{Float64},
                    cond::AbstractMatrix{Float64}...; kwargs...)
    mutualinfo(Kraskov1, xs, ys, cond...; kwargs...)
end

function mutualinfo(xs::AbstractVector{Float64}, ys::AbstractVector{Float64},
                    cond::AbstractVector{Float64}...; kwargs...)
    conds = map(c -> reshape(c, 1, length(c)), cond)
    mutualinfo(reshape(xs, 1, length(xs)), reshape(ys, 1, length(ys)), conds...; kwargs...)
end
