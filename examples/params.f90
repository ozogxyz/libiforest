! Custom hyperparameters: number of trees and subsample size (psi).
program params
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: forest
  real(dp) :: X(1000, 4), s(1000)
  integer :: i, j
  real(dp) :: r

  do i = 1, 1000
     do j = 1, 4
        call random_number(r); X(i,j) = r
     end do
  end do

  call train_forest(forest, X, 1000, psi=128, n_trees=200)
  call predict_scores(forest, X, 1000, s)

  print '(a,f6.3)', "mean score (200 trees, psi=128) = ", sum(s) / 1000

  call free_forest(forest)
end program params
