module ImageInTerminalExt

using Eternity2Puzzles
import ImageInTerminal


function Base.show(io::IOContext, mime::MIME"text/plain", puzzle::Eternity2Puzzle)
    if ImageInTerminal.ENCODER_BACKEND[] == :Sixel && ImageInTerminal.SHOULD_RENDER_IMAGE[]
        println(io, summary(puzzle), ":")
        display("image/png", puzzle)
    else
        invoke(Base.show, Tuple{IO, typeof(mime), Eternity2Puzzle}, io, mime, puzzle)
    end
end

end
