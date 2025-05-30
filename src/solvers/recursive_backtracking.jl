"""
    RecursiveBacktrackingSearch()
    RecursiveBacktrackingSearch(seed::Integer)

A simple recursive backtracking search which can be used with all board sizes. Pre-placed
pieces on the board won't be modified during the search. If there exists a solution, this
search algorithm will find it in a finite amount of time by placing pieces one by one onto
the board and backtracking if no more matching piece can be placed. Pieces are only placed
if all edge colors match exactly. The algorithm stops when a solution is found, or if the
entire search space is exhausted without finding a solution.

This algorithm should be able to solve smaller boards with dimensions up to 6x6, but it is
not optimized for speed and it won't get anywhere close to a full solution of the original
16x16 Eternity II board. Due to the huge search space which is explored in a depth first
search, the initial pieces that are placed on the first rows of the board are unlikely to
ever be modified later, and only a tiny and probably uninteresting fraction of the search
space is searched.

The only runtime optimization is to precompute lookup tables of the matching piece
candidates for any given color constraints. Piece candidates for a board position can be
obtained by simply indexing the table, instead of checking all pieces and rotations
individually each time.

# Examples

```julia
julia> puzzle = Eternity2Puzzle(:clue1)
6×6 Eternity2Puzzle with 0 pieces:
...

julia> solve!(puzzle, alg=RecursiveBacktrackingSearch())
6×6 Eternity2Puzzle with 36 pieces, 60 matching edges and 0 errors:
  26/1   7/1  23/1  31/1  21/1  34/2
  12/0  32/2   6/3  29/2   2/0  17/2
  10/0   4/3   3/1  33/2   8/0  15/2
  11/0   9/2  19/0  35/2  27/2  18/2
  22/0  24/1   5/3  30/0   1/2  13/2
  36/0  25/3  16/3  20/3  28/3  14/3

julia> preview(puzzle)
```
"""
@kwdef struct RecursiveBacktrackingSearch <: Eternity2Solver
    seed::Int = 1
end


function solve!(puzzle::Eternity2Puzzle, solver::RecursiveBacktrackingSearch)
    nrows, ncols = size(puzzle.board)
    npieces = size(puzzle.pieces, 1)
    @assert npieces >= nrows * ncols "Number of pieces is incompatible with the board dimensions"
    _colors = sort(unique(puzzle.pieces))
    @assert _colors[1] == 0 "Border color must be 0"
    # Remap the color numbers from 1 to ncolors, so that they can be used as array indices
    ncolors = border_color = length(_colors)
    popfirst!(_colors)
    push!(_colors, 0)
    pieces = replace(puzzle.pieces, [c => findfirst(isequal(c), _colors) for c in _colors]...)
    board = fill(0x0001, nrows + 1, ncols + 1)
    board[1:nrows, 1:ncols] = puzzle.board
    available = fill(true, npieces)

    # Convert the piece color matrix into another table with the rotation of each piece
    # being already encoded as part of the row index
    colors = Matrix{UInt8}(undef, npieces << 2 | 3, 4)
    colors[0x0001, :] .= border_color
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        idx = piece << 2 | rotation
        top = piece_colors[mod1(1 - rotation, 4)]
        right = piece_colors[mod1(2 - rotation, 4)]
        bottom = piece_colors[mod1(3 - rotation, 4)]
        left = piece_colors[mod1(4 - rotation, 4)]
        colors[idx, 1] = top
        colors[idx, 2] = right
        colors[idx, 3] = bottom
        colors[idx, 4] = left
    end
    constraints = [(0, 0), (border_color, 0), (0, border_color), (border_color, border_color)]
    for col = 1:ncols, row = 1:nrows
        value = puzzle.board[row, col]
        if value != 0x0000
            available[value >> 2] = false  # Mark pre-placed pieces as unavailable
        end
        val1 = row == 1 ? 0x0001 : board[row - 1, col]
        top = val1 == 0x0000 ? 0 : colors[val1, 3]
        val2 = col == 1 ? 0x0001 : board[row, col - 1]
        left = val2 == 0x0000 ? 0 : colors[val2, 2]
        (top, left) in constraints && continue
        push!(constraints, (top, left))
    end

    # If there are no pieces pre-placed on a square board, by convention the first corner
    # piece is placed at the bottom-right corner to eliminate rotational symmetric solutions
    if nrows == ncols && all(available)
        for piece = 1:npieces, rotation = 0:3
            idx = piece << 2 | rotation
            if colors[idx, 2] == border_color && colors[idx, 3] == border_color
                board[nrows, ncols] = idx
                available[piece] = false
                break
            end
        end
    end

    # Build a set of piece candidates tables which can be used to quickly obtain the pieces
    # that satisfy the given edge color constraints
    candidates = [UInt16[] for _ in 1:ncolors, _ in 1:ncolors, _ in 1:length(constraints)]
    for piece = 1:npieces, rotation = 0:3
        available[piece] || continue
        value = piece << 2 | rotation
        top = colors[value, 1]
        right = colors[value, 2]
        bottom = colors[value, 3]
        left = colors[value, 4]
        table_idx = findfirst(isequal((top, left)), constraints)
        isnothing(table_idx) || push!(candidates[right, bottom, table_idx], value)
        if left != border_color
            table_idx = findfirst(isequal((top, 0)), constraints)
            isnothing(table_idx) || push!(candidates[right, bottom, table_idx], value)
        end
        if top != border_color
            table_idx = findfirst(isequal((0, left)), constraints)
            isnothing(table_idx) || push!(candidates[right, bottom, table_idx], value)
        end
        if top != border_color && left != border_color
            push!(candidates[right, bottom, 1], value)
        end
    end

    Random.seed!(solver.seed)
    for idx in eachindex(candidates)
        length(candidates[idx]) > 1 || continue
        Random.shuffle!(candidates[idx])
    end

    positions = Tuple{Int, Int, Int}[]
    # Pieces are placed row by row, starting from the bottom-right corner
    for row = nrows:-1:1, col = ncols:-1:1
        board[row, col] == 0x0000 || continue
        val1 = row == 1 ? 0x0001 : board[row - 1, col]
        top = val1 == 0x0000 ? 0 : colors[val1, 3]
        val2 = col == 1 ? 0x0001 : board[row, col - 1]
        left = val2 == 0x0000 ? 0 : colors[val2, 2]
        table_idx = findfirst(isequal((top, left)), constraints)
        push!(positions, (row, col, table_idx))
    end
    # Special value at the end, which signals to stop the search when all pieces are placed
    push!(positions, (0, 0, 0))

    if _backtracking_search_recursive!(board, available, colors, candidates, positions, 1)
        puzzle.board[:, :] = board[1:nrows, 1:ncols]
    else
        @warn "Search finished with no valid solution found"
    end
    nothing
end


function _backtracking_search_recursive!(board, available, colors, candidates, positions, depth)
    row, col, table_idx = positions[depth]
    (row, col, table_idx) == (0, 0, 0) && return true
    right = colors[board[row, col + 1], 4]
    bottom = colors[board[row + 1, col], 1]

    for val in candidates[right, bottom, table_idx]
        piece = val >> 2
        available[piece] || continue
        board[row, col] = val
        available[piece] = false
        _backtracking_search_recursive!(board, available, colors, candidates, positions, depth + 1) && return true
        available[piece] = true
    end

    return false
end
