program g
  use iforest, only: dp, fit
  implicit none
  real(dp) :: X(5,2)
  integer :: i
  do i = 1, 5
     X(i,1) = real(i, dp); X(i,2) = real(i, dp)
  end do
  call fit(X, 5, 2, psi=10)
  print *, "unreached"
end program g
