"""
    E2BacktrackingSearch(target_score::Int, seed::Int)

A backtracking algorithm for the original Eternity II puzzle that searches for arrangements
with a high number of matching edges, controlled by the `target_score` parameter.
"""
@kwdef struct E2BacktrackingSearch <: Eternity2Solver
    target_score::Int = 470
    seed::Int = 1
end


function solve!(puzzle::Eternity2Puzzle, solver::E2BacktrackingSearch)
    nrows, ncols = size(puzzle.board)
    npieces = size(puzzle.pieces, 1)

    @assert nrows == ncols == 16 "Incompatible board size"
    @assert npieces == 256 "Wrong number of pieces"
    @assert puzzle["I8"] == (139, 2) "Mandatory starter-piece not on square I8"
    @assert 450 <= solver.target_score <= 478 "Target score must be between 450 and 478"

    maximum_score = 480  # 2 * nrows * ncols - nrows - ncols

    @info "Parameters" solver.target_score solver.seed
    Random.seed!(solver.seed)

    # ============================== Phase 0: initialization ===============================

    # Remap the colors to consecutive numbers starting from 1, so that they can be used as
    # array indices.
    pieces, frame_colors, inner_colors = remap_piece_colors(puzzle)
    ncolors = length(frame_colors) + length(inner_colors)

    # Lookup table with the colors of the top and right edges for all pieces and rotations.
    colors = FixedSizeMatrix{UInt8}(undef, npieces << 2 | 3, 2)
    colors[0x0001, :] .= ncolors + 1  # Special value for the edge pieces
    colors[0x0002, :] .= ncolors + 2  # Special value for the corner pieces
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3, side = 1:2
        colors[piece << 2 | rotation, side] = piece_colors[mod1(side - rotation, 4)]
    end

    STARTER_PIECE_BOTTOM_COLOR = puzzle.pieces[STARTER_PIECE, 1]
    STARTER_PIECE_LEFT_COLOR = puzzle.pieces[STARTER_PIECE, 2]

    path = ["I8", "P1", "P2", "O1", "O2", "P3", "O3", "N1", "N2", "N3", "P4", "O4", "N4", "M1", "M2", "M3", "M4", "P5", "O5", "N5", "M5", "L1", "L2", "L3", "L4", "L5", "P6", "O6", "N6", "M6", "L6", "K1", "K2", "K3", "K4", "K5", "K6", "P7", "O7", "N7", "M7", "L7", "K7", "J1", "J2", "J3", "J4", "J5", "J6", "J7", "P8", "O8", "N8", "M8", "L8", "K8", "J8", "I1", "I2", "I3", "I4", "I5", "I6", "I7", "P9", "P10", "P11", "P12", "P13", "P14", "P15", "P16", "O9", "O10", "O11", "O12", "O13", "O14", "O15", "O16", "N9", "N10", "N11", "N12", "N13", "N14", "N15", "N16", "M9", "M10", "M11", "M12", "M13", "M14", "M15", "M16", "L9", "L10", "L11", "L12", "L13", "L14", "L15", "L16", "K9", "K10", "K11", "K12", "K13", "K14", "K15", "K16", "J9", "J10", "J11", "J12", "J13", "J14", "J15", "J16", "I9", "I10", "I11", "I12", "I13", "I14", "I15", "I16", "H1", "H2", "H3", "H4", "H5", "H6", "H7", "H8", "H9", "H10", "H11", "H12", "H13", "H14", "H15", "H16", "G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8", "G9", "G10", "G11", "G12", "G13", "G14", "G15", "G16", "F1", "F2", "F3", "F4", "F5", "F6", "F7", "F8", "F9", "F10", "F11", "F12", "F13", "F14", "F15", "F16", "E1", "E2", "E3", "E4", "E5", "E6", "E7", "E8", "E9", "E10", "E11", "E12", "E13", "E14", "E15", "E16", "D1", "C1", "B1", "A1", "D2", "C2", "B2", "A2", "D3", "C3", "B3", "A3", "D4", "C4", "B4", "A4", "D5", "C5", "B5", "A5", "D6", "C6", "B6", "A6", "D7", "C7", "B7", "A7", "D8", "C8", "B8", "A8", "D9", "C9", "B9", "A9", "D10", "C10", "B10", "A10", "D11", "C11", "B11", "A11", "D12", "C12", "B12", "A12", "D13", "C13", "B13", "A13", "D14", "D15", "D16", "C14", "B14", "A14", "C15", "C16", "B15", "A15", "B16", "A16"]

    @assert length(path) == 256

    # Colors which should be eliminated early
    prioritized_colors = _prioritized_colors(puzzle)
    # prioritized_colors = [5, 7, 20]  # 94 pieces, 122 sides total
    # prioritized_colors = [5, 8, 9]   # 94 pieces, 120 sides total, 3 sides already part of the starter-piece

    prioritized_sides = vec(count(in(prioritized_colors), puzzle.pieces; dims=2))
    fixed_pieces = filter(!iszero, puzzle.board) .>> 2
    preplaced_prioritized_sides = count(in(prioritized_colors), puzzle.pieces[fixed_pieces, :])
    required_prioritized_sides = sum(prioritized_sides) + div(solver.target_score, 10) - 54

    # Parameters for the amount of allowed errors dependent on the number of placed pieces
    K = maximum_score - solver.target_score; B = 0.24; M = 224; nu = 3.8

    # Add one more row/column at the bottom and the right edge of the board, filled with
    # only the border color. Then the side color constraints for the pieces on row/column 16
    # can be obtained by indexing the 17th row/column and without the need to have a special
    # case for these edge pieces in the code. Furthermore, a different border color value is
    # assigned to the border sides of the corner pieces. This automatically prevents the
    # corner pieces from being placed at the non-corner positions of the frame and ensures
    # that only corner pieces are considered for the corner positions, without the need for
    # special cases for the corner positions within the loops.
    board = FixedSizeMatrix{UInt16}(undef, nrows+1, ncols+1)
    fill!(board, 0x0002)
    board[nrows+1, 3:ncols] .= 0x0001  # non-corner sides bottom frame pieces
    board[2:nrows-1, 1] .= 0x0001  # non-corner sides left frame pieces
    available = FixedSizeVector{Bool}(undef, npieces)  # tracks which pieces are already placed on the board
    fill!(available, true)
    state = FixedSizeVector{NTuple{4, Int}}(undef, 256)  # stores the current state for each level in the search tree

    node_count = 0  # counts the total number of placed pieces, i.e. half of the loop iterations
    restarts = 0
    best_score = 0

    # Precompute the row/column position for each search depth, as well as the amount of
    # required placed sides with the prioritized colors (for the first half) and allowed
    # errors (for the second half)
    board_position = FixedSizeVector{NTuple{3, Int}}(undef, 256)
    for depth = 2:128
        row, col = _parse_position(path[depth])
        min_placed_sides = floor(Int, clamp((required_prioritized_sides + 300)/(1 + exp(-0.02 * (depth + 22))) - 280, 0, required_prioritized_sides))
        board_position[depth] = (row, col + 1, min_placed_sides)
    end
    for depth = 129:256
        row, col = _parse_position(path[depth])
        max_errors = floor(Int, (K + 1)/(1 + exp(-B * (depth - M - K)))^(1/nu))
        board_position[depth] = (row, col + 1, max_errors)
    end

    allowed_error_depths = findall(>(0), diff(last.(board_position[129:256]))) .+ 130
    @info "Heuristics" prioritized_colors=Tuple(prioritized_colors) allowed_error_depths=Tuple(allowed_error_depths)

    _print_progress(puzzle; clear=false)

    while best_score - 32 < solver.target_score

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

        board[1:nrows, 2:ncols+1] .= 0x0000
        board[9, 9] = STARTER_PIECE << 2 | 2
        fill!(available, true)
        available[STARTER_PIECE] = false

        placed_sides = preplaced_prioritized_sides
        candidates, index_table = _prepare_candidates_table(pieces, inner_colors, ncolors, available; prioritized_sides)

        depth = 2
        last_restart = node_count

        row, col, min_placed_sides = board_position[depth]
        left = colors[board[row, col-1], 2]
        bottom = colors[board[row+1, col], 1]
        start_index, end_index, _ = index_table[left, bottom]

        @inbounds while depth < allowed_error_depths[1]
            piece_found = false
            for idx = start_index:end_index
                value = candidates[idx]
                piece = value >> 2
                available[piece] || continue
                piece_sides = prioritized_sides[piece]
                placed_sides + piece_sides >= min_placed_sides || continue
                if (row, col) == (10, 9)
                    pieces[piece, mod1(1 - value & 3, 4)] == STARTER_PIECE_BOTTOM_COLOR || continue
                elseif (row, col) == (9, 8)
                    pieces[piece, mod1(2 - value & 3, 4)] == STARTER_PIECE_LEFT_COLOR || continue
                end
                board[row, col] = value
                available[piece] = false
                state[depth] = (idx + 1, end_index, placed_sides, 0)
                placed_sides += piece_sides
                depth += 1
                node_count += 1
                row, col, min_placed_sides = board_position[depth]
                left = colors[board[row, col-1], 2]
                bottom = colors[board[row+1, col], 1]
                start_index, end_index, _ = index_table[left, bottom]
                piece_found = true
                break
            end
            if !piece_found
                # Usually it shouldn't take very long to fill the first half of the board,
                # but sometimes this phase can get stuck for a long time while searching
                # for a valid arrangement with the prioritized colors. In that case it is
                # better to restart this phase, which is done here if the number of visited
                # nodes exceed 1e10.
                depth -= 1
                if depth == 1
                    error("Could not fill bottom half with prioritized colors")
                elseif node_count - last_restart > 10_000_000_000
                    restarts += 1
                    _print_progress(puzzle, node_count, restarts)
                    @goto restart
                end
                row, col, min_placed_sides = board_position[depth]
                available[board[row, col] >> 2] = true
                start_index, end_index, placed_sides, _ = state[depth]
            end
        end

        # ========================= Phase 2: top half of the board =========================

        # Now the pieces on the bottom half of the board are fixed and the lookup table is
        # recomputed with only the remaining pieces. During this phase it is allowed to
        # place a piece even if there is one mismatched side (error), provided that the
        # total amount of errors is smaller than an upper bound, which depends on the number
        # of placed pieces.

        fill!(available, true)
        board[1:8, 2:17] .= 0x0000
        available[filter(!iszero, board .>> 2)] .= false

        # Note that for this phase the order of the candidates doesn't matter, because all
        # of them are tried exhaustively before the search is restarted.
        candidates, index_table = _prepare_candidates_table(pieces, inner_colors, ncolors, available; shuffle=false, allow_errors=true)

        depth = 129

        row, col, max_errors = board_position[depth]
        left = colors[board[row, col-1], 2]
        bottom = colors[board[row+1, col], 1]
        start_index, end_index1, end_index2 = index_table[left, bottom]
        errors = 0

        # This is the main backtracking loop; it should be as fast as possible, i.e. avoid
        # allocations, function calls and unnecessary operations.
        @inbounds while depth >= 129
            @label next_iter
            for idx = start_index:end_index2
                value = candidates[idx]
                piece = value >> 2
                available[piece] || continue
                board[row, col] = value
                available[piece] = false
                state[depth] = (idx+1, end_index1, end_index2, errors)
                node_count += 1
                if idx > end_index1
                    errors += 1
                elseif 2 * depth > best_score + errors
                    best_score = 2 * depth - errors  # The actual score is 32 lower, but we can ignore the constant
                    puzzle.board[:, :] = board[1:nrows, 2:ncols+1]
                    _print_progress(puzzle, node_count, restarts)
                    depth == 256 && return
                end
                depth += 1
                row, col, max_errors = board_position[depth]
                left = colors[board[row, col-1], 2]
                bottom = colors[board[row+1, col], 1]
                start_index, end_index1, end_index2 = index_table[left, bottom]
                if errors == max_errors
                    end_index2 = end_index1
                end
                @goto next_iter
            end
            depth -= 1
            row, col, max_errors = board_position[depth]
            available[board[row, col] >> 2] = true
            start_index, end_index1, end_index2, errors = state[depth]
        end
        restarts += 1
        _print_progress(puzzle, node_count, restarts)
    end

    nothing
