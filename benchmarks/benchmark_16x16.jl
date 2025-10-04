using FixedSizeArrays


struct RotatedPiece
    number::UInt16
    top::UInt8
    right::UInt8
end

Broadcast.broadcastable(x::RotatedPiece) = Ref(x)


"""
A fast backtracking solver for performance testing using the pieces of the original
Eternity II puzzle.

The input argument specifies the number of pieces placed onto the board before the algorithm
stops. The constraint from the starter-piece on square I8 is ignored. The return values are
the total number of placed pieces (i.e. the visited nodes in the search tree) and the number
of million pieces placed per second.
"""
function solve(maxdepth::Int = 206)
    pieces = [0 0 1 3; 0 0 1 4; 0 0 2 3; 0 0 3 2; 0 1 6 1; 0 1 7 2; 0 1 9 1; 0 1 9 5; 0 1 12 3; 0 1 14 4; 0 1 15 2; 0 1 19 4; 0 1 19 5; 0 1 21 4; 0 2 7 1; 0 2 8 3; 0 2 10 5; 0 2 13 5; 0 2 14 2; 0 2 15 2; 0 2 16 4; 0 2 17 1; 0 2 17 5; 0 2 18 1; 0 2 21 1; 0 3 6 2; 0 3 6 3; 0 3 7 3; 0 3 8 3; 0 3 14 5; 0 3 15 2; 0 3 18 3; 0 3 19 2; 0 3 19 4; 0 3 20 5; 0 3 22 4; 0 4 8 1; 0 4 11 5; 0 4 12 5; 0 4 13 2; 0 4 13 3; 0 4 15 1; 0 4 15 2; 0 4 15 3; 0 4 16 1; 0 4 18 4; 0 4 19 4; 0 4 20 4; 0 5 6 5; 0 5 7 1; 0 5 7 2; 0 5 9 1; 0 5 14 4; 0 5 16 4; 0 5 16 5; 0 5 19 3; 0 5 20 1; 0 5 20 5; 0 5 21 2; 0 5 22 3; 6 6 9 8; 6 6 10 14; 6 7 7 11; 6 8 6 19; 6 8 8 22; 6 8 10 10; 6 8 12 7; 6 8 18 9; 6 8 22 19; 6 11 11 14; 6 11 14 17; 6 12 10 8; 6 12 15 16; 6 12 18 15; 6 12 19 11; 6 13 10 15; 6 13 13 15; 6 14 11 20; 6 14 18 11; 6 14 20 21; 6 15 13 8; 6 16 8 8; 6 16 12 16; 6 17 8 13; 6 17 9 10; 6 17 19 17; 6 17 20 18; 6 18 6 21; 6 18 9 22; 6 18 16 20; 6 19 12 17; 6 19 13 15; 6 19 13 16; 6 19 16 21; 6 19 17 10; 6 21 21 11; 6 22 16 13; 6 22 18 19; 6 22 21 9; 6 22 22 21; 7 7 17 15; 7 7 17 20; 7 7 20 13; 7 7 22 9; 7 8 16 15; 7 9 11 19; 7 9 13 19; 7 9 16 15; 7 9 20 12; 7 10 15 17; 7 10 17 15; 7 11 18 13; 7 11 18 20; 7 12 10 16; 7 12 14 17; 7 12 17 12; 7 12 22 20; 7 13 11 21; 7 14 20 17; 7 15 19 22; 7 16 10 22; 7 18 9 20; 7 18 10 13; 7 18 18 15; 7 19 17 22; 7 19 21 15; 7 20 10 9; 7 20 13 21; 7 20 16 11; 7 20 18 19; 7 21 9 18; 7 21 17 10; 7 22 10 20; 7 22 12 16; 7 22 16 11; 7 22 20 18; 8 8 18 14; 8 9 9 11; 8 9 9 12; 8 9 9 17; 8 9 13 21; 8 9 15 9; 8 9 20 17; 8 9 21 21; 8 10 11 16; 8 11 8 17; 8 11 8 22; 8 11 11 10; 8 11 15 17; 8 13 9 12; 8 13 16 22; 8 14 12 12; 8 14 12 13; 8 14 22 20; 8 16 14 14; 8 16 14 17; 8 16 22 14; 8 18 14 20; 8 18 19 9; 8 19 21 21; 8 20 9 18; 8 20 10 18; 8 22 15 12; 8 22 16 20; 9 10 11 16; 9 10 16 19; 9 12 11 11; 9 13 12 15; 9 13 13 21; 9 14 16 19; 9 14 18 20; 9 14 21 12; 9 15 15 15; 9 15 17 18; 9 16 14 21; 9 17 14 13; 9 18 10 16; 9 19 17 20; 9 19 19 15; 9 20 14 20; 9 21 12 20; 9 21 14 12; 10 10 13 19; 10 11 22 14; 10 12 13 17; 10 12 19 19; 10 13 21 14; 10 14 10 21; 10 14 11 13; 10 14 20 13; 10 15 11 11; 10 15 15 18; 10 16 12 14; 10 17 21 12; 10 17 21 22; 10 17 22 15; 10 18 12 22; 10 18 13 19; 10 18 18 18; 10 19 13 11; 10 20 21 19; 10 20 22 14; 10 21 17 13; 10 21 17 19; 10 21 20 11; 10 21 22 21; 11 11 22 14; 11 12 13 22; 11 12 19 15; 11 14 12 13; 11 14 20 15; 11 15 11 20; 11 16 19 19; 11 17 11 18; 11 17 16 22; 11 17 22 21; 11 18 13 15; 11 20 16 17; 11 21 12 16; 11 22 12 20; 11 22 21 21; 11 22 21 22; 12 12 17 22; 12 12 18 14; 12 12 20 15; 12 14 13 15; 12 14 17 17; 12 16 13 19; 12 18 14 22; 12 18 20 19; 12 19 17 18; 12 19 17 21; 13 13 13 18; 13 14 20 16; 13 16 14 16; 13 16 14 18; 13 16 17 15; 13 17 16 20; 13 18 15 22; 13 18 21 15; 13 19 14 21; 13 19 16 21; 14 15 15 17; 14 15 18 19; 14 16 22 18; 14 21 20 22; 15 15 21 22; 15 16 17 16; 15 17 16 21; 15 18 20 21; 16 16 22 19; 16 17 19 17; 17 19 20 18; 18 20 21 20; 18 22 20 22; 19 22 21 22]

    replace!(pieces, 0 => 23)
    candidates_table = [RotatedPiece[] for _ in 1:24, _ in 1:23]
    for (piece, piece_colors) in enumerate(eachrow(pieces)), rotation = 0:3
        bottom, left, top, right = circshift(piece_colors, rotation)
        if top == 23  # skip pieces of the topmost row because we won't reach that far
            continue
        elseif bottom == right == 23  # bottom-right corner
            bottom = 24
        end
        push!(candidates_table[bottom, left], RotatedPiece(piece, top, right))
    end

    maxindex = 1 + mapreduce(length, +, candidates_table) + mapreduce(!isempty, +, candidates_table)
    maxdepth += 16  # stop criterium: number of placed pieces + 16 (offset)

    candidates = FixedSizeVector{RotatedPiece}(undef, maxindex)
    index_table = FixedSizeMatrix{Int}(undef, 24, 23)
    used = FixedSizeVector{Bool}(undef, 256)
    board = FixedSizeVector{RotatedPiece}(undef, maxdepth)
    idx_state = FixedSizeVector{Int}(undef, maxdepth)

    candidates[1] = RotatedPiece(0, 0, 0)
    idx = 2
    for bottom = 1:24, left = 1:23
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
    board[1:15] .= RotatedPiece(0, 23, 0)
    board[16] = RotatedPiece(0, 24, 23)

    depth = 17
    nodes = 0
    idx = index_table[23, 23]

    t0 = time_ns()

    @inbounds begin
        @label loop
        candidate = candidates[idx]
        piece = candidate.number
        if iszero(piece)  # backtrack
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
        if depth == maxdepth
            t1 = time_ns()
            # show piece numbers on the board
            display(transpose(reshape(vcat(Int.(getfield.(board[17:maxdepth], :number)), zeros(Int, 272-maxdepth)), 16, 16))[16:-1:1, :])
            return nodes, round(1000*nodes/(t1 - t0), digits=1)
        end
        depth += 1
        idx = index_table[board[depth-16].top, candidate.right]
        @goto loop
    end
end
