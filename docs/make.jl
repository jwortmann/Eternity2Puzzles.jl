push!(LOAD_PATH, "../src/")

using Documenter
using DocumenterCitations
using Eternity2Puzzles

bib = CitationBibliography(joinpath(@__DIR__, "src", "refs.bib"); style=:numeric)

makedocs(
    sitename = "Eternity2Puzzles.jl",
    format = Documenter.HTML(
        # prettyurls = false,
        edit_link = nothing,
        mathengine = Documenter.KaTeX(Dict(:fleqn => true)),
        footer = nothing
    ),
    # draft = true,
    pages = [
        "Overview" => "index.md",
        "Theory" => "theory.md",
        "Solvers" => "solvers.md",
        "API Reference" => "reference.md"
    ],
    plugins = [bib]
)

deploydocs(
    repo = "github.com/jwortmann/Eternity2Puzzles.jl.git",
    devbranch = "main",
    forcepush = true,
    versions = nothing
)
