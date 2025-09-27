It can be useful to create a mathematical model for Eternity II puzzles, in order to compare the efficiencies of different solving strategies without the need to gather empirical results, to find an estimation for the number of solutions, and to derive a measure for the difficulty of a given puzzle.
The following section first describes some of the terms that are used in this documentation and also in the source code.


## Terminology

An Eternity II puzzle is a special kind of edge-matching puzzle on a rectangular grid -- the __board__ -- with a given number of rows and columns.
The rows and columns divide the board into a set of __squares__, with each square being identified by a combination of a letter for the row (from top to bottom) and a number for the column (from left to right); for example A1 for the top-left corner square.

The puzzle __pieces__ (or tiles) have one of various colored patterns on each of their four sides.
For simplicitly these different edge types are just called the __colors__.
One of the edge types that occurs on some of the pieces doesn't have an actual pattern; this is the grey __border color__ and edges of that type are the __border edges__.
Border edges must only be placed towards the outside border of the board.
We can distinguish between __corner pieces__ (pieces with two border edges), __edge pieces__ (pieces with one border edge) and __inner pieces__ (pieces without border edges), while the set of __frame pieces__ consists of the corner pieces and the edge pieces.
The __corner squares__, __edge squares__, __inner squares__ and __frame squares__ are the corresponding positions on the board.
A __fixed piece__ (or pre-placed piece) is a piece that must be placed with a given rotation on a given square of the board - the original Eternity II puzzle has a single fixed piece on square I8.

An important property of the Eternity II puzzle is that the set of colors which occur on the edges between two frame pieces, and the set of colors which occur on the edges between two inner pieces and between one inner piece and one frame piece, are disjunct.
This separates the colors into __frame colors__, which only occur on frame pieces, and __inner colors__, which occur on the inner pieces and on the inside edges of the edge pieces.

A __join__ describes a pair of edges between two adjacent pieces, and similarly to the frame and inner colors we can further distinguish between __frame joins__ and __inner joins__.
The joins can either be __valid joins__ if both of the edge colors match, or __invalid joins__ if they don't match.
Since there is only a single valid rotation for the pieces on the frame squares (determined by the orientation of the border edge), frame joins are always made from two edges with frame colors and inner joins are always made from two edges with inner colors, regardless whether these joins are valid or invalid.

The __score__ of an arrangement of pieces on the board is defined as the total number of valid joins.
At the time of writing, the highest known score for the original Eternity II puzzle are 470 valid joins out of the maximum 480.


## Symmetries

A puzzle can have three possible types of symmetries, which act as multiplicative factors for the total number of solutions.
The symmetries can also be utilized to reduce the number of nodes in the search tree that a backtracking algorithm has to visit in order to find all possible solutions.

1. __Symmetries due to the board__:
    For a square board without fixed pieces, any solution rotated by 90°, 180° or 270° is also a solution.
    For a rectangular board with different numbers of rows and columns, any solution rotated by 180° gives another solution.
    On a square board, fixing one of the four corner pieces reduces the number of nodes for an exhaustive search by an average factor of 4 (the precise number of nodes depends on which particular corner piece was used, because the colors of its edges affect the number of possible candidates for the neighboring pieces and so on).
    Similarly, for a rectangular but not square board, fixing one of the corner pieces on one of the corner squares first and then on another corner square that is not directly opposite to the first one, reduces the number of nodes for an exhaustive search by an average factor of 2.

2. __Symmetries due to rotationally symmetric individual pieces__:
    If a piece has the same edge colors on opposite sides both in vertical and horizontal direction, the piece can be rotated by 180° without affecting the global edge color arrangement on the board.
    If all four of its edges have the same color, the piece can be rotated by 90°, 180° or 270°.

3. __Symmetries due to rotationally identical pieces__:
    If two or more pieces have exactly the same edge colors under some rotation, their positions on the board can be swapped without affecting the global edge color arrangement.
    In general, for each set of ``n`` duplicate pieces there are ``n!`` permutations for the positions of these pieces with identical edge color arrangement.

The original Eternity II puzzle has neither symmetrical individual nor rotationally identical pieces, and for a valid solution the symmetries due to the board are eliminated by fixing piece 139 on the square I8.


## Solution estimates

