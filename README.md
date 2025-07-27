<p>
  <h1 align="center">Eternity2Puzzles.jl</h1>
</p>

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

Please visit the [documentation]() for a detailed description about more features of this package, for example how to run an automatic solver algorithm and how to calculate an estimation for the number of solutions of an arbitrary Eternity II type puzzle.


## Preview

![Preview](img/preview.png)
