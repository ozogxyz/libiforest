!------------------------------------------------------------------------------
! C ABI for libiforest (iso_c_binding). Data is passed ROW-MAJOR as C expects:
! X[i*m + j] is sample i, feature j. The forest is an opaque handle.
!
! The boundary validates its inputs and never lets a Fortran error stop abort the
! C host: iforest_train returns NULL on invalid input, and iforest_score is a
! no-op on a NULL handle or a feature-count mismatch.
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
    real(dp), allocatable :: X(:,:)
    integer :: nt, ps, i, j

    handle = c_null_ptr
    if (n < 2 .or. m < 1) return        ! cannot train; signal failure with NULL

    nt = n_trees; if (nt <= 0) nt = 100
    if (nt < 1) nt = 1
    ps = psi;     if (ps <= 0) ps = min(256, n)
    if (ps < 2) ps = 2
    if (ps > n) ps = n

    allocate(X(n, m))                   ! heap copy: row-major C -> column-major (n,m)
    do j = 1, m
       do i = 1, n
          X(i, j) = Xc((i - 1) * m + j)
       end do
    end do

    allocate(f)
    call train_forest(f, X, n, ps, nt)
    handle = c_loc(f)
  end function

  subroutine iforest_score(handle, Xc, n, m, scores) bind(C, name="iforest_score")
    type(c_ptr), value :: handle
    real(c_double), intent(in) :: Xc(n * m)
    integer(c_int), value :: n, m
    real(c_double), intent(out) :: scores(n)
    type(IsolationForest), pointer :: f
    real(dp), allocatable :: X(:,:)
    integer :: i, j

    if (.not. c_associated(handle)) return
    call c_f_pointer(handle, f)
    if (m /= f%n_features) return       ! feature count must match training

    allocate(X(n, m))
    do j = 1, m
       do i = 1, n
          X(i, j) = Xc((i - 1) * m + j)
       end do
    end do

    call predict_scores(f, X, n, scores) ! c_double == dp: write straight into caller's buffer
  end subroutine

  subroutine iforest_free(handle) bind(C, name="iforest_free")
    type(c_ptr), value :: handle
    type(IsolationForest), pointer :: f

    if (.not. c_associated(handle)) return
    call c_f_pointer(handle, f)
    call free_forest(f)
    deallocate(f)
  end subroutine

end module iforest_c
