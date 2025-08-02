<p>
  <h1 align="center">Eternity2Puzzles.jl</h1>
</p>

[![Docs](https://img.shields.io/badge/docs-dev-blue.svg)](https://jwortmann.github.io/Eternity2Puzzles.jl/)
[![Julia](https://img.shields.io/badge/Julia-1.10%2B-9558b2.svg)](https://julialang.org/)
[![Version](https://juliahub.com/docs/General/Eternity2Puzzles/stable/version.svg)](https://juliahub.com/ui/Packages/General/Eternity2Puzzles)
[![License](https://img.shields.io/github/license/jwortmann/Eternity2Puzzles.jl)](https://github.com/jwortmann/Eternity2Puzzles.jl/blob/main/LICENSE)

<p align="center">
  <img src="svg/logo.svg">
</p>

Eternity2Puzzles.jl is an implementation of the [Eternity II puzzle](https://en.wikipedia.org/wiki/Eternity_II_puzzle) in the [Julia](https://julialang.org/) programming language.
This package allows to either play the puzzle as an interactive game, or to attempt to find a solution using a brute-force backtracking search.


## Installation

This package is registered in the Julia package registry and can be installed using the built-in package manager from the Julia REPL:

```
julia> ]

pkg> add Eternity2Puzzles
```

> [!IMPORTANT]
> Please note that the package is only tested on Windows and that the interactive game part might not work correctly on a Mac with Retina display.


## Rules

The goal is to place all 256 pieces on the board, such that the colors and symbols of adjoining pairs of edges match, and with the grey edges around the outside.
Piece number 139 is a mandatory starter-piece with a fixed position on the board, that can neither be moved nor rotated.


## Basic usage

To start the interactive game, type in the Julia REPL:

```julia
julia> using Eternity2Puzzles

julia> play()
```

Puzzle pieces can be moved with the left mouse button and rotated with a right click.

You can also use the commands `play(:clue1)`, `play(:clue2)` or `play(:clue4)` to play one of the smaller clue puzzles.

Please visit the [documentation](https://jwortmann.github.io/Eternity2Puzzles.jl/) for a detailed description about more features of this package, for example how to run a solver algorithm.


## Preview

![Preview](img/preview.png)
