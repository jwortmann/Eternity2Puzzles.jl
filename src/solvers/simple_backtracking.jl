"""
    SimpleBacktrackingSearch()
    SimpleBacktrackingSearch(seed::Integer)

A simple backtracking search which can be used with all board sizes. If there exists a
solution, this search algorithm will find it in a finite amount of time by placing pieces
one by one onto the board and backtracking if no more matching piece can be placed. Pieces
are only placed if all edge colors match exactly. The algorithm stops when a solution is
found, or if the entire search space is exhausted without finding a solution. This
implementation only works for empty boards, i.e. it cannot be used for the original
Eternity II puzzle with the mandatory starter piece at a fixed position.

# Examples

```julia
julia> puzzle = Eternity2Puzzle(:clue1)
6×6 Eternity2Puzzle with 0 pieces:
...

julia> solve!(puzzle, alg=SimpleBacktrackingSearch())
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

    nrows::Int, ncols::Int = size(puzzle)
    npieces = size(puzzle.pieces, 1)
    ncolors = border_color = length(unique(puzzle.pieces))

    @assert iszero(puzzle.board) "Initial board must be empty"
    @assert npieces >= nrows * ncols "Number of pieces is incompatible with the board dimensions"

    pieces, _, _ = remap_piece_colors(puzzle)

    colors = FixedSizeMatrix{UInt8}(undef, npieces << 2 | 3, 2)
    colors[0x0001, :] .= border_color
    colors[0x0002, :] .= border_color + 1

    _candidates = [UInt16[] for _ in 1:ncolors+1, _ in 1:ncolors+1]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        colors[piece << 2 | rotation, 1] = piece_colors[mod1(1 - rotation, 4)]
        colors[piece << 2 | rotation, 2] = piece_colors[mod1(2 - rotation, 4)]
        left = piece_colors[4 - rotation]
        bottom = piece_colors[mod1(3 - rotation, 4)]
        push!(_candidates[left, bottom], piece << 2 | rotation)
    end
    for idx in eachindex(_candidates)
        if length(_candidates[idx]) > 1
            Random.shuffle!(_candidates[idx])
        end
    end
    candidates = FixedSizeVector{UInt16}(undef, mapreduce(length, +, _candidates))
    index_table = FixedSizeMatrix{UnitRange{Int}}(undef, ncolors+1, ncolors+1)
    idx = 1
    for left = 1:ncolors+1, bottom = 1:ncolors+1
        start_idx = idx
        for candidate in _candidates[left, bottom]
            candidates[idx] = candidate
            idx += 1
        end
        end_idx = idx - 1
        index_table[left, bottom] = start_idx:end_idx
    end

    board = FixedSizeMatrix{UInt16}(undef, nrows+1, ncols+1)
    fill!(board, 0x0002)
    board[2:end-2, 1] .= 0x0001
    board[end, 3:end-1] .= 0x0001
    board[1:end-1, 2:end] .= 0x0000

    rowcol = FixedSizeVector{NTuple{2, Int}}(undef, nrows*ncols)
    idx = 1
    if ncols <= nrows  # scan rows
        for row = nrows:-1:1, col = 1:ncols
            rowcol[idx] = (row, col+1)
            idx += 1
        end
    else  # scan columns
        for col = 1:ncols, row = nrows:-1:1
            rowcol[idx] = (row, col+1)
            idx += 1
        end
    end

    available = FixedSizeVector{Bool}(undef, npieces)
    fill!(available, true)
    idx_range = FixedSizeVector{UnitRange{Int}}(undef, nrows*ncols)

    depth = 1
    best_depth = 0
    row, col = rowcol[1]
    left = colors[board[row, col-1], 2]
    bottom = colors[board[row+1, col], 1]
    _idx_range = index_table[left, bottom]

    iters = 0

    display(puzzle)
    println("Iterations: 0.00 B")

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
                print("\e[$(nrows + 3)F")
                print("\e[0J")
                display(puzzle)
                println("Iterations: $(round(iters/1_000_000_000, digits=2)) B")
                depth == nrows*ncols && return
            end
            available[candidate >> 2] = false
            idx_range[depth] = idx+1:_idx_range.stop
            depth += 1
            row, col = rowcol[depth]
            left = colors[board[row, col-1], 2]
            bottom = colors[board[row+1, col], 1]
            _idx_range = index_table[left, bottom]
            @goto next
        end
        depth -= 1
        if depth == 0
            @warn "Search finished with no valid solution found"
            return
        end
        row, col = rowcol[depth]
        available[board[row, col] >> 2] = true
        _idx_range = idx_range[depth]
    end
end
