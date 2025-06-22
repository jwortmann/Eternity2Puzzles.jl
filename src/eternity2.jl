using Colors
import DelimitedFiles
using GameZero
import NativeFileDialog
import PNGFiles
using Printf: @printf
using Scratch: @get_scratch!, get_scratch!
import SimpleDirectMediaLayer


SimpleDirectMediaLayer.LibSDL2.SDL_SetHint(SimpleDirectMediaLayer.LibSDL2.SDL_HINT_RENDER_SCALE_QUALITY, "2")


game_include("core.jl")
false && include("core.jl")  # make file contents visible to LSP


const WIDTH = 1392
const HEIGHT = 912

struct BoundingBox
    xmin::Int
    ymin::Int
    xmax::Int
    ymax::Int
end

Base.in(pos::Tuple{Integer, Integer}, bb::BoundingBox) = bb.xmin <= pos[1] <= bb.xmax && bb.ymin <= pos[2] <= bb.ymax

const cache_dir = get_scratch!(Base.UUID("7b8a590e-5f29-49cd-9d3d-d6aab43f7c56"), "eternity2")
const board = _load(joinpath(cache_dir, "board.et2"))
const _pieces = DelimitedFiles.readdlm(joinpath(cache_dir, "pieces.txt"), UInt8)

const NROWS, NCOLS = size(board)
const NPIECES = NROWS * NCOLS

const MAXIMUM_SCORE = 2 * NROWS * NCOLS - NROWS - NCOLS

const BACKGROUND, BOARD_BOUNDING_BOX, puzzle = if (NROWS, NCOLS) == (16, 16)
    ("background.png", BoundingBox(61, 61, 844, 844), Eternity2Puzzle(board, _pieces))
elseif (NROWS, NCOLS) == (6, 6)
    ("background_6x6.png", BoundingBox(306, 306, 598, 598), Eternity2Puzzle(board, _pieces))
elseif (NROWS, NCOLS) == (6, 12)
    ("background_6x12.png", BoundingBox(159, 306, 745, 598), Eternity2Puzzle(board, _pieces))
else
    error("Unsupported board size")
end

const initial_position_xmin = 898
const initial_position_ymin = 38
const initial_position_width = 12*32 + 11*6
const initial_position_height = 22*32 + 21*6

const PIECES = repeat(puzzle.pieces, 1, 2)
const BORDER_COLOR = 0

const CORNER_PIECES = [piece for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces)) if count(isequal(BORDER_COLOR), piece_colors) == 2]
const EDGE_PIECES = [piece for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces)) if count(isequal(BORDER_COLOR), piece_colors) == 1]
const INNER_PIECES = [piece for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces)) if count(isequal(BORDER_COLOR), piece_colors) == 0]

linspace(a, b, n) = [a + (b-a)*k/(n-1) for k in 0:n-1]
smoothstep(a, b, n) = [a + (b-a)*(3*(k/(n-1))^2 - 2*(k/(n-1))^3) for k in 0:n-1]

const ANIMATION_FRAMES_COUNT = 8
const ANIMATION_ANGLES = smoothstep(0.0, 90.0, ANIMATION_FRAMES_COUNT)
const ANIMATION_RESET_ANGLES = hcat(
    zeros(ANIMATION_FRAMES_COUNT),  # don't rotate
    smoothstep(90.0, 0.0, ANIMATION_FRAMES_COUNT),  # rotate counter-clockwise
    smoothstep(180.0, 0.0, ANIMATION_FRAMES_COUNT),  # rotate counter-clockwise
    smoothstep(270.0, 360.0, ANIMATION_FRAMES_COUNT)  # rotate clockwise
)
const ANIMATION_RESET_SCALES = linspace(1.0, 0.66667, ANIMATION_FRAMES_COUNT)
const FRAME_TIME_60HZ = 0.016667


"State variables for the user interface"
mutable struct UIState
    dragged_piece::Int  # piece number if mouse is holding a piece, otherwise set to 0
    dragged_piece_rotation::Int
    animated_piece::Int  # piece number if a piece is currently resetting,
    matching_pieces::Vector{Int}
    matching_pieces_cache::Matrix{Union{Vector{Int}, Nothing}}
    errors::Vector{Int}
    highlight_matching_pieces::Bool  # when mouse is hovering over an empty cell on the board
    highlight_errors::Bool
    draw_board_highlight::Bool  # when mouse is holding a piece over the board
    overlay::Union{Symbol, Nothing}  # whether the menu is open
    draw_button_hover::Bool  # when mouse is hovering over a menu button
    can_save::Bool  # whether the save button is activated
    score::Int
    old_score::Int   # the score which is currently shown in the top left corner
    old_score2::Int  # the score which is currently shown in the menu
