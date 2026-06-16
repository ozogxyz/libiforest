program stress
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, predict, &
                     free_forest
  implicit none

  call test_auc()
  call test_scale()
  call test_edges()
  call test_extremes()
  call test_multi_instance()
  call test_refit_loop()
  call test_predict()

  print *, "STRESS OK"

contains

  subroutine assert(cond, msg)
    logical, intent(in) :: cond
    character(*), intent(in) :: msg
    if (.not. cond) then
       write(*,*) "FAIL: ", msg
       error stop 1
    end if
  end subroutine

  logical function finite(x)
    real(dp), intent(in) :: x
    finite = (x == x) .and. (abs(x) <= huge(x))
  end function

  ! 5000 inliers vs 200 well-separated outliers: rank AUC must be near 1.
  subroutine test_auc()
    integer, parameter :: nin = 5000, nout = 200, m = 8, n = nin + nout
    real(dp), allocatable :: X(:,:), s(:)
    type(IsolationForest) :: f
    integer :: i, j
    real(dp) :: r, auc, mean_in, mean_out
    integer(8) :: wins, total

    allocate(X(n,m), s(n))
    do i = 1, nin
       do j = 1, m
          call random_number(r); X(i,j) = -1.0_dp + 2.0_dp*r
       end do
    end do
    do i = nin+1, n
       do j = 1, m
          call random_number(r); X(i,j) = 5.0_dp + 2.0_dp*r
       end do
    end do

    call train_forest(f, X, n, 256, 100)
    call predict_scores(f, X, n, s)
    call free_forest(f)

    do i = 1, n
       call assert(finite(s(i)) .and. s(i) > 0.0_dp .and. s(i) <= 1.0000001_dp, "auc score range")
    end do

    wins = 0; total = 0
    do i = nin+1, n
       do j = 1, nin
          total = total + 1
          if (s(i) > s(j)) wins = wins + 1
       end do
    end do
    auc = real(wins, dp) / real(total, dp)
    mean_in = sum(s(1:nin)) / nin
    mean_out = sum(s(nin+1:n)) / nout
    write(*,'(a,f6.3,a,f6.3,a,f6.3)') " auc=", auc, "  mean_in=", mean_in, "  mean_out=", mean_out
    call assert(auc > 0.95_dp, "auc too low")
    call assert(mean_out > mean_in, "outliers not scored higher")
    deallocate(X, s)
    print *, "ok: auc / separation"
  end subroutine

  subroutine test_scale()
    integer, parameter :: n = 50000, m = 10
    real(dp), allocatable :: X(:,:), s(:)
    type(IsolationForest) :: f
    integer :: i, j
    real(dp) :: r
    real :: t0, t1

    allocate(X(n,m), s(n))
    do i = 1, n
       do j = 1, m
          call random_number(r); X(i,j) = r
       end do
    end do
    call cpu_time(t0)
    call train_forest(f, X, n, 256, 100)
    call predict_scores(f, X, n, s)
    call cpu_time(t1)
    call free_forest(f)
    do i = 1, n
       call assert(finite(s(i)), "scale finite")
    end do
    write(*,'(a,i0,a,i0,a,f6.2,a)') " scale n=", n, " m=", m, " train+score=", t1-t0, "s"
    deallocate(X, s)
    print *, "ok: scale"
  end subroutine

  subroutine test_edges()
    real(dp), allocatable :: X(:,:), s(:)
    type(IsolationForest) :: f
    integer :: i
    real(dp) :: r

    ! single feature
    allocate(X(50,1), s(50))
    do i = 1, 50
       call random_number(r); X(i,1) = r
    end do
    call train_forest(f, X, 50, 16, 50)
    call predict_scores(f, X, 50, s)
    call free_forest(f)
    do i = 1, 50
       call assert(finite(s(i)) .and. s(i) > 0.0_dp, "edge m=1")
    end do
    deallocate(X, s)

    ! minimal sample size
    allocate(X(2,2), s(2))
    X(1,:) = [0.0_dp, 0.0_dp]; X(2,:) = [1.0_dp, 1.0_dp]
    call train_forest(f, X, 2, 2, 10)
    call predict_scores(f, X, 2, s)
    call free_forest(f)
    call assert(finite(s(1)) .and. finite(s(2)), "edge n=2")
    deallocate(X, s)

    ! all points identical: every tree root is a leaf, score must be exactly 0.5
    allocate(X(100,3), s(100))
    X = 7.0_dp
    call train_forest(f, X, 100, 64, 50)
    call predict_scores(f, X, 100, s)
    call free_forest(f)
    do i = 1, 100
       call assert(finite(s(i)) .and. abs(s(i) - 0.5_dp) < 1.0e-9_dp, "edge identical 0.5")
    end do
    deallocate(X, s)

    ! one constant column, one varying
    allocate(X(200,2), s(200))
    do i = 1, 200
       X(i,1) = 3.0_dp
       call random_number(r); X(i,2) = r
    end do
    call train_forest(f, X, 200, 128, 100)
    call predict_scores(f, X, 200, s)
    call free_forest(f)
    do i = 1, 200
       call assert(finite(s(i)), "edge const column")
    end do
    deallocate(X, s)

    print *, "ok: edges (m=1, n=2, identical, constant column)"
  end subroutine

  subroutine test_extremes()
    real(dp), allocatable :: X(:,:), s(:)
    type(IsolationForest) :: f
    integer :: i, j
    real(dp) :: r

    allocate(X(500,4), s(500))
    do i = 1, 500
       do j = 1, 4
          call random_number(r); X(i,j) = (r - 0.5_dp) * 1.0e150_dp
       end do
    end do
    X(1,:) =  1.0e300_dp
    X(2,:) = -1.0e300_dp
    X(3,:) =  1.0e-300_dp
    call train_forest(f, X, 500, 256, 100)
    call predict_scores(f, X, 500, s)
    call free_forest(f)
    do i = 1, 500
       call assert(finite(s(i)) .and. s(i) > 0.0_dp .and. s(i) <= 1.0000001_dp, "extreme finite")
    end do
    deallocate(X, s)
    print *, "ok: extremes (1e+-300 magnitudes)"
  end subroutine

  subroutine test_multi_instance()
    type(IsolationForest) :: f1, f2
    real(dp) :: A(100,2), B(100,2), s1(1), s2(1), Xq(1,2)
    integer :: i
    real(dp) :: r

    do i = 1, 100
       call random_number(r); A(i,1) = r
       call random_number(r); A(i,2) = r
       call random_number(r); B(i,1) = 10.0_dp + r
       call random_number(r); B(i,2) = 10.0_dp + r
    end do
    call train_forest(f1, A, 100, 64, 50)
    call train_forest(f2, B, 100, 64, 50)

    Xq(1,:) = [0.5_dp, 0.5_dp]              ! in A's region, far from B
    call predict_scores(f1, Xq, 1, s1)
    call predict_scores(f2, Xq, 1, s2)
    call assert(finite(s1(1)) .and. finite(s2(1)), "multi finite")
    call assert(s2(1) > s1(1), "multi: point anomalous to f2, normal to f1")

    call free_forest(f1)
    call free_forest(f2)
    print *, "ok: multi-instance"
  end subroutine

  ! 300 refits on one object: relies on free-on-refit not leaking / corrupting.
  subroutine test_refit_loop()
    type(IsolationForest) :: f
    real(dp) :: X(1000,5), s(1000)
    integer :: i, j, k
    real(dp) :: r

    do k = 1, 300
       do i = 1, 1000
          do j = 1, 5
             call random_number(r); X(i,j) = r
          end do
       end do
       call train_forest(f, X, 1000, 256, 50)
       call predict_scores(f, X, 1000, s)
       call assert(finite(s(1)), "refit finite")
    end do
    call free_forest(f)
    print *, "ok: refit loop (300x, free-on-refit)"
  end subroutine

  ! 200 inliers + 10 far outliers; predict by contamination and by threshold.
  subroutine test_predict()
    type(IsolationForest) :: f
    real(dp) :: X(210, 2)
    integer :: lab(210), i, nflag
    real(dp) :: r

    do i = 1, 200
       call random_number(r); X(i,1) = r
       call random_number(r); X(i,2) = r
    end do
    do i = 201, 210
       call random_number(r); X(i,1) = 50.0_dp + r
       call random_number(r); X(i,2) = 50.0_dp + r
    end do
    call train_forest(f, X, 210, 128, 100)

    call predict(f, X, 210, lab, contamination=0.05_dp)
    nflag = sum(lab)
    call assert(nflag >= 7 .and. nflag <= 16, "predict contamination count")
    call assert(sum(lab(201:210)) >= 8, "predict contamination flags outliers")

    call predict(f, X, 210, lab, threshold=0.55_dp)
    call assert(sum(lab(201:210)) >= 8, "predict threshold flags outliers")

    call free_forest(f)
    print *, "ok: predict (contamination + threshold)"
  end subroutine

end program stress
