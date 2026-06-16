!------------------------------------------------------------------------------
! MIT License
!
! Copyright (c) 2025 Orkun Ozoglu
!
! Permission is hereby granted, free of charge, to any person obtaining a copy
! of this software and associated documentation files (the "Software"), to deal
! in the Software without restriction, including without limitation the rights
! to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
! copies of the Software, and to permit persons to whom the Software is
! furnished to do so, subject to the following conditions:
!
! The above copyright notice and this permission notice shall be included in
! all copies or substantial portions of the Software.
!
! THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
! IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
! FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
! AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
! LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
! OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
! SOFTWARE.
!------------------------------------------------------------------------------

module iforest
  use iso_fortran_env, only: error_unit
  implicit none
  private

  integer, parameter :: dp = kind(1.0d0)

  public :: dp, IsolationForest
  public :: train_forest, predict_scores, free_forest
  public :: fit, get_score, release

  type :: TreeNode
     logical                 :: is_leaf
     integer                 :: split_feature
     real(dp)                :: split_value
     type(TreeNode), pointer :: left => null()
     type(TreeNode), pointer :: right => null()
     integer                 :: size
  end type TreeNode

  type :: Tree
     type(TreeNode), pointer :: root => null()
  end type Tree

  type :: IsolationForest
     type(Tree), allocatable :: trees(:)
     integer :: n_trees
     integer :: psi
     integer :: n_features
  end type IsolationForest

  ! One global model for the convenience API (fit/get_score/release).
  ! Not thread-safe, and a second fit replaces the first. For multiple
  ! models or threaded use, call train_forest/predict_scores on your own
  ! IsolationForest instance.
  type(IsolationForest), save :: model

