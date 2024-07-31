const BORDER_COLOR = UInt8(NCOLORS)
const BORDER_COLOR2 = UInt8(NCOLORS + 1)


"""
    BacktrackingSearch(target_score::Int, seed::Int)

A single-threaded backtracking search with heuristics for the original Eternity II puzzle.

This algorithm is not designed to search for a perfect solution, but to find partial
solutions with a high score. Therefore a certain amount of mismatched edges is tolerated,
controlled by the `target_score` parameter.

The solver is work in progress, i.e. the parameters are probably not optimally tuned and
further speed optimizations may be possible.
"""
@kwdef struct BacktrackingSearch <: Eternity2Solver
    target_score::Int = 470
    seed::Int = 1
end


function solve!(puzzle::Eternity2Puzzle, solver::BacktrackingSearch)
    size(puzzle) == (16, 16) || error("This algorithm only works with board dimensions 16x16")
    puzzle[9, 8] == (STARTER_PIECE, 2) || error("Expected starter-piece on row 9 column 8")
    449 < solver.target_score < 479 || error("Target score outside of allowed range 450..478")

    @info "Parameters" solver.target_score solver.seed
    Random.seed!(solver.seed)

    # The algorithm doesn't operate on the puzzle.board and puzzle.pieces fields directly;
    # instead, derived arrays and lookup tables are created to reduce the amount of accessed
    # array values and other operations. The border color number is remapped from 0 to 23,
    # so that it can be used as an array index.

    # ============================= Phase 0: initialize arrays =============================

    # Prepare a table that contains the edge colors in all directions for all possible
    # UInt16 values of the pieces and rotations
    colors = Matrix{UInt8}(undef, 256 << 2 | 3, 2)
    colors[0x0001, :] .= BORDER_COLOR
    colors[0x0002, :] .= BORDER_COLOR2

    for (piece, piece_colors) in enumerate(eachrow(replace(puzzle.pieces, 0=>BORDER_COLOR))), rotation = 0:3
        colors[piece << 2 | rotation, 1] = piece_colors[mod1(1 - rotation, 4)]
        colors[piece << 2 | rotation, 2] = piece_colors[4 - rotation]
    end

    STARTER_PIECE_BOTTOM_COLOR = puzzle.pieces[STARTER_PIECE, 1]
    STARTER_PIECE_RIGHT_COLOR = puzzle.pieces[STARTER_PIECE, 4]

    # Colors which should be eliminated early during the search; pick one of the frame
    # colors 1..5 which is least often used in the corner pieces, and two inner colors 6..22
    # which result in the smallest amount of pieces containing these three colors.
    corner_colors = [piece_colors[side] for piece_colors in eachrow(puzzle.pieces) for side = 1:4 if count(isequal(0), piece_colors) == 2]
    c1 = findmin(count(isequal(color), corner_colors) for color = 1:5)[2]
    _, c2, c3 = findmin(collect((count(any(color in (c1, c2, c3) for color in piece_colors) for piece_colors in eachrow(puzzle.pieces)), c2, c3) for c2 = 6:21 for c3 = c2+1:22))[1]
    prioritized_colors = [c1, c2, c3]
    # prioritized_colors = [5, 15, 19]  # 94 pieces, 122 sides total
    # prioritized_colors = [5, 20, 21]  # 94 pieces, 120 sides total, 3 sides already part of the starter-piece
    @info prioritized_colors

    # Parameters for the amount of allowed errors dependent on the number of placed pieces
    K = 480 - solver.target_score; B = 0.24; M = 225; nu = 3.8

    # The order in which pieces are placed during the search has a significant influence on
    # the efficiency. Ideally the pieces should be placed in such a way that the search tree
    # becomes smallest, i.e. the next considered position should be the one with the least
    # matching piece candidates. However, for performance reasons it is not feasible to
    # calculate the best next position after each step, therefore a fixed search order is
    # used instead. Starting with position number 1 for the top-left corner and continuing
    # in row-major ordering (run `permutedims(reshape(1:256, 16, 16))` to visualize), a
    # position number is assigned to each cell of the puzzle board. The following list of
    # position numbers defines the search order. Note that the pre-placed starter-piece at
    # position 136 is included at the start of the list and the search is started at an
    # initial depth of 2 to account for that.
    search_order = [
        136, 256, 255, 254, 253, 252, 251, 250, 249, 248, 247, 246, 245, 244, 243, 242, 241,
        240, 239, 238, 237, 236, 235, 234, 233, 232, 231, 230, 229, 228, 227, 226, 225, 224,
        223, 222, 221, 220, 219, 218, 217, 216, 215, 214, 213, 212, 211, 210, 209, 208, 207,
        206, 205, 204, 203, 202, 201, 200, 199, 198, 197, 196, 195, 194, 193, 192, 191, 190,
        189, 188, 187, 186, 185, 184, 183, 182, 181, 180, 179, 178, 177, 176, 175, 174, 173,
        172, 171, 170, 169, 168, 167, 166, 165, 164, 163, 162, 161, 160, 159, 158, 157, 156,
        155, 154, 153, 152, 151, 150, 149, 148, 147, 146, 145, 144, 143, 142, 141, 140, 139,
        138, 137, 135, 134, 133, 132, 131, 130, 129, 128, 127, 126, 125, 124, 123, 122, 121,
        120, 119, 118, 117, 116, 115, 114, 113, 112, 111, 110, 109, 108, 107, 106, 105, 104,
        103, 102, 101, 100,  99,  98,  97,  96,  95,  94,  93,  92,  91,  90,  89,  88,  87,
         86,  85,  84,  83,  82,  81,  80,  79,  78,  77,  76,  75,  74,  73,  72,  71,  70,
         69,  68,  67,  66,  65,  64,  48,  32,  16,  63,  47,  31,  15,  62,  46,  30,  14,
         61,  45,  29,  13,  60,  44,  28,  12,  59,  43,  27,  11,  58,  42,  26,  10,  57,
         41,  25,   9,  56,  40,  24,   8,  55,  39,  23,   7,  54,  38,  22,   6,  53,  37,
         21,   5,  52,  51,  50,  49,  36,  20,   4,  35,  34,  33,  19,   3,  18,  17,   2,
          1
    ]

    @assert length(search_order) == length(unique(search_order)) == 256

    prioritized_sides = [count(color in prioritized_colors for color in piece_colors) for piece_colors in eachrow(puzzle.pieces)]
    # max_prioritized_sides = sum(prioritized_sides) + div(solver.target_score, 5) - 100
    max_prioritized_sides = sum(prioritized_sides) - 6
    prioritized_pieces = [piece for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces)) if any(color in prioritized_colors for color in piece_colors)]

    # Add one more row/column at the bottom and the right edge of the board, filled with
    # only the border color. Then the side color constraints for the pieces on row/column 16
    # can be obtained by indexing the 17th row/column and without the need to have a special
    # case for these edge pieces in the code. Furthermore a special value is assigned to the
    # border sides of the corner pieces, so that the corner pieces are automatically placed
    # at the correct positions and no special casing for them is required within the loops.
    board = fill(0x0002, 17, 17)
    board[17, 2:15] .= 0x0001  # non-corner sides
    board[2:15, 17] .= 0x0001  # non-corner sides
    available = fill(true, 256)
    next_idx = ones(Int, 256)
    cumulative_errors = zeros(Int, 256)

    iters = 0  # only the number of piece placements is counted, i.e. half of the total loop iterations
    restarts = 0
    best_score = 0

    # Precompute the row/column position for each search depth, as well as the amount of
    # required placed sides with the prioritized colors (for the first half) and allowed
    # errors (for the second half)
    position_data = [_position_data(position, depth, max_prioritized_sides, K, B, M, nu) for (depth, position) in enumerate(search_order)]::Vector{NTuple{3, Int}}
    min_error_depths = findall(>(0), diff([pos[3] for pos in position_data[129:256]])) .+ 129
    @info min_error_depths

    _display_board(puzzle, clear=false)

    while best_score < solver.target_score

        # ======================== Phase 1: bottom half of the board =======================

        # In this phase the bottom half of the board is filled with pieces in such a way
        # that an unequal color distribution is created, i.e. try to eliminate certain
        # colors early so that the remaining pieces for the upper half fit together better.
        # The pieces from the bottom half are then considered to be fixed, which allows to
        # eliminate them from the lookup tables for the candidate pieces of the second
        # phase. The backtracking search in phase 1 continues until a higher depth is
        # reached, to ensure that at least a required amount of pieces can be placed without
        # errors.

        @label restart

        board[1:16, 1:16] .= EMPTY
        board[9, 8] = STARTER_PIECE << 2 | 2
        fill!(available, true); available[STARTER_PIECE] = false
        fill!(next_idx, 1)

        placed_sides = count(puzzle.pieces[STARTER_PIECE, side] in prioritized_colors for side in 1:4)
        candidates, index_table = _prepare_candidates_table(puzzle, available, true; prioritized_pieces)

        depth = 2
        last_restart = iters

        @inbounds while depth < min_error_depths[1]
            row, col, min_placed_sides = position_data[depth]
            value = board[row, col]
            if value != EMPTY
                piece = value >> 2
                available[piece] = true
                board[row, col] = EMPTY
                placed_sides -= prioritized_sides[piece]
            end
            piece_found = false
            right = colors[board[row, col + 1], 2]
            bottom = colors[board[row + 1, col], 1]
            start_index, end_index, _ = index_table[right, bottom]
            for idx = max(next_idx[depth], start_index):end_index
                value = candidates[idx]
                piece = value >> 2
                available[piece] || continue
                piece_sides = prioritized_sides[piece]
                placed_sides + piece_sides >= min_placed_sides || continue
                if (row, col) == (10, 8)
                    piece > 60 && colors[value, 1] == STARTER_PIECE_BOTTOM_COLOR || continue
                elseif (row, col) == (9, 9)
                    piece > 60 && colors[value, 2] == STARTER_PIECE_RIGHT_COLOR || continue
                end
                board[row, col] = value
                available[piece] = false
                placed_sides += piece_sides
                next_idx[depth] = idx + 1
                iters += 1
                depth += 1
                piece_found = true
                break
            end
            if !piece_found
                # Usually it should take less than a second to fill the first half of the
                # board, but sometimes this phase gets "stuck" while searching for a valid
                # arrangement containing the pieces with the prioritized colors. To avoid
                # this case, restart if the loop iterations exceed 2*2e8.
                if iters - last_restart > 200_000_000
                    @goto restart
                end
                next_idx[depth] = 1
                depth -= 1
                depth == 1 && error("Could not fill bottom half with prioritized colors")
            end
        end

        # ========================= Phase 2: top half of the board =========================

        # Now the pieces on the bottom half of the board are fixed and the lookup table is
        # recomputed with only the remaining pieces. During this phase it is allowed to
        # place a piece even if there is one mismatched side (error), provided that the
        # total amount of errors is smaller than an upper bound, which depends on the number
        # of placed pieces.

        fill!(available, true)
        board[1:8, 1:16] .= EMPTY
        for col = 1:16, row = 9:16
            available[board[row, col] >> 2] = false
        end

        candidates, index_table = _prepare_candidates_table(puzzle, available, false)

        depth = 129
        fill!(cumulative_errors, 0)
        fill!(next_idx, 1)

        row, col, max_errors = position_data[depth]
        right = colors[board[row, col + 1], 2]
        bottom = colors[board[row + 1, col], 1]
        start_idx, end_idx1, end_idx2 = index_table[right, bottom]

        # This is the main backtracking loop; it should be as fast as possible, i.e. avoid
        # allocations, function calls and unnecessary operations.
        @inbounds while depth > 128
            errors = cumulative_errors[depth]
            @label next_iter
            for idx = start_idx:end_idx1
                value = candidates[idx]
                piece = value >> 2
                available[piece] || continue
                board[row, col] = value
                available[piece] = false
                next_idx[depth] = idx + 1
                score = 2 * depth - errors - 32
                if score > best_score
                    best_score = score
                    puzzle.board[:, :] = board[1:16, 1:16]
                    _display_board(puzzle, iters, restarts)
                    depth == 256 && return
                end
                depth += 1
                cumulative_errors[depth] = errors
                row, col, max_errors = position_data[depth]
                right = colors[board[row, col + 1], 2]
                bottom = colors[board[row + 1, col], 1]
                start_idx, end_idx1, end_idx2 = index_table[right, bottom]
                iters += 1
                @goto next_iter
            end
            if errors < max_errors
                for idx = start_idx:end_idx2
                    value = candidates[idx]
                    piece = value >> 2
                    available[piece] || continue
                    board[row, col] = value
                    available[piece] = false
                    next_idx[depth] = idx + 1
                    depth += 1
                    errors += 1
                    cumulative_errors[depth] = errors
                    row, col, max_errors = position_data[depth]
                    right = colors[board[row, col + 1], 2]
                    bottom = colors[board[row + 1, col], 1]
                    start_idx, end_idx1, end_idx2 = index_table[right, bottom]
                    iters += 1
                    @goto next_iter
                end
            end
            depth -= 1
            row, col, max_errors = position_data[depth]
            right = colors[board[row, col + 1], 2]
            bottom = colors[board[row + 1, col], 1]
            _, end_idx1, end_idx2 = index_table[right, bottom]
            start_idx = next_idx[depth]
            available[board[row, col] >> 2] = true
        end
        restarts += 1
        _display_board(puzzle, iters, restarts)
    end

    nothing
