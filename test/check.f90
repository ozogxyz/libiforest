program check
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none

  type(IsolationForest) :: forest
  real(dp) :: X(40, 2), q(2, 2), s(2)
  integer :: i

  do i = 1, 40
     X(i,1) = real(i, dp)
     X(i,2) = real(i, dp) + 0.1_dp
  end do

  call train_forest(forest, X, 40)

  q(1,:) = [20.0_dp, 20.1_dp]            ! normal
  q(2,:) = [200.0_dp, -100.0_dp]         ! outlier
  call predict_scores(forest, q, 2, s)
  if (s(2) <= s(1)) error stop "outlier should score higher than normal"

  call train_forest(forest, X, 40)       ! refit must not crash or leak
  call free_forest(forest)

  print *, "ok"
end program check
