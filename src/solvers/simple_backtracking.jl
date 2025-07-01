"""
    SimpleBacktrackingSearch()
    SimpleBacktrackingSearch(seed::Int)

A simple backtracking search that can be used with arbitrary board sizes. Pre-placed pieces
on the board are considered to be additional constraints for a valid solution. This search
algorithm places pieces one after another onto the board and backtracks if no more matching
piece can be placed. Pieces are only placed if all edges match exactly. The algorithm stops
when a solution is found, or if the entire search space is exhausted.

# Examples

```julia-repl
julia> puzzle = Eternity2Puzzle(:clue1)
6×6 Eternity2Puzzle with 0 pieces:
...

julia> solve!(puzzle; alg=SimpleBacktrackingSearch())
6×6 Eternity2Puzzle with 36 pieces, 60 matching edges and 0 errors:
  26/1  28/1  31/1  10/1  13/1  14/2
  12/0   4/3  29/2   2/2  24/1   7/2
  18/0   8/2   5/2  32/0   1/3  11/2
  16/0  27/1  33/0  30/2   3/1  21/2
  20/0  35/1   6/2  19/3   9/2  25/2
  34/0  15/3  17/3  23/3  22/3  36/3

julia> preview(puzzle)
```
"""
@kwdef struct SimpleBacktrackingSearch <: Eternity2Solver
    seed::Int = 1
end


function solve!(puzzle::Eternity2Puzzle, solver::SimpleBacktrackingSearch)
    @info "Parameters" solver.seed
    Random.seed!(solver.seed)

    nrows, ncols = size(puzzle)
    npieces = size(puzzle.pieces, 1)
    ncolors = border_color = length(unique(puzzle.pieces))
    fixed_pieces = count(>(0), puzzle.board)
    maxdepth = nrows * ncols

    @assert npieces >= nrows * ncols "Number of pieces is incompatible with the board dimensions"

    pieces, frame_colors_range, inner_colors_range = remap_piece_colors(puzzle)

    frame_colors = length(frame_colors_range)
    inner_colors = length(inner_colors_range)

    @info "Properties" frame_colors inner_colors fixed_pieces

    colors = FixedSizeMatrix{UInt8}(undef, npieces << 2 | 3, 4)
    colors[0x0001, :] .= border_color
    colors[0x0002, :] .= border_color + 1

    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3, side = 1:4
        colors[piece << 2 | rotation, side] = piece_colors[mod1(side - rotation, 4)]
    end

    available = FixedSizeVector{Bool}(undef, npieces)
    fill!(available, true)
    for piece in filter(>(0), puzzle.board .>> 2)
        available[piece] = false
    end

    constraints = NTuple{2, Int}[(0, 0)]
    rowcol = FixedSizeVector{NTuple{3, Int}}(undef, maxdepth)
    depth = fixed_pieces + 1
    for row = nrows:-1:1, col = 1:ncols
        iszero(puzzle.board[row, col]) || continue
        right = 0
        top = 0
        if col < ncols
            right_neighbor = puzzle.board[row, col+1]
            if !iszero(right_neighbor)
                right = colors[right_neighbor, 4]
            end
        end
        if row > 1
            top_neighbor = puzzle.board[row-1, col]
            if !iszero(top_neighbor)
                top = colors[top_neighbor, 3]
            end
        end
        constraint = findfirst(isequal((right, top)), constraints)
        if isnothing(constraint)
            push!(constraints, (right, top))
            constraint = length(constraints)
        end
        rowcol[depth] = (row, col+1, constraint)
        depth += 1
    end
    nconstraints = length(constraints)

    _candidates = [UInt16[] for _ in 1:ncolors+1, _ in 1:ncolors+1, _ in 1:nconstraints]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        top, right, bottom, left = circshift(piece_colors, rotation)
        for (constraint, (r, t)) in enumerate(constraints)
            if (r == 0 || r == right) && (t == 0 || t == top)
                push!(_candidates[left, bottom, constraint], piece << 2 | rotation)
            end
        end
    end
    for idx in eachindex(_candidates)
        if length(_candidates[idx]) > 1
            Random.shuffle!(_candidates[idx])
        end
    end
    candidates = FixedSizeVector{UInt16}(undef, mapreduce(length, +, _candidates))
    index_table = FixedSizeArray{UnitRange{Int}}(undef, ncolors+1, ncolors+1, nconstraints)
    idx = 1
    for constraint = 1:nconstraints, left = 1:ncolors+1, bottom = 1:ncolors+1
        start_idx = idx
        for candidate in _candidates[left, bottom, constraint]
            candidates[idx] = candidate
            idx += 1
        end
        end_idx = idx - 1
        index_table[left, bottom, constraint] = start_idx:end_idx
    end

    board = FixedSizeMatrix{UInt16}(undef, nrows+1, ncols+1)
    fill!(board, 0x0002)
    board[2:end-2, 1] .= 0x0001
    board[end, 3:end-1] .= 0x0001
    board[1:end-1, 2:end] = puzzle.board

    idx_range = FixedSizeVector{UnitRange{Int}}(undef, maxdepth)

    depth = fixed_pieces + 1
    best_depth = fixed_pieces
    row, col, constraint = rowcol[depth]
    left = colors[board[row, col-1], 2]
    bottom = colors[board[row+1, col], 1]
    _idx_range = index_table[left, bottom, constraint]

    iters = 0

    if !displayable("image/png")
        display(puzzle)
    end
    println("Pieces: $fixed_pieces/$maxdepth   Iterations: 0.00 B")

    @inbounds while true
        @label next
        for idx in _idx_range
            candidate = candidates[idx]
            available[candidate >> 2] || continue
            board[row, col] = candidate
            iters += 1
            if depth > best_depth
                best_depth = depth
                puzzle.board[:, :] = board[1:end-1, 2:end]
                if displayable("image/png")
                    print("\e[1F\e[0J")
                else
                    print("\e[$(nrows + 3)F\e[0J")
                    display(puzzle)
                end
                println("Pieces: $depth/$maxdepth   Iterations: $(round(iters/1_000_000_000, digits=2)) B")
                if depth == maxdepth
                    @info "Solution found after $iters iterations"
                    return
                end
            end
            available[candidate >> 2] = false
            idx_range[depth] = idx+1:_idx_range.stop
            depth += 1
            row, col, constraint = rowcol[depth]
            left = colors[board[row, col-1], 2]
            bottom = colors[board[row+1, col], 1]
            _idx_range = index_table[left, bottom, constraint]
            @goto next
        end
        depth -= 1
        if depth == fixed_pieces
            @warn "Search finished with no valid solution found"
            return
        end
        row, col = rowcol[depth]
        available[board[row, col] >> 2] = true
        _idx_range = idx_range[depth]
    end
end
