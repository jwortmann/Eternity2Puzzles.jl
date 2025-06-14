const STARTER_PIECE = 139
const EMPTY = 0x0000

const board_img = PNGFiles.load(joinpath(@__DIR__, "images", "board.png"))
const colors_img = PNGFiles.load(joinpath(@__DIR__, "images", "colors.png"))

abstract type Eternity2Solver end


"""
    Eternity2Puzzle()
    Eternity2Puzzle(; starter_piece::Bool = true, hint_pieces::Bool = false)
    Eternity2Puzzle(pieces::Symbol)
    Eternity2Puzzle(pieces::String)
    Eternity2Puzzle(nrows::Int, ncols::Int)
    Eternity2Puzzle(nrows::Int, ncols::Int, pieces::Union{Symbol, String, Matrix{Int}}; board::String)


The `Eternity2Puzzle` type represents a puzzle instance consisting of the piece definitions
and the pieces configuration on the board.

The constructor can be called in different ways:

The default constructor without arguments creates a puzzle with 16 rows and 16 columns and
with the original Eternity II pieces. The keyword arguments `starter_piece` and
`hint_pieces` control whether the mandatory starter-piece and the four hint pieces from the
clue puzzles 1-4 should be pre-placed on the board. A solution or a partially filled board
can be loaded with the `board` keyword argument, which should be the filepath to a file in
`.et2` format. If a `board` is provided, the `starter_piece` and `hint_pieces` arguments are
ignored.

The board size can be adjusted by passing two integer arguments `nrows` and `ncols`.
A different set of pieces with corresponding board size can be used by passing
 - one of the predefined symbols `:meta_16x16`, `:meta_14x14`, `:meta_12x12`, `:meta_10x10`,
   `:clue1`, `:clue2`, `:clue4`
 - the filepath to a file containing the edge color numbers for the pieces as outlined in
   the README
 - or a `Matrix{Int}` in the same format (in this case `nrows` and `ncols` must also be
   given as input arguments)

The `Eternity2Puzzle` type has two fields; `board` and `pieces`. `board` contains the piece
numbers and rotations for each row/column position of the board in form of a
`Matrix{UInt16}`, where the first 14 bits in each entry represent the piece number and the
last 2 bits are used for the rotation in clockwise direction. By convention the value `0` is
used for empty positions on the board. `pieces` is a `Matrix{UInt8}` with rows containing
the four color numbers for all of the pieces.

The piece number and rotation at a given row and column on the board can also be obtained as
a tuple of two integers by indexing the `Eternity2Puzzle` type directly. For example, the
number and rotation of the pre-placed starter-piece on square I8 (row 9, column 8) of the
original Eternity II puzzle are:

# Examples

```julia
julia> puzzle = Eternity2Puzzle()
16×16 Eternity2Puzzle with 1 piece:
...

julia> puzzle[9, 8]  # Get number and rotation of the piece on square I8 (row 9, column 8)
(139, 2)
```

Note that assigning and obtaining the piece values by indexing `Eternity2Puzzle` directly is
not optimized for performance, i.e. it is not recommended to be used in a hot loop.
"""
struct Eternity2Puzzle
    board::Matrix{UInt16}  # nrows x ncols
    pieces::Matrix{UInt8}  # npieces x 4
end

function Eternity2Puzzle(
    nrows::Integer,
    ncols::Integer,
    pieces::Union{Symbol, AbstractString, AbstractMatrix{<:Integer}} = :cached;
    starter_piece::Bool = true,
    hint_pieces::Bool = false,
    board::AbstractString = ""
)
    _pieces, _, _ = _get_pieces(pieces)
    npieces = size(_pieces, 1)
    @assert npieces >= nrows * ncols "Not enough pieces for given board size"
    _board = isempty(board) ? zeros(UInt16, nrows, ncols) : _load(board)
    @assert size(_board) == (nrows, ncols) "Input file incompatible with given board size"
    @assert maximum(_board .>> 2) <= npieces "Board contains invalid piece number"
    if isempty(board) && nrows == ncols == 16 && pieces == :cached
        if starter_piece
            _board[9, 8] = 139 << 2 | 2    # I8
        end
        if hint_pieces
            _board[14, 3] = 181 << 2 | 3   # N3  (Clue Puzzle 1)
            _board[3, 14] = 255 << 2 | 3   # C14 (Clue Puzzle 2)
            _board[14, 14] = 249 << 2 | 0  # N14 (Clue Puzzle 3)
            _board[3, 3] = 208 << 2 | 3    # C3  (Clue Puzzle 4)
        end
    end
    return Eternity2Puzzle(_board, _pieces)
end

function Eternity2Puzzle(
    pieces::Union{Symbol, AbstractString, AbstractMatrix{<:Integer}} = :cached;
    starter_piece::Bool = true,
    hint_pieces::Bool = false,
    board::AbstractString = ""
)
    _pieces, nrows, ncols = _get_pieces(pieces)
    npieces = size(_pieces, 1)
    if isempty(board)
        @assert nrows > 0 && ncols > 0 "Board size undefined"
        _board = zeros(UInt16, nrows, ncols)
    else
        _board = _load(board)
    end
    @assert size(_pieces, 1) >= prod(size(_board)) "Not enough pieces for given board size"
    @assert maximum(_board .>> 2) <= npieces "Board contains invalid piece number"
    if isempty(board) && nrows == ncols == 16 && pieces == :cached
        if starter_piece
            _board[9, 8] = 139 << 2 | 2    # I8
        end
        if hint_pieces
            _board[14, 3] = 181 << 2 | 3   # N3  (Clue Puzzle 1)
            _board[3, 14] = 255 << 2 | 3   # C14 (Clue Puzzle 2)
            _board[14, 14] = 249 << 2 | 0  # N14 (Clue Puzzle 3)
            _board[3, 3] = 208 << 2 | 3    # C3  (Clue Puzzle 4)
        end
    end
    return Eternity2Puzzle(_board, _pieces)
