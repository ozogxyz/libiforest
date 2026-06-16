program main
  use iforest, only: dp, fit, get_score, release
  implicit none

  integer, parameter :: num_samples = 10, num_features = 2
  real(dp) :: M(num_samples, num_features), x(num_features), score
  integer :: i

  do i = 1, num_samples
     M(i,1) = real(i, dp)
     M(i,2) = real(2*i, dp) + sin(real(i, dp))
  end do

  call fit(M, num_samples, num_features)

  x = [5.0_dp, 10.0_dp]
  call get_score(x, num_features, score)
  print *, "Normal score:", score

  x = [100.0_dp, -50.0_dp]
  call get_score(x, num_features, score)
  print *, "Outlier score:", score

  call release()
end program main
