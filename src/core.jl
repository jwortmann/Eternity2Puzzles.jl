const NCOLORS = 23
const FRAME_COLORS = 1:5
const INNER_COLORS = 6:22
const STARTER_PIECE = 139
const EMPTY = 0x0000

const board_img = PNGFiles.load(joinpath(@__DIR__, "images", "board.png"))
const colors_img = PNGFiles.load(joinpath(@__DIR__, "images", "colors.png"))

abstract type Eternity2Solver end


"""
    Eternity2Puzzle()
    Eternity2Puzzle(nrows::Int, ncols::Int; pieces::Union{Matrix{Int}, String, Symbol})
    Eternity2Puzzle(filename::String; pieces::Union{Matrix{Int}, String, Symbol})

Create a puzzle board with `nrows` rows and `ncols` columns (by default 16×16).
Alternatively, a `filename` can be passed to load an existing solution or a partially
filled board from a file in `.et2` format.

The optional `pieces` keyword argument can be the name of a piece definitions file, an
n×4 matrix, where n is the total amount of pieces, specifying the edge color numbers for
each piece in the format outlined in the README, or one of the predefined symbols
`:meta_16x16`, `:meta_14x14`, `:meta_12x12`, `:meta_10x10`, `:clue1`, `:clue2`, `:clue4`.
The amount of pieces must be compatible with the board dimensions. If `pieces` is not
provided, the piece definitions are loaded from the cache (see [`initialize_pieces`](@ref)).

`Eternity2Puzzle` has two fields; `board` and `pieces`. `board` contains the piece numbers
and rotations for each row/column position of the board in form of a `Matrix{UInt16}`, where
the first 14 bits in each entry represent the piece number and the last 2 bits are used for
the rotation in clockwise direction. By convention `0x0000` is used for empty positions on
the board.

The piece number and rotation at a given row and column can also be obtained as a tuple of
two integers by indexing the `Eternity2Puzzle` struct directly. For example the number and
rotation of the pre-placed starter-piece at row 9, column 8 of the original Eternity II
puzzle are:

# Examples

```julia
julia> puzzle = Eternity2Puzzle(16, 16)
16×16 Eternity2Puzzle with 1 piece:
...

julia> puzzle[9, 8]  # Get the piece number and rotation at row 9, column 8
(139, 2)

julia> puzzle[3, 3] = (208, 3)  # Assign piece 208 with a 270° rotation to row 3, column 3
```

!!! info
    If the code is run within a [Pluto.jl](https://juliahub.com/ui/Packages/General/Pluto)
    notebook, the board with the puzzle pieces is rendered directly inside the notebook.

Note that assigning and obtaining the piece values by indexing `Eternity2Puzzle` directly is
not optimized for performance, i.e. it is not recommended to be used in a hot loop.
"""
struct Eternity2Puzzle
    board::Matrix{UInt16}  # nrows × ncols
    pieces::Matrix{UInt8}  # npieces × 4
end

function Eternity2Puzzle(
    nrows::Integer = 16,
    ncols::Integer = 16;
    pieces::Union{AbstractMatrix{<:Integer}, AbstractString, Symbol} = :cached,
    hint_pieces::Bool = false
)
    _pieces = _get_pieces(pieces)
    npieces = size(_pieces, 1)
    npieces == nrows * ncols || error("The number of pieces ($npieces) is incompatible with the board dimensions $nrows x $ncols - call initialize_pieces first")
    board = zeros(UInt16, nrows, ncols)
    if nrows == ncols == 16
        board[9, 8] = STARTER_PIECE << 2 | 2  # I8
        if hint_pieces
            board[3, 3] = 208 << 2 | 3        # C3
            board[3, 14] = 255 << 2 | 3       # C14
            board[14, 3] = 181 << 2 | 3       # N3
            board[14, 14] = 249 << 2 | 0      # N14
        end
    end
    return Eternity2Puzzle(board, _pieces)
end

function Eternity2Puzzle(
    filename::AbstractString;
    pieces::Union{AbstractMatrix{<:Integer}, AbstractString, Symbol} = :cached
)
    board = _load(filename)
    nrows, ncols = size(board)
    _pieces = _get_pieces(pieces)
    npieces = size(_pieces, 1)
    npieces == nrows * ncols || error("The number of pieces ($npieces) is incompatible with the board dimensions $nrows x $ncols - call initialize_pieces first")
    return Eternity2Puzzle(board, _pieces)
end

