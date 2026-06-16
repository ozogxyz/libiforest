program check
  use iforest, only: dp, fit, get_score, release
  implicit none

  real(dp) :: X(40, 2), normal(2), outlier(2), sn, so
  integer :: i

  do i = 1, 40
     X(i,1) = real(i, dp)
     X(i,2) = real(i, dp) + 0.1_dp
  end do

  call fit(X, 40, 2)

  normal  = [20.0_dp, 20.1_dp]
  outlier = [200.0_dp, -100.0_dp]

  call get_score(normal, 2, sn)
  call get_score(outlier, 2, so)
  if (so <= sn) error stop "outlier should score higher than normal"

  call fit(X, 40, 2)
  call release()

  print *, "ok"
end program check
