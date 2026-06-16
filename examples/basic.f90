! Train a forest and score a batch of points.
program basic
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: forest
  real(dp) :: X(100, 2), s(100)
  integer :: i
  real(dp) :: r1, r2

  do i = 1, 99
     call random_number(r1); call random_number(r2)
     X(i,:) = [r1, r2]                       ! inliers in the unit square
  end do
  X(100,:) = [5.0_dp, 5.0_dp]                ! one outlier

  call train_forest(forest, X, 100)          ! defaults: 100 trees, psi = min(256, n)
  call predict_scores(forest, X, 100, s)

  print '(a,f6.3)', "mean inlier score = ", sum(s(1:99)) / 99
  print '(a,f6.3)', "outlier score     = ", s(100)

  call free_forest(forest)
end program basic