end


function Base.show(io::IO, ::MIME"text/plain", puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    placed_pieces = count(!=(0x0000), puzzle.board)
    _score, errors = score(puzzle)
    header = if _score > 0
        "$nrows×$ncols Eternity2Puzzle with $placed_pieces $(placed_pieces == 1 ? "piece" : "pieces"), $_score matching edges and $errors errors:"
    else
        "$nrows×$ncols Eternity2Puzzle with $placed_pieces $(placed_pieces == 1 ? "piece" : "pieces"):"
    end
    grid = join([join([iszero(val) ? " ---/-" : "$(lpad(val >> 2, 4))/$(val & 3)" for val in row]) for row in eachrow(puzzle.board)], "\n")
    println(io, header * "\n" * grid)
end

function Base.show(io::IO, ::MIME"image/png", puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    if nrows == ncols == 16
        img = copy(board_img)
    else
        height = 49 * nrows + 1
        width = 49 * ncols + 1
        light_gray = colorant"#615e66"
        white = colorant"#a09ea3"
        img = fill(light_gray, height, width)
        for row = 0:nrows
            img[49 * row + 1, :] .= white
        end
        for col = 0:ncols
            img[:, 49 * col + 1] .= white
        end
    end
    if !iszero(puzzle.board)
        dark_gray = colorant"#323135"
        for col = 1:ncols, row = 1:nrows
            value = puzzle.board[row, col]
            iszero(value) && continue
            piece = value >> 2
            rotation = value & 3
            x = 49 * col - 47
            y = 49 * row - 47
            c1, c2, c3, c4 = puzzle.pieces[piece, :]
            piece_img = colors_img[:, 48c1+1:48c1+48] + rotr90(colors_img[:, 48c2+1:48c2+48]) +
                rot180(colors_img[:, 48c3+1:48c3+48]) + rotl90(colors_img[:, 48c4+1:48c4+48])
            for i = 1:48
                piece_img[i, i] = dark_gray
                piece_img[i, 49-i] = dark_gray
            end
            img[y:y+47, x:x+47] = if rotation == 1
                rotr90(piece_img)
            elseif rotation == 2
                rot180(piece_img)
            elseif rotation == 3
                rotl90(piece_img)
            else
                piece_img
            end
        end
    end
    PNGFiles.save(io, img)
end


function Base.getindex(puzzle::Eternity2Puzzle, inds...)
    value = puzzle.board[inds...]
    return Int(value >> 2), value & 3
end

function Base.setindex!(puzzle::Eternity2Puzzle, value::UInt16, inds...)
    puzzle.board[inds...] = value
end

function Base.setindex!(puzzle::Eternity2Puzzle, value::Tuple{Integer, Integer}, inds...)
    puzzle.board[inds...] = value[1] << 2 | value[2]
end

Base.size(puzzle::Eternity2Puzzle) = size(puzzle.board)
Base.size(puzzle::Eternity2Puzzle, dim::Integer) = size(puzzle.board, dim)

Base.in(piece::Integer, puzzle::Eternity2Puzzle) = piece in puzzle.board .>> 2


"""
    preview(puzzle::Eternity2Puzzle)

Open a preview image of the puzzle board.
"""
function preview(puzzle::Eternity2Puzzle)
    maximum(puzzle.pieces) <= 22 || error("Cannot preview puzzle with given color patterns. Highest color number must not exceed 22.")
    filepath = joinpath(@get_scratch!("eternity2"), "preview.png")
    open(filepath, "w") do file
        show(file, "image/png", puzzle)
    end
    command = @static Sys.iswindows() ? `powershell.exe start $filepath` : `open $filepath`
    run(command)
    nothing
end


function find(puzzle::Eternity2Puzzle, piece::Integer)
    nrows, ncols = size(puzzle)
    for col = 1:ncols, row = 1:nrows
        if puzzle.board[row, col] >> 2 == piece
            return row, col
        end
    end
    return 0, 0
end


function _get_pieces(pieces::Symbol)
    if pieces == :cached
        cache_file = joinpath(@get_scratch!("eternity2"), "pieces.txt")
        if isfile(cache_file)
            return DelimitedFiles.readdlm(cache_file, UInt8), 16, 16
        end
        @warn "Puzzle pieces are undefined - using predefined pieces instead"
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_16x16.txt"), UInt8), 16, 16
    elseif pieces == :meta_16x16
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_16x16.txt"), UInt8), 16, 16
    elseif pieces == :meta_14x14
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_14x14.txt"), UInt8), 14, 14
    elseif pieces == :meta_12x12
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_12x12.txt"), UInt8), 12, 12
    elseif pieces == :meta_10x10
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_10x10.txt"), UInt8), 10, 10
    elseif pieces == :clue1
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "clue1.txt"), UInt8), 6, 6
    elseif pieces == :clue2
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "clue2.txt"), UInt8), 6, 12
    elseif pieces == :clue4
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "clue4.txt"), UInt8), 6, 12
    end
    error("Unknown option :$pieces")
