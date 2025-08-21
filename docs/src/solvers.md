This page explains the different strategies for solving Eternity II puzzles, which are implemented in this package.

!!! warning "Under construction"

    This page is not fully written yet and most of the content is just an early draft version.


## Backtracking search

A common approach for solving edge-matching puzzles like the Eternity II puzzle is a backtracking search.
Hereby the pieces are placed one after another onto the board, and as soon as no more piece can be placed, the last one is removed and another piece is tried instead.
An efficient implementation precomputes a lookup table with all possible piece candidates that fit for each combination of two edge colors, which during the search are the constraints from the edges of the neighboring pieces.
Such a lookup table contains all pieces pre-rotated in four different orientations.

The backtracking algorithm corresponds to exploring a search tree, where each node of the tree represents a piece that is placed during the search.
The depth of this search tree is defined by the total number of squares on the board (which is 256 for the original 16x16 Eternity II puzzle - or 255 if the starter-piece is considered as pre-placed on square I8), and the width for each level depends on a branching factor defined by the number of possible piece candidates for a particular board square.
For example, if the backtracking algorithm starts at the corner square A1, there are 4 possible corner pieces to choose from.
In the next step one of the 56 edge pieces should be placed on the next square A2 adjacent to this corner, but there is only a subset of these edge pieces which satisfy the constraint of matching edge colors with the already placed corner piece.
In particular, for the original Eternity II pieces and depending on which of the corner pieces was placed, there are between 10 and 12 matching edge pieces for the square A2.
This yields a total of 45 different combinations of corner and adjacent edge piece, or $4 + 45 = 49$ cumulative nodes for the first two levels of the search tree.
As the search proceeds and more pieces are placed onto the board, the branching factor becomes smaller because there are fewer remaining pieces to choose from.

### Search order

As already discussed on the previous page, the order in which pieces are placed onto the board has a significant influence on the width of the search tree and therefore on the efficiency of the search algorithm.
For the Eternity II puzzle, it is best to start at the bottom-left corner, which is the closest corner to the fixed starter-piece on square I8.
To keep the implementation simple and efficient, we only consider search orders in which each newly placed piece has always two adjacent edges from other, already placed pieces on the bottom and on the left side.
Then the orientation to the neighboring pieces doesn't need to be considered when looking up the edge constraint in the piece candidates table.
The optimal search order depends on the allowed number of invalid joins and where exactly on the board they are allowed.
The current implementation uses the search order shown in figure 1.

```@raw html
<figure>
  <img src="../assets/path_e2.svg">
  <figcaption><b>Figure 1</b>: Search order for the Eternity II puzzle</figcaption>
</figure>
```

!!! note "A note about dynamic search orders"

    Instead of using a predetermined search order, it might seem like a good idea to compare the numbers of piece candidates for different squares after every placed piece, and then choose the next square to be the one with the fewest possible candidates.
    However, aside from making the implementation more difficult, such a dynamic search order is actually significantly less efficient than a good, fixed search order.
    The reason for that is because choosing the next square by using a greedy strategy minimizes the branching factor of the search tree early on, but it generates partially filled board configurations which leave less optimal choices later during the search.
    So it is better to have a more global view of the situation and to keep the branching factor small when it counts the most.
    The greatest width of the search tree for the Eternity II puzzle is reached after placing around 160 to 170 pieces.
    It turns out that good search orders are those which minimize the number of open edges on the board when the search depths with the greatest widths are reached, which is for example the case using a simple rowscan order.
    Furthermore, the exact order in which the last pieces are placed almost doesn't matter, because the corresponding search depths are reached so rarely that their influence is negligible.
    The last statement is however not true if specific heuristics are used, for example if some invalid joins are allowed after a certain amount of pieces are placed onto the board.


### Heuristics

Heuristics can be very useful if there are many solutions, but they are less effective if there are only a few solutions.
A good heuristic that is used for the Eternity II puzzle is to prioritize the piece candidates with certain edge colors during the first phase of the search, such that some of the colors get eliminated early, which creates an uneven color distribution and increases the probability during the end of the search that the remaining pieces match together.


## Backtracking search with 2x2 pieces