end


const _initial_score = score(puzzle)[1]
const ui = UIState(0, 0, 0, [], Matrix{Union{Vector{Int}, Nothing}}(nothing, 16, 16), [], false, false, false, :main_menu, false, false, _initial_score, _initial_score, _initial_score)


# The x and y coordinates of the positions on the right for a given piece number
function initial_position(piece::Integer)
    row, col = divrem(piece - 1, 12)
    return (initial_position_xmin + col * 38, 38 + row * 38)
end


# For given x and y coordinates return the row and column numbers on the board.
function coords_to_rowcol(x::Integer, y::Integer)
    if (x, y) in BOARD_BOUNDING_BOX
        row = div(y - BOARD_BOUNDING_BOX.ymin, 49) + 1
        col = div(x - BOARD_BOUNDING_BOX.xmin, 49) + 1
        return (row, col)
    end
    return (0, 0)
end


# For given row and column numbers of the board return the x and y coordinates.
function rowcol_to_coords(row::Integer, col::Integer)
    x = BOARD_BOUNDING_BOX.xmin + 49 * (col - 1)
    y = BOARD_BOUNDING_BOX.ymin + 49 * (row - 1)
    return (x, y)
end


# For given x and y coordinates return the piece index of the initial positions on the
# righthand side. Returns 0 if the coordinates don't match any position. This is used to
# check whether the mouse is hovering over an unplaced puzzle piece.
function coords_to_initial_position(x::Integer, y::Integer)
    xloc = x - initial_position_xmin
    yloc = y - initial_position_ymin
    if 0 <= xloc < initial_position_width && 0 <= yloc < initial_position_height
        col, r = divrem(xloc, 38)
        r > 32 && return 0
        row, r = divrem(yloc, 38)
        r > 32 && return 0
        idx = row * 12 + col + 1
        idx > NPIECES && return 0
        return idx
    end
    return 0
end


function _score_pos(score, menu)
    if menu
        return if score > 99
            (705, 678)
        elseif score > 9
            (720, 678)
        else
            (735, 678)
        end
    else
        return if score > 99
            (11, 10)
        elseif score > 9
            (19, 10)
        else
            (28, 10)
        end
    end
end


const images = Vector{UInt32}[]

# An Actor which uses a given pixel matrix instead of an image file stored on disk.
function PixelActor(image::AbstractMatrix{<:Colorant}; kv...)
    height, width = size(image)
    depth = 32
    pitch = 4 * width
    format = SimpleDirectMediaLayer.LibSDL2.SDL_PIXELFORMAT_RGBA8888

    pixels = Vector{UInt32}(undef, width * height)

    for (idx, pixel) in enumerate(permutedims(image))
        r = UInt32(reinterpret(UInt8, red(pixel)))
        g = UInt32(reinterpret(UInt8, green(pixel)))
        b = UInt32(reinterpret(UInt8, blue(pixel)))
        a = UInt32(255)
        pixels[idx] = r << 24 | g << 16 | b << 8 | a  # RGBA8888
    end

    # Prevent the memory of the pixels array from being deallocated by the garbace collector
    push!(images, pixels)

    surface = SimpleDirectMediaLayer.LibSDL2.SDL_CreateRGBSurfaceWithFormatFrom(pixels, width, height, depth, pitch, format)
    actor = GameZero.Actor("", surface, Rect(0, 0, width, height), [1.0, 1.0], 0, 255, Dict{Symbol,Any}())
    for (k, v) in kv
        setproperty!(actor, k, v)
    end
    return actor
end


# Collection of all Actors (instead of having them as separate global variables)
mutable struct ActorCollection
    overlay::Actor
    button_hover::Actor
    puzzle_pieces::Vector{Actor}
    shadow::Actor
    board_highlight::Actor
    error_highlights::Vector{Actor}
    candidates_highlights::Vector{Actor}
    score_label::Actor  # score which is shown in the top left corner
    score_label2::Actor # score which is shown in the menu
    checkmark1::Actor
    checkmark2::Actor