end

function _get_pieces(filename::AbstractString)
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("No such file $path"))
    endswith(filename, ".txt") || throw(ArgumentError("Unsupported file format"))
    pieces_nrows_ncols = try
        (DelimitedFiles.readdlm(path, UInt8), 0, 0)
    catch  # The file probably contains a header line
        nrows, ncols = [parse(Int, n) for n in split(readline(path))]  # Header line
        (DelimitedFiles.readdlm(path, UInt8, skipstart=1), nrows, ncols)
    end
    @assert size(pieces_nrows_ncols[1], 2) == 4 "Unexpected number of columns in file $filename"
    return pieces_nrows_ncols
end

_get_pieces(pieces::AbstractMatrix{<:Integer}) = (pieces, 0, 0)


function _load(filename::AbstractString)
    endswith(filename, ".et2") || throw(ArgumentError("Unsupported file format"))
    if !isabspath(filename)
        filename = abspath(pwd(), filename)
    end
    isfile(filename) || throw(ArgumentError("File not found: $filename"))
    parsed = DelimitedFiles.readdlm(filename, String)
    nrows, ncols = size(parsed)
    npieces = nrows * ncols
    board = zeros(UInt16, nrows, ncols)
    pieces = UInt16[]
    for col = 1:ncols, row = 1:nrows
        parsed[row, col] == "---/-" && continue
        values = split(parsed[row, col], "/")
        piece = parse(UInt16, values[1])
        rotation = parse(UInt16, values[2])
        piece in 0:npieces || error("Invalid piece number $piece at row $row, column $col")
        rotation in 0:3 || error("Invalid rotation $rotation at row $row, column $col")
        piece in pieces && error("Board contains duplicate piece number $piece")
        push!(pieces, piece)
        board[row, col] = piece << 2 | rotation
    end
    if nrows == ncols == 16 && board[9, 8] != STARTER_PIECE << 2 | 2
        @warn "Starter-piece not correctly placed"
    end
    return board
end


"""
    load!(puzzle::Eternity2Puzzle, filename::AbstractString)

Load the pieces on the board from a file in `.et2` format.

Note that the board dimensions of the given `Eternity2Puzzle` must be compatible with the
amount of rows and columns in the input file.

See also [`save`](@ref).
"""
function load!(puzzle::Eternity2Puzzle, filename::AbstractString)
    board = _load(filename)
    @assert size(puzzle) == size(board) "Incompatible board dimensions"
    puzzle.board[:, :] = board
    nothing
end


"""
    save(puzzle::Eternity2Puzzle, filename::AbstractString)

Save the board of a given `Eternity2Puzzle` to a file in `.et2` format.

See also [`load!`](@ref).
"""
function save(puzzle::Eternity2Puzzle, filename::AbstractString)
    open(filename, "w") do file
        write(file, join([join([iszero(val) ? " ---/-" : "$(lpad(val >> 2, 4))/$(val & 3)" for val in row]) for row in eachrow(puzzle.board)], "\n"))
    end
    nothing
end


"""
    initialize_pieces(filename::AbstractString)

Load the puzzle pieces from an input file, which must be in plain text (.txt) format and
contain rows with the four colors for each piece. See the package README file for details.
"""
function initialize_pieces(filename::AbstractString)
    pieces, _, _ = _get_pieces(filename)
    DelimitedFiles.writedlm(joinpath(@get_scratch!("eternity2"), "pieces.txt"), pieces)
    nothing
end


"""
    reset!(puzzle::Eternity2Puzzle)

Clear all pieces from the board (except for the starter-piece in case of the 16×16 board).
"""
function reset!(puzzle::Eternity2Puzzle; starter_piece::Bool = true)
    fill!(puzzle.board, 0x0000)
    nrows, ncols = size(puzzle.board)
    if starter_piece && nrows == ncols == 16
        puzzle.board[9, 8] = STARTER_PIECE << 2 | 2
    end
    puzzle
end


