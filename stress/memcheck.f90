program memcheck
  use iforest, only: dp, IsolationForest, train_forest, free_forest
  implicit none
  type(IsolationForest) :: f
  real(dp) :: X(500,4)
  integer :: i, j, k
  real(dp) :: r

  do i = 1, 500
     do j = 1, 4
        call random_number(r); X(i,j) = r
     end do
  end do

  call show_rss("start            ")
  do k = 1, 5000
     call train_forest(f, X, 500, 128, 30)   ! free-on-refit reclaims previous
     if (k == 100) call show_rss("after 100 refits ")
  end do
  call free_forest(f)
  call show_rss("after 5000 refits")

contains

  subroutine show_rss(tag)
    character(*), intent(in) :: tag
    integer :: u, ios
    character(256) :: line
    open(newunit=u, file="/proc/self/status", status="old", action="read", iostat=ios)
    if (ios /= 0) return
    do
       read(u, '(a)', iostat=ios) line
       if (ios /= 0) exit
       if (line(1:6) == "VmHWM:" .or. line(1:6) == "VmRSS:") &
            write(*,'(a,a,a)') tag, "  ", trim(line)
    end do
    close(u)
  end subroutine

end program memcheck
