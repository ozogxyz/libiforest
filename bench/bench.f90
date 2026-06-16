program bench
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: f
  real(dp), allocatable :: X(:,:), s(:)
  integer :: n, m, i, u
  integer(8) :: c0, c1, rate
  real(dp) :: t_train, t_score

  open(newunit=u, file="bench/Xbig.txt", status="old", action="read")
  read(u,*) n, m
  allocate(X(n,m), s(n))
  do i = 1, n
     read(u,*) X(i,:)
  end do
  close(u)

  call system_clock(count_rate=rate)

  call system_clock(c0)
  call train_forest(f, X, n, min(256, n), 100)
  call system_clock(c1); t_train = real(c1 - c0, dp) / rate

  call system_clock(c0)
  call predict_scores(f, X, n, s)
  call system_clock(c1); t_score = real(c1 - c0, dp) / rate

  call free_forest(f)

  print '(a,i0,a,i0,a)', "n=", n, " m=", m, "  trees=100  max_samples=256"
  print '(a,f8.3,a)', "fortran train:    ", t_train, " s"
  print '(a,f8.3,a)', "fortran score:    ", t_score, " s"
  call show_rss()

contains

  subroutine show_rss()
    integer :: uu, ios
    character(256) :: line
    open(newunit=uu, file="/proc/self/status", status="old", action="read", iostat=ios)
    if (ios /= 0) return
    do
       read(uu, '(a)', iostat=ios) line
       if (ios /= 0) exit
       if (line(1:6) == "VmHWM:") print '(a,a)', "fortran peak RSS: ", trim(line(7:))
    end do
    close(uu)
  end subroutine

end program bench
