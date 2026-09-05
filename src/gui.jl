import GLFW
using ModernGL


const glfwCreateWindow = GLFW.CreateWindow
const glfwDestroyWindow = GLFW.DestroyWindow
const glfwGetCursorPos = GLFW.GetCursorPos
const glfwMakeContextCurrent = GLFW.MakeContextCurrent
const glfwPollEvents = GLFW.PollEvents
const glfwSetCursorPosCallback = GLFW.SetCursorPosCallback
const glfwSetKeyCallback = GLFW.SetKeyCallback
const glfwSetMouseButtonCallback = GLFW.SetMouseButtonCallback
const glfwSetWindowIcon = GLFW.SetWindowIcon
const glfwSetWindowTitle = GLFW.SetWindowTitle
const glfwSwapBuffers = GLFW.SwapBuffers
const glfwSwapInterval = GLFW.SwapInterval
const glfwWaitEvents = GLFW.WaitEvents
const glfwWindowHint = GLFW.WindowHint
const glfwWindowShouldClose = GLFW.WindowShouldClose


function gl_gen_textures(n)::GLuint
    textures = Ref{GLuint}()
    glGenTextures(n, textures)
    return textures[]
end

function gl_gen_vertex_arrays(n)::GLuint
    arrays = Ref{GLuint}()
    glGenVertexArrays(n, arrays)
    return arrays[]
end

function gl_gen_buffers(n)::GLuint
    buffers = Ref{GLuint}()
    glGenBuffers(n, buffers)
    return buffers[]
end

function gl_get_shaderiv(shader, pname)::GLint
    status = Ref{GLint}()
    glGetShaderiv(shader, pname, status)
    return status[]
end

function gl_get_programiv(program, pname)::GLint
    status = Ref{GLint}()
    glGetProgramiv(program, pname, status)
    return status[]
end


function update_window_title(window::GLFW.Window, puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    max_score = 2 * nrows * ncols - nrows - ncols
    glfwSetWindowTitle(window, "Eternity II - Score: $(score(puzzle)[1])/$max_score")
end


const ICONS = reinterpret.(NTuple{4, UInt8}, PNGFiles.load.([normpath("$(@__FILE__)/../../assets/$icon") for icon in ["icon16.png", "icon24.png", "icon48.png"]]))


function create_texture(texture_img::Matrix{RGBA{N0f8}}, slot = 0)
    @assert slot <= 32 "Invalid texture slot $slot"
    texture_id = gl_gen_textures(1)
    glActiveTexture(GL_TEXTURE0 + slot)
    glBindTexture(GL_TEXTURE_2D, texture_id)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE)
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE)
    height, width = size(texture_img)
    bytes = vec(reinterpret(UInt8, permutedims(texture_img)))
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA8, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, bytes)
    return texture_id
end

