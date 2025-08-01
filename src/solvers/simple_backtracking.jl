"""
    SimpleBacktrackingSearch()
    SimpleBacktrackingSearch(; seed::Int=1, slip_array::Vector{Int}=[], exhaustive_search::Bool=false)

A simple backtracking search that can be used with arbitrary board sizes. Pre-placed pieces
on the board are considered to be additional constraints for a valid solution. This search
algorithm places pieces one after another onto the board and backtracks if no more matching
piece can be placed.

# Examples

```julia-repl
julia> puzzle = Eternity2Puzzle(:clue1)
6×6 Eternity2Puzzle with 0 pieces:
...

julia> solve!(puzzle; alg=SimpleBacktrackingSearch())
6×6 Eternity2Puzzle with 36 pieces, 60 matching edge pairs and 0 errors:
  26/1  28/1  31/1  10/1  13/1  14/2
  12/0   4/3  29/2   2/2  24/1   7/2
  18/0   8/2   5/2  32/0   1/3  11/2
  16/0  27/1  33/0  30/2   3/1  21/2
  20/0  35/1   6/2  19/3   9/2  25/2
  34/0  15/3  17/3  23/3  22/3  36/3
```
"""
@kwdef struct SimpleBacktrackingSearch <: Eternity2Solver
    seed::Int = 1
    slip_array::Vector{Int} = Int[]
    exhaustive_search::Bool = false
end


struct RotatedPiece
    number::Int
    rotation::Int
    top::UInt8
    right::UInt8
    invalid_joins::Int
end


