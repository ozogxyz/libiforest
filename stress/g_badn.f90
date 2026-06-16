program g
  use iforest, only: dp, fit
  implicit none
  real(dp) :: X(1,2)
  X = 1.0_dp
  call fit(X, 1, 2)
  print *, "unreached"
end program g