create_texture(filename::String, slot = 0) = create_texture(convert(Matrix{RGBA{N0f8}}, PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/$filename"))), slot)

function background_texture(puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    npieces = size(puzzle.pieces, 1)
    if nrows == ncols == 16 && npieces == 256
        return convert(Matrix{RGBA{N0f8}}, PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/background_16x16.png")))
    end
    stock_rows = fld1(npieces, 12)
    width = 592 + ncols * 49
    height = max(112 + nrows * 49, 60 + 38 * stock_rows)
    board_bb = BoundingBox(57, 57, 56 + 49 * ncols, 56 + 49 * nrows)
    stock_bb = BoundingBox(100 + 49 * ncols, 33, 550 + 49 * ncols, 27 + 38 * stock_rows)
    background_img = Matrix{RGBA{N0f8}}(undef, height, width)
    background_color = RGBA{N0f8}(0.353, 0.506, 0.541, 1.0)
    fill!(background_img, background_color)
    background_img[31:46, 57:56+49*ncols] = convert(Matrix{RGBA{N0f8}}, PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/background_cols.png")))[:, 1:49*ncols]
    background_img[57:56+49*nrows, 32:47] = convert(Matrix{RGBA{N0f8}}, PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/background_rows.png")))[1:49*nrows, :]
    background_img[board_bb.ymin:board_bb.ymax+1, board_bb.xmin:board_bb.xmax+1] = convert(Matrix{RGBA{N0f8}}, board_background_image(nrows, ncols))
    background_img[31:30+38*stock_rows, stock_bb.xmin-2:stock_bb.xmax+3] = convert(Matrix{RGBA{N0f8}}, PNGFiles.load(normpath("$(@__FILE__)/../../assets/textures/background_pieces.png")))[1:38*stock_rows, :]
    stock_trailing_cols = mod(npieces, 12)
    if stock_trailing_cols > 0
        background_img[38*stock_rows-7:30+38*stock_rows, stock_bb.xmin-2+38*stock_trailing_cols:stock_bb.xmax+3] .= background_color
    end
    return background_img
end

function pieces_texture(puzzle::Eternity2Puzzle)
    npieces = size(puzzle.pieces, 1)
    grey = RGBA{N0f8}(0.196, 0.192, 0.208, 1.0)
    colors_img = convert(Matrix{RGBA{N0f8}}, COLOR_PATTERNS_IMG)
    pieces_img = Matrix{RGBA{N0f8}}(undef, 192, 48 * npieces)
    for piece = 1:npieces
        c1, c2, c3, c4 = puzzle.pieces[piece, :]
        offset = 48 * (piece - 1)
        piece_img = colors_img[:, 48*c3+1:48*c3+48] + rotr90(colors_img[:, 48*c4+1:48*c4+48]) + rot180(colors_img[:, 48*c1+1:48*c1+48]) + rotl90(colors_img[:, 48*c2+1:48*c2+48])
        # Set opaque color for diagonal pixels which are half-transparent
        for i = 1:48
            piece_img[i, i] = grey
            piece_img[i, 49-i] = grey
        end
        pieces_img[  1: 48, offset+1:offset+48] = piece_img
        pieces_img[ 49: 96, offset+1:offset+48] = rotr90(piece_img)
        pieces_img[ 97:144, offset+1:offset+48] = rot180(piece_img)
        pieces_img[145:192, offset+1:offset+48] = rotl90(piece_img)
    end
    return pieces_img
end

function create_shader(type_::GLenum, filename::String)
    filepath = normpath("$(@__FILE__)/../../shaders/$filename")
    source = read(filepath, String)
    shader_id::GLuint = glCreateShader(type_)
    @assert shader_id != 0 "Error creating shader"
    glShaderSource(shader_id, 1, Ref(pointer(source)), C_NULL)
    glCompileShader(shader_id)
    @assert gl_get_shaderiv(shader_id, GL_COMPILE_STATUS) == GL_TRUE "Shader compilation error"
    return shader_id
end


# 4x4 orthographic projection matrix
# https://registry.khronos.org/OpenGL-Refpages/gl2.1/xhtml/glOrtho.xml
function ortho(l::Float32, r::Float32, b::Float32, t::Float32, nearVal::Float32 = -1.0f0, farVal::Float32 = 1.0f0)
    M = zeros(Float32, 4, 4)
    M[1, 1] =  2.0f0 / (r - l)
    M[2, 2] =  2.0f0 / (t - b)
    M[3, 3] = -2.0f0 / (farVal - nearVal)
    M[4, 4] =  1.0f0
    M[1, 4] = -(r + l) / (r - l)
    M[2, 4] = -(t + b) / (t - b)
    M[3, 4] = -(farVal + nearVal) / (farVal - nearVal)
    return M
end

ortho(width::Int, height::Int) = ortho(0.0f0, Float32(width), Float32(height), 0.0f0)

# 4x4 translation matrix
function translate(dx::Float32, dy::Float32, dz::Float32 = 0.0f0)
    return Float32[1.0f0 0.0f0 0.0f0 dx; 0.0f0 1.0f0 0.0f0 dy; 0.0f0 0.0f0 1.0f0 dz; 0.0f0 0.0f0 0.0f0 1.0f0]
end

# 4x4 rotation matrix
function rotate(angle::Float32)
    s = sind(angle)
    c = cosd(angle)
    return Float32[c -s 0.0f0 0.0f0; s c 0.0f0 0.0f0; 0.0f0 0.0f0 1.0f0 0.0f0; 0.0f0 0.0f0 0.0f0 1.0f0]
end

# 4x4 projection matrix
function projection_matrix(window_width::Int, window_height::Int, x::Float64, y::Float64, rotation::Float32)
    proj = ortho(window_width, window_height)
    if rotation != 0.0
        dx = Float32(x)
        dy = Float32(y)
        proj *= translate(dx, dy) * rotate(rotation) * translate(-dx, -dy)
    end
    return proj
end

projection_matrix(window_width::Int, window_height::Int, x::Float64, y::Float64, w::Float64, h::Float64, rotation::Float32 = 0.0f0) = projection_matrix(window_width, window_height, x+w/2, y+h/2, rotation)

smoothstep(a, b, n) = [a + (b-a)*(3*(k/(n-1))^2 - 2*(k/(n-1))^3) for k in 0:n-1]

struct BoundingBox
    xmin::Int
    ymin::Int
    xmax::Int
    ymax::Int
end

Base.in(pos::NTuple{2, <:Real}, bb::BoundingBox) = bb.xmin <= pos[1] <= bb.xmax && bb.ymin <= pos[2] <= bb.ymax

mutable struct UIState
    active_piece::Int
    active_piece_rotation::Int
    animation_frames::Int
    show_hints::Bool
    hover_row::Int
    hover_col::Int
    highlighted_pieces::Dict{Tuple{Int, Int}, Vector{Int}}
end

# Pixel position of a board square
function get_pos(bb::BoundingBox, row::Int, col::Int)::Tuple{Float32, Float32}
    return (bb.xmin + 49 * (col - 1), bb.ymin + 49 * (row - 1))
end

# Pixel position of a piece in the stock
function get_pos(bb::BoundingBox, piece::Int)::Tuple{Float32, Float32}
    row, col = divrem(piece - 1, 12)
    return (bb.xmin + 38 * col, bb.ymin + 38 * row)
end

function _get_constraints(puzzle::Eternity2Puzzle, row::Int, col::Int)::Vector{Union{UInt8, Nothing}}
    nrows, ncols = size(puzzle.board)
    if row == 1
        t = 0x00
        piece, rotation = puzzle[2, col]
        b = iszero(piece) ? nothing : puzzle.pieces[piece, mod1(3 - rotation, 4)]
    elseif row == nrows
        piece, rotation = puzzle[row - 1, col]
        t = iszero(piece) ? nothing : puzzle.pieces[piece, mod1(1 - rotation, 4)]
        b = 0x00
    else
        piece, rotation = puzzle[row - 1, col]
        t = iszero(piece) ? nothing : puzzle.pieces[piece, mod1(1 - rotation, 4)]
        piece, rotation = puzzle[row + 1, col]
        b = iszero(piece) ? nothing : puzzle.pieces[piece, mod1(3 - rotation, 4)]
    end
    if col == 1
        l = 0x00
        piece, rotation = puzzle[row, 2]
        r = iszero(piece) ? nothing : puzzle.pieces[piece, mod1(2 - rotation, 4)]
    elseif col == ncols
        piece, rotation = puzzle[row, col - 1]
        l = iszero(piece) ? nothing : puzzle.pieces[piece, 4 - rotation]
        r = 0x00
    else
        piece, rotation = puzzle[row, col - 1]
        l = iszero(piece) ? nothing : puzzle.pieces[piece, 4 - rotation]
        piece, rotation = puzzle[row, col + 1]
        r = iszero(piece) ? nothing : puzzle.pieces[piece, mod1(2 - rotation, 4)]
    end
    return [b, l, t, r]
end


function create_index_vector(num_quads::Int)
    indices = Vector{UInt32}(undef, num_quads * 6)
    offset = 0
    for i = 1:6:length(indices)
        indices[i + 0] = 0 + offset
        indices[i + 1] = 1 + offset
        indices[i + 2] = 2 + offset
        indices[i + 3] = 2 + offset
        indices[i + 4] = 3 + offset
        indices[i + 5] = 0 + offset
        offset += 4
    end
    return indices
end


# Store vertex values for a quad with coordinates `x0`, `y0`, `x1`, `y1` and with texture
# coordinates `tex_x0`, `tex_y0`, `tex_x1`, `tex_y1` into the preallocated vector `vertices`
# starting at (zero-based) index `idx`.
function set_quad_vertices!(
    vertices::Vector{Float32},
    idx::Int,
    x0::Float32,
    y0::Float32,
    x1::Float32,
    y1::Float32,
    tex_x0::Float32 = 0f0,
    tex_y0::Float32 = 0f0,
    tex_x1::Float32 = 1f0,
    tex_y1::Float32 = 1f0
)
    vertices[idx +  1] = x0
    vertices[idx +  2] = y0
    vertices[idx +  3] = tex_x0
    vertices[idx +  4] = tex_y0
    vertices[idx +  5] = x1
    vertices[idx +  6] = y0
    vertices[idx +  7] = tex_x1
    vertices[idx +  8] = tex_y0
    vertices[idx +  9] = x1
    vertices[idx + 10] = y1
    vertices[idx + 11] = tex_x1
    vertices[idx + 12] = tex_y1
    vertices[idx + 13] = x0
    vertices[idx + 14] = y1
    vertices[idx + 15] = tex_x0
    vertices[idx + 16] = tex_y1
    return nothing
end


"""
    play!()
    play!(:clue1)
    play!(:clue2)
    play!(:clue3)
    play!(:clue4)
    play!(puzzle::Eternity2Puzzle)

Start the interactive GUI. Supported board sizes (rows x columns) are 16x16, 6x6, and 6x12.
"""
function play!(puzzle::Eternity2Puzzle)
    nrows, ncols = size(puzzle.board)
    @assert nrows <= 16 "Puzzle must have at most 16 rows"
    @assert ncols <= 16 "Puzzle must have at most 16 columns"
    npieces = size(puzzle.pieces, 1)
    @assert npieces <= 264 "Puzzle must have at most 264 pieces"
    @assert npieces >= nrows * ncols "Puzzle for this board size must have at least $(nrows * ncols) pieces"
    @assert all(puzzle.pieces .<= 22) "Only 22 different color patterns are supported, but found color number $(maximum(puzzle.pieces))"

    stock_rows = fld1(npieces, 12)
    width = 592 + ncols * 49
    height = max(112 + nrows * 49, 60 + 38 * stock_rows)
    board_bb = BoundingBox(57, 57, 56 + 49 * ncols, 56 + 49 * nrows)
    stock_bb = BoundingBox(100 + 49 * ncols, 33, 550 + 49 * ncols, 27 + 38 * stock_rows)
    has_fixed_starter_piece = nrows == 16 && ncols == 16 && puzzle["I8"] == (139, 2)
    tex_dx = Float32(1 / npieces)
    piece_numbers = [[piece for (piece, piece_colors) in enumerate(eachrow(puzzle.pieces)) if count(iszero, piece_colors) == border_edges] for border_edges = 0:2]
    animation_frames_count = 10
    rotation_angles = convert(Vector{Float32}, smoothstep(0f0, -90f0, animation_frames_count+1))

    state = UIState(0, 0, 0, false, 0, 0, Dict{Tuple{Int, Int}, Vector{Int}}())
    placed_pieces = fill(false, npieces)

    glfwWindowHint(GLFW.RESIZABLE, false)
    window = glfwCreateWindow(width, height, "Eternity II")
    glfwSetWindowIcon(window, ICONS)
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)

    update_window_title(window, puzzle)

    function on_mouse_button_event(w::GLFW.Window, button::GLFW.MouseButton, action::GLFW.Action, mods::Cint)
        pos = glfwGetCursorPos(w)
        x = Int(pos.x)
        y = Int(pos.y)
        if button == GLFW.MOUSE_BUTTON_LEFT
            if action == GLFW.PRESS
                if (x, y) in board_bb
                    row, r = fldmod1(y + 1 - board_bb.ymin, 49)
                    if r > 48 return end
                    col, r = fldmod1(x + 1 - board_bb.xmin, 49)
                    if r > 48 return end
                    if has_fixed_starter_piece && row == 9 && col == 8 return end
                    piece, rotation = puzzle[row, col]
                    if piece == 0 return end
                    # Pick up piece from the board
                    puzzle[row, col] = (0, 0)
                    placed_pieces[piece] = false
                    state.active_piece = piece
                    state.active_piece_rotation = rotation
                    empty!(state.highlighted_pieces)
                    update_window_title(w, puzzle)
                elseif (x, y) in stock_bb
                    row, r = fldmod1(y + 1 - stock_bb.ymin, 38)
                    if r > 32 return end
                    col, r = fldmod1(x + 1 - stock_bb.xmin, 38)
                    if r > 32 return end
                    piece = 12 * row + col - 12
                    if piece > npieces return end
                    if placed_pieces[piece] return end
                    # Pick up piece from stock
                    state.active_piece = piece
                    state.active_piece_rotation = 0
                end
            elseif action == GLFW.RELEASE
                if state.active_piece != 0
                    if (x, y) in board_bb
                        row, r1 = fldmod1(y + 1 - board_bb.ymin, 49)
                        col, r2 = fldmod1(x + 1 - board_bb.xmin, 49)
                        if r1 < 49 && r2 < 49 && puzzle[row, col][1] == 0
                            # Place piece onto the board
                            puzzle[row, col] = (state.active_piece, state.active_piece_rotation)
                            placed_pieces[state.active_piece] = true
                            empty!(state.highlighted_pieces)
                            update_window_title(w, puzzle)
                        end
                    end
                    state.active_piece = 0
                end
            end
        elseif button == GLFW.MOUSE_BUTTON_RIGHT
            if action == GLFW.PRESS
                if state.active_piece == 0
                    if (x, y) in board_bb
                        row, r = fldmod1(y + 1 - board_bb.ymin, 49)
                        if r > 48 return end
                        col, r = fldmod1(x + 1 - board_bb.xmin, 49)
                        if r > 48 return end
                        if has_fixed_starter_piece && row == 9 && col == 8 return end
                        piece, rotation = puzzle[row, col]
                        if piece == 0 return end
                        # Rotate piece on the board
                        puzzle[row, col] = (piece, mod(rotation + 1, 4))
                        empty!(state.highlighted_pieces)
                        update_window_title(w, puzzle)
                    end
                else
                    # Rotate the active piece
                    state.active_piece_rotation = mod(state.active_piece_rotation + 1, 4)
                    state.animation_frames = animation_frames_count
                end
            end
        end
    end

    function on_cursor_pos_event(w::GLFW.Window, x::Cdouble, y::Cdouble)
        x = Int(x)
        y = Int(y)
        state.hover_row = 0
        if !((x, y) in board_bb) return end
        row, r = fldmod1(y + 1 - board_bb.ymin, 49)
        if r > 48 return end
        col, r = fldmod1(x + 1 - board_bb.xmin, 49)
        if r > 48 return end
        state.hover_row = row
        state.hover_col = col
        # Calculate applicable pieces for the currently hovered empty square
        if !state.show_hints return end
        if puzzle[row, col][1] != 0 return end
        if state.active_piece != 0 return end
        if haskey(state.highlighted_pieces, (row, col)) return end
        state.highlighted_pieces[row, col] = Int[]
        edge_colors = _get_constraints(puzzle, row, col)
        constraints_filter = .!isnothing.(edge_colors)
        if !any(constraints_filter) return end  # No highlighting for unconstraint inner pieces
        constraints = edge_colors[constraints_filter]
        for piece in piece_numbers[count(iszero, constraints) + 1]
            if placed_pieces[piece] continue end
            for rotation = 0:3
                if circshift(puzzle.pieces[piece, :], rotation)[constraints_filter] == constraints
                    push!(state.highlighted_pieces[row, col], piece)
                    break
                end
            end
        end
    end

    function on_key_event(w::GLFW.Window, key::GLFW.Key, scancode::Cint, action::GLFW.Action, mods::Cint)
        if key == GLFW.KEY_H && action == GLFW.PRESS
            # Toggle applicable pieces highlight
            state.show_hints = !state.show_hints
            if state.show_hints
                pos = glfwGetCursorPos(w)
                on_cursor_pos_event(w, pos.x, pos.y)
            end
        end
    end

    glfwSetMouseButtonCallback(window, on_mouse_button_event)
    glfwSetCursorPosCallback(window, on_cursor_pos_event)
    glfwSetKeyCallback(window, on_key_event)

    GC.gc()

    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    vertex_shader_id = create_shader(GL_VERTEX_SHADER, "vertex.glsl")
    fragment_shader_id = create_shader(GL_FRAGMENT_SHADER, "fragment.glsl")
    program_id::GLuint = glCreateProgram()
    @assert program_id != 0 "Error creating shader program"
    glAttachShader(program_id, vertex_shader_id)
    glAttachShader(program_id, fragment_shader_id)
    glLinkProgram(program_id)
    @assert gl_get_programiv(program_id, GL_LINK_STATUS) == GL_TRUE "Error linking shader program"
    proj_id::GLint = glGetUniformLocation(program_id, "proj")
    texture_sampler_id::GLint = glGetUniformLocation(program_id, "u_TextureSampler")
    glDeleteShader(vertex_shader_id)
    glDeleteShader(fragment_shader_id)
    glUseProgram(program_id)

    create_texture(background_texture(puzzle), 0)
    create_texture(pieces_texture(puzzle), 1)
    create_texture("highlight.png", 2)
    create_texture("shadow.png", 3)
    create_texture("highlight_small.png", 4)

    proj = ortho(width, height)
    glUniformMatrix4fv(proj_id, 1, GL_FALSE, proj)

    vao = gl_gen_vertex_arrays(1)
    glBindVertexArray(vao)

    vertices = Vector{Float32}(undef, npieces * 16)
    indices = create_index_vector(npieces)

    bg_vertices = Float32[0, 0, 0, 0, width, 0, 1, 0, width, height, 1, 1, 0, height, 0, 1]

    vbo = gl_gen_buffers(1)
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), Ptr{Cvoid}(C_NULL), GL_DYNAMIC_DRAW)

    glEnableVertexAttribArray(0)
    stride = 4 * sizeof(Float32)
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, stride, Ptr{Cvoid}(0))

    ibo = gl_gen_buffers(1)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

    try
        # Render loop
        while !glfwWindowShouldClose(window)
            # Draw background
            glBufferSubData(GL_ARRAY_BUFFER, 0, 64, bg_vertices)
            glUniform1i(texture_sampler_id, 0)
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, Ptr{Cvoid}(0))

            # Pieces placed on the board
            idx = 0
            pieces = 0
            for col = 1:ncols, row = 1:nrows
                piece, rotation = puzzle[row, col]
                if piece != 0
                    pieces += 1
                    x0, y0 = get_pos(board_bb, row, col)
                    x1 = x0 + 48f0
                    y1 = y0 + 48f0
                    tex_x1 = tex_dx * piece
                    tex_x0 = tex_x1 - tex_dx
                    tex_y0 = 0.25f0 * rotation
                    tex_y1 = tex_y0 + 0.25f0
                    set_quad_vertices!(vertices, idx, x0, y0, x1, y1, tex_x0, tex_y0, tex_x1, tex_y1)
                    idx += 16
                    placed_pieces[piece] = true
                end
            end
            # Unplaced pieces
            for piece = 1:npieces
                if placed_pieces[piece] continue end
                if state.active_piece == piece continue end
                pieces += 1
                x0, y0 = get_pos(stock_bb, piece)
                x1 = x0 + 32f0
                y1 = y0 + 32f0
                tex_x1 = tex_dx * piece
                tex_x0 = tex_x1 - tex_dx
                tex_y0 = 0f0
                tex_y1 = 0.25f0
                set_quad_vertices!(vertices, idx, x0, y0, x1, y1, tex_x0, tex_y0, tex_x1, tex_y1)
                idx += 16
            end
            glBufferSubData(GL_ARRAY_BUFFER, 0, idx * sizeof(Float32), vertices[1:idx])
            glUniform1i(texture_sampler_id, 1)
            glDrawElements(GL_TRIANGLES, 6 * pieces, GL_UNSIGNED_INT, Ptr{Cvoid}(0))

            if state.active_piece == 0
                # Draw applicable pieces highlight
                if state.show_hints && state.hover_row != 0
                    idx = 0
                    pieces = 0
                    for piece in get(state.highlighted_pieces, (state.hover_row, state.hover_col), [])
                        pieces += 1
                        x0, y0 = get_pos(stock_bb, piece)
                        x1 = x0 + 32f0
                        y1 = y0 + 32f0
                        set_quad_vertices!(vertices, idx, x0, y0, x1, y1)
                        idx += 16
                    end
                    if pieces != 0
                        glBufferSubData(GL_ARRAY_BUFFER, 0, idx * sizeof(Float32), vertices[1:idx])
                        glUniform1i(texture_sampler_id, 4)
                        glDrawElements(GL_TRIANGLES, 6 * pieces, GL_UNSIGNED_INT, Ptr{Cvoid}(0))
                    end
                end
            else
                pos = glfwGetCursorPos(window)
                # Draw highlighted square
                if state.hover_row != 0 && puzzle[state.hover_row, state.hover_col][1] == 0
                    x1 = board_bb.xmin + 49 * state.hover_col
                    y1 = board_bb.ymin + 49 * state.hover_row
                    x0 = x1 - 50
                    y0 = y1 - 50
                    glBufferSubData(GL_ARRAY_BUFFER, 0, 64, Float32[x0, y0, 0, 0, x1, y0, 1, 0, x1, y1, 1, 1, x0, y1, 0, 1])
                    glUniform1i(texture_sampler_id, 2)
                    glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, Ptr{Cvoid}(0))
                end
                # Draw active piece shadow
                x0 = pos.x - 28
                y0 = pos.y - 28
                x1 = pos.x + 28
                y1 = pos.y + 28
                if state.animation_frames > 0
                    glUniformMatrix4fv(proj_id, 1, GL_FALSE, projection_matrix(width, height, pos.x, pos.y, rotation_angles[state.animation_frames]))
                end
                glBufferSubData(GL_ARRAY_BUFFER, 0, 64, Float32[x0, y0, 0, 0, x1, y0, 1, 0, x1, y1, 1, 1, x0, y1, 0, 1])
                glUniform1i(texture_sampler_id, 3)
                glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, Ptr{Cvoid}(0))
                # Draw active piece
                x0 = pos.x - 24
                y0 = pos.y - 24
                x1 = pos.x + 24
                y1 = pos.y + 24
                tex_x1 = tex_dx * state.active_piece
                tex_x0 = tex_x1 - tex_dx
                tex_y0 = 0.25f0 * state.active_piece_rotation
                tex_y1 = tex_y0 + 0.25f0
                glBufferSubData(GL_ARRAY_BUFFER, 0, 64, Float32[x0, y0, tex_x0, tex_y0, x1, y0, tex_x1, tex_y0, x1, y1, tex_x1, tex_y1, x0, y1, tex_x0, tex_y1])
                glUniform1i(texture_sampler_id, 1)
                glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, Ptr{Cvoid}(0))
                if state.animation_frames > 0
                    glUniformMatrix4fv(proj_id, 1, GL_FALSE, proj)
                    state.animation_frames -= 1
                end
            end

            glfwSwapBuffers(window)
            if state.animation_frames == 0
                glfwWaitEvents()
            else
                glfwPollEvents()
            end
        end
    finally
        glfwDestroyWindow(window)
    end
