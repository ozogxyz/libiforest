program compare
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none
  type(IsolationForest) :: f
  real(dp), allocatable :: X(:,:), s(:)
  integer :: n, m, i, u, psi

  open(newunit=u, file="bench/X.txt", status="old", action="read")
  read(u,*) n, m
  allocate(X(n,m), s(n))
  do i = 1, n
     read(u,*) X(i,:)
  end do
  close(u)

  psi = min(256, n)
  call train_forest(f, X, n, psi, 100)
  call predict_scores(f, X, n, s)
  call free_forest(f)

  open(newunit=u, file="bench/ours.txt", status="replace", action="write")
  do i = 1, n
     write(u,'(es24.16)') s(i)
  end do
  close(u)

  print '(a,i0,a,i0)', "wrote bench/ours.txt  n=", n, " m=", m
end program compare
