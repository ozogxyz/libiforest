program g
  use iforest, only: dp, fit, get_score
  implicit none
  real(dp) :: X(8,2), s
  integer :: i
  do i = 1, 8
     X(i,1) = real(i, dp); X(i,2) = real(i, dp)
  end do
  call fit(X, 8, 2)
  call get_score([1.0_dp, 2.0_dp, 3.0_dp], 3, s)
  print *, s
end program g