To get an estimate for the number of valid solutions, we can count the total number of possible piece configurations on the board, and multiply that number with the probability that all joins between adjacent edges have matching colors.

The number of piece configurations -- ignoring whether or not adjacent edges match -- can be calculated exactly.
For the original Eternity II puzzle with 16 rows and 16 columns there are 4 corner pieces, 56 edge pieces and 196 inner pieces, with one of the inner pieces already being fixed with a given rotation on square I8.
Under the restriction that the frame pieces must be placed with all their border edges around the outside of the board, we have ``4! = 24`` different permutations for the arrangement of the corner pieces, ``56!`` possible configurations of the edge pieces, and ``195!\cdot 4^{195}`` possible configurations for the inner pieces, including the four rotations for each piece. In total this yields ``4!\cdot 56!\cdot 195!\cdot 4^{195}\approx 1.12\cdot 10^{557}`` possible configurations for all the pieces.

The board of the Eternity II puzzle has 60 frame joins and 420 inner joins, and there are 5 different frame colors and 17 different inner colors with flat distributions over the number of edges.
A very simple approach is to use the value ``1/5`` as an approximation for the probability of a valid frame join, and ``1/17`` for the probability of a valid inner join.
If the probabilities of valid joins are assumed to be independent over the entire board, one could simply multiply these values and get the total probability ``(1/5)^{60}\cdot (1/17)^{420}\approx 1.88\cdot 10^{-559}`` that all of the joins are valid.
Then the expected number of solutions is the product from the number of all possible configurations and the probability that all joins for a particular configuration are valid.
With the values from above we expect ``0.02`` solutions, which suggests that the puzzle has only a single solution -- the one that was used to generate the puzzle pieces.
However, when comparing this method with empirical results from puzzles with fewer pieces, which can be searched exhaustively with a backtracking algorithm, it becomes apparent that this approximation is not very accurate.
In fact, it is clear that in practice the probabilities of valid joins are not independent and constant over the whole board; after more and more pieces are correctly placed onto the board, the color distribution over the remaining edges changes and the probability to create valid joins increases as some of the colors get used up.

A more sophisticated probability model was developed by Brendan Owen [Owen2008, Owen2009](@cite), which takes into account that the numbers of edges of each color are finite.
This model is generalized for any number of fixed pieces on the board, and for any configuration of squares on a partially filled board, which will be useful to estimate the total number of nodes in a search tree that a backtracking algorithm has to visit for an exhaustive search.

In the following, we use the notation ``P(n, k) = n!/(n-k)!`` for the number of ``k``-permutations of ``n``, and ``C(n, k) = n!/(k!(n-k)!)`` for the number of ``k``-combinations of ``n`` (binomial coefficient).

### Number of piece configurations

Let ``a_\text{c}`` be the number of available corner pieces, ``a_\text{e}`` be the number of available edge pieces, and ``a_\text{i}`` be the number of available inner pieces.
Each of these numbers are counted without the fixed pieces on the board.
Note that these numbers are allowed to be larger than the corresponding numbers of board squares of each type; this makes it possible to, for example, calculate estimations about filling a smaller board with a subset of pieces made from any of the 256 Eternity II pieces.

Further, for any partially or completed piece configuration on the board, let ``p_\text{c}`` be the number of placed corner pieces, ``p_\text{e}`` be the number of placed edge pieces, and ``p_\text{i}`` be the number of placed inner pieces, but again, counted without any fixed pieces.

Then, for a specific selection of squares on the board, the number of possible piece configurations that fill these squares, and ignoring whether joins between adjacent pieces match or not, is given by
```math
P(p_\text{c}, p_\text{e}, p_\text{i}) = P(a_\text{c}, p_\text{c}) P(a_\text{e}, p_\text{e}) P(a_\text{i}, p_\text{i}) 4^{p_\text{i}} = \frac{a_\text{c}!}{(a_\text{c} - p_\text{c})!}\cdot\frac{a_\text{e}!}{(a_\text{e} - p_\text{e})!}\cdot\frac{a_\text{i}!}{(a_\text{i} - p_\text{i})!} 4^{p_\text{i}}
```

### Matching probabilities

