const STARTER_PIECE = 139

const BOARD_BACKGROUND_IMG = PNGFiles.load(joinpath(@__DIR__, "images", "board.png"))
const COLOR_PATTERNS_IMG = PNGFiles.load(joinpath(@__DIR__, "images", "colors.png"))


""" Abstract type for a solver algorithm. """
abstract type Eternity2Solver end


"""
    Eternity2Puzzle()
    Eternity2Puzzle(; starter_piece::Bool=true, hint_pieces::Bool=false)
    Eternity2Puzzle(pieces::Union{Symbol, String}[, nrows::Int, ncols::Int])
    Eternity2Puzzle(nrows::Int, ncols::Int; frame_colors::Int, inner_colors::Int, seed::Int=1, symmetries::Bool=false)

The `Eternity2Puzzle` type represents a puzzle instance consisting of the piece definitions
and the piece configuration on the board.

The constructor can be called in different ways:

The default constructor without arguments creates a puzzle with 16 rows and 16 columns and
with the original Eternity II pieces. Keyword arguments `starter_piece` and `hint_pieces`
control whether the mandatory starter-piece and the four hint pieces from the clue puzzles
1-4 are pre-placed on the board.

A different set of pieces with the corresponding board size can be used by passing either
one of the predefined symbols `:eternity2`, `:meta_16x16`, `:meta_14x14`, `:meta_12x12`,
`:meta_10x10`, `:clue1`, `:clue2`, `:clue4`, or a path to a file containing the edge color
numbers for the pieces in the format as described in the README of this package. In the
latter case, the input file is expected to contain an additional header line with the
numbers of rows and columns of the board. If the header line is missing, the numbers of rows
and columns must be declared explicitly by passing two integers in addition to the filepath.
If provided, those numbers override the derived size of the board. This can also be used,
for example, to solve a smaller sized board using only a subset of the specified pieces.

If only two integer arguments for the numbers of rows and columns are passed without the
`pieces` argument, a puzzle is created with randomly generated pieces. Optional keyword
arguments `frame_colors` and `inner_colors` can be used to adjust the numbers of frame and
inner color types, and `symmetries` controls whether the generated pieces must all be unique
and not rotationally symmetric.

To load the piece configuration on the board from a file in `.et2` format, use the
[`load!`](@ref) function.

The `Eternity2Puzzle` type has two fields; `board` and `pieces`. `board` contains the piece
numbers and rotations for each row/column position as a `Matrix{UInt16}`, where the first 14
bits of each entry represent the piece number and the last 2 bits are used for the rotation
in clockwise direction. By convention a value of `0` is used if no piece is placed on a
particular position of the board. `pieces` is a `Matrix{UInt8}` with rows containing the
four color numbers for each of the pieces.

The `Eternity2Puzzle` type supports a few basic operations, such as getting or setting a
piece on the board by indexing with the row and column numbers directly. The corresponding
value is returned or must be provided as a tuple of two integers, representing the piece
number and the rotation in clockwise direction. An example how to obtain the number and
rotation of the pre-placed starter-piece on square I8 (row 9, column 8) of the original
Eternity II puzzle is given below.

# Examples

```julia-repl
julia> puzzle = Eternity2Puzzle()  # The original Eternity II puzzle
16×16 Eternity2Puzzle with 1 piece:
...

julia> puzzle[9, 8]  # Get number and rotation of the piece on square I8 (row 9, column 8)
(139, 2)

julia> load!(puzzle, "path/to/saved_board.et2")  # Load pieces on the board from a file

julia> puzzle = Eternity2Puzzle(:clue1)  # Clue puzzle 1
6×6 Eternity2Puzzle with 0 pieces:
...

julia> puzzle = Eternity2Puzzle(8, 8)  # A puzzle with randomly generated pieces
8×8 Eternity2Puzzle with 64 pieces, 112 matching edge pairs and 0 errors:
...

julia> reset!(puzzle)  # Clear the entire board

julia> puzzle = Eternity2Puzzle(:eternity2, 12, 12)  # Eternity II pieces, but smaller board
12×12 Eternity2Puzzle with 0 pieces:
...
```
"""
struct Eternity2Puzzle
    board::Matrix{UInt16}  # nrows x ncols
    pieces::Matrix{UInt8}  # npieces x 4
end

function Eternity2Puzzle(
    pieces::Union{Symbol, AbstractString} = :eternity2;
    starter_piece::Bool = true,
    hint_pieces::Bool = false
)
    _pieces, nrows, ncols = _get_pieces(pieces)
    @assert nrows > 0 && ncols > 0 "Board size undefined"
    board = zeros(UInt16, nrows, ncols)
    if pieces == :eternity2
        if starter_piece
            board[9, 8] = 139 << 2 | 2    # I8
        end
        if hint_pieces
            board[14, 3] = 181 << 2 | 3   # N3  (Clue Puzzle 1)
            board[3, 14] = 255 << 2 | 3   # C14 (Clue Puzzle 2)
            board[14, 14] = 249 << 2 | 0  # N14 (Clue Puzzle 3)
            board[3, 3] = 208 << 2 | 3    # C3  (Clue Puzzle 4)
        end
    end
    return Eternity2Puzzle(board, _pieces)
