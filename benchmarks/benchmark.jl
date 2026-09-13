using FixedSizeArrays


struct RotatedPiece
    number::UInt8
    top::UInt8
    right::UInt8
end

Broadcast.broadcastable(x::RotatedPiece) = Ref(x)


"""
A simple rowscan backtracking solver.
"""
function solve()
    # nrows = ncols = 8
    # pieces = [0 0 1 2; 0 0 2 1; 0 0 2 2; 0 0 2 3; 0 1 4 1; 0 1 5 3; 0 1 6 3; 0 1 8 1; 0 1 8 3; 0 1 10 1; 0 1 10 2; 0 1 11 1; 0 1 11 2; 0 2 4 1; 0 2 4 2; 0 2 4 3; 0 2 9 1; 0 2 9 2; 0 2 10 3; 0 3 4 2; 0 3 4 3; 0 3 5 1; 0 3 5 2; 0 3 9 1; 0 3 9 3; 0 3 10 2; 0 3 11 1; 0 3 11 3; 4 5 4 7; 4 5 10 6; 4 6 5 9; 4 6 7 5; 4 6 10 9; 4 7 4 9; 4 7 5 6; 4 8 7 11; 4 8 10 10; 4 9 6 5; 4 9 6 8; 4 10 11 8; 4 11 7 10; 4 11 8 6; 5 5 5 8; 5 5 11 10; 5 6 10 10; 5 7 5 10; 5 7 6 9; 5 8 6 6; 5 9 6 6; 5 9 8 11; 5 11 8 7; 6 6 8 11; 6 7 8 7; 6 7 11 7; 6 8 7 9; 6 9 10 7; 6 10 7 8; 7 8 9 11; 7 9 10 11; 7 10 10 8; 7 10 11 11; 7 11 9 8; 7 11 9 9; 8 8 9 11]
    # pieces = [0 0 1 3; 0 0 2 2; 0 0 2 3; 0 0 3 3; 0 1 4 1; 0 1 6 1; 0 1 7 2; 0 1 7 3; 0 1 8 1; 0 1 9 1; 0 1 10 1; 0 1 11 2; 0 1 11 3; 0 2 5 1; 0 2 5 2; 0 2 6 2; 0 2 7 3; 0 2 8 1; 0 2 9 3; 0 2 10 1; 0 3 4 3; 0 3 5 1; 0 3 5 2; 0 3 5 3; 0 3 6 1; 0 3 6 2; 0 3 7 2; 0 3 11 2; 4 4 4 7; 4 5 5 8; 4 5 6 7; 4 5 6 8; 4 5 10 10; 4 6 5 8; 4 6 10 9; 4 7 6 11; 4 7 10 11; 4 7 11 9; 4 8 6 5; 4 8 6 10; 4 8 7 6; 4 8 9 8; 4 9 9 7; 4 10 9 11; 4 11 8 10; 4 11 11 11; 5 6 5 11; 5 6 8 11; 5 7 5 9; 5 7 8 9; 5 7 9 11; 5 8 9 7; 5 10 7 6; 5 11 8 9; 6 6 7 10; 6 7 7 10; 6 7 9 8; 6 8 9 10; 6 9 9 7; 6 11 10 10; 7 10 8 8; 8 10 11 10; 9 9 9 11; 10 10 11 11]  # 19_196_125_979 nodes

    nrows = ncols = 7
    pieces = [0 0 1 2; 0 0 1 3; 0 0 2 1; 0 0 3 2; 0 1 5 1; 0 1 6 1; 0 1 6 3; 0 1 7 2; 0 1 8 2; 0 1 8 3; 0 2 4 2; 0 2 5 3; 0 2 7 2; 0 2 8 2; 0 2 8 3; 0 2 9 1; 0 2 9 3; 0 3 4 1; 0 3 4 2; 0 3 5 1; 0 3 6 1; 0 3 6 3; 0 3 8 3; 0 3 9 1; 4 4 5 8; 4 4 7 5; 4 4 7 7; 4 5 5 7; 4 5 8 5; 4 6 5 7; 4 6 7 6; 4 8 6 9; 4 8 7 7; 4 8 9 5; 4 8 9 6; 4 9 6 8; 4 9 8 5; 4 9 9 6; 5 5 8 7; 5 5 9 7; 5 6 7 7; 5 6 8 6; 5 6 9 9; 5 9 7 9; 6 7 9 8; 6 8 7 7; 6 8 8 7; 6 9 8 9; 6 9 9 7]
    # pieces = [0 0 1 2; 0 0 2 1; 0 0 2 3; 0 0 3 2; 0 1 4 3; 0 1 5 1; 0 1 5 2; 0 1 8 1; 0 1 8 3; 0 1 9 2; 0 1 9 3; 0 2 4 2; 0 2 5 2; 0 2 7 1; 0 2 7 3; 0 2 8 3; 0 2 9 1; 0 3 4 1; 0 3 6 1; 0 3 6 2; 0 3 6 3; 0 3 7 2; 0 3 8 1; 0 3 8 3; 4 4 8 6; 4 4 8 9; 4 5 5 9; 4 5 7 5; 4 5 8 6; 4 5 9 7; 4 6 4 8; 4 6 4 9; 4 6 6 9; 4 7 5 8; 4 7 6 6; 4 8 8 7; 4 9 7 6; 5 5 6 7; 5 6 5 7; 5 6 6 7; 5 7 8 6; 5 7 9 9; 5 8 9 7; 5 9 7 8; 5 9 7 9; 6 7 8 8; 6 9 9 7; 6 9 9 9; 7 8 8 8]

    npieces = size(pieces, 1)
    ncolors = maximum(pieces)
    maxdepth = (nrows + 1) * ncols
    corner_depth = nrows * ncols + 1

    replace!(pieces, 0 => ncolors + 1)
    candidates_table = [RotatedPiece[] for _ in 1:ncolors+2, _ in 1:ncolors+1]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        bottom, left, top, right = circshift(piece_colors, rotation)
        if bottom == right == ncolors + 1  # bottom-right corner
            bottom = ncolors + 2
        end
        # There is no special check for the top-left corner square which would directly
        # enforce to use a corner piece for that square, because if another edge piece gets
        # placed on that square, there won't be any matching piece left for the next square,
        # which in turn causes the algorithm to backtrack immediately and try a different
        # piece for the corner square. It turns out that this is slightly faster than having
        # an additional if-branch in the backtracking loop to directly pick a corner piece.
        push!(candidates_table[bottom, left], RotatedPiece(piece, top, right))
    end

    maxindex = 1 + mapreduce(length, +, candidates_table) + mapreduce(!isempty, +, candidates_table)

    candidates = FixedSizeVector{RotatedPiece}(undef, maxindex)
    index_table = FixedSizeMatrix{Int}(undef, ncolors+2, ncolors+1)
    used = FixedSizeVector{Bool}(undef, npieces)
    board = FixedSizeVector{RotatedPiece}(undef, maxdepth)
    idx_state = FixedSizeVector{Int}(undef, maxdepth)

    candidates[1] = RotatedPiece(0, 0, 0)
    idx = 2
    for bottom = 1:ncolors+2, left = 1:ncolors+1
        matching_candidates = candidates_table[bottom, left]
        if isempty(matching_candidates)
            index_table[bottom, left] = 1
        else
            index_table[bottom, left] = idx
            for candidate in matching_candidates
                candidates[idx] = candidate
                idx += 1
            end
            candidates[idx] = RotatedPiece(0, 0, 0)
            idx += 1
        end
    end

    fill!(used, false)
    board[1:ncols-1] .= RotatedPiece(0, ncolors+1, 0)
    board[ncols] = RotatedPiece(0, ncolors+2, ncolors+1)

    depth = ncols + 1
    nodes = 0
    idx = index_table[ncolors+1, ncolors+1]

    t0 = time_ns()

    @inbounds while true
        candidate = candidates[idx]
        piece = candidate.number
        if iszero(piece)
            depth -= 1
            used[board[depth].number] = false
            idx = idx_state[depth]
            continue
        end
        idx += 1
        if used[piece]
            continue
        end
        board[depth] = candidate
        used[piece] = true
        idx_state[depth] = idx
        nodes += 1
        if depth == maxdepth
            break
        end
        depth += 1
        idx = index_table[board[depth-ncols].top, candidate.right]
    end

    t1 = time_ns()

    display(transpose(reshape(Int.(getfield.(board[ncols+1:end], :number)), nrows, ncols))[nrows:-1:1, :])

    return nodes, round(1000*nodes/(t1 - t0), digits=1)
end