"""
    score(puzzle::Eternity2Puzzle)

Return the number of matching and non-matching edge pairs on the board.
"""
function score(puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    npieces = nrows * ncols
    matching_edges = 0
    errors = 0
    for col = 1:ncols-1, row = 1:nrows-1
        val1 = puzzle.board[row, col]
        p1, r1 = val1 >> 2, val1 & 3
        0 < p1 <= npieces || continue
        val2 = puzzle.board[row, col + 1]
        p2, r2 = val2 >> 2, val2 & 3
        if 0 < p2 <= npieces
            if puzzle.pieces[p1, mod1(2 - r1, 4)] == puzzle.pieces[p2, 4 - r2]
                if puzzle.pieces[p2, 4 - r2] != 0x00
                    matching_edges += 1
                end
            else
                errors += 1
            end
        end
        val3 = puzzle.board[row + 1, col]
        p3, r3 = val3 >> 2, val3 & 3
        if 0 < p3 <= npieces
            if puzzle.pieces[p1, mod1(3 - r1, 4)] == puzzle.pieces[p3, mod1(1 - r3, 4)]
                if puzzle.pieces[p1, mod1(3 - r1, 4)] != 0x00
                    matching_edges += 1
                end
            else
                errors += 1
            end
        end
    end
    for col = 1:ncols-1
        val1 = puzzle.board[nrows, col]
        p1, r1 = val1 >> 2, val1 & 3
        0 < p1 <= npieces || continue
        val2 = puzzle.board[nrows, col + 1]
        p2, r2 = val2 >> 2, val2 & 3
        0 < p2 <= npieces || continue
        if puzzle.pieces[p1, mod1(2 - r1, 4)] == puzzle.pieces[p2, 4 - r2]
            if puzzle.pieces[p2, 4 - r2] != 0x00
                matching_edges += 1
            end
        else
            errors += 1
        end
    end
    for row = 1:nrows-1
        val1 = puzzle.board[row, ncols]
        p1, r1 = val1 >> 2, val1 & 3
        0 < p1 <= npieces || continue
        val2 = puzzle.board[row + 1, ncols]
        p2, r2 = val2 >> 2, val2 & 3
        0 < p2 <= npieces || continue
        if puzzle.pieces[p1, mod1(3 - r1, 4)] == puzzle.pieces[p2, mod1(1 - r2, 4)]
            if puzzle.pieces[p1, mod1(3 - r1, 4)] != 0x00
                matching_edges += 1
            end
        else
            errors += 1
        end
    end
    return matching_edges, errors
end


"""
    remap_piece_colors(puzzle::Eternity2Puzzle)

Remap and reorder the color numbers such that colors are consecutive numbers starting at 1,
with all frame color numbers first and all inner color numbers last. The border color and
another "virtual" border color for the corner pieces are appended to the end of the number
list.

While the relative orderings of the color numbers within the set of the frame colors and the
set of the inner colors are preserved, gaps between the color numbers are eliminated, so
that they can be used as array indices.

Return a new matrix for the piece definitions using the remapped color numbers, and two
`UnitRange`s for the numbers of the remapped frame colors and inner colors.
"""
function remap_piece_colors(puzzle::Eternity2Puzzle)
    frame_colors = Set{UInt8}()
    # Find the edge pieces and extract the frame colors, i.e. the sides which are adjacent
    # to the border.
    for piece_colors in eachrow(puzzle.pieces)
        if count(iszero, piece_colors) == 1
            border_edge_index = findfirst(iszero, piece_colors)
            push!(frame_colors, piece_colors[mod1(border_edge_index + 1, 4)])
            push!(frame_colors, piece_colors[mod1(border_edge_index - 1, 4)])
        end
    end
    frame_colors = sort(collect(frame_colors))
    unique_colors = sort(unique(puzzle.pieces))
    @assert unique_colors[1] == 0 "Border color must be 0"
    popfirst!(unique_colors)
    inner_colors = setdiff(unique_colors, frame_colors)
    remapped_colors = [frame_colors; inner_colors]
    push!(remapped_colors, 0)
    ncolors = length(remapped_colors)
    border_color = UInt8(ncolors)
    virtual_border_color = UInt8(ncolors + 1)
    remapped_pieces = replace(puzzle.pieces, [color => UInt8(findfirst(isequal(color), remapped_colors)) for color in remapped_colors]...)
    # Find the corner pieces and assign a different "virtual" border color value to their
    # border sides. This "trick" automatically ensures that only the corner pieces are
    # placed at the corner positions of the puzzle board, without the need for a special
    # check within the inner loop of the backtracking algorithm.
    for piece_colors in eachrow(remapped_pieces)
        if count(isequal(border_color), piece_colors) == 2
            replace!(piece_colors, border_color=>virtual_border_color)
        end
    end
    frame_colors_count = length(frame_colors)
    frame_colors_range = 1:frame_colors_count
    inner_colors_count = length(inner_colors)
    inner_colors_range = frame_colors_count+1:frame_colors_count+inner_colors_count
    return remapped_pieces, frame_colors_range, inner_colors_range
end


# Number of k-permutations of n (as Float128); perm(n, k) = n!/(n-k)!
perm(n, k) = prod(n-k+1:n; init=Float128(1.0))

# Number of k-combinations of n; comb(n, k) = n!/((n-k)!k!)
comb(n, k) = prod((n+1-i)/i for i = 1:min(k, n-k); init=1.0)


"""
    estimate_solutions(puzzle::Eternity2Puzzle)
    estimate_solutions(puzzle::Eternity2Puzzle, max_errors::Int = 0, path::Symbol = :rowscan; verbose = true)

Estimate the total number of valid solutions for a given [`Eternity2Puzzle`](@ref), based on
a probability model for edge matching puzzles developed by Brendan Owen.

Pre-placed pieces on the board are considered to be additional constraints that must be
satisfied in a solution.

If `max_errors` is given and greater than zero, a piece configuration is considered to be a
valid solution if at most `max_errors` of the inner joins don't match (all of the joins
between neighboring frame pieces are still considered to match).

If the `verbose` keyword argument is enabled, pieces are placed one after each other onto
the board, and the cumulative sum of partial solutions is printed after each step. The order
in which pieces are placed can be controlled with the `path` positional argument.
Currently implemented options are:
 - :rowscan   (fill row by row, starting from the bottom left corner)
 - :colscan   (fill column by column, starting from the bottom left corner)
 - :spiral_in (counter-clockwise starting from the bottom right corner)
Alternatively, `path` can be given as a `Vector{String}`, specifying all board positions
explicitly; for example `path = ["I8", "A1", "A2", "B1", ...]`. Hereby it is necessary that
each board position is visited exactly once, and that the positions of all pre-placed pieces
are at the start of the list.
The cumulative sum of estimated partial solutions represents the number of nodes in a search
tree that a backtracking algorithm has to visit to explore the entire tree.
The ratio between the number of full solutions and the cumulative sum of partial solutions
can be used as a measure for the difficulty of the puzzle.

Return the number of solutions as a Float128.

# Examples

Estimated number of valid solutions for the Eternity II puzzle:
```julia
julia> puzzle = Eternity2Puzzle()
16×16 Eternity2Puzzle with 1 piece:
...

julia> floor(Int, estimate_solutions(puzzle))
14702
```

Estimated number of solutions if at most 2 non-matching inner joins (score >= 478) are
allowed:
```
julia> floor(Int, estimate_solutions(puzzle, 2))
2440885684
```

# References

https://groups.io/g/eternity2/message/5209
https://groups.io/g/eternity2/message/6408
"""
function estimate_solutions(
    puzzle::Eternity2Puzzle,
    max_errors::Int = 0,
    path::Union{Symbol, Vector{String}} = :rowscan;
    verbose=false
)
    nrows, ncols = size(puzzle)

    # Number of corner, edge and inner squares on the board
    corner_squares = 4
    edge_squares = 2 * (nrows - 2) + 2 * (ncols - 2)
    inner_squares = (nrows - 2) * (ncols - 2)

    # Number of corner, edge and inner pieces
    pieces_per_type = zeros(Int, 3)
    for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces))
        border_edges = count(iszero, piece_colors)
        @assert border_edges <= 2 "Piece $piece has too many border edges"
        pieces_per_type[3 - border_edges] += 1
    end
    corner_pieces, edge_pieces, inner_pieces = pieces_per_type

    @assert corner_pieces >= corner_squares "Not enough corner pieces"
    @assert edge_pieces >= edge_squares "Not enough edge pieces"
    @assert inner_pieces >= inner_squares "Not enough inner pieces"

    # Number of pre-placed corner, edge and inner pieces
    fixed_corner_pieces, fixed_edge_pieces, fixed_inner_pieces = _count_pieces(puzzle.board)

    # Number of available (i.e. not pre-placed) corner, edge and inner pieces
    Cp = corner_pieces - fixed_corner_pieces
    Ep = edge_pieces - fixed_edge_pieces
    Ip = inner_pieces - fixed_inner_pieces

    pieces, frame_colors_range, inner_colors_range = remap_piece_colors(puzzle)

    # Number of different frame and inner color types
    frame_colors = length(frame_colors_range)
    inner_colors = length(inner_colors_range)

    # Number of frame joins and inner joins for each color
    frame_joins = Int[count(isequal(color), pieces)/2 for color in frame_colors_range]
    inner_joins = Int[count(isequal(color), pieces)/2 for color in inner_colors_range]

    # Total number of frame joins and inner joins in the given set of pieces
    Tb = sum(frame_joins)
    Tm = sum(inner_joins)

    # Number of frame joins and inner joins on the board
    total_frame_joins = 2 * (nrows - 1) + 2 * (ncols - 1)
    total_inner_joins = (nrows - 1) * (ncols - 2) + (nrows - 2) * (ncols - 1)

    @assert Tb >= total_frame_joins
    @assert Tm >= total_inner_joins

    # Precomputed table with number of k-permutations of n
    nmax = max(maximum(frame_joins), 2*maximum(inner_joins))
    kmax = min(nmax, max(total_frame_joins, 2*total_inner_joins))
    P = OffsetArrays.Origin(0)(zeros(Float128, nmax+1, kmax+1))
    for n = 0:nmax, k = 0:min(n, kmax)
        P[n, k] = perm(n, k)
    end

    # Precomputed table with number of k-combinations of n (Pascal's triangle)
    nmax = max(total_frame_joins, total_inner_joins)
    C = OffsetArrays.Origin(0)(zeros(Float128, nmax+1, nmax+1))
    for n = 0:nmax, k = 0:n
        C[n, k] = comb(n, k)
    end

    # Vb(i, b) = Number of valid configurations of b frame joins can be made using 2b edges of colors 1 to i
    Vb = OffsetArrays.Origin(0)(zeros(Float128, frame_colors+1, total_frame_joins+1))
    Vb[0, 0] = 1.0
    for i = 1:frame_colors
        n = frame_joins[i]
        for b = 0:total_frame_joins
            Vb[i, b] = sum(Vb[i-1, b-j] * P[n, j]^2 * C[b, j] for j = 0:min(n, b))
        end
    end

    # Vm(i, m) = Number of valid configurations of m inner joins can be made using 2m edges of colors 1 to i
    Vm = OffsetArrays.Origin(0)(zeros(Float128, inner_colors+1, total_inner_joins+1))
    Vm[0, 0] = 1.0
    for i = 1:inner_colors
        n = inner_joins[i]
        for m = 0:total_inner_joins
            Vm[i, m] = sum(Vm[i-1, m-j] * P[2n, 2j] * C[m, j] for j = 0:min(n, m))
        end
    end

    # pm(m, v) = Probability the first v inner joins are valid and the rest are not using 2m edges
    pm = OffsetArrays.Origin(0)(zeros(Float128, total_inner_joins+1, total_inner_joins+1))
    for m = 0:total_inner_joins
        pm[m, m] = Vm[inner_colors, m] / perm(2Tm, 2m)
        for v = m-1:-1:0
            pm[m, v] = pm[m-1, v] - pm[m, v+1]
        end
    end

    if verbose  # Estimate the number of partial solutions after each placed piece
        search_path = _create_search_path(puzzle, path)
        board = zeros(Int, nrows, ncols)

        estimated_solutions::Float128 = 1.0

        # The cumulative sum of partial solutions after each placed piece represents the
        # total number of valid board configurations for the given search path, i.e. the
        # number of nodes in the search tree for a backtracking algorithm.
        cumulative_sum::Float128 = 0.0

        for placed_pieces = 1:nrows*ncols
            square = search_path[placed_pieces]
            row, col = _parse_position(square)
            board[row, col] = placed_pieces
            if placed_pieces > fixed_corner_pieces + fixed_edge_pieces + fixed_inner_pieces
                placed_corner_pieces, placed_edge_pieces, placed_inner_pieces = _count_pieces(board)
                c = placed_corner_pieces - fixed_corner_pieces  # Number of selected corner pieces
                e = placed_edge_pieces - fixed_edge_pieces      # Number of selected edge pieces
                i = placed_inner_pieces - fixed_inner_pieces    # Number of selected inner pieces
                # Numbers of completed frame and inner joins between pieces on the board
                b, m = _count_joins(board)
                # Number of piece configurations including 4 orientations for the inner pieces
                piece_configurations = perm(Cp, c) * perm(Ep, e) * perm(Ip, i) * 4.0^i
                # Probability of all frame joins are valid
                pb = Vb[frame_colors, b] / perm(Tb, b)^2
                estimated_solutions = piece_configurations * pb * sum(pm[m, v] * C[m, v] for v = max(m-max_errors, 0):m)
            end
            cumulative_sum += estimated_solutions
            @printf "%3i  %-3s  %.5e  %.5e\n" placed_pieces square estimated_solutions cumulative_sum
        end
        return estimated_solutions
    else  # Only calculate the number of solutions for the full board
        c = corner_squares - fixed_corner_pieces
        e = edge_squares - fixed_edge_pieces
        i = inner_squares - fixed_inner_pieces
        b, m = total_frame_joins, total_inner_joins
        piece_configurations = perm(Cp, c) * perm(Ep, e) * perm(Ip, i) * 4.0^i
        pb = Vb[frame_colors, b] / perm(Tb, b)^2
        return piece_configurations * pb * sum(pm[m, v] * C[m, v] for v = m-max_errors:m)
    end