The next part is to determine the probability that all the edges are matching.
The probability for a particular state of a partially filled board is taken as the ratio between the number of valid combinations for a given number of joins (corresponding to the particular state of the board) and the total number of combinations how that many joins can be made from either matching or non-matching edges with arbitrary colors.
This model assumes that the edges can be moved independently from each other, which is not strictly true as groups of four edges are attached to a piece.

The basic idea of the following method involves to calculate the number of valid combinations by just using a subset of the colors, and then incrementally adding new colors with the help of that result as a building block in the calculation.
This process is repeated until all edge types have been taken into account.
The concept leads to recursive formulas for the numbers of valid combinations, which can be implemented very efficiently.

### Probabilities of valid frame joins

It was already mentioned before, that the orientations of the frame pieces are constrained by their border edges.
This means that a join between two frame pieces is always made from one "left" edge and one "right" edge.

Let ``B`` be the number of different frame colors and assign consecutive numbers from ``1`` to ``B`` to those colors.
Let ``2n_i`` be the number of edges of color ``i`` and ``2T_\text{b} = 2\sum_{i=1}^B n_i`` be the total number of frame edges over all pieces.
Define ``V_\text{b}(i, b)`` to be the number of valid configurations of how ``b`` frame joins can be made using ``2b`` edges of colors ``1`` to ``i``.
It is
```math
\begin{align*}
V_\text{b}(0, 0) &= 1 \\
V_\text{b}(0, b) &= 0 \quad \text{for} \quad b > 0
\end{align*}
```
and one can derive the recursive formula
```math
V_\text{b}(i, b) = \sum_{j=0}^{n_i} V_\text{b}(i-1, b-j)\cdot P(n_i, j)^2\cdot C(b, j)
```
by adding up the ways ``0`` to ``n_i`` extra joins can be made when adding the color ``i``.
Hereby are ``V_\text{b}(i-1, b-j)`` the number of valid configurations using just the previous colors with ``b-j`` joins, ``P(n_i, j)^2`` the ways of making ``j`` joins using ``j`` edges from a set of ``n_i`` left edges and ``j`` edges from a set of ``n_i`` right edges, and ``C(b, j)`` are the ways of merging ``b-j`` joins with the ``j`` new joins to make ``b`` joins.

For the total number of ways to make ``b`` joins using ``2b`` edges, regardless whether they are valid or invalid, we just pick ``b`` left edges from the total set of ``T_\text{b}`` left edges and ``b`` right edges from the total set of ``T_\text{b}`` right edges.
This results in a number of ``P(T_\text{b}, b)^2`` permutations, and a corresponding probability
```math
p_\text{b}(b) = \frac{V_\text{b}(B, b)}{P(T_\text{b}, b)^2}
```
that all ``b`` frame joins are valid, using ``2b`` frame edges.

### Probabilities of valid inner joins

The approach for the inner joins works similar to that one for the frame joins.
The difference in this case is that there is no such notion of left or right edges for the inner joins, and thus instead of ``P(n_i, j)^2`` ways to make ``j`` joins from the ``n_i`` left and ``n_i`` right edges of color ``i`` we now have ``P(2n_i, 2j)`` ways to pick any ``2j`` edges from the total of ``2n_i`` edges with that color.

Let ``M`` be the number of different inner colors, with color numbers assigned from ``1`` to ``M``.
Again, let ``2n_i`` be the number of edges of color ``i`` and ``2T_\text{m} = 2\sum_{i=1}^M n_i`` the total number of inner edges over all pieces.
Define ``V_\text{m}(i, m)`` to be the number of valid configurations of how ``m`` inner joins can be made using ``2m`` edges of colors ``1`` to ``i``.
Then we have again
```math
\begin{align*}
V_\text{m}(0, 0) &= 1 \\
V_\text{m}(0, m) &= 0 \quad \text{for} \quad m > 0
\end{align*}
```
and the recursive formula
```math
V_\text{m}(i, m) = \sum_{j=0}^{n_i} V_\text{m}(i-1, m-j)\cdot P(2n_i, 2j)\cdot C(m, j)
```
from which follows the probability
```math
p_\text{m}(m) = \frac{V_\text{m}(M, m)}{P(2T_\text{m}, 2m)}
```
that all ``m`` inner joins are valid, using ``2m`` inner edges.

Figures 1 and 2 show the probabilities of a particular join to be valid, plotted over the cumulative number of joins for the Eternity II puzzle with 256 pieces, 60 total frame joins and 420 total inner joins.

