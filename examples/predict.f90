! Binary anomaly labels, by fixed threshold and by contamination fraction.
program predict_example
  use iforest, only: dp, IsolationForest, train_forest, predict, free_forest
  implicit none
  type(IsolationForest) :: forest
  real(dp) :: X(210, 2)
  integer :: lab(210), i
  real(dp) :: r1, r2

  do i = 1, 200
     call random_number(r1); call random_number(r2)
     X(i,:) = [r1, r2]                        ! 200 inliers
  end do
  do i = 201, 210
     call random_number(r1); call random_number(r2)
     X(i,:) = [20.0_dp + r1, 20.0_dp + r2]    ! 10 outliers
  end do

  call train_forest(forest, X, 210)

  call predict(forest, X, 210, lab, threshold=0.6_dp)
  print '(a,i0)', "flagged at threshold 0.6:    ", sum(lab)

  call predict(forest, X, 210, lab, contamination=0.05_dp)
  print '(a,i0)', "flagged at 5% contamination: ", sum(lab)

  call free_forest(forest)
end program predict_example
