! Train a forest and score a batch: 100 inliers plus one outlier.
program basic
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: forest
  real(dp) :: X(101, 2), s(101), a, b
  integer :: i

  do i = 1, 100                          ! 100 inliers in the unit square
     call random_number(a); call random_number(b)
     X(i,:) = [a, b]
  end do
  X(101,:) = [5.0_dp, 5.0_dp]            ! 1 outlier

  call train_forest(forest, X, 101)      ! 100 trees, psi = min(256, n)
  call predict_scores(forest, X, 101, s)
  print '(a,f5.3,a,f5.3)', "inlier ", s(1), "   outlier ", s(101)

  call free_forest(forest)
end program basic