end


# Edge colors which should be eliminated early during the search. Returns a vector of three
# colors, with one of the frame colors 1..5 that occurs least often on the corner pieces
# (to prevent that some of the corner pieces are never used in the last side of the frame),
# and two inner colors 6..22 that result in the smallest number of pieces containing these
# three colors (so that the colors can be eliminated by using fewer pieces).
function _prioritized_colors(puzzle::Eternity2Puzzle)
    frame_colors, inner_colors = _get_colors(puzzle)
    corner_pieces = findall(isequal(2), vec(count(iszero, puzzle.pieces; dims=2)))
    c1 = argmin(color -> count(isequal(color), puzzle.pieces[corner_pieces, :]), frame_colors)
    domain = [(c2, c3) for (idx, c2) in enumerate(inner_colors[1:end-1]) for c3 = inner_colors[idx+1:end]]
    c2, c3 = argmin(c -> count(any(in((c1, c[1], c[2])), puzzle.pieces; dims=2)), domain)
    return Int[c1, c2, c3]
end


# Precompute a lookup table to quickly obtain the piece candidates which satisfy given color
# constraints for the right side (first index) and bottom side (second index). Note that
# mismatched colors between the frame pieces (color numbers 1 to 5) are not allowed, because
# there are only 5 different frame colors (4 if one color was already eliminated), so the
# frame pieces are expected to tile relatively well.
function _prepare_candidates_table(
    pieces::AbstractMatrix{UInt8},
    inner_colors::UnitRange{Int},
    ncolors::Int,
    available::AbstractVector{Bool};
    prioritized_sides::Vector{Int} = Int[],
    shuffle::Bool = true,
    allow_errors::Bool = false
)
    # For the second phase (top half of the board) we don't need to consider the edge border
    # color and corner border color for the bottom side in the lookup table.
    bottom_colors = allow_errors ? ncolors : ncolors + 2
    candidates_table = [UInt16[] for _ in 1:ncolors+2, _ in 1:bottom_colors, _ in 1:2]

    for (piece, colors) in enumerate(eachrow(pieces))
        available[piece] || continue
        for rotation = 0:3
            value = piece << 2 | rotation
            bottom = colors[mod1(3 - rotation, 4)]
            left = colors[4 - rotation]
            if allow_errors
                bottom > ncolors && continue
                push!(candidates_table[left, bottom, 1], value)
                # Consider pieces with one wrong color, except for the frame colors (frame
                # should always match exactly).
                if left in inner_colors
                    for idx in inner_colors
                        idx == left && continue
                        push!(candidates_table[idx, bottom, 2], value)
                    end
                end
                if bottom in inner_colors
                    for idx in inner_colors
                        idx == bottom && continue
                        push!(candidates_table[left, idx, 2], value)
                    end
                end
            else
                push!(candidates_table[left, bottom, 1], value)
            end
        end
    end

    prioritized_pieces = findall(!iszero, prioritized_sides)
    has_prioritized_pieces = !isempty(prioritized_pieces)

    for idx in eachindex(candidates_table)
        len = length(candidates_table[idx])
        len > 1 || continue
        if shuffle
            Random.shuffle!(candidates_table[idx])
        end
        if has_prioritized_pieces
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
    candidates = FixedSizeVector{UInt16}(undef, mapreduce(length, +, candidates_table))
    index_table = FixedSizeMatrix{NTuple{3, Int}}(undef, ncolors+2, bottom_colors)
    idx = 1
    for left = 1:ncolors+2, bottom = 1:bottom_colors
        idx1 = idx
        for candidate in candidates_table[left, bottom, 1]
            candidates[idx] = candidate
            idx += 1
        end
        idx2 = idx - 1
        for candidate in candidates_table[left, bottom, 2]
            candidates[idx] = candidate
            idx += 1
        end
        idx3 = idx - 1
        index_table[left, bottom] = (idx1, idx2, idx3)
    end

    return candidates, index_table
end