end

# Numbers of corner, edge and inner pieces on the board
function _count_pieces(board::Matrix{<:Real})
    isnonzero = x -> !iszero(x)
    corner_pieces = count(isnonzero, board[[1, end], [1, end]])
    edge_pieces = count(isnonzero, board[2:end-1, [1, end]]) + count(isnonzero, board[[1, end], 2:end-1])
    inner_pieces = count(isnonzero, board[2:end-1, 2:end-1])
    return corner_pieces, edge_pieces, inner_pieces
end

# Numbers of completed frame and inner joins between pieces on the board
function _count_joins(board::Matrix{<:Real})
    nrows, ncols = size(board)
    frame_joins = 0
    inner_joins = 0
    for row = 1:nrows-1
        if !iszero(board[row, 1]) && !iszero(board[row+1, 1])
            frame_joins += 1
        end
        if !iszero(board[row, ncols]) && !iszero(board[row+1, ncols])
            frame_joins += 1
        end
        for col = 2:ncols-1
            if !iszero(board[row, col]) && !iszero(board[row+1, col])
                inner_joins += 1
            end
        end
    end
    for col = 1:ncols-1
        if !iszero(board[1, col]) && !iszero(board[1, col+1])
            frame_joins += 1
        end
        if !iszero(board[nrows, col]) && !iszero(board[nrows, col+1])
            frame_joins += 1
        end
        for row = 2:nrows-1
            if !iszero(board[row, col]) && !iszero(board[row, col+1])
                inner_joins += 1
            end
        end
    end
    return frame_joins, inner_joins