function solve!(puzzle::Eternity2Puzzle, solver::SimpleBacktrackingSearch)
    @info "Solver parameters" seed=solver.seed slip_array=Tuple(solver.slip_array)
    Random.seed!(solver.seed)

    nrows, ncols = size(puzzle)
    npieces = size(puzzle.pieces, 1)
    ncolors = border_color = length(unique(puzzle.pieces))
    maxdepth = nrows * ncols

    @assert npieces >= nrows * ncols "Number of pieces is incompatible with the board dimensions"

    pieces, frame_colors_range, inner_colors_range = remap_piece_colors(puzzle)

    frame_colors = length(frame_colors_range)
    inner_colors = length(inner_colors_range)

    fixed_pieces = count(!iszero, puzzle.board)
    symmetries = symmetry_factor(puzzle)

    @info "Puzzle properties" frame_colors inner_colors fixed_pieces symmetries

    colors = FixedSizeMatrix{UInt8}(undef, npieces << 2 | 3, 2)
    colors[0x0001, :] .= border_color
    colors[0x0002, :] .= border_color + 1

    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3, side = 1:2
        colors[piece << 2 | rotation, side] = piece_colors[mod1(side - rotation, 4)]
    end

    available = FixedSizeVector{Bool}(undef, npieces)
    fill!(available, true)
    available[filter(!iszero, puzzle.board .>> 2)] .= false

    constraints = NTuple{2, UInt8}[(0x00, 0x00)]
    rowcol = FixedSizeVector{NTuple{4, Int}}(undef, maxdepth)
    depth = fixed_pieces + 1
    for row = nrows:-1:1, col = 1:ncols
        iszero(puzzle.board[row, col]) || continue
        top = 0x00
        right = 0x00
        if row > 1
            piece, rotation = puzzle[row-1, col]
            if !iszero(piece)
                top = pieces[piece, mod1(3 - rotation, 4)]
            end
        end
        if col < ncols
            piece, rotation = puzzle[row, col+1]
            if !iszero(piece)
                right = pieces[piece, 4 - rotation]
            end
        end
        constraint = findfirst(isequal((top, right)), constraints)
        if isnothing(constraint)
            push!(constraints, (top, right))
            constraint = length(constraints)
        end
        rowcol[depth] = (row, col+1, constraint, count(<=(depth), solver.slip_array))
        depth += 1
    end
    nconstraints = length(constraints)

    _candidates = [RotatedPiece[] for _ in 1:ncolors+1, _ in 1:ncolors+1, _ in 1:nconstraints]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        top, right, bottom, left = circshift(piece_colors, rotation)
        for (constraint, (t, r)) in enumerate(constraints)
            # Check whether piece candidate satisfies the constraints from adjacent pieces
            # TODO if invalid joins are allowed, also consider candidates that don't satisfy
            # the constraints but set the corresponding number of invalid joins
            if (top != t > 0) || (right != r > 0) continue end
            # Piece candidates with 0 invalid joins
            push!(_candidates[bottom, left, constraint], RotatedPiece(piece, rotation, top, right, 0))
            if !isempty(solver.slip_array)
                # Piece candidates with 1 invalid join
                if left in inner_colors_range
                    for l in inner_colors_range
                        if l == left continue end
                        push!(_candidates[bottom, l, constraint], RotatedPiece(piece, rotation, top, right, 1))
                    end
                end
                if bottom in inner_colors_range
                    for b in inner_colors_range
                        if b == bottom continue end
                        push!(_candidates[b, left, constraint], RotatedPiece(piece, rotation, top, right, 1))
                    end
                end
                # Piece candidates with 2 invalid joins
                if left in inner_colors_range && bottom in inner_colors_range
                    for l in inner_colors_range
                        if l == left continue end
                        for b in inner_colors_range
                            if b == bottom continue end
                            push!(_candidates[b, l, constraint], RotatedPiece(piece, rotation, top, right, 2))
                        end
                    end
                end
            end
        end
    end
    for idx in eachindex(_candidates)
        if length(_candidates[idx]) > 1
            Random.shuffle!(_candidates[idx])
            # Sort by number of invalid joins, in order to prefer pieces that match best.
            # Note that the random order from the shuffle is preserved between candidates
            # with the same number of invalid joins.
            sort!(_candidates[idx]; by=x->x.invalid_joins)
        end
    end
    candidates = FixedSizeVector{RotatedPiece}(undef, mapreduce(length, +, _candidates))
    index_table = FixedSizeArray{UnitRange{Int}}(undef, ncolors+1, ncolors+1, nconstraints)
    idx = 1
    for constraint = 1:nconstraints, left = 1:ncolors+1, bottom = 1:ncolors+1
        start_idx = idx
        for candidate in _candidates[bottom, left, constraint]
            candidates[idx] = candidate
            idx += 1
        end
        end_idx = idx - 1
        index_table[bottom, left, constraint] = start_idx:end_idx
    end

    board = FixedSizeMatrix{RotatedPiece}(undef, nrows+1, ncols+1)
    board[1, 1] = RotatedPiece(0, 0, border_color+1, border_color+1, 0)
    board[nrows, 1] = RotatedPiece(0, 0, border_color+1, border_color+1, 0)
    board[nrows+1, 2] = RotatedPiece(0, 0, border_color+1, border_color+1, 0)
    board[nrows+1, ncols+1] = RotatedPiece(0, 0, border_color+1, border_color+1, 0)
    for row = 2:nrows-1
        board[row, 1] = RotatedPiece(0, 0, border_color, border_color, 0)
    end
    for col = 3:ncols
        board[nrows+1, col] = RotatedPiece(0, 0, border_color, border_color, 0)
    end
    for col = 1:ncols, row = 1:nrows
        piece, rotation = puzzle[row, col]
        if iszero(piece)
            board[row, col+1] = RotatedPiece(0, 0, 0x00, 0x00, 0)
        else
            top = pieces[piece, mod1(1 - rotation, 4)]
            right = pieces[piece, mod1(2 - rotation, 4)]
            board[row, col+1] = RotatedPiece(piece, rotation, top, right, 0)
        end
    end

    idx_range = FixedSizeVector{UnitRange{Int}}(undef, maxdepth)
    invalid_joins = FixedSizeVector{Int}(undef, maxdepth)
    fill!(invalid_joins, 0)

    depth = fixed_pieces + 1
    best_depth = fixed_pieces
    current_invalid_joins = 0
    row, col, constraint, max_invalid_joins = rowcol[depth]
    _idx_range = index_table[board[row+1, col].top, board[row, col-1].right, constraint]

    nodes = 0
    solutions = 0

    _print_progress(puzzle; clear=false)

    @inbounds while true
        @label next
        for idx in _idx_range
            candidate = candidates[idx]
            if !available[candidate.number] continue end
            if current_invalid_joins + candidate.invalid_joins > max_invalid_joins
                # Piece candidates are sorted by number of invalid joins, i.e. all folling
                # candidates are also not allowed
                break
            end
            current_invalid_joins += candidate.invalid_joins
            board[row, col] = candidate
            nodes += 1
            if depth > best_depth
                best_depth = depth
                if !solver.exhaustive_search
                    for col = 1:ncols, row = 1:nrows
                        piece = board[row, col+1]
                        puzzle.board[row, col] = piece.number << 2 | piece.rotation
                    end
                    _print_progress(puzzle, nodes)
                end
                if depth == maxdepth
                    if solver.exhaustive_search
                        best_depth -= 1
                        solutions += 1
                        _print_progress(puzzle, nodes, 0, solutions; verbose=false)
                        continue
                    else
                        @info "Solution found after $nodes nodes"
                        return
                    end
                end
            end
            available[candidate.number] = false
            idx_range[depth] = idx+1:_idx_range.stop
            invalid_joins[depth] = current_invalid_joins
            depth += 1
            row, col, constraint, max_invalid_joins = rowcol[depth]
            _idx_range = index_table[board[row+1, col].top, board[row, col-1].right, constraint]
            @goto next
        end
        depth -= 1
        if depth == fixed_pieces
            if solver.exhaustive_search
                @info "Search finished with $solutions solutions after $nodes nodes"
            else
                @warn "Search finished with no valid solution found after $nodes nodes"
            end
            return
        end
        row, col = rowcol[depth]
        available[board[row, col].number] = true
        _idx_range = idx_range[depth]
        current_invalid_joins = invalid_joins[depth]
    end
end
