using Eternity2Puzzles
using Test


@testset "Eternity2Puzzle constructors" begin
    # The original Eternity II puzzle should have starter-piece pre-placed on square I8
    puzzle1 = Eternity2Puzzle()
    @test size(puzzle1) == (16, 16)
    @test puzzle1[9, 8] == (139, 2)

    # Eternity II puzzle with starter-piece and four additional hint pieces
    puzzle2 = Eternity2Puzzle(; hint_pieces=true)
    @test count(>(0), puzzle2.board) == 5

    # The 16x16 META2010 puzzle does not have the starter-piece
    puzzle3 = Eternity2Puzzle(:meta_16x16)
    @test iszero(puzzle3.board)

    # Puzzle with randomly generated pieces and different numbers of rows and columns
    nrows, ncols = 6, 12
    puzzle4 = Eternity2Puzzle(nrows, ncols)
    @test size(puzzle4) == (nrows, ncols)
end


@testset "Eternity2Puzzle basic operations" begin
    puzzle = Eternity2Puzzle()
    @test 139 in puzzle
    reset!(puzzle; starter_piece=false)
    @test !in(139, puzzle)
end


@testset "Eternity2Puzzle advanced functions" begin
    puzzle = Eternity2Puzzle()

    # Predicted number of solutions with starter-piece
    @test trunc(Int, estimate_solutions(puzzle)) == 14702

    # Predicted number of solutions without starter-piece
    reset!(puzzle; starter_piece=false)
    @test trunc(Int, estimate_solutions(puzzle)) == 11526580
end
