using Eternity2Puzzles
using Test


@testset "Eternity2Puzzle constructors" begin
    puzzle = Eternity2Puzzle(16, 16, pieces=:meta_16x16)
    @test size(puzzle) == (16, 16)
    @test puzzle[9, 8] == (139, 2)  # pre-placed starter-piece
end


@testset "Eternity2Puzzle operations" begin
    n = 3
    puzzle = Eternity2Puzzle(n, n, pieces=fill(0x00, n*n, 4))
    piece = 1; rotation = 1
    @test !in(piece, puzzle)
    puzzle[1, 1] = (piece, rotation)
    @test piece in puzzle
    @test puzzle[1, 1] == (piece, rotation)
    reset!(puzzle)
    @test puzzle[1, 1] == (0, 0)
end