end


# Precompute a lookup table to quickly obtain the piece candidates which satisfy given color
# constraints for the right side (first index) and bottom side (second index). Note that
# mismatched colors between the frame pieces (color numbers 1 to 5) are not allowed, because
# there are only 5 different frame colors (4 if one color was already eliminated), so the
# frame pieces are expected to tile relatively well.
function _prepare_candidates_table(
    puzzle::Eternity2Puzzle,
    available::Vector{Bool},
    first_phase::Bool;
    prioritized_pieces::Vector{Int} = Int[]
)
    bottom_colors = first_phase ? NCOLORS + 1 : NCOLORS - 1
    candidates_table = [UInt16[] for _ in 1:NCOLORS+1, _ in 1:bottom_colors, _ in 1:2]

    # The total amount of edges with that color over the remaining pieces
    # color_frequency = zeros(Int, NCOLORS)

    for (piece, colors) in enumerate(eachrow(replace(puzzle.pieces, 0=>BORDER_COLOR)))
        available[piece] || continue
        if count(isequal(BORDER_COLOR), colors) == 2
            replace!(colors, BORDER_COLOR=>BORDER_COLOR2)
        end
        for rotation = 0:3
            value = piece << 2 | rotation
            right = colors[mod1(2 - rotation, 4)]
            bottom = colors[mod1(3 - rotation, 4)]
            # color_frequency[right] += 1
            if first_phase
                push!(candidates_table[right, bottom, 1], value)
            else
                bottom == BORDER_COLOR && continue
                bottom == BORDER_COLOR2 && continue
                push!(candidates_table[right, bottom, 1], value)
                # Consider pieces with one wrong color, except for the frame colors 1..5
                if right in INNER_COLORS
                    for idx in INNER_COLORS
                        idx == right && continue
                        push!(candidates_table[idx, bottom, 2], value)
                    end
                end
                if bottom in INNER_COLORS
                    for idx in INNER_COLORS
                        idx == bottom && continue
                        push!(candidates_table[right, idx, 2], value)
                    end
                end
            end
        end
    end

    total_candidates = 0
    for idx in eachindex(candidates_table)
        len = length(candidates_table[idx])
        total_candidates += len
        if first_phase && len > 1
            shuffle!(candidates_table[idx])
            for i = 2:len
                if candidates_table[idx][i] >> 2 in prioritized_pieces
                    pushfirst!(candidates_table[idx], popat!(candidates_table[idx], i))
                end
            end
        end
    end

    # The array of piece candidate lists is converted to a vector holding all candidates and
    # an index table with the start and end indices into this vector. Furthermore the
    # inexact matches for given color constraints are ordered directly after the exact
    # matches to improve memory locality. The tuple values of the index table are the start
    # index, the end index for the exactly matching pieces, and the end index for the partly
    # matching pieces.
    candidates = Vector{UInt16}(undef, total_candidates)
    index_table = Matrix{NTuple{3, Int}}(undef, NCOLORS+1, bottom_colors)
    idx = 1
    for right = 1:NCOLORS+1, bottom = 1:bottom_colors
        idx1 = idx
        for candidate in candidates_table[right, bottom, 1]
            candidates[idx] = candidate
            idx += 1
        end
        idx2 = idx - 1
        for candidate in candidates_table[right, bottom, 2]
            candidates[idx] = candidate
            idx += 1
        end
        idx3 = idx - 1
        index_table[right, bottom] = (idx1, idx2, idx3)
    end

    return (candidates, index_table)
end


function _position_data(
    position::Int,
    depth::Int,
    max_prioritized_sides::Int,
    K::Int,
    B::Float64,
    M::Int,
    nu::Float64
)
    row, col = fldmod1(position, 16)
    val = if depth > 128
        # maximum amount of allowed errors
        floor(Int, (K + 1)/(1 + exp(-B * (depth - M - K)))^(1/nu))
    else
        # minimum amount of sides with the prioritized colors
        floor(Int, clamp((max_prioritized_sides + 300)/(1 + exp(-0.02 * (depth + 22))) - 280, 0, max_prioritized_sides))
    end
    return (row, col, val)
end


function _display_board(
    puzzle::Eternity2Puzzle,
    iters::Int = 0,
    restarts::Int = 0;
    clear::Bool = true
)
    if clear
        print("\e[19F")
        print("\e[0J")
    end
    display(puzzle)
    println("Iterations: $(round(iters/1_000_000_000, digits=2)) B    Restarts: $restarts")
end