end

function ActorCollection()
    colors = PNGFiles.load(joinpath(@__DIR__, "images", "colors.png"))
    puzzle_pieces = Vector{Actor}(undef, NPIECES)
    error_highlights = Vector{Actor}(undef, 4 * NPIECES)
    candidates_highlights = Vector{Actor}(undef, NPIECES)

    for idx = 1:NPIECES
        row, col = fldmod1(idx, NCOLS)
        x, y = rowcol_to_coords(row, col)
        error_highlights[4*(idx-1)+1] = Actor("highlight1.png")
        error_highlights[4*(idx-1)+1].pos = (x, y)
        error_highlights[4*(idx-1)+2] = Actor("highlight2.png")
        error_highlights[4*(idx-1)+2].pos = (x, y)
        error_highlights[4*(idx-1)+3] = Actor("highlight3.png")
        error_highlights[4*(idx-1)+3].pos = (x, y)
        error_highlights[4*(idx-1)+4] = Actor("highlight4.png")
        error_highlights[4*(idx-1)+4].pos = (x, y)
        # Combine the 4 images of the edges into a single image
        c1, c2, c3, c4 = PIECES[idx, 1:4]
        image = colors[:,48*c1+1:48*c1+48] + rotr90(colors[:,48*c2+1:48*c2+48]) + rot180(colors[:,48*c3+1:48*c3+48]) + rotl90(colors[:,48*c4+1:48*c4+48])
        # Set opaque color for diagonal pixels which are half-transparent
        for i = 1:48
            image[i, i] = colorant"#323135"
            image[i, 49-i] = colorant"#323135"
        end
        pos = initial_position(idx)
        candidates_highlights[idx] = Actor("highlight_small.png")
        candidates_highlights[idx].pos = pos
        row, col = find(puzzle, idx)
        if (row, col) == (0, 0)
            puzzle_pieces[idx] = PixelActor(image, scale=[0.666667, 0.666667])
            puzzle_pieces[idx].pos = pos
        else
            puzzle_pieces[idx] = PixelActor(image, scale=[1.0, 1.0])
            puzzle_pieces[idx].pos = rowcol_to_coords(row, col)
            puzzle_pieces[idx].angle = 90.0 * puzzle[row, col][2]
        end
    end
    score_label = TextActor(string(ui.score), "luckiestguy", font_size=16, color=Int[255,255,255,255])
    score_label.pos = _score_pos(ui.score, false)
    score_label2 = TextActor("$(ui.score)/$MAXIMUM_SCORE", "luckiestguy", font_size=30, color=Int[221,221,221,255])
    score_label2.pos = _score_pos(ui.score, true)
    checkmark1 = Actor("checkmark.png")
    checkmark1.pos = (591, 336)
    checkmark2 = Actor("checkmark.png")
    checkmark2.pos = (591, 376)
    return ActorCollection(
        Actor("menu.png"),
        Actor("button_hover.png"),
        puzzle_pieces,
        Actor("shadow.png"),
        Actor("highlight.png"),
        error_highlights,
        candidates_highlights,
        score_label,
        score_label2,
        checkmark1,
        checkmark2
    )
end

const actors = ActorCollection()


# Animation for rotating a puzzle piece.
function rotate_animation(piece::Integer, rotation::Integer, frame::Integer=2)
    angle = ANIMATION_ANGLES[frame]
    actors.puzzle_pieces[piece].angle = 90.0 * (rotation - 1) + angle
    actors.shadow.angle = angle
    if frame < ANIMATION_FRAMES_COUNT
        frame += 1
        schedule_once(() -> rotate_animation(piece, rotation, frame + 1), FRAME_TIME_60HZ)
    else
        actors.puzzle_pieces[piece].angle = 90.0 * rotation
        actors.shadow.angle = 0.0
    end
end


