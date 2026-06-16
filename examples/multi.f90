! Two independent forests, each its own object. No shared state.
program multi
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: fa, fb
  real(dp) :: A(100, 2), B(100, 2), q(1, 2), sa(1), sb(1)
  integer :: i
  real(dp) :: r1, r2

  do i = 1, 100
     call random_number(r1); call random_number(r2)
     A(i,:) = [r1, r2]                        ! cluster near the origin
     call random_number(r1); call random_number(r2)
     B(i,:) = [10.0_dp + r1, 10.0_dp + r2]    ! cluster near (10, 10)
  end do

  call train_forest(fa, A, 100)
  call train_forest(fb, B, 100)

  q(1,:) = [0.5_dp, 0.5_dp]                    ! normal to A, anomalous to B
  call predict_scores(fa, q, 1, sa)
  call predict_scores(fb, q, 1, sb)
  print '(a,f6.3,a,f6.3)', "point (0.5,0.5): score vs A = ", sa(1), "   vs B = ", sb(1)

  call free_forest(fa)
  call free_forest(fb)
end program multi
