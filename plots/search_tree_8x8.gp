set terminal svg size 752,400 font 'Lato' name 'Search_tree_estimates_8x8'
set encoding utf8
set output 'search_tree_8x8.svg'

set style line 1 lc rgb '#56b4e9' lw 1.5  # blue
set style line 2 lc rgb '#e69f00' lw 1.5  # yellow
set style line 3 lc rgb '#009e73' lw 1.5  # green

# documenter-light
set lt 1 lw 1 lc rgb '#dbdbdb'  # border
set lt 2 lw 1 lc rgb '#707070'  # font
set lt 3 lw 1 lc rgb '#e4e4e4'  # grid-major
set lt 4 lw 1 lc rgb '#e9e9e9'  # grid-minor
set object 1 rectangle from graph 0,0 to graph 1,1 fillcolor rgb '#f5f5f5' behind
set key box lt 1 opaque fillcolor rgb '#ffffff' textcolor lt 2 top left samplen 2 Left reverse keywidth graph 0.15

# documenter-dark
# set lt 1 lw 1 lc rgb '#5e6d6f'  # border
# set lt 2 lw 1 lc rgb '#868c98'  # font
# set lt 3 lw 1 lc rgb '#3b4242'  # grid-major
# set lt 4 lw 1 lc rgb '#333a3a'  # grid-minor
# set object 1 rectangle from graph 0,0 to graph 1,1 fillcolor rgb '#282f2f' behind
# set key box lt 1 opaque fillcolor rgb '#1f2424' textcolor lt 2 top left samplen 2 Left reverse keywidth graph 0.15

set style data lines
set border lt 1
set grid xtics ytics mxtics lt 3, lt 4

set xlabel 'Depth' textcolor lt 2
set xrange [0:65]
set xtics axis nomirror out scale 0.6,0.4 5 textcolor lt 2
set mxtics 5

set ylabel 'Nodes' textcolor lt 2
set logscale y
set yrange [1e0:1e13]
set format y '10^{%-02T}'
set ytics axis nomirror out scale 0.6,0.4 1e0,1e1,1e13 textcolor lt 2
unset mytics

$data << EOD
#  Depth        model  pieces_set_1  pieces_set_2
       1  4.00000e+00             4             4
       2  3.20816e+01            30            31
       3  2.47211e+02           232           235
       4  1.82676e+03          1739          1768
       5  1.29186e+04         12418         12694
       6  8.72400e+04         84538         86700
       7  5.61216e+05        548148        564048
       8  5.71681e+05        530376        556272
       9  3.50455e+06       2970840       3432984
      10  7.27602e+06       5444911       7983818
      11  1.47139e+07      11553558      16473214
      12  2.89563e+07      22515790      33369561
      13  5.54029e+07      43905538      65299457
      14  1.02959e+08      81986946     123963646
      15  1.85647e+08     143926374     225766745
      16  1.30098e+08      87200383     164032802
      17  7.13602e+08     477709131     888348027
      18  1.24797e+09     835953729    1569392891
      19  2.11272e+09    1478369823    2646225807
      20  3.45802e+09    2486078560    4323964183
      21  5.46492e+09    4079463044    6809888505
      22  8.32710e+09    6390929627   10348474107
      23  1.22150e+10    9856160041   15251495745
      24  7.63888e+09    6078254307    9461531460
      25  3.69442e+10   29849931639   46410644501
      26  5.21153e+10   41765644529   66809363549
      27  7.05308e+10   58233843443   90198477364
      28  9.14002e+10   76726107868  116457773853
      29  1.13176e+11   97071040521  143457725140
      30  1.33599e+11  116538999051  168692760786
      31  1.49965e+11  132717258332  188609963279
      32  8.22363e+10   72876905655  107757476786
      33  3.44072e+11  308341025901  457199529160
      34  3.66396e+11  328099262763  493344259093
      35  3.68817e+11  340733167520  493692040734
      36  3.49712e+11  328015529086  464586584892
      37  3.11128e+11  298515978459  409724181633
      38  2.58553e+11  252996399811  337873646370
      39  1.99670e+11  200905873775  259356596398
      40  9.38613e+10   94264869744  126148955994
      41  3.31104e+11  335562168459  449702692106
      42  2.36292e+11  237809663027  325120311672
      43  1.54689e+11  159834727114  211919607062
      44  9.21250e+10   96103494500  125406582959
      45  4.94121e+10   52453448596   66714234029
      46  2.35734e+10   25364354273   31593348489
      47  9.84688e+09   10782838944   13101487912
      48  3.84674e+09    4187863992    5268215327
      49  1.10258e+10   12087007798   15257045922
      50  3.95158e+09    4297209936    5534286575
      51  1.18120e+09    1315981940    1646872834
      52  2.82944e+08     316989971     391953141
      53  5.10877e+07      57722105      70133051
      54  6.25541e+06       7120634       8485461
      55  4.05251e+05        505112        526011
      56  1.37473e+05        174923        182430
      57  1.00714e+05        120215        124310
      58  3.20857e+04         34706         42326
      59  9.60469e+03         10131         12709
      60  2.75843e+03          2833          4085
      61  7.88564e+02           772          1210
      62  2.43647e+02           225           390
      63  1.15504e+02           101           211
      64  6.83262e+01            52            96
EOD

plot $data using 1:2 ls 1 title 'model', \
     $data using 1:3 ls 2 title 'Puzzle C', \
     $data using 1:4 ls 3 title 'Puzzle D'
