Eternity2Puzzles.jl Changelog
=============================

v0.2.0 (2025-??-??)
-------------------

  Breaking changes:

  * The required minimum Julia version is now 1.10.

  * Changed some of the arguments of the `Eternity2Puzzle` type constructor; the
    argument to specify the piece definitions has become a positional argument,
    while the argument used to load a puzzle board from a file is now a keyword
    argument `board`. See the docstring of `Eternity2Puzzle` for details and
    examples.

  * Renamed the included solvers `BacktrackingSearch` to `HeuristicBacktrackingSearch`
    and `BacktrackingSearchRecursive` to `SimpleBacktrackingSearch`.


  New features and improvements:

  * Added the ability to play the smaller 6x6 Clue Puzzle 1 via `play(:clue1)`
    and the 6x12 Clue Puzzle 2 via `play(:clue2)`.

  * Added a new `estimate_solutions` function to predict the number of valid
    solutions for a given `Eternity2Puzzle`.

  * An `Eternity2Puzzle` can now be created with more puzzle pieces than are
    necessary to fill the entire board. This allows, for example, to solve a
    smaller sized board using only a subset of the original Eternity II pieces.


v0.1.0 (2024-07-20)
-------------------

  * Initial release.
