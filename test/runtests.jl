using Eolas, Test

import Eolas: vertices, toposort!, isbelow

include("lattice-vertices.jl")

@test Vertex <: AbstractVertex
@test Vertex{Int} <: AbstractVertex{Int}
@test !(Vertex{Int} <: AbstractVertex{Float64})

@test_throws TypeError Vertex{Int, Vertex{Float64}}

let v = Vertex([1, 2], 2, Vertex{Int}[], Vertex{Int}[])
    @test name(v) == [1,2]
    @test payload(v) == 2
    @test above(v) == Vertex{Int}[]
    @test below(v) == Vertex{Int}[]
    @test string(v) == "Vertex([1, 2], 2)"
end

let v = Vertex([1,2], 1)
    @test name(v) == [1,2]
    @test payload(v) == 1
    @test above(v) == Vertex{Int}[]
    @test below(v) == Vertex{Int}[]
    @test string(v) == "Vertex([1, 2], 1)"
end

let v = Vertex{Int64}([1,2])
    @test name(v) == [1,2]
    @test payload(v) == 0
    @test above(v) == Vertex{Int}[]
    @test below(v) == Vertex{Int}[]
    @test string(v) == "Vertex([1, 2], 0)"
end

@test isbelow(Vertex{Int}([1,2]), Vertex{Int}([1]))
@test isbelow(Vertex{Int}([1,2]), Vertex{Int}([3]))
@test isbelow(Vertex{Int}([2]), Vertex{Int}([2]))
@test isbelow(Vertex{Float64}([1,2,4]), Vertex{Float64}([7]))

@test !isbelow(Vertex{Int}([1]), Vertex{Int}([2]))
@test !isbelow(Vertex{Int}([2]), Vertex{Int}([1,2]))

@test length(vertices(Vertex{Int}, 1)) == 1
@test length(vertices(Vertex{Int}, 2)) == 4
@test length(vertices(Vertex{Int}, 3)) == 18
@test length(vertices(Vertex{Int}, 4)) == 166
@test length(vertices(Vertex{Int}, 5)) == 7579

@test Set(name.(vertices(Vertex{Int}, 1))) == Set(VERTICES_1)
@test Set(name.(vertices(Vertex{Int}, 2))) == Set(VERTICES_2)
@test Set(name.(vertices(Vertex{Int}, 3))) == Set(VERTICES_3)
@test Set(name.(vertices(Vertex{Int}, 4))) == Set(VERTICES_4)

@test name.(toposort!(vertices(Vertex{Int}, 1))) == VERTICES_1
@test name.(toposort!(vertices(Vertex{Int}, 2))) == VERTICES_2
@test name.(toposort!(vertices(Vertex{Int}, 3))) == VERTICES_3
@test name.(toposort!(vertices(Vertex{Int}, 4))) == VERTICES_4