end

_board_square(row::Int, col::Int) = ('@' + row) * string(col)            # (2, 6) -> "B6"
_parse_position(pos::String) = pos[1] - 'A' + 1, parse(Int, pos[2:end])  # "B6" -> (2, 6)

function _create_search_path(puzzle::Eternity2Puzzle, strategy::Symbol = :rowscan)
    nrows, ncols = size(puzzle)
    preplaced_pieces = [_board_square(Tuple(idx)...) for idx in eachindex(IndexCartesian(), puzzle.board) if !iszero(puzzle.board[idx])]
    if strategy == :rowscan
        path = [_board_square(row, col) for row = nrows:-1:1 for col = 1:ncols if iszero(puzzle.board[row, col])]
        return vcat(preplaced_pieces, path)
    elseif strategy == :colscan
        path = [_board_square(row, col) for col = 1:ncols for row = nrows:-1:1 if iszero(puzzle.board[row, col])]
    elseif strategy == :spiral_in
        path = String[]
        row, col = nrows, ncols  # start at bottom right corner
        vsteps, hsteps = nrows - 1, ncols - 1  # initial steps in vertical and horizontal direction
        while vsteps > 0 && hsteps > 0
            for _ = 1:vsteps  # go up
                iszero(puzzle.board[row, col]) && push!(path, _board_square(row, col))
                row -= 1
            end
            for _ = 1:hsteps  # go left
                iszero(puzzle.board[row, col]) && push!(path, _board_square(row, col))
                col -= 1
            end
            for _ = 1:vsteps  # go down
                iszero(puzzle.board[row, col]) && push!(path, _board_square(row, col))
                row += 1
            end
            for _ = 1:hsteps  # go right
                iszero(puzzle.board[row, col]) && push!(path, _board_square(row, col))
                col += 1
            end
            vsteps -= 2
            hsteps -= 2
            row -= 1
            col -= 1
        end
        return vcat(preplaced_pieces, path)
    else
        error("Unknown option :$strategy")
    end