```@raw html
<figure>
  <picture style="width: 100%">
    <source srcset="../assets/frame_probabilities_dark.svg" media="(prefers-color-scheme: dark)">
    <img src="../assets/frame_probabilities.svg">
  </picture>
  <figcaption><b>Figure 1</b>: Probabilities of valid frame joins for the Eternity II puzzle with 256 pieces</figcaption>
</figure>

<figure>
  <picture style="width: 100%">
    <source srcset="../assets/inner_probabilities_dark.svg" media="(prefers-color-scheme: dark)">
    <img src="../assets/inner_probabilities.svg">
  </picture>
  <figcaption><b>Figure 2</b>: Probabilities of valid inner joins for the Eternity II puzzle with 256 pieces</figcaption>
</figure>
```

### Solutions and search tree estimates

The product of the probabilities for ``b`` valid frame joins made from ``2b`` frame edges and ``m`` valid inner joins  made from ``2m`` inner edges and the total number of piece configurations with ``p_\text{c}`` placed corner pieces, ``p_\text{e}`` placed edge pieces and ``p_\text{i}`` placed inner pieces gives an estimation for the number of partial solutions of a partially filled board:
```math
S(p_\text{c}, p_\text{e}, p_\text{i}, b, m) = P(p_\text{c}, p_\text{e}, p_\text{i})\cdot p_\text{b}(b)\cdot p_\text{m}(m)
```

For a board with ``r`` rows and ``c`` columns, that has
```math
\begin{align*}
s_\text{c} &= 4 \\
s_\text{e} &= 2(r-2) + 2(c-2) = 2r + 2c - 8 \\
s_\text{i} &= (r-2)(c-2)
\end{align*}
```
corner squares, edge squares and inner squares, and using
```math
\begin{align*}
b &= 2(r-1) + 2(c-1) \\
m &= (r-1)(c-2) + (r-2)(c-1)
\end{align*}
```
as the total numbers of frame joins and inner joins on the board, we finally have the estimation for the number of puzzle solutions of the entirely filled board.

Table 1 compares the predicted numbers of solutions with empirical results for the two smaller puzzles with 36 pieces that are shown in figure 3.

```@raw html
<figure style="display: flex; justify-content: space-around; flex-wrap: wrap">
  <span></span>
  <figure style="width: 40%">
    <img src="../assets/pieces_06x06.png">
    <figcaption>Puzzle A: 3 frame colors, 5 inner colors,<br>160 solutions</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/clue1.png">
    <figcaption>Puzzle B: 4 frame colors, 3 inner colors, 115071633408 solutions</figcaption>
  </figure>
  <figcaption><b>Figure 3</b>: 6x6 puzzles with different characteristics</figcaption>
</figure>
```

|                                    | Puzzle A |   Puzzle B   | Eternity II |
| ---------------------------------- | -------- | ------------ | ----------- |
| estimated solutions                |      146 | 262881014825 |       14702 |
| actual solutions                   |      160 | 115071633408 |             |
| symmetries due to the board        |        4 |            4 |           1 |
| symmetries due to symmetric pieces |        1 |            4 |           1 |
| symmetries due to identical pieces |        1 |          384 |           1 |
| total symmetries                   |        4 |         6144 |           1 |

```@raw html
<figure>
  <figcaption><b>Table 1</b>: Estimated and empirical numbers of solutions for different puzzles</figcaption>
</figure>
```

A backtracking search algorithm gradually fills the board with pieces one after another, and following a given search order, which maps each search depth to a particular square on the board.
After each placed piece for that search order we can count the total numbers of the already placed corner, edge and inner pieces, as well as the numbers of frame joins and inner joins between neighboring pieces, and then estimate the number of partial solutions for that particular, partially filled board.
The cumulative sum of these partial solutions, from placing the first until the last piece, represents an estimation for the total numbers of nodes in the search tree.

It has been observed that the predicted numbers from the theoretical model matches empirical results gathered by exhaustive searches very well, and the relative error becomes smaller with bigger puzzle sizes.
Figure 4 shows two different puzzles with 64 pieces, but with the same characteristics (3 frame colors, 8 inner colors, no symmetric or identical pieces), and figure 5 visualizes the estimated and empirical numbers of nodes for each depth in the search tree, using a simple rowscan search order starting from the bottom-left corner.