function Eternity2Puzzle(pieces::Symbol)
    board = if pieces == :meta_16x16
        _board = zeros(UInt16, 16, 16)
        _board[9, 8] = STARTER_PIECE << 2 | 2
        _board
    elseif pieces == :meta_14x14
        zeros(UInt16, 14, 14)
    elseif pieces == :meta_12x12
        zeros(UInt16, 12, 12)
    elseif pieces == :meta_10x10
        zeros(UInt16, 10, 10)
    elseif pieces == :clue1
        zeros(UInt16, 6, 6)
    elseif pieces == :clue2
        zeros(UInt16, 6, 12)
    elseif pieces == :clue4
        zeros(UInt16, 6, 12)
    else
        error("Unknown option :$pieces")
    end
    _pieces = _get_pieces(pieces)
    return Eternity2Puzzle(board, _pieces)
end


function Base.show(io::IO, ::MIME"text/plain", puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    npieces = nrows * ncols
    placed_pieces = count(@. 0 < puzzle.board >> 2 <= npieces)
    _score, errors = score(puzzle)
    header = if _score > 0
        "$nrows×$ncols Eternity2Puzzle with $placed_pieces $(placed_pieces == 1 ? "piece" : "pieces"), $_score matching edges and $errors errors:"
    else
        "$nrows×$ncols Eternity2Puzzle with $placed_pieces $(placed_pieces == 1 ? "piece" : "pieces"):"
    end
    grid = join([join([0 < val >> 2 <= npieces ? "$(lpad(val >> 2, 4))/$(val & 3)" : " ---/-" for val in row]) for row in eachrow(puzzle.board)], "\n")
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
    if count(@. 0 < puzzle.board >> 2 <= nrows * ncols) > 0
        dark_gray = colorant"#323135"
        for col = 1:ncols, row = 1:nrows
            value = puzzle.board[row, col]
            0 < value >> 2 <= nrows * ncols || continue
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
    return (Int(value >> 2), value & 3)
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
    filepath = joinpath(@get_scratch!("eternity2"), "preview.png")
    open(filepath, "w") do file
        show(file, "image/png", puzzle)
    end
    command = @static Sys.iswindows() ? `powershell.exe start $filepath` : `open $filepath`
    run(command)
    nothing
end


function find(puzzle::Eternity2Puzzle, piece::Integer)
    piece in puzzle || return (0, 0)
    nrows, ncols = size(puzzle)
    for col = 1:ncols, row = 1:nrows
        if puzzle.board[row, col] >> 2 == piece
            return (row, col)
        end
    end
end


_get_pieces(pieces::AbstractString) = parse_pieces(pieces)
_get_pieces(pieces::AbstractMatrix{<:Integer}) = pieces

function _get_pieces(pieces::Symbol)
    if pieces == :cached
        cache_file = joinpath(@get_scratch!("eternity2"), "pieces.txt")
        if isfile(cache_file)
            return DelimitedFiles.readdlm(cache_file, UInt8)
        end
        @warn "Puzzle pieces are undefined - using predefined pieces instead"
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_16x16_rotated.txt"), UInt8)
    elseif pieces == :meta_16x16
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_16x16.txt"), UInt8)
    elseif pieces == :meta_14x14
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_14x14.txt"), UInt8)
    elseif pieces == :meta_12x12
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_12x12.txt"), UInt8)
    elseif pieces == :meta_10x10
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "meta_10x10.txt"), UInt8)
    elseif pieces == :clue1
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "clue1.txt"), UInt8)
    elseif pieces == :clue2
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "clue2.txt"), UInt8)
    elseif pieces == :clue4
        return DelimitedFiles.readdlm(abspath(@__DIR__, "..", "pieces", "clue4.txt"), UInt8)
    end
    error("Unknown option :$pieces")
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
    size(puzzle) == size(board) || throw(ArgumentError("Incompatible board dimensions"))
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
        write(file, join([join([val == 0x0000 ? " ---/-" : "$(lpad(val >> 2, 4))/$(val & 3)" for val in row]) for row in eachrow(puzzle.board)], "\n"))
    end
    nothing
end


"""
    initialize_pieces(filename::AbstractString)

Load the puzzle pieces from an input file, which must be in plain text (.txt) format and
contain rows with the four colors for each piece. See the package README file for details.
"""
function initialize_pieces(filename::AbstractString)
    DelimitedFiles.writedlm(joinpath(@get_scratch!("eternity2"), "pieces.txt"), parse_pieces(filename))
    nothing
end


