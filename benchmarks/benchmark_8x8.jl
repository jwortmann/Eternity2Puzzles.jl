using FixedSizeArrays


struct RotatedPiece
    number::UInt8
    top::UInt8
    right::UInt8
end

Broadcast.broadcastable(x::RotatedPiece) = Ref(x)


"""
A fast backtracking solver for Brendan's 8x8 puzzle.
"""
function solve(maxdepth::Int = 64)
    pieces = [0 0 1 2; 0 0 2 1; 0 0 2 2; 0 0 2 3; 0 1 4 1; 0 1 5 3; 0 1 6 3; 0 1 8 1; 0 1 8 3; 0 1 10 1; 0 1 10 2; 0 1 11 1; 0 1 11 2; 0 2 4 1; 0 2 4 2; 0 2 4 3; 0 2 9 1; 0 2 9 2; 0 2 10 3; 0 3 4 2; 0 3 4 3; 0 3 5 1; 0 3 5 2; 0 3 9 1; 0 3 9 3; 0 3 10 2; 0 3 11 1; 0 3 11 3; 4 5 4 7; 4 5 10 6; 4 6 5 9; 4 6 7 5; 4 6 10 9; 4 7 4 9; 4 7 5 6; 4 8 7 11; 4 8 10 10; 4 9 6 5; 4 9 6 8; 4 10 11 8; 4 11 7 10; 4 11 8 6; 5 5 5 8; 5 5 11 10; 5 6 10 10; 5 7 5 10; 5 7 6 9; 5 8 6 6; 5 9 6 6; 5 9 8 11; 5 11 8 7; 6 6 8 11; 6 7 8 7; 6 7 11 7; 6 8 7 9; 6 9 10 7; 6 10 7 8; 7 8 9 11; 7 9 10 11; 7 10 10 8; 7 10 11 11; 7 11 9 8; 7 11 9 9; 8 8 9 11]
    # pieces = [0 0 1 3; 0 0 2 2; 0 0 2 3; 0 0 3 3; 0 1 4 1; 0 1 6 1; 0 1 7 2; 0 1 7 3; 0 1 8 1; 0 1 9 1; 0 1 10 1; 0 1 11 2; 0 1 11 3; 0 2 5 1; 0 2 5 2; 0 2 6 2; 0 2 7 3; 0 2 8 1; 0 2 9 3; 0 2 10 1; 0 3 4 3; 0 3 5 1; 0 3 5 2; 0 3 5 3; 0 3 6 1; 0 3 6 2; 0 3 7 2; 0 3 11 2; 4 4 4 7; 4 5 5 8; 4 5 6 7; 4 5 6 8; 4 5 10 10; 4 6 5 8; 4 6 10 9; 4 7 6 11; 4 7 10 11; 4 7 11 9; 4 8 6 5; 4 8 6 10; 4 8 7 6; 4 8 9 8; 4 9 9 7; 4 10 9 11; 4 11 8 10; 4 11 11 11; 5 6 5 11; 5 6 8 11; 5 7 5 9; 5 7 8 9; 5 7 9 11; 5 8 9 7; 5 10 7 6; 5 11 8 9; 6 6 7 10; 6 7 7 10; 6 7 9 8; 6 8 9 10; 6 9 9 7; 6 11 10 10; 7 10 8 8; 8 10 11 10; 9 9 9 11; 10 10 11 11]

    replace!(pieces, 0 => 12)
    candidates_table = [RotatedPiece[] for _ in 1:13, _ in 1:13]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        bottom, left, top, right = circshift(piece_colors, rotation)
        if maxdepth <= 56 && top == 12  # skip pieces of top row if the search stops earlier
            continue
        elseif top == left == 12  # top-left corner
            left = 13
        elseif bottom == right == 12  # bottom-right corner
            bottom = 13
        end
        push!(candidates_table[bottom, left], RotatedPiece(piece, top, right))
    end

    maxindex = 1 + mapreduce(length, +, candidates_table) + mapreduce(!isempty, +, candidates_table)
    maxdepth += 8  # add offset from auxiliary row

    candidates = FixedSizeVector{RotatedPiece}(undef, maxindex)
    index_table = FixedSizeMatrix{Int}(undef, 13, 13)
    used = FixedSizeVector{Bool}(undef, 64)
    board = FixedSizeVector{RotatedPiece}(undef, maxdepth)
    idx_state = FixedSizeVector{Int}(undef, maxdepth)

    candidates[1] = RotatedPiece(0, 0, 0)
    idx = 2
    for bottom = 1:13, left = 1:13
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
    board[1:7] .= RotatedPiece(0, 12, 0)
    board[8] = RotatedPiece(0, 13, 12)

    depth = 9
    nodes = 0
    idx = index_table[12, 12]

    t0 = time_ns()

    @inbounds begin
        @label loop
        candidate = candidates[idx]
        piece = candidate.number
        if iszero(piece)
            depth -= 1
            used[board[depth].number] = false
            idx = idx_state[depth]
            @goto loop
        end
        idx += 1
        if used[piece]
            @goto loop
        end
        board[depth] = candidate
        used[piece] = true
        idx_state[depth] = idx
        nodes += 1
        if depth != maxdepth
            depth += 1
            # TODO the following ifelse is only necessary if maxdepth >= 65 (top-left corner)
            idx = index_table[board[depth-8].top, ifelse(depth == 65, 13, candidate.right)]
            @goto loop
        end
    end

    t1 = time_ns()
    display(transpose(reshape(vcat(Int.(getfield.(board[9:maxdepth], :number)), zeros(Int, 72-maxdepth)), 8, 8))[8:-1:1, :])
    return nodes, round(1000*nodes/(t1 - t0), digits=1)
end
