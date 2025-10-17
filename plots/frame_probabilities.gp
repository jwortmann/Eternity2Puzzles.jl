set terminal svg size 752,400 font 'Lato' name 'Frame_probabilities'
set encoding utf8
set output 'frame_probabilities.svg'

# documenter-light
set style line 1 lc rgb '#2e63b8' lw 1.5
set lt 1 lw 1 lc rgb '#dbdbdb'  # border
set lt 2 lw 1 lc rgb '#707070'  # font
set lt 3 lw 1 lc rgb '#e4e4e4'  # grid
set object 1 rectangle from graph 0,0 to graph 1,1 fillcolor rgb '#f5f5f5' behind

# documenter-dark
# set style line 1 lc rgb '#1abc9c' lw 1.5
# set lt 1 lw 1 lc rgb '#5e6d6f'  # border
# set lt 2 lw 1 lc rgb '#868c98'  # font
# set lt 3 lw 1 lc rgb '#3b4242'  # grid
# set object 1 rectangle from graph 0,0 to graph 1,1 fillcolor rgb '#282f2f' behind

set style data lines
set border lt 1
set grid xtics ytics lt 3
unset key

set xlabel 'Cumulative frame joins' textcolor lt 2
set xrange [0:60]
set xtics axis nomirror out scale 0.6,0.4 5 textcolor lt 2

set ylabel 'Probability per join' textcolor lt 2
set yrange [0.0:1.0]
set format y '%.1f'
set ytics axis nomirror out scale 0.6,0.4 0.1 textcolor lt 2

plot '-' using 1:2 ls 1

 1 0.200000000
 2 0.200229819
 3 0.200459929
 4 0.200690723
 5 0.200922601
 6 0.201155971
 7 0.201391256
 8 0.201628889
 9 0.201869320
10 0.202113018
11 0.202360474
12 0.202612202
13 0.202868745
14 0.203130679
15 0.203398616
16 0.203673211
17 0.203955171
18 0.204245238
19 0.204544252
20 0.204853090
21 0.205172727
22 0.205504218
23 0.205848734
24 0.206207568
25 0.206582130
26 0.206974027
27 0.207385004
28 0.207817057
29 0.208272418
30 0.208753608
31 0.209263488
32 0.209805336
33 0.210382896
34 0.211000498
35 0.211663167
36 0.212376745
37 0.213148127
38 0.213985428
39 0.214898369
40 0.215898587
41 0.217000233
42 0.218220617
43 0.219581213
44 0.221108913
45 0.222837958
46 0.224812554
47 0.227090884
48 0.229751090
49 0.232900789
50 0.236692676
51 0.241351315
52 0.247221712
53 0.254861597
54 0.265225441
55 0.280045862
56 0.302658141
57 0.339913028
58 0.407485228
59 0.551401864
60 1.000000000