end
_create_search_path(puzzle::Eternity2Puzzle, path::Vector{String}) = path


# For a given board position return the color constraints of all 4 edges as a vector
# [top, right, bottom, left] with UInt8 entries for the color constraints or `nothing` if
# there is no adjacent piece in that direction.
function _get_color_constraints(puzzle::Eternity2Puzzle, row::Int, col::Int)
    nrows, ncols = size(puzzle.board)
    if nrows == ncols == 16 && (row, col) == (9, 8)
        return puzzle.pieces[STARTER_PIECE, 2:-1:1]  # starter-piece has 180° rotation
    end
    if row == 1
        top = 0x00
        val = puzzle.board[row + 1, col]
        bottom = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(1 - val & 3, 4)]
    elseif row == nrows
        val = puzzle.board[row - 1, col]
        top = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(3 - val & 3, 4)]
        bottom = 0x00
    else
        val = puzzle.board[row - 1, col]
        top = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(3 - val & 3, 4)]
        val = puzzle.board[row + 1, col]
        bottom = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(1 - val & 3, 4)]
    end
    if col == 1
        left = 0x00
        val = puzzle.board[row, col + 1]
        right = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(4 - val & 3, 4)]
    elseif col == ncols
        val = puzzle.board[row, col - 1]
        left = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(2 - val & 3, 4)]
        right = 0x00
    else
        val = puzzle.board[row, col - 1]
        left = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(2 - val & 3, 4)]
        val = puzzle.board[row, col + 1]
        right = iszero(val) ? nothing : puzzle.pieces[val >> 2, mod1(4 - val & 3, 4)]
    end
    return [top, right, bottom, left]
end


