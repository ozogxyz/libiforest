program main
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none

  integer, parameter :: n = 10, m = 2
  type(IsolationForest) :: forest
  real(dp) :: X(n, m), q(2, m), s(2)
  integer :: i

  do i = 1, n
     X(i,1) = real(i, dp)
     X(i,2) = real(2*i, dp) + sin(real(i, dp))
  end do

  call train_forest(forest, X, n)        ! defaults: 100 trees, psi = min(256, n)

  q(1,:) = [5.0_dp, 10.0_dp]             ! a normal point
  q(2,:) = [100.0_dp, -50.0_dp]          ! an outlier
  call predict_scores(forest, q, 2, s)

  print *, "Normal score: ", s(1)
  print *, "Outlier score:", s(2)

  call free_forest(forest)
end program main
