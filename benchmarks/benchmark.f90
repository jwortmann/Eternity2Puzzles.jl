! gfortran -Ofast benchmark.f90 -o benchmark
program benchmark
    integer :: nargs
    character(len=3) :: arg1
    integer :: maxdepth

    type :: rpiece
        integer :: number
        integer :: top
        integer :: right
    end type

    nargs = command_argument_count()
    if (nargs == 0) then
        maxdepth = 206
    else
        call get_command_argument(1, arg1)
        read(arg1, *) maxdepth
    end if

    call solve(maxdepth)

    contains

    subroutine solve(maxdepth)
        implicit none
        integer, intent(in) :: maxdepth
        logical, dimension(256) :: used
        integer, dimension(0:23, 0:22) :: index_table, index_table2
        type(rpiece), dimension(:), allocatable :: candidates
        type(rpiece) :: candidate
        type(rpiece), dimension(-15:256) :: board
        integer, dimension(256) :: idx_state
        integer :: depth, idx, bottom, left, top, right, piece, rotation, tmp
        integer(kind=4) :: nodes
        real(kind=8) :: t0, t1

        integer, parameter, dimension(0:3, 256) :: pieces = reshape([ &
             0,  0,  1,  3,  0,  0,  1,  4,  0,  0,  2,  3,  0,  0,  3,  2, &
             0,  1,  6,  1,  0,  1,  7,  2,  0,  1,  9,  1,  0,  1,  9,  5, &
             0,  1, 12,  3,  0,  1, 14,  4,  0,  1, 15,  2,  0,  1, 19,  4, &
             0,  1, 19,  5,  0,  1, 21,  4,  0,  2,  7,  1,  0,  2,  8,  3, &
             0,  2, 10,  5,  0,  2, 13,  5,  0,  2, 14,  2,  0,  2, 15,  2, &
             0,  2, 16,  4,  0,  2, 17,  1,  0,  2, 17,  5,  0,  2, 18,  1, &
             0,  2, 21,  1,  0,  3,  6,  2,  0,  3,  6,  3,  0,  3,  7,  3, &
             0,  3,  8,  3,  0,  3, 14,  5,  0,  3, 15,  2,  0,  3, 18,  3, &
             0,  3, 19,  2,  0,  3, 19,  4,  0,  3, 20,  5,  0,  3, 22,  4, &
             0,  4,  8,  1,  0,  4, 11,  5,  0,  4, 12,  5,  0,  4, 13,  2, &
             0,  4, 13,  3,  0,  4, 15,  1,  0,  4, 15,  2,  0,  4, 15,  3, &
             0,  4, 16,  1,  0,  4, 18,  4,  0,  4, 19,  4,  0,  4, 20,  4, &
             0,  5,  6,  5,  0,  5,  7,  1,  0,  5,  7,  2,  0,  5,  9,  1, &
             0,  5, 14,  4,  0,  5, 16,  4,  0,  5, 16,  5,  0,  5, 19,  3, &
             0,  5, 20,  1,  0,  5, 20,  5,  0,  5, 21,  2,  0,  5, 22,  3, &
             6,  6,  9,  8,  6,  6, 10, 14,  6,  7,  7, 11,  6,  8,  6, 19, &
             6,  8,  8, 22,  6,  8, 10, 10,  6,  8, 12,  7,  6,  8, 18,  9, &
             6,  8, 22, 19,  6, 11, 11, 14,  6, 11, 14, 17,  6, 12, 10,  8, &
             6, 12, 15, 16,  6, 12, 18, 15,  6, 12, 19, 11,  6, 13, 10, 15, &
             6, 13, 13, 15,  6, 14, 11, 20,  6, 14, 18, 11,  6, 14, 20, 21, &
             6, 15, 13,  8,  6, 16,  8,  8,  6, 16, 12, 16,  6, 17,  8, 13, &
             6, 17,  9, 10,  6, 17, 19, 17,  6, 17, 20, 18,  6, 18,  6, 21, &
             6, 18,  9, 22,  6, 18, 16, 20,  6, 19, 12, 17,  6, 19, 13, 15, &
             6, 19, 13, 16,  6, 19, 16, 21,  6, 19, 17, 10,  6, 21, 21, 11, &
             6, 22, 16, 13,  6, 22, 18, 19,  6, 22, 21,  9,  6, 22, 22, 21, &
             7,  7, 17, 15,  7,  7, 17, 20,  7,  7, 20, 13,  7,  7, 22,  9, &
             7,  8, 16, 15,  7,  9, 11, 19,  7,  9, 13, 19,  7,  9, 16, 15, &
             7,  9, 20, 12,  7, 10, 15, 17,  7, 10, 17, 15,  7, 11, 18, 13, &
             7, 11, 18, 20,  7, 12, 10, 16,  7, 12, 14, 17,  7, 12, 17, 12, &
             7, 12, 22, 20,  7, 13, 11, 21,  7, 14, 20, 17,  7, 15, 19, 22, &
             7, 16, 10, 22,  7, 18,  9, 20,  7, 18, 10, 13,  7, 18, 18, 15, &
             7, 19, 17, 22,  7, 19, 21, 15,  7, 20, 10,  9,  7, 20, 13, 21, &
             7, 20, 16, 11,  7, 20, 18, 19,  7, 21,  9, 18,  7, 21, 17, 10, &
             7, 22, 10, 20,  7, 22, 12, 16,  7, 22, 16, 11,  7, 22, 20, 18, &
             8,  8, 18, 14,  8,  9,  9, 11,  8,  9,  9, 12,  8,  9,  9, 17, &
             8,  9, 13, 21,  8,  9, 15,  9,  8,  9, 20, 17,  8,  9, 21, 21, &
             8, 10, 11, 16,  8, 11,  8, 17,  8, 11,  8, 22,  8, 11, 11, 10, &
             8, 11, 15, 17,  8, 13,  9, 12,  8, 13, 16, 22,  8, 14, 12, 12, &
             8, 14, 12, 13,  8, 14, 22, 20,  8, 16, 14, 14,  8, 16, 14, 17, &
             8, 16, 22, 14,  8, 18, 14, 20,  8, 18, 19,  9,  8, 19, 21, 21, &
             8, 20,  9, 18,  8, 20, 10, 18,  8, 22, 15, 12,  8, 22, 16, 20, &
             9, 10, 11, 16,  9, 10, 16, 19,  9, 12, 11, 11,  9, 13, 12, 15, &
             9, 13, 13, 21,  9, 14, 16, 19,  9, 14, 18, 20,  9, 14, 21, 12, &
             9, 15, 15, 15,  9, 15, 17, 18,  9, 16, 14, 21,  9, 17, 14, 13, &
             9, 18, 10, 16,  9, 19, 17, 20,  9, 19, 19, 15,  9, 20, 14, 20, &
             9, 21, 12, 20,  9, 21, 14, 12, 10, 10, 13, 19, 10, 11, 22, 14, &
            10, 12, 13, 17, 10, 12, 19, 19, 10, 13, 21, 14, 10, 14, 10, 21, &
            10, 14, 11, 13, 10, 14, 20, 13, 10, 15, 11, 11, 10, 15, 15, 18, &
            10, 16, 12, 14, 10, 17, 21, 12, 10, 17, 21, 22, 10, 17, 22, 15, &
            10, 18, 12, 22, 10, 18, 13, 19, 10, 18, 18, 18, 10, 19, 13, 11, &
            10, 20, 21, 19, 10, 20, 22, 14, 10, 21, 17, 13, 10, 21, 17, 19, &
            10, 21, 20, 11, 10, 21, 22, 21, 11, 11, 22, 14, 11, 12, 13, 22, &
            11, 12, 19, 15, 11, 14, 12, 13, 11, 14, 20, 15, 11, 15, 11, 20, &
            11, 16, 19, 19, 11, 17, 11, 18, 11, 17, 16, 22, 11, 17, 22, 21, &
            11, 18, 13, 15, 11, 20, 16, 17, 11, 21, 12, 16, 11, 22, 12, 20, &
            11, 22, 21, 21, 11, 22, 21, 22, 12, 12, 17, 22, 12, 12, 18, 14, &
            12, 12, 20, 15, 12, 14, 13, 15, 12, 14, 17, 17, 12, 16, 13, 19, &
            12, 18, 14, 22, 12, 18, 20, 19, 12, 19, 17, 18, 12, 19, 17, 21, &
            13, 13, 13, 18, 13, 14, 20, 16, 13, 16, 14, 16, 13, 16, 14, 18, &
            13, 16, 17, 15, 13, 17, 16, 20, 13, 18, 15, 22, 13, 18, 21, 15, &
            13, 19, 14, 21, 13, 19, 16, 21, 14, 15, 15, 17, 14, 15, 18, 19, &
            14, 16, 22, 18, 14, 21, 20, 22, 15, 15, 21, 22, 15, 16, 17, 16, &
            15, 17, 16, 21, 15, 18, 20, 21, 16, 16, 22, 19, 16, 17, 19, 17, &
            17, 19, 20, 18, 18, 20, 21, 20, 18, 22, 20, 22, 19, 22, 21, 22  &
        ], [4, 256])

        used = .false.
        index_table = 0
        board(-15:-1) = rpiece(0, 0, 0)
        board(0) = rpiece(0, 23, 0)

        do piece = 1, 256
            do rotation = 0, 3
                bottom = pieces(rotation, piece)
                left   = pieces(modulo(rotation+1, 4), piece)
                top    = pieces(modulo(rotation+2, 4), piece)
                right  = pieces(modulo(rotation+3, 4), piece)
                if (top == 0) then
                    cycle
                else if (bottom == 0 .and. right == 0) then
                    bottom = 23
                end if
                index_table(bottom, left) = index_table(bottom, left) + 1
            end do
        end do

        idx = 2
        do bottom = 0, 23
            do left = 0, 22
                tmp = index_table(bottom, left)
                if (tmp == 0) then
                    index_table(bottom, left) = 1
                else
                    index_table(bottom, left) = idx
                    idx = idx + tmp + 1
                end if
            end do
        end do

        index_table2 = index_table

        allocate(candidates(idx-1))
        candidates(1) = rpiece(0, 0, 0)

        do piece = 1, 256
            do rotation = 0, 3
                bottom = pieces(rotation, piece)
                left   = pieces(modulo(rotation+1, 4), piece)
                top    = pieces(modulo(rotation+2, 4), piece)
                right  = pieces(modulo(rotation+3, 4), piece)
                if (top == 0) then
                    cycle
                else if (bottom == 0 .and. right == 0) then
                    bottom = 23
                end if
                idx = index_table2(bottom, left)
                index_table2(bottom, left) = index_table2(bottom, left) + 1
                candidates(idx) = rpiece(piece, top, right)
            end do
        end do

        do bottom = 0, 23
            do left = 0, 22
                idx = index_table2(bottom, left)
                if (idx /= 1) then
                    candidates(idx) = rpiece(0, 0, 0)
                end if
            end do
        end do

        depth = 1
        nodes = 0
        idx = index_table(0, 0)

        call cpu_time(t0)

        do
            candidate = candidates(idx)
            piece = candidate%number
            if (piece == 0) then
                depth = depth - 1
                used(board(depth)%number) = .false.
                idx = idx_state(depth)
                cycle
            end if
            idx = idx + 1
            if (used(piece)) then
                cycle
            end if
            board(depth) = candidate
            used(piece) = .true.
            idx_state(depth) = idx
            nodes = nodes + 1
            if (depth == maxdepth) then
                exit
            end if
            depth = depth + 1
            idx = index_table(board(depth-16)%top, candidate%right)
        end do

        call cpu_time(t1)

        deallocate(candidates)

        print *, nodes, nodes/(t1-t0)/1e6
    end subroutine

end program
