"""
A backtracking search using pre-computed 2x2 compound pieces for the original Eternity II
puzzle.
"""
@kwdef struct E2BacktrackingSearch2x2 <: Eternity2Solver
    seed::Int = 1
end

""" 2x2 compound piece with a fixed rotation. """
struct CompoundPiece
    top::Int
    right::Int
    pieces_bitmask::UInt256
    pieces::NTuple{4, UInt16}
end

Broadcast.broadcastable(x::CompoundPiece) = Ref(x)


function solve!(puzzle::Eternity2Puzzle, solver::E2BacktrackingSearch2x2)
    @assert size(puzzle.board) == (16, 16) "This algorithm is only compatible with boad size 16x16"
    @assert puzzle["I8"] == (139, 2) "Expected starter-piece on square I8"
    @assert size(puzzle.pieces, 1) == 256 "This algorithm is only compatible with the original Eternity II pieces"

    pieces, frame_colors, inner_colors = remap_piece_colors(puzzle)

    @assert length(frame_colors) == 5 "This algorithm is only compatible with the original Eternity II pieces"
    @assert length(inner_colors) == 17 "This algorithm is only compatible with the original Eternity II pieces"

    @info "Parameters" solver.seed
    Random.seed!(solver.seed)

    # Number of border edges for each piece
    border_edges = vec(count(iszero, puzzle.pieces; dims=2))

    # Piece numbers of the corner, edge and inner pieces
    corner_pieces = findall(isequal(2), border_edges)  # 1:4
    edge_pieces = findall(isequal(1), border_edges)    # 5:60
    inner_pieces = findall(iszero, border_edges)       # 61:256

    # Exclude the pre-placed starter-piece from the list of inner pieces
    filter!(!isequal(139), inner_pieces)

    # compound_colors_unsorted = [0 0 0 0 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 0 0; 0 0 0 0 0 18 19 20 21 22 23 24 25 26 27 28 29 30 31 32 33 34 0 0; 0 0 0 0 0 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50 51 0 0; 0 0 0 0 0 52 53 54 55 56 57 58 59 60 61 62 63 64 65 66 67 68 0 0; 0 0 0 0 0 69 70 71 72 73 74 75 76 77 78 79 80 81 82 83 84 85 0 0; 86 87 88 89 90 91 92 93 94 95 96 97 98 99 100 101 102 103 104 105 106 107 0 0; 108 109 110 111 112 113 114 115 116 117 118 119 120 121 122 123 124 125 126 127 128 129 0 0; 130 131 132 133 134 135 136 137 138 139 140 141 142 143 144 145 146 147 148 149 150 151 0 0; 152 153 154 155 156 157 158 159 160 161 162 163 164 165 166 167 168 169 170 171 172 173 0 0; 174 175 176 177 178 179 180 181 182 183 184 185 186 187 188 189 190 191 192 193 194 195 0 0; 196 197 198 199 200 201 202 203 204 205 206 207 208 209 210 211 212 213 214 215 216 217 0 0; 218 219 220 221 222 223 224 225 226 227 228 229 230 231 232 233 234 235 236 237 238 239 0 0; 240 241 242 243 244 245 246 247 248 249 250 251 252 253 254 255 256 257 258 259 260 261 0 0; 262 263 264 265 266 267 268 269 270 271 272 273 274 275 276 277 278 279 280 281 282 283 0 0; 284 285 286 287 288 289 290 291 292 293 294 295 296 297 298 299 300 301 302 303 304 305 0 0; 306 307 308 309 310 311 312 313 314 315 316 317 318 319 320 321 322 323 324 325 326 327 0 0; 328 329 330 331 332 333 334 335 336 337 338 339 340 341 342 343 344 345 346 347 348 349 0 0; 350 351 352 353 354 355 356 357 358 359 360 361 362 363 364 365 366 367 368 369 370 371 0 0; 372 373 374 375 376 377 378 379 380 381 382 383 384 385 386 387 388 389 390 391 392 393 0 0; 394 395 396 397 398 399 400 401 402 403 404 405 406 407 408 409 410 411 412 413 414 415 0 0; 416 417 418 419 420 421 422 423 424 425 426 427 428 429 430 431 432 433 434 435 436 437 0 0; 438 439 440 441 442 443 444 445 446 447 448 449 450 451 452 453 454 455 456 457 458 459 0 0; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 460 461; 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 461 0]

    # Table with compound color IDs, sorted by frequency of 2x2 blocks, but ignoring the
    # contribution from the 2x2 blocks which contain the starter-piece. There are in total
    # 17*17 + 5*17 + 17*5 = 459 compound inner colors, plus the border colors for the edge
    # blocks and for the corner blocks.
    compound_colors = [
           0   0   0   0   0  31 140  85  63 137 102  88 130  62 159  74 133 109  97 169 115 128   0   0
           0   0   0   0   0  13  11   2  94 117  25  60 155   3 168 108 114 111  46  91 121 149   0   0
           0   0   0   0   0 136  21  28  20  10  52  90  64   8  24  40 106  41   5  70  67  16   0   0
           0   0   0   0   0 152  44  57  56 123 100 151 150  33   1 110 157 112  39  23   6 163   0   0
           0   0   0   0   0  42 125 126  99 132 145 144  92 160  59 129  80 164 156  26 119 127   0   0
          18 103  50 134  55 229 176 192 228 364 378 224 391 294 197 253 425 239 213 295 271 347   0   0
          75  43  89 167 143 174 371 172 207 238 219 317 306 297 417 267 237 272 266 220 376 283   0   0
           9  77  34   7  72 206 195 268 185 375 431 186 180 373 232 307 243 211 321 234 406 233   0   0
          35  82 120 154 118 212 235 173 226 287 215 304 299 314 178 179 424 262 171 326 227 411   0   0
          95  79 113 131  81 419 275 315 281 305 412 448 368 242 241 420 278 445 273 342 292 377   0   0
          36 107 105 165 122 264 276 309 339 439 434 350 444 388 366 415 450 421 257 413 416 432   0   0
         138  96 141  51 146 312 319 199 208 418 427 254 344 216 296 430 356 310 320 340 446 458   0   0
          65  53  87 170  84 256 252 357 374 367 337 454 362 380 204 203 402 435 218 397 259 423   0   0
          15  48  45  38  98 363 341 447 182 308 453 329 303 392 221 194 429 214 255 381 316 345   0   0
          29 101  12 142  61 177 190 181 230 382 311 291 403 301 198 285 231 284 298 318 336 348   0   0
          22  86  58 139  17 387 222 244 280 286 399 436 263 390 240 372 327 401 396 209 410 202   0   0
         166  71 153 162 148 351 175 201 282 404 354 394 459 265 261 379 407 443 400 200 325 457   0   0
          14  54  78 135  76 193 405 349 302 288 455 383 184 437 269 343 324 386 210 251 433 290   0   0
          30  47  68 104  49 313 217 322 196 245 293 385 346 270 408 249 248 223 328 338 274 187   0   0
          73 116  32   4 147 323 358 360 205 355 452 414 258 188 236 333 331 247 246 426 289 441   0   0
          27  93  69  19 158 191 398 395 250 330 451 365 300 389 183 449 370 384 359 352 332 369   0   0
          37 124  83  66 161 334 279 225 260 438 440 277 422 428 393 353 456 189 335 409 361 442   0   0
           0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 460 461
           0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0   0 461   0
    ]


    bit1 = UInt256(1)

    _candidates = [CompoundPiece[] for _ in 1:461, _ in 1:461, _ in 1:2]

    num_corner_blocks = 0
    num_edge_blocks = 0
    num_inner_blocks = 0

    compound_edges = zeros(Int, 461)

    @info "Generating 2x2 compound pieces"

    #  p3 p4
    #  p1 p2

    # Generate 2x2 compound pieces for the corner positions
    for p1 in corner_pieces
        p1b, p1l, p1t, p1r = pieces[p1, :]
        for p2 in edge_pieces
            p2b, p2l, p2t, p2r = pieces[p2, :]
            if p2l != p1r continue end
            for p3 in edge_pieces
                if p3 == p2 continue end
                p3l, p3t, p3r, p3b = pieces[p3, :]
                if p3b != p1t continue end
                for p4 in inner_pieces
                    v4 = view(pieces, p4, :)
                    pieces_bitmask = bit1 << (p1-1) | bit1 << (p2-1) | bit1 << (p3-1) | bit1 << (p4-1)
                    for r4 = 0:3
                        p4b, p4l, p4t, p4r = circshift(v4, r4)
                        if p4b != p2t || p4l != p3r continue end
                        push!(_candidates[compound_colors[p1b, p2b], compound_colors[p3l, p1l], 1], CompoundPiece(compound_colors[p3t, p4t], compound_colors[p4r, p2r], pieces_bitmask, (UInt16(p1 << 2 | 0), UInt16(p2 << 2 | 0), UInt16(p3 << 2 | 1), UInt16(p4 << 2 | r4))))
                        push!(_candidates[compound_colors[p2r, p4r], compound_colors[p1b, p2b], 1], CompoundPiece(compound_colors[p1l, p3l], compound_colors[p3t, p4t], pieces_bitmask, (UInt16(p2 << 2 | 1), UInt16(p4 << 2 | mod(r4+1, 4)), UInt16(p1 << 2 | 1), UInt16(p3 << 2 | 2))))
                        push!(_candidates[compound_colors[p4t, p3t], compound_colors[p2r, p4r], 1], CompoundPiece(compound_colors[p2b, p1b], compound_colors[p1l, p3l], pieces_bitmask, (UInt16(p4 << 2 | mod(r4+2, 4)), UInt16(p3 << 2 | 3), UInt16(p2 << 2 | 2), UInt16(p1 << 2 | 2))))
                        push!(_candidates[compound_colors[p3l, p1l], compound_colors[p4t, p3t], 1], CompoundPiece(compound_colors[p4r, p2r], compound_colors[p2b, p1b], pieces_bitmask, (UInt16(p3 << 2 | 0), UInt16(p1 << 2 | 3), UInt16(p4 << 2 | mod(r4+3, 4)), UInt16(p2 << 2 | 3))))
                        compound_edges[compound_colors[p1b, p2b]] += 1
                        compound_edges[compound_colors[p2r, p4r]] += 1
                        compound_edges[compound_colors[p4t, p3t]] += 1
                        compound_edges[compound_colors[p3l, p1l]] += 1
                        num_corner_blocks += 1
                    end
                end
            end
        end
    end

    # Generate 2x2 compound pieces for the edge positions
    for p1 in edge_pieces
        p1b, p1l, p1t, p1r = pieces[p1, :]
        for p2 in edge_pieces
            if p2 == p1 continue end
            p2b, p2l, p2t, p2r = pieces[p2, :]
            if p2l != p1r continue end
            for p3 in inner_pieces
                v3 = view(pieces, p3, :)
                for r3 = 0:3
                    p3b, p3l, p3t, p3r = circshift(v3, r3)
                    if p3b != p1t continue end
                    for p4 in inner_pieces
                        if p4 == p3 continue end
                        v4 = view(pieces, p4, :)
                        pieces_bitmask = bit1 << (p1-1) | bit1 << (p2-1) | bit1 << (p3-1) | bit1 << (p4-1)
                        for r4 = 0:3
                            p4b, p4l, p4t, p4r = circshift(v4, r4)
                            if p4b != p2t || p4l != p3r continue end
                            push!(_candidates[compound_colors[p1b, p2b], compound_colors[p3l, p1l], 1], CompoundPiece(compound_colors[p3t, p4t], compound_colors[p4r, p2r], pieces_bitmask, (UInt16(p1 << 2 | 0), UInt16(p2 << 2 | 0), UInt16(p3 << 2 | r3), UInt16(p4 << 2 | r4))))
                            push!(_candidates[compound_colors[p2r, p4r], compound_colors[p1b, p2b], 1], CompoundPiece(compound_colors[p1l, p3l], compound_colors[p3t, p4t], pieces_bitmask, (UInt16(p2 << 2 | 1), UInt16(p4 << 2 | mod(r4+1, 4)), UInt16(p1 << 2 | 1), UInt16(p3 << 2 | mod(r3+1, 4)))))
                            push!(_candidates[compound_colors[p4t, p3t], compound_colors[p2r, p4r], 1], CompoundPiece(compound_colors[p2b, p1b], compound_colors[p1l, p3l], pieces_bitmask, (UInt16(p4 << 2 | mod(r4+2, 4)), UInt16(p3 << 2 | mod(r3+2, 4)), UInt16(p2 << 2 | 2), UInt16(p1 << 2 | 2))))
                            push!(_candidates[compound_colors[p3l, p1l], compound_colors[p4t, p3t], 1], CompoundPiece(compound_colors[p4r, p2r], compound_colors[p2b, p1b], pieces_bitmask, (UInt16(p3 << 2 | mod(r3+3, 4)), UInt16(p1 << 2 | 3), UInt16(p4 << 2 | mod(r4+3, 4)), UInt16(p2 << 2 | 3))))
                            compound_edges[compound_colors[p1b, p2b]] += 1
                            compound_edges[compound_colors[p2r, p4r]] += 1
                            compound_edges[compound_colors[p4t, p3t]] += 1
                            compound_edges[compound_colors[p3l, p1l]] += 1
                            num_edge_blocks += 1
                        end
                    end
                end
            end
        end
    end

    # Generate 2x2 compound pieces for the inner positions (excluding the starter-piece)
    for p1 = 61:253
        if p1 == 139 continue end
        v1 = view(pieces, p1, :)
        for r1 = 0:3
            p1b, p1l, p1t, p1r = circshift(v1, r1)
            for p2 = p1+1:256
                if p2 == 139 continue end
                v2 = view(pieces, p2, :)
                for r2 = 0:3
                    p2b, p2l, p2t, p2r = circshift(v2, r2)
                    if p2l != p1r continue end
                    for p3 = p1+1:256
                        if p3 == 139 || p3 == p2 continue end
                        v3 = view(pieces, p3, :)
                        for r3 = 0:3
                            p3b, p3l, p3t, p3r = circshift(v3, r3)
                            if p3b != p1t continue end
                            for p4 = p1+1:256
                                if p4 == 139 || p4 == p2 || p4 == p3 continue end
                                v4 = view(pieces, p4, :)
                                pieces_bitmask = bit1 << (p1-1) | bit1 << (p2-1) | bit1 << (p3-1) | bit1 << (p4-1)
                                for r4 = 0:3
                                    p4b, p4l, p4t, p4r = circshift(v4, r4)
                                    if p4b != p2t || p4l != p3r continue end
                                    push!(_candidates[compound_colors[p1b, p2b], compound_colors[p3l, p1l], 1], CompoundPiece(compound_colors[p3t, p4t], compound_colors[p4r, p2r], pieces_bitmask, (UInt16(p1 << 2 | r1), UInt16(p2 << 2 | r2), UInt16(p3 << 2 | r3), UInt16(p4 << 2 | r4))))
                                    push!(_candidates[compound_colors[p2r, p4r], compound_colors[p1b, p2b], 1], CompoundPiece(compound_colors[p1l, p3l], compound_colors[p3t, p4t], pieces_bitmask, (UInt16(p2 << 2 | mod(r2+1, 4)), UInt16(p4 << 2 | mod(r4+1, 4)), UInt16(p1 << 2 | mod(r1+1, 4)), UInt16(p3 << 2 | mod(r3+1, 4)))))
                                    push!(_candidates[compound_colors[p4t, p3t], compound_colors[p2r, p4r], 1], CompoundPiece(compound_colors[p2b, p1b], compound_colors[p1l, p3l], pieces_bitmask, (UInt16(p4 << 2 | mod(r4+2, 4)), UInt16(p3 << 2 | mod(r3+2, 4)), UInt16(p2 << 2 | mod(r2+2, 4)), UInt16(p1 << 2 | mod(r1+2, 4)))))
                                    push!(_candidates[compound_colors[p3l, p1l], compound_colors[p4t, p3t], 1], CompoundPiece(compound_colors[p4r, p2r], compound_colors[p2b, p1b], pieces_bitmask, (UInt16(p3 << 2 | mod(r3+3, 4)), UInt16(p1 << 2 | mod(r1+3, 4)), UInt16(p4 << 2 | mod(r4+3, 4)), UInt16(p2 << 2 | mod(r2+3, 4)))))
                                    compound_edges[compound_colors[p1b, p2b]] += 1
                                    compound_edges[compound_colors[p2r, p4r]] += 1
                                    compound_edges[compound_colors[p4t, p3t]] += 1
                                    compound_edges[compound_colors[p3l, p1l]] += 1
                                    num_inner_blocks += 1
                                end
                            end
                        end
                    end
                end
            end
        end
    end

    # Generate 2x2 compound pieces that contain the starter-piece
    p4t, p4r, p4b, p4l = pieces[139, :]
    for p3 in inner_pieces
        v3 = view(pieces, p3, :)
        for r3 = 0:3
            p3b, p3l, p3t, p3r = circshift(v3, r3)
            if p3r != p4l continue end
            for p1 in inner_pieces
                if p1 == p3 continue end
                v1 = view(pieces, p1, :)
                for r1 = 0:3
                    p1b, p1l, p1t, p1r = circshift(v1, r1)
                    if p1t != p3b continue end
                    for p2 in inner_pieces
                        if p2 == p1 || p2 == p3 continue end
                        v2 = view(pieces, p2, :)
                        pieces_bitmask = bit1 << (p1-1) | bit1 << (p2-1) | bit1 << (p3-1) | bit1 << 138
                        for r2 = 0:3
                            p2b, p2l, p2t, p2r = circshift(v2, r2)
                            if p1r != p2l || p2t != p4b continue end
                            push!(_candidates[compound_colors[p1b, p2b], compound_colors[p3l, p1l], 2], CompoundPiece(compound_colors[p3t, p4t], compound_colors[p4r, p2r], pieces_bitmask, (UInt16(p1 << 2 | r1), UInt16(p2 << 2 | r2), UInt16(p3 << 2 | r3), UInt16(139 << 2 | 2))))
                            num_inner_blocks += 1
                        end
                    end
                end
            end
        end
    end

    @info "Number of 2x2 compound pieces" num_corner_blocks num_edge_blocks num_inner_blocks
    # @show pairs(compound_edges)

    for idx in eachindex(_candidates)
        if length(_candidates[idx]) > 1
            Random.shuffle!(_candidates[idx])
            # sort!(_candidates[idx]; by=x->compound_edges[x.top]*compound_edges[x.right], rev=true)
        end
    end

    candidates = FixedSizeVector{CompoundPiece}(undef, mapreduce(length, +, _candidates))
    index_table = FixedSizeArray{UnitRange{Int}}(undef, 461, 461, 2)
    idx = 1
    for type = 1:2, left = 1:461, bottom = 1:461
        start_idx = idx
        for candidate in _candidates[bottom, left, type]
            candidates[idx] = candidate
            idx += 1
        end
        end_idx = idx - 1
        index_table[bottom, left, type] = start_idx:end_idx
    end

    board = Matrix{CompoundPiece}(undef, 9, 9)
    fill!(board, CompoundPiece(461, 461, UInt256(0), (UInt16(0), UInt16(0), UInt16(0), UInt16(0))))
    board[2:7, 1] .= CompoundPiece(460, 460, UInt256(0), (UInt16(0), UInt16(0), UInt16(0), UInt16(0)))
    board[9, 3:8] .= CompoundPiece(460, 460, UInt256(0), (UInt16(0), UInt16(0), UInt16(0), UInt16(0)))

    used_pieces = UInt256(0)
    index_state = FixedSizeVector{UnitRange{Int}}(undef, 64)

    rowcol = [(row, col+1, (row, col) == (5, 4) ? 2 : 1) for row = 8:-1:1 for col = 1:8]

    depth = 1
    best_depth = 1
    nodes = 0

    row, col, type = rowcol[1]
    index_range = index_table[461, 461, 1]
    piece_found = false

    _print_progress(puzzle; clear=false)

    @inbounds while true
        for idx in index_range
            candidate = candidates[idx]
            if used_pieces & candidate.pieces_bitmask != 0 continue end
            board[row, col] = candidate
            nodes += 1
            if depth > best_depth
                for row = 1:8, col = 1:8
                    p1, p2, p3, p4 = board[row, col+1].pieces
                    puzzle.board[2row, 2col-1] = p1
                    puzzle.board[2row, 2col] = p2
                    puzzle.board[2row-1, 2col-1] = p3
                    puzzle.board[2row-1, 2col] = p4
                end
                _print_progress(puzzle, nodes)
                if depth == 64 return end
                best_depth = depth
            end
            used_pieces |= candidate.pieces_bitmask
            index_state[depth] = idx+1:index_range.stop
            depth += 1
            row, col, type = rowcol[depth]
            index_range = index_table[board[row+1, col].top, board[row, col-1].right, type]
            piece_found = true
            break
        end
        if !piece_found
            depth -= 1
            if depth == 0 return end
            row, col, type = rowcol[depth]
            used_pieces ⊻= board[row, col].pieces_bitmask
            index_range = index_state[depth]
        else
            piece_found = false
        end
    end
end