```@raw html
<figure style="display: flex; justify-content: space-around; flex-wrap: wrap">
  <span></span>
  <figure style="width: 40%">
    <img src="../assets/pieces_08x08_set_1.png">
    <figcaption>Puzzle C: 52 solutions</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/pieces_08x08_set_2.png">
    <figcaption>Puzzle D: 96 solutions</figcaption>
  </figure>
  <figcaption><b>Figure 4</b>: 8x8 puzzles with 3 frame colors and 8 inner colors</figcaption>
</figure>
```

```@raw html
<figure>
  <picture style="width: 100%">
    <source srcset="../assets/search_tree_8x8_dark.svg" media="(prefers-color-scheme: dark)">
    <img src="../assets/search_tree_8x8.svg">
  </picture>
  <figcaption><b>Figure 5</b>: Estimated and empirical numbers of nodes in the search tree</figcaption>
</figure>
```

Figure 6 visualizes different search orders for the original Eternity II puzzle with a single fixed piece on square I8, and shows the total number of nodes in the corresponding search trees.
It is worth to mention that the optimal optimal search order depends on the specific properties of the puzzle, i.e. the board size, the number of frame and inner colors, the distribution of colors, and the number of symmetries in the pieces.

```@raw html
<figure style="display: flex; justify-content: space-around; flex-wrap: wrap">
  <span></span>
  <figure style="width: 40%">
    <img src="../assets/path_rowscan.svg">
    <figcaption>Horizontal rowscan - 1.365e+47 nodes</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/path_best.svg">
    <figcaption>Best known search order - 1.364e+47 nodes</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/path_frame_rowscan.svg">
    <figcaption>Frame first, then horizontal rowscan - 1.110e+57 nodes</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/path_zig_zag.svg">
    <figcaption>Diagonal zig-zag path - 4.176e+53 nodes</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/path_spiral_in.svg">
    <figcaption>Spiral-in path - 3.979e+57 nodes</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/path_spiral_out.svg">
    <figcaption>Spiral-out path - 1.556e+57 nodes</figcaption>
  </figure>
  <figcaption><b>Figure 6</b>: Different search orders and the total number of nodes in the corresponding search trees</figcaption>
</figure>
```

```@raw html
<figure>
  <picture style="width: 100%">
    <source srcset="../assets/search_tree_dark.svg" media="(prefers-color-scheme: dark)">
    <img src="../assets/search_tree.svg">
  </picture>
  <figcaption><b>Figure 7</b>: Search tree estimates for selected search orders</figcaption>
</figure>
```


## Estimates with invalid joins

For a simple backtracking approach, the search space of the Eternity II puzzle with 256 pieces is too large for a realistic chance of finding one of the solutions.
A different objective can be to optimize for the best score, i.e. the highest number of valid joins on the board.
This involves to allow a certain amount of mismatched edges while placing new pieces onto the board.
Since the probability of valid joins between two random frame pieces of the Eternity II puzzle is higher than the probability of valid inner joins, the following model only considers the invalid joins between two inner edges and assumes that all edges between the frame pieces must still match.

Let ``p_\text{m}(m, v)`` be the probability that the first ``v`` inner joins are valid and the rest are not, using ``2m`` inner edges. This probability can be calculated using the recursive relation
```math
p_\text{m}(m, v) = p_\text{m}(m-1, v) - p_\text{m}(m, v+1)
```
and the special case of all ``m`` inner joins to be valid was already considered above, therefore
```math
p_\text{m}(m, m) = p_\text{m}(m)
```

If we want to allow the ``v`` valid inner joins to be anywhere on the board, we still have to multiply ``p_\text{m}(m, v)`` with the number of ways to arrange ``v`` valid joins over ``m`` positions, i.e. with a factor ``C(m, v) = C(m, m-v)``.

More convenient for practical calculations is the probability of __at most__ ``N = m - v`` invalid inner joins, using ``2m`` edges. In this case we have to sum up the probabilities ``p_\text{m}(m, m-0)`` for no invalid joins, ``p_\text{m}(m, m-1)`` for 1 invalid join, up to ``p_\text{m}(m, m-N)`` for ``N`` invalid joins, with each of these probabilities multiplied the number of ways of arranging the corresponding number of invalid joins over all of the ``m`` inner joins:
```math
p_\text{m} = \sum_{i=0}^N p_\text{m}(m, m-i)\cdot C(m, i)
```