"""
    generate_pieces(nrows::Integer, ncols::Integer; frame_colors::Integer, inner_colors::Integer, seed::Integer)

Generate random pieces for an `nrows`×`ncols` Eternity II style puzzle with `frame_colors`
unique frame colors and `inner_colors` unique inner colors.

Note that the amount of frame colors and inner colors have a significant influence on the
difficulty of the puzzle. For example if there are many different colors, there might only
be a single solution which is easily found because the pieces can't be combined in a lot of
different ways. Similarly, if there are only a few different colors, the number of solutions
becomes large and it will be easy to find one of them.

# Examples

```julia
julia> generate_pieces(6, 6, frame_colors=3, inner_colors=6, seed=1234)
36×4 Matrix{UInt8}:
...
```
"""
function generate_pieces(
    nrows::Integer,
    ncols::Integer;
    frame_colors::Integer = 5,
    inner_colors::Integer = 17,
    seed::Integer = 1
)
    nrows > 2 && ncols > 2 || error("The puzzle board must have at least 3 rows and columns")
    2 <= frame_colors <= 5 || error("The number of frame colors must be between 2 and 5")
    2 <= inner_colors <= 17 || error("The number of inner colors must be between 2 and 17")
    npieces = nrows * ncols

    corner_pieces_range = 1:4
    edge_pieces_range = 5:2*nrows+2*ncols-4
    inner_pieces_range = edge_pieces_range[end]+1:npieces

    frame_edges_count = 2 * (nrows + ncols) - 4
    inner_edges_count = 2 * nrows * ncols - 3 * (nrows + ncols) + 4

    pieces = Matrix{UInt8}(undef, npieces, 4)
    rotations = zeros(Int, npieces)

    he = Matrix{UInt8}(undef, nrows, ncols - 1)  # grid of horizontal edges (right/left)
    ve = Matrix{UInt8}(undef, nrows - 1, ncols)  # grid of vertical edges (top/bottom)

    frame_color_numbers = [1, 2, 3, 4, 5]  # 12 pairs of each color
    inner_color_numbers = [6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22]
    #                      |------------- 25 pairs each ------------|  |--- 24 pairs ---|

    # Generate uniform distributions of frame edge colors and inner edge colors.
    frame_edges = [frame_color_numbers[mod1(i, frame_colors)] for i = 1:frame_edges_count]
    inner_edges = [inner_color_numbers[mod1(i, inner_colors)] for i = 1:inner_edges_count]

    function validate(pieces)
        _pieces = repeat(pieces, 1, 2)
        # Pieces must be unique
        for p1 = 1:npieces-1, p2 = p1+1:npieces, rotation = 0:3
            if _pieces[p1, 1:4] == _pieces[p2, 5-rotation:8-rotation]
                return false
            end
        end
        # Pieces must not be symmetric (each rotation must be unique)
        for idx = 1:npieces
            top, right, bottom, left = pieces[idx, :]
            if top == bottom && right == left
                return false
            end
        end
        return true
    end

    Random.seed!(seed)

    maxiters = 1000

    for _ in 1:maxiters
        Random.shuffle!(frame_edges)
        Random.shuffle!(inner_edges)
        # Randomly assign the frame colors to adjacent edges of the frame pieces
        he[1, :] = frame_edges[1:ncols-1]
        he[end, :] = frame_edges[ncols:2ncols-2]
        ve[:, 1] = frame_edges[2ncols-1:2ncols+nrows-3]
        ve[:, end] = frame_edges[2ncols+nrows-2:2ncols+2nrows-4]
        # Randomly assign the inner colors to adjacent edges of the inner pieces
        horizontal_inner_edges_count = (nrows - 2) * (ncols - 1)
        he[2:end-1, :] = reshape(inner_edges[1:horizontal_inner_edges_count], nrows-2, ncols-1)
        ve[:, 2:end-1] = reshape(inner_edges[horizontal_inner_edges_count+1:end], nrows-1, ncols-2)

        # Generate the pieces using the grids of horizontal and vertical edge colors. Color
        # numbers are assigned in the order [top, right, bottom, left], with color 0 being
        # the border color. In accordance with the original Eternity II puzzle, The piece
        # numbers 1 to 4 are used for the corner pieces, the next 2*nrows+2*ncols-8 numbers
        # are the edge pieces, eventually followed by the numbers for the inner pieces.

        # Corner pieces (rotate such that the border edges are at the bottom and left sides)
        pieces[1, :] = [he[1, 1], ve[1, 1], 0, 0]          # top-left corner
        pieces[2, :] = [ve[1, end], he[1, end], 0, 0]      # top-right corner
        pieces[3, :] = [ve[end, 1], he[end, 1], 0, 0]      # bottom-left corner
        pieces[4, :] = [he[end, end], ve[end, end], 0, 0]  # bottom-right corner
        rotations[1:4] = [1, 2, 0, 3]

        # Edge pieces in clockwise direction, starting from the top-left corner (rotate
        # such that the border edge is at the bottom side)
        idx = 5
        for col = 2:ncols-1
            pieces[idx, :] = [ve[1, col], he[1, col-1], 0, he[1, col]]
            rotations[idx] = 2
            idx += 1
        end
        for row = 2:nrows-1
            pieces[idx, :] = [he[row, end], ve[row-1, end], 0, ve[row, end]]
            rotations[idx] = 3
            idx += 1
        end
        for col = ncols-1:-1:2
            pieces[idx, :] = [ve[end, col], he[end, col], 0, he[end, col-1]]
            idx += 1
        end
        for row = nrows-1:-1:2
            pieces[idx, :] = [he[row, 1], ve[row, 1], 0, ve[row-1, 1]]
            rotations[idx] = 1
            idx += 1
        end

        # Inner pieces row by row from left to right
        for row = 2:nrows-1, col = 2:ncols-1
            pieces[idx, :] = [ve[row-1, col], he[row, col], ve[row, col], he[row, col-1]]
            idx += 1
        end

        if validate(pieces)
            # Remap piece numbers randomly
            corner_pieces_idx = Random.shuffle(corner_pieces_range)
            edge_pieces_idx = Random.shuffle(edge_pieces_range)
            inner_pieces_idx = Random.shuffle(inner_pieces_range)
            pieces[corner_pieces_range, :] = pieces[corner_pieces_idx, :]
            pieces[edge_pieces_range, :] = pieces[edge_pieces_idx, :]
            pieces[inner_pieces_range, :] = pieces[inner_pieces_idx, :]

            # Rotate inner pieces randomly
            rotations[inner_pieces_range] = rand([0, 1, 2, 3], length(inner_pieces_range))
            for idx = inner_pieces_range, _ = 1:rotations[idx]
                pieces[idx, :] = [pieces[idx, 2:4]..., pieces[idx, 1]]
            end

            puzzle = Eternity2Puzzle(nrows, ncols; pieces)
            puzzle[1, 1] = (findfirst(isequal(1), corner_pieces_idx), 1)
            puzzle[1, ncols] = (findfirst(isequal(2), corner_pieces_idx), 2)
            puzzle[nrows, 1] = (findfirst(isequal(3), corner_pieces_idx), 0)
            puzzle[nrows, ncols] = (findfirst(isequal(4), corner_pieces_idx), 3)
            idx = 5
            for col = 2:ncols-1
                puzzle[1, col] = (findfirst(isequal(idx), edge_pieces_idx) + 4, 2)
                idx += 1
            end
            for row = 2:nrows-1
                puzzle[row, ncols] = (findfirst(isequal(idx), edge_pieces_idx) + 4, 3)
                idx += 1
            end
            for col = ncols-1:-1:2
                puzzle[nrows, col] = (findfirst(isequal(idx), edge_pieces_idx) + 4, 0)
                idx += 1
            end
            for row = nrows-1:-1:2
                puzzle[row, 1] = (findfirst(isequal(idx), edge_pieces_idx) + 4, 1)
                idx += 1
            end
            offset = 2*nrows+2*ncols-4
            for row = 2:nrows-1, col = 2:ncols-1
                piece = findfirst(isequal(idx), inner_pieces_idx) + offset
                puzzle[row, col] = (piece, rotations[piece])
                idx += 1
            end

            @info "Random pieces generated with solution" puzzle

            return pieces
        end
    end

    error("No valid edge colors configuration found after $maxiters iterations")
end
