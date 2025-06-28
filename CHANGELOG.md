Eternity2Puzzles.jl Changelog
=============================

v0.2.0 (2025-??-??)
-------------------

Breaking changes:

* The required minimum Julia version is now 1.10.

* Changed some of the arguments of the `Eternity2Puzzle` type constructor;
  the argument to specify the piece definitions is now a positional argument
  and to load a puzzle board from a file, the `load!` function must be used.
  See the docstring of `Eternity2Puzzle` for more details and examples.

* The `initialize_pieces` function has been removed. You can now use the
  `Eternity2Puzzle` constructor without arguments to create a puzzle with the
  original Eternity II pieces.

* The `generate_pieces` function has been removed. Instead, the `Eternity2Puzzle`
  constructor can be used directly to create a puzzle instance with randomly
  generated pieces for a given board size. The number of frame and inner colors
  can be adjusted with the `frame_colors` and `inner_colors` keyword arguments.
  The puzzle board is automatically filled with a valid piece configuration for
  a full solution and you can use the `reset!` function to clear the board.

* Renamed the included solvers `BacktrackingSearch` to `HeuristicBacktrackingSearch`
  and `BacktrackingSearchRecursive` to `SimpleBacktrackingSearch` (using a loop
  instead of recursive function calls now).


New features and improvements:

* Added the ability to play the smaller 6x6 Clue Puzzle 1 with `play(:clue1)`
  and the 6x12 Clue Puzzles 2 and 4 with `play(:clue2)` or `play(:clue4)`.
  These puzzles can be solved by hand. More general, you can now play any
  given puzzle with a board size of either 16x16, 6x6, or 6x12 via
  `play(puzzle::Eternity2Puzzle)`.

* Added a new `estimate_solutions` function to predict the number of valid
  solutions for any given `Eternity2Puzzle`.

* An `Eternity2Puzzle` can now be created with more puzzle pieces than are
  necessary to fill the entire board. This allows, for example, to solve a
  smaller sized board using only a subset of the original Eternity II pieces.

* Added support for the `preview` function to render puzzles that use more
  than the 22 standard color patterns. In this case the patterns are replaced
  by plain colors.

* Added the ability to display an `Eternity2Puzzle` in form of an image directly
  in the REPL. This only works for terminals with Sixel graphics support. To
  enable this feature, install the ImageInTerminal.jl package and load it in
  your REPL session via `using ImageInTerminal`. You can toggle between text
  output and image rendering with the `ImageInTerminal.disable_encoding()` and
  `ImageInTerminal.enable_encoding()` functions.


v0.1.0 (2024-07-20)
-------------------

* Initial release.
