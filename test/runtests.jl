using Eternity2Puzzles
using Test


@testset "Eternity2Puzzle constructors" begin
    nrows, ncols = 6, 12
    puzzle1 = Eternity2Puzzle(nrows, ncols, pieces=fill(0x00, nrows*ncols, 4))
    @test size(puzzle1) == (nrows, ncols)

    # Generic 16x16 puzzle should have pre-placed starter-piece on square I8
    puzzle2 = Eternity2Puzzle(16, 16)
    @test puzzle2[9, 8] == (139, 2)

    # But the 16x16 META2010 puzzle does not have the starter-piece
    puzzle3 = Eternity2Puzzle(:meta_16x16)
    @test iszero(puzzle3.board)
end


@testset "Eternity2Puzzle basic operations" begin
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


@testset "Eternity2Puzzle advanced functions" begin
    # Note that the 16x16 META2010 puzzle has pieces with the same color distribution as the
    # original Eternity II puzzle
    puzzle = Eternity2Puzzle(:meta_16x16)

    # Predicted number of solutions without starter-piece
    @test floor(Int, estimate_solutions(puzzle)) == 11526580

    # Predicted number of solutions with starter-piece
    puzzle[9, 8] = (139, 2)
    @test floor(Int, estimate_solutions(puzzle)) == 14702
end