# Animation for resetting a puzzle piece.
function reset_animation(idx::Integer, x0::Integer, y0::Integer, rotation::Integer, frame::Integer=2)
    x, y = initial_position(idx)
    if frame < ANIMATION_FRAMES_COUNT
        xpos = linspace(x0, x, ANIMATION_FRAMES_COUNT)[frame]
        ypos = linspace(y0, y, ANIMATION_FRAMES_COUNT)[frame]
        actors.puzzle_pieces[idx].pos = (xpos, ypos)
        actors.puzzle_pieces[idx].angle = ANIMATION_RESET_ANGLES[frame, rotation + 1]
        scale = ANIMATION_RESET_SCALES[frame]
        actors.puzzle_pieces[idx].scale = [scale, scale]
        schedule_once(() -> reset_animation(idx, x0, y0, rotation, frame + 1), FRAME_TIME_60HZ)
    else
        actors.puzzle_pieces[idx].pos = (x, y)
        actors.puzzle_pieces[idx].angle = 0.0
        actors.puzzle_pieces[idx].scale = [2//3, 2//3]
        ui.animated_piece = 0
    end
end


# Updates the score shown in the top left corner
function update_score()
    ui.score = score(puzzle)[1]
    ui.old_score == ui.score && return
    actors.score_label = TextActor(string(ui.score), "luckiestguy", font_size=16, color=Int[255,255,255,255])
    actors.score_label.pos = _score_pos(ui.score, false)
    ui.old_score = ui.score
end

# Updates the score shown in the menu
function update_score2()
    ui.old_score2 == ui.score && return
    actors.score_label2 = TextActor("$(ui.score)/$MAXIMUM_SCORE", "luckiestguy", font_size=30, color=Int[221,221,221,255])
    actors.score_label2.pos = _score_pos(ui.score, true)
    ui.old_score2 = ui.score
end


# Update the empty square highlighted on the board if the mouse is hovering over it while
# holding a piece.
function update_board_highlight(pos)
    if ui.dragged_piece > 0
        actors.puzzle_pieces[ui.dragged_piece].pos = (pos[1] - 24, pos[2] - 24)
        row, col = coords_to_rowcol(pos[1], pos[2])
        if (row, col) != (0, 0) && puzzle.board[row, col] == 0x0000
            actors.board_highlight.pos = (BOARD_BOUNDING_BOX.xmin + 49 * col - 50, BOARD_BOUNDING_BOX.ymin + 49 * row - 50)
            ui.draw_board_highlight = true
        else
            ui.draw_board_highlight = false
        end
    else
        ui.draw_board_highlight = false
    end
end


function update_error_highlights()
    ui.highlight_errors || return
    empty!(ui.errors)
    # Horizontal border edges
    for row = 1:NROWS
        val = puzzle.board[row, 1]
        if val != 0x0000 && PIECES[val >> 2, 4 - val & 3] != BORDER_COLOR
            push!(ui.errors, 4 * NCOLS * (row - 1) + 4)
        end
        val = puzzle.board[row, NCOLS]
        if val != 0x0000 && PIECES[val >> 2, 6 - val & 3] != BORDER_COLOR
            push!(ui.errors, 4 * NCOLS * row - 2)
        end
    end
    # Vertical border edges
    for col = 1:NCOLS
        val = puzzle.board[1, col]
        if val != 0x0000 && PIECES[val >> 2, 5 - val & 3] != BORDER_COLOR
            push!(ui.errors, 4 * col - 3)
        end
        val = puzzle.board[NROWS, col]
        if val != 0x0000 && PIECES[val >> 2, 7 - val & 3] != BORDER_COLOR
            push!(ui.errors, 4 * NCOLS * (NROWS - 1) + 4 * col - 1)
        end
    end
    # Horizontal inner edges
    for col = 1:NCOLS-1, row = 1:NROWS
        idx1 = 4 * NCOLS * (row - 1) + 4 * col - 2
        idx2 = 4 * NCOLS * (row - 1) + 4 * col + 4
        p1 = puzzle.board[row, col]
        if p1 != 0x0000
            p1_right = PIECES[p1 >> 2, 6 - p1 & 3]
            if p1_right == BORDER_COLOR
                push!(ui.errors, idx1)
            end
        end
        p2 = puzzle.board[row, col + 1]
        if p2 != 0x0000
            p2_left = PIECES[p2 >> 2, 4 - p2 & 3]
            if p2_left == BORDER_COLOR
                push!(ui.errors, idx2)
            end
        end
        if p1 != 0x0000 && p2 != 0x0000 && p1_right != BORDER_COLOR && p2_left != BORDER_COLOR && p1_right != p2_left
            if p1 >> 2 != STARTER_PIECE
                push!(ui.errors, idx1)
            end
            if p2 >> 2 != STARTER_PIECE
                push!(ui.errors, idx2)
            end
        end
    end
    # Vertical inner edges
    for col = 1:NCOLS, row = 1:NROWS-1
        idx1 = 4 * NCOLS * (row - 1) + 4 * col - 1
        idx2 = 4 * NCOLS * row + 4 * col - 3
        p1 = puzzle.board[row, col]
        if p1 != 0x0000
            p1_bottom = PIECES[p1 >> 2, 7 - p1 & 3]
            if p1_bottom == BORDER_COLOR
                push!(ui.errors, idx1)
            end
        end
        p2 = puzzle.board[row + 1, col]
        if p2 != 0x0000
            p2_top = PIECES[p2 >> 2, 5 - p2 & 3]
            if p2_top == BORDER_COLOR
                push!(ui.errors, idx2)
            end
        end
        if p1 != 0x0000 && p2 != 0x0000 && p1_bottom != BORDER_COLOR && p2_top != BORDER_COLOR && p1_bottom != p2_top
            if p1 >> 2 != STARTER_PIECE
                push!(ui.errors, idx1)
            end
            if p2 >> 2 != STARTER_PIECE
                push!(ui.errors, idx2)
            end
        end
    end
end


# Update the highlighting of matching pieces when the mouse is hovering over an empty cell
# on the board
function update_highlighted_pieces(row::Integer, col::Integer)
    if isnothing(ui.matching_pieces_cache[row, col])
        ui.matching_pieces_cache[row, col] = Int[]
        edge_colors = _get_color_constraints(puzzle, row, col)
        constraints_filter = .!isnothing.(edge_colors)
        any(constraints_filter) || return
        constraints = edge_colors[constraints_filter]
        pieces_category = if (row == 1 || row == NROWS) && (col == 1 || col == NCOLS)
            CORNER_PIECES
        elseif row == 1 || row == NROWS || col == 1 || col == NCOLS
            EDGE_PIECES
        else
            INNER_PIECES
        end
        for idx in pieces_category
            if idx << 2 | 0 in puzzle.board || idx << 2 | 1 in puzzle.board || idx << 2 | 2 in puzzle.board || idx << 2 | 3 in puzzle.board
                continue  # piece is already placed
            end
            for rotation = 0:3
                if PIECES[idx, 5-rotation:8-rotation][constraints_filter] == constraints
                    push!(ui.matching_pieces_cache[row, col], idx)
                    break
                end
            end
        end
    end
    ui.matching_pieces = ui.matching_pieces_cache[row, col]
end


function clear_matching_cache()
    ui.highlight_matching_pieces || return
    for idx in eachindex(ui.matching_pieces_cache)
        ui.matching_pieces_cache[idx] = nothing
    end
end


function load!(puzzle::Eternity2Puzzle)
    try
        filename = NativeFileDialog.pick_file("", filterlist="et2")
        filename == "" && return
        isfile(filename) || return
        load!(puzzle, filename)
        # reset entire board
        for idx = 1:NPIECES
            idx == STARTER_PIECE && continue
            actors.puzzle_pieces[idx].pos = initial_position(idx)
            actors.puzzle_pieces[idx].angle = 0.0
            actors.puzzle_pieces[idx].scale = [2//3, 2//3]
        end
        # place pieces
        for col = 1:NCOLS, row = 1:NROWS
            val = puzzle.board[row, col]
            val == 0x0000 && continue
            piece, rotation = val >> 2, val & 3
            piece == STARTER_PIECE && continue
            actors.puzzle_pieces[piece].pos = rowcol_to_coords(row, col)
            actors.puzzle_pieces[piece].angle = 90.0 * rotation
            actors.puzzle_pieces[piece].scale = [1, 1]
        end
        ui.overlay = nothing
        if actors.overlay.image != "menu2.png"
            actors.overlay.image = "menu2.png"
        end
        ui.draw_button_hover = false
        ui.can_save = true
        clear_matching_cache()
        update_error_highlights()
        update_score()
        @info "Savegame loaded"
    catch ex
        showerror(stdout, ex, catch_backtrace())
    end
end


function save(puzzle::Eternity2Puzzle)
    try
        filename = "$(score(puzzle)[1]).et2"
        filepath = NativeFileDialog.save_file(filename, filterlist="et2")
        if filepath == ""
            return
        elseif !endswith(filepath, ".et2")
            @warn "Board not saved; file extension must be .et2"
            return
        else
            isfile(filepath) && @warn "Overwriting existing file $filepath"
            save(puzzle, filepath)
            @info "Board was saved to file $filepath"
        end
    catch ex
        showerror(stdout, ex, catch_backtrace())
    end
end


# Main draw loop from GameZero
function draw(g::Game)
    draw(actors.score_label)
    ui.draw_board_highlight && draw(actors.board_highlight)
    for idx = 1:NPIECES
        if idx == ui.dragged_piece || idx == ui.animated_piece
            continue
        end
        draw(actors.puzzle_pieces[idx])
    end
    if isnothing(ui.overlay)
        if ui.highlight_matching_pieces
            for idx in ui.matching_pieces
                draw(actors.candidates_highlights[idx])
            end
        end
    else
        draw(actors.overlay)
        ui.draw_button_hover && draw(actors.button_hover)
        if ui.overlay == :main_menu
            ui.can_save && draw(actors.score_label2)
        elseif ui.overlay == :settings_menu
            ui.highlight_matching_pieces && draw(actors.checkmark1)
            ui.highlight_errors && draw(actors.checkmark2)
        end
        return
    end
    if ui.highlight_errors
        for idx in ui.errors
            draw(actors.error_highlights[idx])
        end
    end

    # ensure animated and dragged pieces are always drawn on top
    if ui.animated_piece > 0
        draw(actors.puzzle_pieces[ui.animated_piece])
    end
    if ui.dragged_piece > 0
        draw(actors.shadow)
        draw(actors.puzzle_pieces[ui.dragged_piece])
    end
end


function on_mouse_move(g::Game, pos)
    if ui.overlay == :main_menu
        ui.draw_button_hover = false
        if 547 < pos[1] < 845
            if 213 < pos[2] < 261
                actors.button_hover.pos = (547, 213)
                ui.draw_button_hover = true
            elseif 303 < pos[2] < 351
                actors.button_hover.pos = (547, 303)
                ui.draw_button_hover = true
            elseif ui.can_save && 393 < pos[2] < 441
                actors.button_hover.pos = (547, 393)
                ui.draw_button_hover = true
            elseif 483 < pos[2] < 521
                actors.button_hover.pos = (547, 483)
                ui.draw_button_hover = true
            elseif 573 < pos[2] < 621
                actors.button_hover.pos = (547, 573)
                ui.draw_button_hover = true
            end
        end
        return
    elseif ui.overlay == :settings_menu
        ui.draw_button_hover = false
        if 547 < pos[1] < 845 && 213 < pos[2] < 261  # Back
            actors.button_hover.pos = (547, 213)
            ui.draw_button_hover = true
        end
        return
    end
    if ui.dragged_piece > 0
        actors.puzzle_pieces[ui.dragged_piece].pos = (pos[1] - 24, pos[2] - 24)
        actors.shadow.pos = (pos[1] - 28, pos[2] - 28)
        update_board_highlight(pos)
    elseif ui.highlight_matching_pieces
        row, col = coords_to_rowcol(pos[1], pos[2])
        if (row, col) != (0, 0) && puzzle.board[row, col] == 0x0000
            update_highlighted_pieces(row, col)
        else
            ui.matching_pieces = Int[]
        end
    end
end


function on_mouse_down(g::Game, pos, button)
    isnothing(ui.overlay) || return
    row, col = coords_to_rowcol(pos[1], pos[2])
    if button == MouseButtons.LEFT && ui.dragged_piece == 0
        if (row, col) != (0, 0)
            val = puzzle.board[row, col]
            if val != 0x0000  # pick up piece from board
                piece = val >> 2
                piece == STARTER_PIECE && return
                ui.dragged_piece = piece
                ui.dragged_piece_rotation = val & 3
                puzzle.board[row, col] = 0x0000
                actors.puzzle_pieces[piece].pos = (pos[1] - 24, pos[2] - 24)
                actors.shadow.pos = (pos[1] - 28, pos[2] - 28)
                clear_matching_cache()
                update_board_highlight(pos)
                update_error_highlights()
                update_score()
            end
        else
            piece = coords_to_initial_position(pos[1], pos[2])
            if piece == 0 || piece in puzzle
                return
            end
            # pick up piece from start pile
            ui.dragged_piece = piece
            ui.dragged_piece_rotation = 0
            actors.puzzle_pieces[piece].pos = (pos[1] - 24, pos[2] - 24)
            actors.puzzle_pieces[piece].scale = [1, 1]
            actors.shadow.pos = (pos[1] - 28, pos[2] - 28)
        end
    elseif button == MouseButtons.RIGHT  # rotate clockwise
        if ui.dragged_piece > 0
            ui.dragged_piece_rotation = mod(ui.dragged_piece_rotation + 1, 4)
            rotate_animation(ui.dragged_piece, ui.dragged_piece_rotation)
        elseif (row, col) != (0, 0)
            val = puzzle.board[row, col]
            if val != 0x0000
                piece = val >> 2
                piece == STARTER_PIECE && return
                rotation = mod(val & 3 + 1, 4)
                puzzle.board[row, col] = piece << 2 | rotation
                clear_matching_cache()
                update_error_highlights()
                rotate_animation(piece, rotation)
                update_score()
            end
        end
    end
end


function on_mouse_up(g::Game, pos, button)
    if button == MouseButtons.LEFT
        if ui.overlay == :main_menu
            if 547 < pos[1] < 845
                if 213 < pos[2] < 261  # Play / Continue
                    ui.overlay = nothing
                    ui.draw_button_hover = false
                    actors.overlay.image = "menu2.png"
                    ui.can_save = true
                elseif 303 < pos[2] < 351  # Load
                    load!(puzzle)
                elseif 393 < pos[2] < 441 && ui.can_save  # Save
                    save(puzzle)
                elseif 483 < pos[2] < 521  # Settings
                    ui.overlay = :settings_menu
                    ui.draw_button_hover = false
                    actors.overlay.image = "menu3.png"
                elseif 573 < pos[2] < 621  # Quit
                    throw(GameZero.QuitException())
                end
            end
        elseif ui.overlay == :settings_menu
            if 547 < pos[1] < 845 && 213 < pos[2] < 261  # Back
                ui.overlay = :main_menu
                actors.overlay.image = ui.can_save ? "menu2.png" : "menu.png"
            elseif 591 < pos[1] < 605
                if 336 < pos[2] < 351
                    ui.highlight_matching_pieces = !ui.highlight_matching_pieces
                elseif 376 < pos[2] < 391
                    ui.highlight_errors = !ui.highlight_errors
                    ui.highlight_errors && update_error_highlights()
                end
            end
        elseif ui.dragged_piece > 0
            row, col = coords_to_rowcol(pos[1], pos[2])
            # Place piece if the mouse is hovering over an empty cell on the board
            if (row, col) != (0, 0) && puzzle.board[row, col] == 0x0000
                puzzle.board[row, col] = ui.dragged_piece << 2 | ui.dragged_piece_rotation
                actors.puzzle_pieces[ui.dragged_piece].pos = rowcol_to_coords(row, col)
                ui.dragged_piece = 0
                ui.dragged_piece_rotation = 0
                clear_matching_cache()
                update_board_highlight(pos)
                update_error_highlights()
                update_score()
            else  # Mouse button was released outside of the board or on top of another piece
                ui.animated_piece = ui.dragged_piece
                reset_animation(ui.dragged_piece, pos[1] - 24, pos[2] - 24, ui.dragged_piece_rotation)
                ui.dragged_piece = 0
                ui.dragged_piece_rotation = 0
            end
        end
    end
end


function on_key_down(g::Game, key)
    if key == 27  # Esc
        if isnothing(ui.overlay)
            update_score2()
            ui.overlay = :main_menu
            if ui.dragged_piece > 0
                actors.puzzle_pieces[ui.dragged_piece].pos = initial_position(ui.dragged_piece)
                actors.puzzle_pieces[ui.dragged_piece].angle = 0.0
                actors.puzzle_pieces[ui.dragged_piece].scale = [2//3, 2//3]
                ui.dragged_piece = 0
            end
        elseif ui.overlay == :main_menu
            ui.overlay = nothing
            ui.can_save = true
            if actors.overlay.image == "menu.png"
                actors.overlay.image = "menu2.png"
            end
        elseif ui.overlay == :settings_menu
            ui.overlay = :main_menu
            actors.overlay.image = ui.can_save ? "menu2.png" : "menu.png"
        end
    end
end
