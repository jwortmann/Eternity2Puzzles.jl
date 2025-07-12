using Eternity2Puzzles
using Test


@testset "Eternity2Puzzle constructors" begin
    # The original Eternity II puzzle should have starter-piece pre-placed on square I8
    puzzle = Eternity2Puzzle()
    @test size(puzzle.board) == (16, 16)
    @test count(!iszero, puzzle.board) == 1

    # Eternity II puzzle without starter-piece
    puzzle = Eternity2Puzzle(; starter_piece=false)
    @test count(!iszero, puzzle.board) == 0

    # Eternity II puzzle with starter-piece and four additional hint pieces
    puzzle = Eternity2Puzzle(; hint_pieces=true)
    @test count(!iszero, puzzle.board) == 5

    # The 16x16 META2010 puzzle does not have the starter-piece
    puzzle = Eternity2Puzzle(:meta_16x16)
    @test count(!iszero, puzzle.board) == 0

    # Puzzle with randomly generated pieces and different numbers of rows and columns
    puzzle = Eternity2Puzzle(5, 4)
    @test size(puzzle.board) == (5, 4)
    @test count(iszero, puzzle.board) == 0  # Board prefilled with a solution

    # Puzzle with all 256 original Eternity II pieces, but with a smaller board size
    puzzle = Eternity2Puzzle(:eternity2, 14, 14)
    @test size(puzzle.board) == (14, 14)
    @test size(puzzle.pieces, 1) == 256
end


@testset "Eternity2Puzzle basic operations" begin
    puzzle = Eternity2Puzzle()
    @test size(puzzle) == (16, 16)  # Eternity2Puzzle type supports `size` function directly
    @test puzzle[9, 8] == (139, 2)  # Indexing using row/col numbers
    @test puzzle["I8"] == (139, 2)  # Indexing using a string
    @test 139 in puzzle
    reset!(puzzle; starter_piece=false)
    @test count(!iszero, puzzle.board) == 0
end


@testset "Eternity2Puzzle advanced functions" begin
    puzzle = Eternity2Puzzle()

    # Number of symmetries
    @test Eternity2Puzzles.symmetry_factor(puzzle) == 1

    # Predicted number of solutions with constraint from the starter-piece
    @test trunc(Int, estimate_solutions(puzzle)[1]) == 14702

    # Symmetries and predicted number of solutions without the starter-piece
    reset!(puzzle; starter_piece=false)
    @test Eternity2Puzzles.symmetry_factor(puzzle) == 4
    @test trunc(Int, estimate_solutions(puzzle)[1]) == 11526580
end
