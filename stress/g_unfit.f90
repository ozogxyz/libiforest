program g
  use iforest, only: dp, get_score
  implicit none
  real(dp) :: s
  call get_score([1.0_dp, 2.0_dp], 2, s)
  print *, s
end program g