end

play!() = play!(Eternity2Puzzle())
play!(puzzle::Symbol) = play!(Eternity2Puzzle(puzzle))

# Non-interactive continuous rendering of the puzzle board
function render(puzzle::Eternity2Puzzle)
    @assert all(puzzle.pieces .<= 22)
    nrows, ncols = size(puzzle.board)
    nsquares = nrows * ncols
    npieces = size(puzzle.pieces, 1)
    tex_dx = Float32(1 / npieces)
    background_img = convert(Matrix{RGBA{N0f8}}, board_background_image(nrows, ncols))
    height, width = size(background_img)

    glfwWindowHint(GLFW.RESIZABLE, false)
    window = glfwCreateWindow(width, height, "Eternity II")
    glfwSetWindowIcon(window, ICONS)
    glfwMakeContextCurrent(window)
    glfwSwapInterval(1)

    GC.gc()

    glEnable(GL_BLEND)
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

    vertex_shader_id = create_shader(GL_VERTEX_SHADER, "vertex.glsl")
    fragment_shader_id = create_shader(GL_FRAGMENT_SHADER, "fragment.glsl")
    program_id::GLuint = glCreateProgram()
    @assert program_id != 0 "Error creating shader program"
    glAttachShader(program_id, vertex_shader_id)
    glAttachShader(program_id, fragment_shader_id)
    glLinkProgram(program_id)
    @assert gl_get_programiv(program_id, GL_LINK_STATUS) == GL_TRUE "Error linking shader program"
    proj_id::GLint = glGetUniformLocation(program_id, "proj")
    texture_sampler_id::GLint = glGetUniformLocation(program_id, "u_TextureSampler")
    glDeleteShader(vertex_shader_id)
    glDeleteShader(fragment_shader_id)
    glUseProgram(program_id)

    create_texture(background_img, 0)
    create_texture(pieces_texture(puzzle), 1)

    proj = ortho(width, height)
    glUniformMatrix4fv(proj_id, 1, GL_FALSE, proj)

    vao = gl_gen_vertex_arrays(1)
    glBindVertexArray(vao)

    vertices = Vector{Float32}(undef, nsquares * 16)
    indices = create_index_vector(nsquares)

    bg_vertices = Float32[0, 0, 0, 0, width, 0, 1, 0, width, height, 1, 1, 0, height, 0, 1]

    vbo = gl_gen_buffers(1)
    glBindBuffer(GL_ARRAY_BUFFER, vbo)
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), Ptr{Cvoid}(C_NULL), GL_DYNAMIC_DRAW)

    glEnableVertexAttribArray(0)
    stride = 4 * sizeof(Float32)
    glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, stride, Ptr{Cvoid}(0))

    ibo = gl_gen_buffers(1)
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo)
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW)

    try
        while !glfwWindowShouldClose(window)
            # Draw background
            glBufferSubData(GL_ARRAY_BUFFER, 0, sizeof(bg_vertices), bg_vertices)
            glUniform1i(texture_sampler_id, 0)
            glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, Ptr{Cvoid}(0))

            # Draw pieces placed on the board
            idx = 0
            pieces = 0
            for col = 1:ncols, row = 1:nrows
                piece, rotation = puzzle[row, col]
                if piece != 0
                    pieces += 1
                    x1 = 49f0 * col
                    x0 = x1 - 48f0
                    y1 = 49f0 * row
                    y0 = y1 - 48f0
                    tex_x1 = tex_dx * piece
                    tex_x0 = tex_x1 - tex_dx
                    tex_y0 = 0.25f0 * rotation
                    tex_y1 = tex_y0 + 0.25f0
                    set_quad_vertices!(vertices, idx, x0, y0, x1, y1, tex_x0, tex_y0, tex_x1, tex_y1)
                    idx += 16
                end
            end
            if pieces != 0
                glBufferSubData(GL_ARRAY_BUFFER, 0, idx * sizeof(Float32), vertices[1:idx])
                glUniform1i(texture_sampler_id, 1)
                glDrawElements(GL_TRIANGLES, 6 * pieces, GL_UNSIGNED_INT, Ptr{Cvoid}(0))
            end

            glfwSwapBuffers(window)
            glfwPollEvents()
        end
    finally
        glfwDestroyWindow(window)
    end
end