contains

  ! ---- convenience API over one global model ------------------------------

  ! Train the global model on X (n rows = samples, m columns = features).
  ! n_trees defaults to 100, psi (subsample size) to min(256, n).
  subroutine fit(X, n, m, n_trees, psi)
    real(dp), intent(in) :: X(n, m)
    integer, intent(in) :: n, m
    integer, intent(in), optional :: n_trees, psi
    integer :: nt, ps

    if (n < 2) then
       write(error_unit, '(a)') "fit: need at least 2 samples"
       error stop 1
    end if

    ps = min(256, n)
    if (present(psi)) ps = psi
    nt = 100
    if (present(n_trees)) nt = n_trees

    if (ps < 2 .or. ps > n) then
       write(error_unit, '(a)') "fit: psi must be in [2, n]"
       error stop 1
    end if
    if (nt < 1) then
       write(error_unit, '(a)') "fit: n_trees must be >= 1"
       error stop 1
    end if

    call train_forest(model, X, n, ps, nt)
  end subroutine

  ! Score one m-feature point. score is in (0, 1]: ~0.5 nominal, -> 1 anomalous.
  subroutine get_score(x, m, score)
    real(dp), intent(in) :: x(m)
    integer, intent(in) :: m
    real(dp), intent(out) :: score
    real(dp) :: tmp(1, m)
    real(dp) :: out(1)

    if (.not. allocated(model%trees)) then
       write(error_unit, '(a)') "get_score: call fit first"
       error stop 1
    end if
    if (m /= model%n_features) then
       write(error_unit, '(a)') "get_score: feature count differs from fit"
       error stop 1
    end if

    tmp(1,:) = x(:)
    call predict_scores(model, tmp, 1, out)
    score = out(1)
  end subroutine

  ! Free the global model.
  subroutine release()
    call free_forest(model)
  end subroutine

  ! ---- core type-based API ------------------------------------------------

  subroutine train_forest(forest, X, n_samples, psi, n_trees)
    type(IsolationForest), intent(inout) :: forest
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: n_samples, psi, n_trees
    integer :: i
    integer, allocatable :: idx(:)

    call free_forest(forest)

    allocate(forest%trees(n_trees))
    forest%n_trees = n_trees
    forest%psi = psi
    forest%n_features = size(X, 2)

    allocate(idx(psi))
    do i = 1, n_trees
       call subsample(n_samples, psi, idx)
       forest%trees(i)%root => build_tree(X, idx, 0, ceiling(log(real(psi, dp))/log(2.0_dp)))
    end do

    deallocate(idx)
  end subroutine

  subroutine free_forest(forest)
    type(IsolationForest), intent(inout) :: forest
    integer :: i

    if (allocated(forest%trees)) then
       do i = 1, size(forest%trees)
          call free_node(forest%trees(i)%root)
       end do
       deallocate(forest%trees)
    end if
  end subroutine

  subroutine predict_scores(forest, X, n_samples, scores)
    type(IsolationForest), intent(in) :: forest
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: n_samples
    real(dp), intent(out) :: scores(:)
    integer :: i, j
    real(dp) :: h, avg_h, c_psi

    c_psi = cfactor(forest%psi)
    do i = 1, n_samples
       avg_h = 0.0_dp
       do j = 1, forest%n_trees
          h = path_length(forest%trees(j)%root, X(i,:), 0)
          avg_h = avg_h + h
       end do
       avg_h = avg_h / forest%n_trees
       scores(i) = 2.0_dp ** (-avg_h / c_psi)
    end do
  end subroutine

  ! ---- internals ----------------------------------------------------------

  subroutine subsample(n_samples, psi, sample_idx)
    integer, intent(in) :: n_samples, psi
    integer, intent(out) :: sample_idx(:)
    integer :: i, j, tmp
    real :: rtmp
    integer, allocatable :: perm(:)

    if (size(sample_idx) /= psi) stop "sample_idx wrong size"
    if (psi > n_samples) stop "subsample: psi > n_samples"

    allocate(perm(n_samples))
    perm = [(i, i = 1, n_samples)]

    ! Fisher-Yates shuffle
    do i = n_samples, 2, -1
       call random_number(rtmp)
       j = 1 + int(rtmp * i)
       tmp = perm(i)
       perm(i) = perm(j)
       perm(j) = tmp
    end do

    sample_idx = perm(1:psi)
    deallocate(perm)
  end subroutine

  recursive function build_tree(X, idx, height, height_limit) result(node)
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: idx(:)
    integer, intent(in) :: height, height_limit
    type(TreeNode), pointer :: node
    integer :: n_features, split_feature, i
    real(dp) :: r, fmin, fmax, split_value
    integer :: left_count, right_count
    integer, allocatable :: left_idx(:), right_idx(:)

    allocate(node)

    if (height >= height_limit .or. size(idx) <= 1) then
       node%is_leaf = .true.
       node%size = size(idx)
       return
    end if

    n_features = size(X, 2)
    call random_number(r)
    split_feature = min(n_features, 1 + int(r * n_features))

    fmin = minval(X(idx, split_feature))
    fmax = maxval(X(idx, split_feature))
    if (fmax == fmin) then
       node%is_leaf = .true.
       node%size = size(idx)
       return
    end if

    call random_number(r)
    split_value = fmin + r * (fmax - fmin)

    left_count = 0
    right_count = 0
    do i = 1, size(idx)
       if (X(idx(i), split_feature) < split_value) then
          left_count = left_count + 1
       else
          right_count = right_count + 1
       end if
    end do

    allocate(left_idx(left_count), right_idx(right_count))
    left_count = 0
    right_count = 0
    do i = 1, size(idx)
       if (X(idx(i), split_feature) < split_value) then
          left_count = left_count + 1
          left_idx(left_count) = idx(i)
       else
          right_count = right_count + 1
          right_idx(right_count) = idx(i)
       end if
    end do

    node%is_leaf = .false.
    node%split_feature = split_feature
    node%split_value = split_value
    node%size = size(idx)
    node%left  => build_tree(X, left_idx, height + 1, height_limit)
    node%right => build_tree(X, right_idx, height + 1, height_limit)

    deallocate(left_idx, right_idx)
  end function build_tree

  recursive function path_length(node, x, depth) result(h)
    type(TreeNode), pointer :: node
    real(dp), intent(in) :: x(:)
    integer, intent(in) :: depth
    real(dp) :: h

    if (node%is_leaf) then
       if (node%size <= 1) then
          h = depth * 1.0_dp
       else
          h = depth + cfactor(node%size)
       end if
       return
    end if

    if (x(node%split_feature) < node%split_value) then
       h = path_length(node%left, x, depth + 1)
    else
       h = path_length(node%right, x, depth + 1)
    end if
  end function path_length

  pure function cfactor(n) result(res)
    integer, intent(in) :: n
    real(dp) :: res

    if (n <= 1) then
       res = 0.0_dp
    else if (n == 2) then
       res = 1.0_dp
    else
       res = 2.0_dp * (log(real(n - 1, dp)) + 0.5772156649_dp) - 2.0_dp * real(n - 1, dp) / real(n, dp)
    end if
  end function cfactor

  recursive subroutine free_node(node)
    type(TreeNode), pointer, intent(inout) :: node
    if (.not. associated(node)) return
    call free_node(node%left)
    call free_node(node%right)
    deallocate(node)
  end subroutine free_node

end module iforest
