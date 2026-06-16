!------------------------------------------------------------------------------
! C ABI for libiforest (iso_c_binding). Data is passed ROW-MAJOR as C expects:
! X[i*m + j] is sample i, feature j. The forest is an opaque handle.
!------------------------------------------------------------------------------
module iforest_c
  use iso_c_binding
  use iforest, only: dp, IsolationForest, train_forest, predict_scores, free_forest
  implicit none

contains

  function iforest_train(Xc, n, m, n_trees, psi) bind(C, name="iforest_train") result(handle)
    real(c_double), intent(in) :: Xc(n * m)
    integer(c_int), value :: n, m, n_trees, psi
    type(c_ptr) :: handle
    type(IsolationForest), pointer :: f
    integer :: nt, ps

    allocate(f)
    nt = n_trees; if (nt <= 0) nt = 100
    ps = psi;     if (ps <= 0) ps = min(256, n)
    call train_forest(f, to_fortran(Xc, n, m), n, ps, nt)
    handle = c_loc(f)
  end function

  subroutine iforest_score(handle, Xc, n, m, scores) bind(C, name="iforest_score")
    type(c_ptr), value :: handle
    real(c_double), intent(in) :: Xc(n * m)
    integer(c_int), value :: n, m
    real(c_double), intent(out) :: scores(n)
    type(IsolationForest), pointer :: f
    real(dp) :: s(n)

    call c_f_pointer(handle, f)
    call predict_scores(f, to_fortran(Xc, n, m), n, s)
    scores = s
  end subroutine

  subroutine iforest_free(handle) bind(C, name="iforest_free")
    type(c_ptr), value :: handle
    type(IsolationForest), pointer :: f

    if (.not. c_associated(handle)) return
    call c_f_pointer(handle, f)
    call free_forest(f)
    deallocate(f)
  end subroutine

  ! Copy a row-major C buffer into a column-major Fortran (n,m) matrix.
  function to_fortran(Xc, n, m) result(X)
    real(c_double), intent(in) :: Xc(n * m)
    integer, intent(in) :: n, m
    real(dp) :: X(n, m)
    integer :: i, j

    do j = 1, m
       do i = 1, n
          X(i, j) = Xc((i - 1) * m + j)
       end do
    end do
  end function

end module iforest_c
