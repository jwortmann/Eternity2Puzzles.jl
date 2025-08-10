using Eternity2Puzzles
using Test


@testset "Constructors" begin
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
    puzzle = Eternity2Puzzle(6, 12)
    @test size(puzzle.board) == (6, 12)
    @test Eternity2Puzzles.score(puzzle) == (126, 0)  # Prefilled board with valid solution
    @test Eternity2Puzzles.symmetry_factor(puzzle) == 1  # No symmetric or identical pieces

    # Puzzle with all 256 original Eternity II pieces, but with a smaller board size
    puzzle = Eternity2Puzzle(:eternity2, 14, 14)
    @test size(puzzle.board) == (14, 14)
    @test size(puzzle.pieces, 1) == 256
end


@testset "Basic operations" begin
    puzzle = Eternity2Puzzle()
    @test size(puzzle) == (16, 16)  # Eternity2Puzzle type supports `size` function directly
    @test puzzle[9, 8] == (139, 2)  # Indexing using row/col numbers
    @test puzzle["I8"] == (139, 2)  # Indexing using a string
    @test 139 in puzzle
    reset!(puzzle; starter_piece=false)
    @test count(!iszero, puzzle.board) == 0
end


@testset "Symmetries" begin
    @test Eternity2Puzzles.symmetry_factor(Eternity2Puzzle()) == 1
    @test Eternity2Puzzles.symmetry_factor(Eternity2Puzzle(starter_piece=false)) == 4
    @test Eternity2Puzzles.symmetry_factor(Eternity2Puzzle(:clue1)) == 6144
    @test Eternity2Puzzles.symmetry_factor(Eternity2Puzzle(:clue2)) == 1902536294400
    @test Eternity2Puzzles.symmetry_factor(Eternity2Puzzle(:clue3)) == 4608
    @test Eternity2Puzzles.symmetry_factor(Eternity2Puzzle(:clue4)) == 226492416
end


@testset "Search paths" begin
    for (nrows, ncols) in [(8, 8), (9, 9), (4, 8), (8, 4), (4, 9), (9, 4), (5, 8), (8, 5), (5, 9), (9, 5)]
        puzzle = Eternity2Puzzle(nrows, ncols)
        reset!(puzzle)
        @test length(Eternity2Puzzles.generate_search_path(puzzle, :spiral_in)) == nrows * ncols
    end
end


@testset "Solution estimates" begin
    # Predicted number of solutions with constraint from the starter-piece
    puzzle = Eternity2Puzzle()
    @test trunc(Int, estimate_solutions(puzzle)[1]) == 14702

    # Predicted number of solutions without the starter-piece
    puzzle = Eternity2Puzzle(starter_piece=false)
    @test trunc(Int, estimate_solutions(puzzle)[1]) == 11526580
end
