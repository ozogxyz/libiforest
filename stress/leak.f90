program leak
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, &
                     free_forest, fit, get_score, release
  implicit none
  type(IsolationForest) :: f
  real(dp) :: X(200,3), s(200), sc
  integer :: i, j, k
  real(dp) :: r

  do i = 1, 200
     do j = 1, 3
        call random_number(r); X(i,j) = r
     end do
  end do

  do k = 1, 5
     call train_forest(f, X, 200, 64, 30)
     call predict_scores(f, X, 200, s)
  end do
  call free_forest(f)

  call fit(X, 200, 3)
  call get_score([0.5_dp, 0.5_dp, 0.5_dp], 3, sc)
  call release()

  print *, "leak prog done", s(1), sc
end program leak