end

function Eternity2Puzzle(
    pieces::Union{Symbol, AbstractString},
    nrows::Integer,
    ncols::Integer
)
    pieces_, _, _ = _get_pieces(pieces)
    @assert size(pieces_, 1) >= nrows * ncols "Not enough pieces for the given board size"
    board = zeros(UInt16, nrows, ncols)
    return Eternity2Puzzle(board, pieces_)
end

function Eternity2Puzzle(
    nrows::Integer,
    ncols::Integer;
    frame_colors::Integer = 0,
    inner_colors::Integer = 0,
    seed::Integer = 1,
    symmetries::Bool = false
)
    @assert 3 <= nrows <= 20 "Number of rows must be between 3 and 20"
    @assert 3 <= ncols <= 20 "Number of columns must be between 3 and 20"
    frame_colors_, inner_colors_ = _get_number_of_colors(nrows, ncols)
    if frame_colors > 0
        frame_colors_ = frame_colors
    end
    if inner_colors > 0
        inner_colors_ = inner_colors
    end
    board, pieces = generate_pieces(nrows, ncols, frame_colors_, inner_colors_, seed, symmetries)
    return Eternity2Puzzle(board, pieces)
end


function Base.summary(io::IO, puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    placed_pieces = count(value -> !iszero(value), puzzle.board)
    valid_joins, invalid_joins = score(puzzle)
    header_score = valid_joins > 0 ? ", $valid_joins matching edge pairs and $invalid_joins errors" : ""
    print(io, "$nrows×$ncols Eternity2Puzzle with $placed_pieces $(placed_pieces == 1 ? "piece" : "pieces")$header_score")
end

function Base.show(io::IO, ::MIME"text/plain", puzzle::Eternity2Puzzle)
    grid = join([join(row) for row in eachrow(map(value -> iszero(value) ? " ---/-" : lpad("$(value >> 2)/$(value & 3)", 6), puzzle.board))], "\n")
    println(io, summary(puzzle), ":\n", grid)
end

function Base.show(io::IO, ::MIME"image/png", puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    ncolors = maximum(puzzle.pieces)
    img = if nrows == ncols == 16
        copy(BOARD_BACKGROUND_IMG)
    else
        height = 49 * nrows + 1
        width = 49 * ncols + 1
        light_gray = colorant"#615e66"
        white = colorant"#a09ea3"
        background = fill(light_gray, height, width)
        background[[49*row+1 for row = 0:nrows], :] .= white
        background[:, [49*col+1 for col = 0:ncols]] .= white
        background
    end
    if !iszero(puzzle.board)
        dark_gray = colorant"#323135"
        colors_img = if ncolors <= 22
            COLOR_PATTERNS_IMG
        else
            pixels = fill(colorant"transparent", 48, 48*(ncolors+1))
            for y = 1:24, x = y:49-y
                pixels[y, x] = colorant"#5a818a"
            end
            frame_color_numbers, inner_color_numbers = _get_colors(puzzle)
            frame_colors = distinguishable_colors(length(frame_color_numbers); lchoices=[70], cchoices=[25])
            inner_colors = distinguishable_colors(length(inner_color_numbers); lchoices=[50, 60, 70], cchoices=[40, 60, 80])
            colors = fill(colorant"black", ncolors)
            for (i, c) in enumerate(frame_color_numbers)
                colors[c] = frame_colors[i]
            end
            for (i, c) in enumerate(inner_color_numbers)
                colors[c] = inner_colors[i]
            end
            for c = 1:ncolors, y = 1:24, x = 48c+y:48c+49-y
                pixels[y, x] = colors[c]
            end
            pixels
        end
        for col = 1:ncols, row = 1:nrows
            value = puzzle.board[row, col]
            iszero(value) && continue
            piece = value >> 2
            rotation = value & 3
            c1, c2, c3, c4 = puzzle.pieces[piece, :]
            piece_img = colors_img[:, 48c3+1:48c3+48] + rotr90(colors_img[:, 48c4+1:48c4+48]) +
                rot180(colors_img[:, 48c1+1:48c1+48]) + rotl90(colors_img[:, 48c2+1:48c2+48])
            for i = 1:48
                piece_img[i, i] = dark_gray
                piece_img[i, 49-i] = dark_gray
            end
            x = 49 * col - 47
            y = 49 * row - 47
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

Base.getindex(puzzle::Eternity2Puzzle, index::String) = puzzle[_parse_position(index)...]

function Base.setindex!(puzzle::Eternity2Puzzle, value::UInt16, inds...)
    puzzle.board[inds...] = value
end

function Base.setindex!(puzzle::Eternity2Puzzle, value::Tuple{Integer, Integer}, inds...)
    puzzle.board[inds...] = value[1] << 2 | value[2]
end

Base.setindex!(puzzle::Eternity2Puzzle, value::UInt16, index::String) = setindex!(puzzle, value, _parse_position(index)...)
Base.setindex!(puzzle::Eternity2Puzzle, value::Tuple{Integer, Integer}, index::String) = setindex!(puzzle, value, _parse_position(index)...)

Base.size(puzzle::Eternity2Puzzle) = size(puzzle.board)
Base.size(puzzle::Eternity2Puzzle, dim::Integer) = size(puzzle.board, dim)

Base.in(piece::Integer, puzzle::Eternity2Puzzle) = piece in puzzle.board .>> 2


"""
    preview(puzzle::Eternity2Puzzle)

Open a preview image of the puzzle board.
"""
function preview(puzzle::Eternity2Puzzle)
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


# Return the number of frame colors and inner colors for the hardest difficulty of a puzzle
# with the given size. It is assumed that two disjoint sets are used for the colors of the
# frame and inner edges, the colors have a flat distribution, and that there are no
# duplicate or symmetric pieces.
# Reference: https://groups.io/g/eternity2/topic/47707608
function _get_number_of_colors(nrows::Integer, ncols::Integer)
    @assert 3 <= nrows <= 20
    @assert 3 <= ncols <= 20

    frame_colors = OffsetArrays.Origin(3)([
        2  2  2  2  3  3  3  3  4  4  4  4  5  5  5  5  6  6
        2  2  2  3  3  3  3  3  4  4  4  4  4  4  5  5  5  5
        2  2  3  3  3  3  3  3  3  4  4  4  4  4  5  5  5  5
        2  3  3  3  3  3  3  3  3  4  4  4  4  4  4  5  5  5
        3  3  3  3  3  3  3  3  4  4  4  4  4  4  4  5  5  5
        3  3  3  3  3  3  3  4  4  4  4  4  4  4  4  5  5  5
        3  3  3  3  3  3  4  4  4  4  4  4  4  4  4  5  5  5
        3  3  3  3  3  4  4  4  4  4  4  4  4  4  5  5  5  5
        4  4  3  3  4  4  4  4  4  4  4  4  4  5  5  5  5  5
        4  4  4  4  4  4  4  4  4  4  4  4  5  5  5  5  5  5
        4  4  4  4  4  4  4  4  4  4  4  5  5  5  5  5  5  5
        4  4  4  4  4  4  4  4  4  4  5  5  5  5  5  5  5  5
        5  4  4  4  4  4  4  4  4  5  5  5  5  5  5  5  5  5
        5  4  4  4  4  4  4  4  5  5  5  5  5  5  5  5  5  5
        5  5  5  4  4  4  4  5  5  5  5  5  5  5  5  5  5  5
        5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5
        6  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  6
        6  5  5  5  5  5  5  5  5  5  5  5  5  5  5  5  6  6
    ])

    inner_colors = OffsetArrays.Origin(3)([
        2  2  3  3  3  3  4  4  4  4  4  5  5  5  5  5  5  5
        2  3  3  4  4  5  5  5  5  6  6  6  6  7  7  7  7  8
        3  3  4  5  5  5  6  6  7  7  7  8  8  8  8  9  9  9
        3  4  5  5  6  6  7  7  8  8  8  9  9  9 10 10 10 11
        3  4  5  6  6  7  7  8  8  9  9 10 10 10 11 11 11 12
        3  5  5  6  7  8  8  9  9 10 10 11 11 11 12 12 12 13
        4  5  6  7  7  8  9  9 10 10 11 11 12 12 13 13 13 14
        4  5  6  7  8  9  9 10 11 11 12 12 13 13 13 14 14 15
        4  5  7  8  8  9 10 11 11 12 12 13 13 14 14 15 15 16
        4  6  7  8  9 10 10 11 12 12 13 13 14 15 15 16 16 16
        4  6  7  8  9 10 11 12 12 13 14 14 15 15 16 16 17 17
        5  6  8  9 10 11 11 12 13 13 14 15 15 16 16 17 17 18
        5  6  8  9 10 11 12 13 13 14 15 15 16 17 17 18 18 19
        5  7  8  9 10 11 12 13 14 15 15 16 17 17 18 18 19 19
        5  7  8 10 11 12 13 13 14 15 16 16 17 18 18 19 20 20
        5  7  9 10 11 12 13 14 15 16 16 17 18 18 19 20 20 21
        5  7  9 10 11 12 13 14 15 16 17 17 18 19 20 20 21 21
        5  8  9 11 12 13 14 15 16 16 17 18 19 19 20 21 21 22
    ])

    return frame_colors[nrows, ncols], inner_colors[nrows, ncols]
end


# Return a the frame color numbers and the inner color numbers
function _get_colors(puzzle::Eternity2Puzzle)
    frame_colors = Set{UInt8}()
    inner_colors = Set{UInt8}()
    for piece_colors in eachrow(puzzle.pieces)
        border_edges = count(iszero, piece_colors)
        if border_edges == 0
            # Extract the inner color numbers from the inner pieces
            for side in eachindex(piece_colors)
                push!(inner_colors, piece_colors[side])
            end
        elseif border_edges == 1
            # Extract the frame color numbers from the edge pieces, i.e. the sides which are
            # adjacent to the border side
            border_edge_index = findfirst(iszero, piece_colors)
            push!(frame_colors, piece_colors[mod1(border_edge_index + 1, 4)])
            push!(frame_colors, piece_colors[mod1(border_edge_index - 1, 4)])
        end
    end
    return sort(collect(frame_colors)), sort(collect(inner_colors))
end

_load_pieces(filename::String) = DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", filename), UInt8)

@eval _get_pieces(::Val{:eternity2}) = $(_load_pieces("e2pieces.txt")), 16, 16
@eval _get_pieces(::Val{:meta_16x16}) = $(_load_pieces("meta_16x16.txt")), 16, 16
@eval _get_pieces(::Val{:meta_14x14}) = $(_load_pieces("meta_14x14.txt")), 14, 14
@eval _get_pieces(::Val{:meta_12x12}) = $(_load_pieces("meta_12x12.txt")), 12, 12
@eval _get_pieces(::Val{:meta_10x10}) = $(_load_pieces("meta_10x10.txt")), 10, 10
@eval _get_pieces(::Val{:clue1}) = $(_load_pieces("clue1.txt")), 6, 6
@eval _get_pieces(::Val{:clue2}) = $(_load_pieces("clue2.txt")), 6, 12
@eval _get_pieces(::Val{:clue3}) = $(_load_pieces("clue3.txt")), 6, 6
@eval _get_pieces(::Val{:clue4}) = $(_load_pieces("clue4.txt")), 6, 12

function _get_pieces(pieces::Symbol)
    pieces in (:eternity2, :meta_16x16, :meta_14x14, :meta_12x12, :meta_10x10, :clue1, :clue2, :clue3, :clue4) || throw(ArgumentError("Unknown option :$pieces"))
    return _get_pieces(Val(pieces))
end

function _get_pieces(filename::AbstractString)
    endswith(filename, ".txt") || throw(ArgumentError("Unsupported file format"))
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("No such file $path"))
    try
        return DelimitedFiles.readdlm(path, UInt8), 0, 0
    catch  # The file probably contains a header line with the number of rows and columns
        nrows, ncols = [parse(Int, n) for n in split(readline(path))]
        return DelimitedFiles.readdlm(path, UInt8, skipstart=1), nrows, ncols
    end
end


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
    return board
end


"""
    load!(puzzle::Eternity2Puzzle, filename::AbstractString)

Load the pieces on the board from a file in `.et2` format.

The board dimensions of the given `Eternity2Puzzle` must be compatible with the numbers of
rows and columns in the input file.

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
    reset!(puzzle::Eternity2Puzzle)

Clear all pieces from the board (except for the starter-piece in case of the 16×16 board).
"""
function reset!(puzzle::Eternity2Puzzle; starter_piece::Bool = true)
    fill!(puzzle.board, 0x0000)
    if starter_piece && size(puzzle.board) == (16, 16)
        puzzle.board[9, 8] = STARTER_PIECE << 2 | 2
    end
    puzzle
end


"""
    score(puzzle::Eternity2Puzzle)

Return the numbers of matching and non-matching edge pairs on the board.
"""
function score(puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    border_color = 0x00
    valid_joins = 0
    invalid_joins = 0
    # Horizontal joins
    for row = 1:nrows
        right_piece = puzzle.board[row, 1]
        for col = 2:ncols
            left_piece = right_piece
            right_piece = puzzle.board[row, col]
            if iszero(left_piece) || iszero(right_piece) continue end
            # Right edge color of the left piece
            color1 = puzzle.pieces[left_piece >> 2, 4 - left_piece & 3]
            # Left edge color of the right piece
            color2 = puzzle.pieces[right_piece >> 2, mod1(2 - right_piece & 3, 4)]
            if color1 == color2
                if color1 != border_color
                    valid_joins += 1
                end
            else
                invalid_joins += 1
            end
        end
    end
    # Vertical joins
    for col = 1:ncols
        bottom_piece = puzzle.board[1, col]
        for row = 2:nrows
            top_piece = bottom_piece
            bottom_piece = puzzle.board[row, col]
            if iszero(top_piece) || iszero(bottom_piece) continue end
            # Bottom edge color of the top piece
            color1 = puzzle.pieces[top_piece >> 2, mod1(1 - top_piece & 3, 4)]
            # Top edge color of the bottom piece
            color2 = puzzle.pieces[bottom_piece >> 2, mod1(3 - bottom_piece & 3, 4)]
            if color1 == color2
                if color1 != border_color
                    valid_joins += 1
                end
            else
                invalid_joins += 1
            end
        end
    end
    return valid_joins, invalid_joins
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
    @assert minimum(puzzle.pieces) == 0 "Border color must be 0"
    frame_colors, inner_colors = _get_colors(puzzle)
    remapped_colors = [frame_colors; inner_colors; 0x00]
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
    frame_colors_range = 1:length(frame_colors)
    inner_colors_range = (1:length(inner_colors)) .+ last(frame_colors_range)
    return remapped_pieces, frame_colors_range, inner_colors_range
end


# Number of k-permutations of n (as Float128); perm(n, k) = n!/(n-k)!
perm(n, k) = prod(n-k+1:n; init=Float128(1.0))

# Number of k-combinations of n (as Float128); comb(n, k) = n!/(k!(n-k)!)
comb(n, k) = prod((n+1-i)/i for i = 1:min(k, n-k); init=Float128(1.0))


"""
    estimate_solutions(puzzle::Eternity2Puzzle)
    estimate_solutions(puzzle::Eternity2Puzzle, path::Union{Symbol, Vector{String}} = :rowscan, slip_array::Vector{Int} = []; verbose::Bool = false)

Estimate the number of solutions for a given [`Eternity2Puzzle`](@ref) and the total number
of nodes in the search tree for a backtracking algorithm, based on an extended version of
the probability model for edge matching puzzles developed by Brendan Owen.

Pre-placed pieces on the board are considered to be additional constraints that must be
satisfied in a solution.

The order in which pieces are placed onto the board can be controlled with the `path`
argument. It can either be one of the predefined symbols `:rowscan` (fill row by row,
starting from the bottom left corner), `:colscan` (fill column by column, starting from the
bottom left corner), `:spiral_in` (in clockwise direction, starting from the top-left
corner), or `path` can be given as a `Vector{String}`, containing all board positions
explicitly; for example `["I8", "A1", "A2", "B1", ...]`. Hereby it is required that each
board position occurs exactly once, and that the positions of pre-placed pieces are at the
start of the list. Note that if no invalid joins are allowed, the placement order doesn't
effect the number of solutions, but it can have a significant influence on the total number
of nodes in the search tree.

If a vector `slip_array` is given, its entries specify the numbers of placed pieces at
which another invalid join is allowed. This means that a piece arrangement is considered to
be valid even if not all of the inner joins match. For example the vector `[220, 230, 240]`
specifies that at least the first 219 pieces have to be placed with all edges matching, at
least 229 pieces have to be placed with no more than one invalid join, at least 239 pieces
with no more than two invalid joins, and for the rest of the pieces there must be no more
than three invalid joins in total. Note that all of the frame joins between neighboring
frame pieces still have to match exactly.

If the `verbose` keyword argument is enabled, the cumulative sum of estimated partial
solutions is printed to the console for each depth in the search tree of a backtracking
search. This cumulative sum represents the number of nodes that the backtracking algorithm
has to visit in order to explore the entire search tree. The ratio between the number of
full solutions and cumulative sum of partial solutions can be a measure for the difficulty
of the puzzle.

Return the number of solutions and the total number of nodes in the search tree as a tuple
of Float128 values.

# Examples

Estimated number of valid solutions for the Eternity II puzzle:
```julia-repl
julia> puzzle = Eternity2Puzzle()
16×16 Eternity2Puzzle with 1 piece:
...

julia> trunc(Int, estimate_solutions(puzzle)[1])
14702
```

Estimated average number of nodes that a backtracking algorithm has to visit in order to
find a full solution, using a row-by-row search path starting at the bottom left corner:
```julia-repl
julia> solutions, nodes = estimate_solutions(puzzle)
(1.47022707008833935129885673337590720e+04, 1.36503111141314673778599540194846603e+47)

julia> nodes/solutions
9.28449175766521657015077720929987568e+42
```

# References

- <https://groups.io/g/eternity2/message/5209>
- <https://groups.io/g/eternity2/message/6408>
"""
function estimate_solutions(
    puzzle::Eternity2Puzzle,
    path::Vector{String},
    slip_array::Vector{Int} = Int[];
    verbose=false
)
    nrows, ncols = size(puzzle.board)
    max_errors = length(slip_array)

    @assert length(path) == nrows * ncols "Invalid search path"
    @assert issorted(slip_array) "Error depths must be a weakly increasing sequence"

    # Number of border edges for each piece
    border_edges = vec(count(iszero, puzzle.pieces; dims=2))

    # Number of corner, edge and inner pieces
    corner_pieces = count(isequal(2), border_edges)
    edge_pieces = count(isequal(1), border_edges)
    inner_pieces = count(iszero, border_edges)

    @assert corner_pieces >= 4 "Not enough corner pieces"
    @assert edge_pieces >= 2nrows + 2ncols - 8 "Not enough edge pieces"
    @assert inner_pieces >= (nrows-2) * (ncols-2) "Not enough inner pieces"

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
    max_frame_joins = 2 * (nrows - 1) + 2 * (ncols - 1)
    max_inner_joins = (nrows - 1) * (ncols - 2) + (nrows - 2) * (ncols - 1)

    @assert Tb >= max_frame_joins
    @assert Tm >= max_inner_joins

    board = zeros(Int, nrows, ncols)

    # joins(p) = Number of completed (valid or invalid) inner joins after p placed pieces
    joins = OffsetArrays.Origin(0)(zeros(Int, nrows*ncols+1))

    for placed_pieces = 1:nrows*ncols
        row, col = _parse_position(path[placed_pieces])
        board[row, col] = placed_pieces
        joins[placed_pieces] = _count_joins(board)[2]
    end

    fill!(board, 0)

    # Precomputed table with number of k-permutations of n
    nmax = max(maximum(frame_joins), 2*maximum(inner_joins))
    kmax = min(nmax, max(max_frame_joins, 2*max_inner_joins))
    P = OffsetArrays.Origin(0)(zeros(Float128, nmax+1, kmax+1))
    for n = 0:nmax, k = 0:min(n, kmax)
        P[n, k] = perm(n, k)
    end

    # Precomputed table with number of k-combinations of n (Pascal's triangle)
    nmax = max(max_frame_joins, max_inner_joins)
    C = OffsetArrays.Origin(0)(zeros(Float128, nmax+1, nmax+1))
    for n = 0:nmax, k = 0:n
        C[n, k] = comb(n, k)
    end

    # Vb(i, b) = Number of valid configurations of b frame joins can be made using 2b edges of colors 1 to i
    Vb = OffsetArrays.Origin(0)(zeros(Float128, frame_colors+1, max_frame_joins+1))
    Vb[0, 0] = 1.0
    for i = 1:frame_colors
        n = frame_joins[i]
        for b = 0:max_frame_joins
            Vb[i, b] = sum(Vb[i-1, b-j] * P[n, j]^2 * C[b, j] for j = 0:min(n, b))
        end
    end

    # pb(b) = Probability that all b frame joins are valid using 2b edges
    pb = OffsetArrays.Origin(0)(zeros(Float128, max_frame_joins+1))
    for b = 0:max_frame_joins
        pb[b] = Vb[frame_colors, b] / perm(Tb, b)^2
    end

    # Vm(i, m) = Number of valid configurations of m inner joins can be made using 2m edges of colors 1 to i
    Vm = OffsetArrays.Origin(0)(zeros(Float128, inner_colors+1, max_inner_joins+1))
    Vm[0, 0] = 1.0
    for i = 1:inner_colors
        n = inner_joins[i]
        for m = 0:max_inner_joins
            Vm[i, m] = sum(Vm[i-1, m-j] * P[2n, 2j] * C[m, j] for j = 0:min(n, m))
        end
    end

    # pm(m, v) = Probability the first v inner joins are valid and the rest are not using 2m edges
    pm = OffsetArrays.Origin(0)(zeros(Float128, max_inner_joins+1, max_inner_joins+1))
    for m = 0:max_inner_joins
        pm[m, m] = Vm[inner_colors, m] / perm(2Tm, 2m)
        for v = m-1:-1:0
            pm[m, v] = pm[m-1, v] - pm[m, v+1]
        end
    end

    # Wm(p, i) = Number of ways to arrange exactly i invalid inner joins after p placed pieces
    Wm = OffsetArrays.Origin(0)(zeros(Float128, nrows*ncols+1, max_errors+1))
    Wm[:, 0] .= 1.0
    for i = 1:max_errors
        d = slip_array[i]
        for p = d:nrows*ncols
            Wm[p, i] = sum(Wm[d-1, k] * C[joins[p]-joins[d-1], i-k] for k = 0:i-1)
        end
    end

    estimated_solutions::Float128 = 1.0
    cumulative_sum::Float128 = 0.0

    for placed_pieces = 1:nrows*ncols
        square = path[placed_pieces]
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
            # estimated_solutions = piece_configurations * pb[b] * sum(pm[m, v] * C[m, v] for v = max(m-max_errors, 0):m)  # Old version that only supports the invalid joins considered to be anywhere on the board
            estimated_solutions = piece_configurations * pb[b] * sum(pm[m, m-k] * Wm[placed_pieces, k] for k = 0:min(max_errors, m))
        end
        cumulative_sum += estimated_solutions
        if verbose
            @printf "%3i  %-3s  %.5e  %.5e\n" placed_pieces square estimated_solutions cumulative_sum
        end
    end
    return estimated_solutions, cumulative_sum
end

function estimate_solutions(puzzle::Eternity2Puzzle, path::Symbol = :rowscan, slip_array::Vector{Int} = Int[]; verbose=false)
    return estimate_solutions(puzzle, generate_search_path(puzzle, path), slip_array; verbose=verbose)
end

# Numbers of corner, edge and inner pieces on the board
function _count_pieces(board::Matrix{<:Real})
    corner_pieces = count(!iszero, board[[1, end], [1, end]])
    edge_pieces = count(!iszero, board[2:end-1, [1, end]]) + count(!iszero, board[[1, end], 2:end-1])
    inner_pieces = count(!iszero, board[2:end-1, 2:end-1])
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

function generate_search_path(puzzle::Eternity2Puzzle, strategy::Symbol)
    nrows, ncols = size(puzzle)
    path = String[]
    sizehint!(path, nrows*ncols)
    # Add pre-placed pieces first
    for idx in eachindex(IndexCartesian(), puzzle.board)
        if !iszero(puzzle.board[idx])
            push!(path, _board_square(Tuple(idx)...))
        end
    end

    if strategy == :rowscan
        for row = nrows:-1:1, col = 1:ncols
            if iszero(puzzle.board[row, col])
                push!(path, _board_square(row, col))
            end
        end
    elseif strategy == :colscan
        for col = 1:ncols, row = nrows:-1:1
            if iszero(puzzle.board[row, col])
                push!(path, _board_square(row, col))
            end
        end
    elseif strategy == :spiral_in  # Clockwise direction starting in the top-left corner
        row, col = 1, 0
        hsteps = ncols
        vsteps = nrows
        while true
            if hsteps == 0 break end
            for _ = 1:hsteps  # Move right
                col += 1
                if iszero(puzzle.board[row, col]) push!(path, _board_square(row, col)) end
            end
            vsteps -= 1
            if vsteps == 0 break end
            for _ = 1:vsteps  # Move down
                row += 1
                if iszero(puzzle.board[row, col]) push!(path, _board_square(row, col)) end
            end
            hsteps -= 1
            if hsteps == 0 break end
            for _ = 1:hsteps  # Move left
                col -= 1
                if iszero(puzzle.board[row, col]) push!(path, _board_square(row, col)) end
            end
            vsteps -= 1
            if vsteps == 0 break end
            for _ = 1:vsteps  # Move up
                row -= 1
                if iszero(puzzle.board[row, col]) push!(path, _board_square(row, col)) end
            end
            hsteps -= 1
        end
    else
        throw(ArgumentError("Unknown option :$strategy"))
    end

    return path
end


"""
    symmetry_factor(puzzle::Eternity2Puzzle)

Return the number of symmetries in the puzzle as a one-based factor, i.e. if there aren't
any symmetries, the return value is `1`. Symmetries can happen due to rotationally symmetric
individual pieces, (rotationally identical) duplicate pieces, and possible rotations of the
board if there aren't any fixed pieces on the board. The total number of puzzle solutions is
divisible by this factor. When using a backtracking algorithm to enumerate all solutions of
a given puzzle, it can be advantageous to first eliminate all the symmetries, for example by
fixing one of the corner pieces and by restricting the rotations of the rotationally
symmetric pieces, and then to multiply the number of found solutions by the corresponding
factor.
"""
function symmetry_factor(puzzle::Eternity2Puzzle)
    symmetries = 1
    nrows, ncols = size(puzzle.board)
    npieces = size(puzzle.pieces, 1)
    fixed_pieces = Int.(filter(!iszero, puzzle.board) .>> 2)
    for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces))
        if piece in fixed_pieces
            continue
        end
        # Symmetries due to rotationally symmetric individual pieces
        if piece_colors[1] == piece_colors[3] && piece_colors[2] == piece_colors[4]
            symmetries *= ifelse(piece_colors[1] == piece_colors[2], 4, 2)
        end
        # Symmetries due to rotationally identical duplicate pieces
        identical_pieces = 1
        for piece2 = piece+1:npieces
            for rotation = 0:3
                if piece_colors == circshift(puzzle.pieces[piece2, :], rotation)
                    identical_pieces += 1
                    break
                end
            end
        end
        symmetries *= identical_pieces
    end
    # Symmetries due to board rotations
    if isempty(fixed_pieces)
        symmetries *= ifelse(nrows == ncols, 4, 2)
    end
    return symmetries