Here, for simplicity the notation ``p_\text{m}`` on the left side of the equation represents the overall probability regarding the inner joins, and its exact meaning should be clear from context, i.e. in this case it is the probability for up to ``N`` invalid joins anywhere on the board.

Since allowing invalid joins increases the numbers of possible piece candidates for each square in a backtracking algorithm, an efficient implementation would likely restrict where exactly on the board these invalid joins are allowed.
For example, instead of right from the beginning and over the entire board, the invalid joins might only be gradually allowed towards the end of the search, after some specified numbers of placed pieces ("slip array").
In this case we have to replace the factor ``C(m, i)`` in the equation by the number of ways to arrange ``i`` invalid joins over a total of ``m`` joins, while satisfying the restictions from the given slip array.

Let ``d=[d_1, d_2, \ldots, d_N]`` with ``d_1\le d_2\le\ldots\le d_N`` be an ordered slip array with ``N`` entries, that specifies the search depths (i.e. the number of placed pieces) at which another invalid join is allowed.
For example, ``d=[220, 230, 240]`` means that the first 219 pieces must be placed without any invalid joins, from piece 220 to 229 at most one invalid join is allowed, from piece 230 to 239 at most two (cumulative) invalid joins, and a third invalid join is allowed when at least 240 pieces are placed.
It is not strictly necessary that the first invalid join occurs somewhere between piece 220 to 229; instead, all of the three allowed invalid joins might be between the last few placed pieces, or there can also be fewer than three invalid joins in total.
Note that multiple consecutive numbers with the same value in ``d`` are allowed, in which case the corresponding number of new invalid joins are allowed from that particular search depth.
For example, to allow up to four invalid inner joins anywhere on the board, you could simply set ``d=[1, 1, 1, 1]`` (in practice it doesn't really make sense to have more than two consecutive numbers with the same value, because new pieces are usually only placed with exactly two of their edges adjacent to other pieces on the board).
Also note that by defining the allowed invalid joins in form of the slip array, their allowed positions on the board are dependent on the search order.

Let ``j(p)`` be the number of completed (either valid or invalid) inner joins after ``p`` placed pieces, with ``1\le p\le p_\text{max}`` and ``p_\text{max}`` being the total number of squares on the board.
The values ``j(p)`` depend on the exact placement order of the pieces, but they can easily be precomputed and stored in an array.

Let ``W(p, i)`` be the number of ways to arrange exactly ``i`` invalid inner joins after ``p`` placed pieces on the board, that satisfy the constraints from the given slip array ``d``.

Obviously ``W(p, i) = 0`` if ``p < d_i``, because ``i`` invalid joins are not permitted when fewer than ``d_i`` pieces are placed on the board.

For a single invalid join any of the last ``j(p) - j(d_1-1)`` positions is allowed, and therefore
```math
W(p, 1) = C(j(p) - j(d_1-1), 1) = j(p) - j(d_1-1)
```

For exactly ``i=2`` invalid joins, either both of them can be between ``d_2`` and ``p`` placed pieces (here "between" means the bounds ``d_2`` and ``p`` are inclusive), or one of them can be between ``d_1`` and ``d_2 - 1`` placed pieces and the other one between ``d_2`` and ``p`` placed pieces.
For the first case we have ``C(j(p) - j(d_2-1), 2)`` combinations to arrange the two invalid joins, and for the second case we have ``C(j(d_2-1) - j(d_1-1), 1)\cdot C(j(p) - j(d_2-1), 1)`` combinations to arrange them.
In total this gives
```math
W(p, 2) = C(j(p) - j(d_2-1), 2) + \underbrace{C(j(d_2-1) - j(d_1-1), 1)}_{W(d_2-1, 1)}\cdot C(j(p) - j(d_2-1), 1)
```
possible configurations for exactly 2 invalid joins.

Now consider an arbitrary number of exactly ``i`` invalid joins after ``p`` placed pieces.
We can list the different cases:

1. All ``i`` invalid joins occur between ``d_i`` and ``p`` placed pieces. This gives ``C(j(p) - j(d_i-1), i)`` possible configurations.
2. There is exactly 1 invalid join between ``d_1`` and ``d_i - 1`` placed pieces and the other ``i-1`` invalid joins occur between ``d_i`` and ``p`` placed pieces. This gives ``C(j(d_i-1) - j(d_1-1), 1)\cdot C(j(p) - j(d_i-1), i-1)`` possible configurations. Notice that the first term in that product is equal to ``W(d_i - 1, 1)``.
3. There are exactly 2 invalid joins between ``d_1`` and ``d_i - 1`` placed pieces and the other ``i-2`` invalid joins occur between ``d_i`` and ``p`` placed pieces. We have already calculated the number of possible configurations for the first 2 invalid joins in the previous paragraph if we again set ``p = d_i - 1``. This gives ``W(d_i - 1, 2)\cdot C(j(p) - j(d_i-1), i-2)`` possible configurations.
4. There are exactly ``k`` invalid joins between ``d_1`` and ``d_i - 1`` placed pieces and the other ``i-k`` invalid joins occur between ``d_i`` and ``p`` placed pieces. This gives ``W(d_i - 1, k)\cdot C(j(p) - j(d_i-1), i-k)`` possible configurations.
5. There are exactly ``i-1`` invalid joins between ``d_1`` and ``d_i - 1`` placed pieces and the last invalid join occurs between ``d_i`` and ``p`` placed pieces. This gives ``W(d_i - 1, i - 1)\cdot C(j(p) - j(d_i-1), 1)`` possible configurations.

The total number of possible configurations for ``i`` invalid joins is the sum of all of these cases, which can be written in a recursive way
```math
\begin{align*}
W(p, i) &= \begin{cases} \sum\limits_{k=0}^{i-1} W(d_i - 1, k)\cdot C(j(p) - j(d_i-1), i-k) & \text{if} & p\ge d_i \\ 0 & \text{if} & p < d_i \end{cases} \\
W(p, 0) &= 1
\end{align*}
```

Using this expression, we can now calculate the probability for the inner joins with up to ``N`` invalid joins after ``p`` placed pieces, that satisfy the restrictions from the given slip array, as
```math
p_\text{m} = \sum_{i=0}^N p_\text{m}(m, m-i)\cdot W(p, i)
```

Note that if invalid joins are allowed only for the inner edges, the optimal search order is usually different from the best search order if no invalid joins were allowed.
The reason for that is because allowing mismatching inner edges significantly increases the number of possible piece candidates for the inner board squares.
Therefore a search order which prioritizes the frame squares during the later phase of the search when invalid joins are allowed is more efficient than a search order which for example leaves the entire top row of the board until the very end.
Figures 8 and 9 show the total number of nodes in the search tree for two different search orders, assuming that up to 10 invalid inner joins (target score 470) within the four topmost rows of the Eternity II board are allowed, which corresponds to the slip array
```math
[192, 192, 192, 192, 192, 192, 192, 192, 192, 192]
```
and an estimated number of ``1.481\cdot 10^{25}`` piece configurations that satisfy these constraints.
Here the search order on the right, which only fills the first 12 rows horizontally and then the last 4 rows vertically, is over 80% more efficient than a full horizontal rowscan over the entire board.

```@raw html
<figure style="display: flex; justify-content: space-around; flex-wrap: wrap">
  <span></span>
  <figure style="width: 40%">
    <img src="../assets/path_rowscan.svg">
    <figcaption>Horizontal rowscan - 3.715e+58 nodes</figcaption>
  </figure>
  <figure style="width: 40%">
    <img src="../assets/path_rowscan2.svg">
    <figcaption>Horizontal rowscan with the last 4 rows filled vertically - 7.000e+57 nodes</figcaption>
  </figure>
  <figcaption><b>Figure 8</b>: Two search orders for the Eternity II puzzle with up to 10 invalid joins allowed</figcaption>
</figure>
```

```@raw html
<figure>
  <picture style="width: 100%">
    <source srcset="../assets/search_tree_470_dark.svg" media="(prefers-color-scheme: dark)">
    <img src="../assets/search_tree_470.svg">
  </picture>
  <figcaption><b>Figure 9</b>: Search tree estimates with up to 10 invalid joins allowed</figcaption>
</figure>
```

## References

```@bibliography
```