"""
    reset!(puzzle::Eternity2Puzzle)

Clear all pieces from the board (except for the starter-piece in case of the 16×16 board).
"""
function reset!(puzzle::Eternity2Puzzle)
    fill!(puzzle.board, 0x0000)
    nrows, ncols = size(puzzle.board)
    if nrows == ncols == 16
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


function parse_pieces(filename::AbstractString)
    path = abspath(filename)
    isfile(path) || throw(ArgumentError("No such file $path"))
    endswith(filename, ".txt") || throw(ArgumentError("Unsupported file format"))
    pieces = try
        DelimitedFiles.readdlm(path, UInt8)
    catch  # The file probably contains a header row
        DelimitedFiles.readdlm(path, UInt8, skipstart=1)
    end
    size(pieces, 2) == 4 || error("Unexpected number of rows")
    return pieces
end


"""
    get_color_constraints(puzzle::Eternity2Puzzle, row::Integer, col::Integer)

For a given board position return the color constraints of all 4 edges in the order
[top, right, bottom, left] or `nothing` if there is no adjacent piece in that direction.
"""
function get_color_constraints(puzzle::Eternity2Puzzle, row::Integer, col::Integer)
    nrows, ncols = size(puzzle.board)
    if nrows == ncols == 16 && (row, col) == (9, 8)
        return puzzle.pieces[STARTER_PIECE, 2:-1:1]  # starter-piece has 180° rotation
    end
    if row == 1
        top = 0x00
        val = puzzle.board[row + 1, col]
        bottom = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(1 - val & 3, 4)] : nothing
    elseif row == nrows
        val = puzzle.board[row - 1, col]
        top = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(3 - val & 3, 4)] : nothing
        bottom = 0x00
    else
        val = puzzle.board[row - 1, col]
        top = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(3 - val & 3, 4)] : nothing
        val = puzzle.board[row + 1, col]
        bottom = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(1 - val & 3, 4)] : nothing
    end
    if col == 1
        left = 0x00
        val = puzzle.board[row, col + 1]
        right = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(4 - val & 3, 4)] : nothing
    elseif col == ncols
        val = puzzle.board[row, col - 1]
        left = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(2 - val & 3, 4)] : nothing
        right = 0x00
    else
        val = puzzle.board[row, col - 1]
        left = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(2 - val & 3, 4)] : nothing
        val = puzzle.board[row, col + 1]
        right = val != 0x0000 ? puzzle.pieces[val >> 2, mod1(4 - val & 3, 4)] : nothing
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
        shuffle!(frame_edges)
        shuffle!(inner_edges)
        # Randomly assign the frame colors to adjacent edges of the frame pieces
        he[1, :] = frame_edges[1:ncols-1]
        he[end, :] = frame_edges[ncols:2ncols-2]
        ve[:, 1] = frame_edges[2ncols-1:2ncols+nrows-3]
        ve[:, end] = frame_edges[2ncols+nrows-2:2ncols+2nrows-4]
        # Randomly assign the inner colors to adjacent edges of the inner pieces
        horizontal_inner_edges_count = (nrows - 2) * (ncols - 1)
        he[2:end-1, :] = reshape(inner_edges[1:horizontal_inner_edges_count], nrows - 2, ncols - 1)
        ve[:, 2:end-1] = reshape(inner_edges[horizontal_inner_edges_count+1:end], nrows - 1, ncols - 2)

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
            pieces[idx, :] = [ve[1, col], he[1, col - 1], 0, he[1, col]]
            rotations[idx] = 2
            idx += 1
        end
        for row = 2:nrows-1
            pieces[idx, :] = [he[row, end], ve[row - 1, end], 0, ve[row, end]]
            rotations[idx] = 3
            idx += 1
        end
        for col = ncols-1:-1:2
            pieces[idx, :] = [ve[end, col], he[end, col], 0, he[end, col - 1]]
            idx += 1
        end
        for row = nrows-1:-1:2
            pieces[idx, :] = [he[row, 1], ve[row, 1], 0, ve[row - 1, 1]]
            rotations[idx] = 1
            idx += 1
        end

        # Inner pieces row by row from left to right
        for row = 2:nrows-1, col = 2:ncols-1
            pieces[idx, :] = [ve[row - 1, col], he[row, col], ve[row, col], he[row, col - 1]]
            idx += 1
        end

        if validate(pieces)
            # Remap piece numbers randomly
            corner_pieces_idx = shuffle(corner_pieces_range)
            edge_pieces_idx = shuffle(edge_pieces_range)
            inner_pieces_idx = shuffle(inner_pieces_range)
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