end


"""
    generate_pieces(nrows::Int, ncols::Int, frame_colors::Int, inner_colors::Int, seed::Int, symmetries::Bool)

Generate random pieces for an Eternity II style puzzle with `nrows` rows, `ncols` columns,
`frame_colors` frame colors and `inner_colors` inner colors.

`nrows` and `ncols` must be between 3 and 20.

`symmetries` controls whether the generated pieces must all be unique and not rotationally
symmetric. If set to `false` and no such pieces can be generated for the given numbers of
frame colors and inner colors after `maxiters` iterations, the function throws an error.

Return a valid arrangement on the board (i.e. puzzle solution) and a matrix with the edge
colors for the pieces.
"""
function generate_pieces(
    nrows::Int,
    ncols::Int,
    frame_colors::Int,
    inner_colors::Int,
    seed::Int,
    symmetries::Bool,
    maxiters::Int = 1000
)
    @assert 3 <= nrows <= 20
    @assert 3 <= ncols <= 20

    npieces = nrows * ncols
    frame_joins_count = 2*(nrows-1) + 2*(ncols-1)
    inner_joins_count = (nrows-1)*(ncols-2) + (nrows-2)*(ncols-1)

    # Generate uniform distributions of frame edge colors and inner edge colors.
    frame_joins = [mod1(i, frame_colors) for i = 1:frame_joins_count]
    inner_joins = [mod1(i, inner_colors) + frame_colors for i = 1:inner_joins_count]

    hj = zeros(UInt8, nrows, ncols+1)  # Horizontal joins including border
    vj = zeros(UInt8, nrows+1, ncols)  # Vertical joins including border

    pieces = Matrix{UInt8}(undef, npieces, 4)
    rotations = Vector{Int}(undef, npieces)

    function validate(pieces)
        for (p1, colors) in enumerate(eachrow(pieces))
            # Pieces must not be rotationally symmetric
            if colors[1] == colors[3] && colors[2] == colors[4]
                return false
            end
            # Pieces must be unique
            if any(colors == view(pieces, p2, :) for p2 = p1+1:npieces)
                return false
            end
        end
        return true
    end

    Random.seed!(seed)

    for _ in 1:maxiters
        Random.shuffle!(frame_joins)
        Random.shuffle!(inner_joins)

        # Assign random frame colors to frame joins
        hj[1, 2:end-1] = frame_joins[1:ncols-1]
        hj[end, 2:end-1] = frame_joins[ncols:2ncols-2]
        vj[2:end-1, 1] = frame_joins[2ncols-1:2ncols+nrows-3]
        vj[2:end-1, end] = frame_joins[2ncols+nrows-2:end]

        # Assign random inner colors to inner joins
        hj[2:end-1, 2:end-1] = reshape(inner_joins[1:(nrows-2)*(ncols-1)], nrows-2, ncols-1)
        vj[2:end-1, 2:end-1] = reshape(inner_joins[(nrows-2)*(ncols-1)+1:end], nrows-1, ncols-2)

        # Generate pieces with edge colors from the grid of joins
        for p = 1:npieces
            row, col = fldmod1(p, ncols)
            # Edge colors in order [bottom, left, top, right]
            edges = [vj[row+1, col], hj[row, col], vj[row, col], hj[row, col+1]]
            # Find rotation which minimizes the tuple of edge color values
            r = argmin(r -> Tuple(circshift(edges, -r)), 0:3)
            pieces[p, :] = circshift(edges, -r)
            rotations[p] = r
        end

        if symmetries || validate(pieces)
            # Sort pieces by their edge color numbers
            idx = sortperm(collect(Tuple(colors) for colors in eachrow(pieces)))
            idx2 = invperm(idx)
            board = Matrix{UInt16}(undef, nrows, ncols)
            for p = 1:npieces
                row, col = fldmod1(p, ncols)
                board[row, col] = idx2[p] << 2 | rotations[p]
            end

            return board, pieces[idx, :]
        end
    end

    error("No valid edge color configuration found after $maxiters iterations")
end


function _print_progress(
    puzzle::Eternity2Puzzle,
    nodes::Int = 0,
    restarts::Int = 0,
    solutions::Int = 0;
    verbose::Bool = true,
    clear::Bool = true
)
    nrows, ncols = size(puzzle.board)
    show_board = verbose && !displayable("image/png")
    if clear
        clear_lines = ifelse(show_board, nrows+3, 1)
        print("\e[$(clear_lines)F\e[0J")
    end
    if show_board
        display(puzzle)
    end
    pieces_str = "Pieces: $(count(!iszero, puzzle.board))/$(nrows*ncols)"
    iterations_str = "   Nodes: $(round(nodes/1_000_000_000, digits=2)) B"
    restarts_str = iszero(restarts) ? "" : "   Restarts: $restarts"
    solutions_str = iszero(solutions) ? "" : "   Solutions: $solutions"
    println(pieces_str, iterations_str, restarts_str, solutions_str)
end