A different version of the backtracking algorithm uses precomputed compound pieces made of four regular pieces that can be combined into a valid ``2\times 2`` block (figure 2).
In each step of the backtracking algorithm a ``2\times 2`` block is placed onto the board.
Instead of the original ``16\times 16`` board size, the grid for the compound pieces has only 8 rows and columns, i.e. the depth of the search tree is reduced by a factor of 4.
On the other hand, there are a lot more possible ``2\times 2`` compound pieces than the 256 regular pieces, so this approach trades the reduced maximum search depth against a significantly higher branching factor at each level in the search tree.

```@raw html
<figure style="display: flex; justify-content: space-around; flex-wrap: wrap">
  <span></span>
  <figure style="width: 20%">
    <img src="../assets/compound_corner_piece.png">
    <figcaption>2x2 corner piece</figcaption>
  </figure>
  <figure style="width: 20%">
    <img src="../assets/compound_edge_piece.png">
    <figcaption>2x2 edge piece</figcaption>
  </figure>
  <figure style="width: 20%">
    <img src="../assets/compound_inner_piece.png">
    <figcaption>2x2 inner piece</figcaption>
  </figure>
  <figcaption><b>Figure 2</b>: Different types of 2x2 compound pieces</figcaption>
</figure>
```

Instead of the original ``5 + 17 = 22`` different edge types (frame and inner colors, not counting the border color), there are now ``17\cdot 17 + 5\cdot 17 + 17\cdot 5 = 459`` possible combinations for the edge types of the compound pieces.

An advantage could be that the distribution of these 459 macro edge types is not equaly flat as the distribution for the original 22 colors.
This could be utilized by heuristics, for example prefer those piece candidates which have the highest number of matching candidate pieces for the open edges.


## Balanced rotation sets

Note that in a valid puzzle solution, for each of the 22 colors the numbers of right edges is equal to the number of left edges on the board with that color, and similarly the numbers of top and bottom edges with that color.
Let's call a set of rotations for all pieces *balanced*, if the edges on the pieces satisfy this condition.

Idea: find a set of "balanced rotations" for each of the pieces, such that the numbers of vertical edges (top/bottom) and horizontal edges (left/right) for each color are equal.
Hereby only those sets need to be considered which also have each of the four rotations for the four corner pieces exactly once, and exactly 14 edge pieces with each of the four rotations, so that a valid border around the outside of the puzzle board is possible.
Then in a second phase, use a regular backtracking algorithm to place the pieces on the board.
The fixed rotations reduces the number of possible pre-rotated piece candidates in the lookup table and accordingly the branching factor at each depth in the search tree by factor of 4, which makes an exhaustive search for a balanced rotations set possible.

This could further be combined with "checkerboard parity", i.e. divide the pieces into two groups "black" and "white", such that for each color the number of left edges on the black squares is the same as the number of right edges on the white squares, and so on.

The problem is that there are probably so many possible balanced rotations sets, that this approach might have no advantages over a regular backtracking search.
Considering that the orientation of the frame pieces are restricted by their border edges, there are ``4!\cdot C(56, 14)\cdot C(42, 14)\cdot C(28, 14)`` possible rotations for the frame pieces and ``4^{195}`` possible rotations for the inner pieces, excluding the fixed starter-piece, which in total gives a combined number of ``7.45\cdot 10^{149}`` possible rotations for all of the pieces.

To get a rough estimate for the probability of balanced edges for a particular color, we could model the orientation of the edges with that color as a symmetric random walk on a 2-dimensional grid (``\mathbb{Z}^2``).
With this model, for ``2n`` edges of a particular color, the probability that the edges are balanced in both vertical and horizontal direction is given by
```math
p_{2n} = \left(\left(\frac{1}{4}\right)^n\cdot C(2n, n)\right)^2
```
For the 12 inner colors with ``n=25`` joins (50 edges):
```math
p_{50} \approx 0.0126057
```
For the 5 inner colors with ``n=24`` joins (48 edges):
```math
p_{48} \approx 0.0131255
```
And for the 5 frame colors with ``n=12`` joins (24 edges):
```math
p_{24} \approx 0.0259791
```

This model gives an estimated number of ``7.45\cdot 10^{149}\cdot {p_{24}}^5\cdot {p_{48}}^5\cdot {p_{50}}^{12}\approx 5.53\cdot 10^{109}`` different balanced rotations sets.
