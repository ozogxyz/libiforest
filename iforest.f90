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

  ! Transient node used only while a tree is being built; the finished tree is
  ! flattened into contiguous arrays (Tree) and these nodes are freed.
  type :: TreeNode
     logical                 :: is_leaf
     integer                 :: split_feature
     real(dp)                :: split_value
     type(TreeNode), pointer :: left => null()
     type(TreeNode), pointer :: right => null()
     integer                 :: size
  end type TreeNode

  ! Flattened tree: parallel arrays in preorder. node 1 is the root; a leaf has
  ! feat < 0 and left = right = 0. Cache- and branch-predictor-friendly.
  type :: Tree
     integer,  allocatable :: feat(:)
     real(dp), allocatable :: thr(:)
     integer,  allocatable :: left(:)
     integer,  allocatable :: right(:)
     integer,  allocatable :: nsize(:)
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
    integer :: i, hlim
    integer, allocatable :: idx(:)
    type(TreeNode), pointer :: root

    call free_forest(forest)

    allocate(forest%trees(n_trees))
    forest%n_trees = n_trees
    forest%psi = psi
    forest%n_features = size(X, 2)

    hlim = ceiling(log(real(psi, dp)) / log(2.0_dp))
    allocate(idx(psi))
    do i = 1, n_trees
       call subsample(n_samples, psi, idx)
       root => build_tree(X, idx, 0, hlim)
       call flatten(root, forest%trees(i))
       call free_node(root)
    end do
    deallocate(idx)
  end subroutine

  subroutine free_forest(forest)
    type(IsolationForest), intent(inout) :: forest
    if (allocated(forest%trees)) deallocate(forest%trees)
  end subroutine

  subroutine predict_scores(forest, X, n_samples, scores)
    type(IsolationForest), intent(in) :: forest
    real(dp), intent(in) :: X(:,:)
    integer, intent(in) :: n_samples
    real(dp), intent(out) :: scores(:)
    integer :: i, j, m
    real(dp) :: c_psi
    real(dp), allocatable :: XT(:,:), avg_h(:)

    m = forest%n_features
    allocate(XT(m, n_samples), avg_h(n_samples))
    do i = 1, n_samples              ! transpose so each sample's features are contiguous
       XT(:, i) = X(i, 1:m)
    end do

    avg_h = 0.0_dp
    do j = 1, forest%n_trees         ! one tree stays cache-resident across all samples
       call accumulate_tree(forest%trees(j), XT, n_samples, avg_h)
    end do

    c_psi = cfactor(forest%psi)
    do i = 1, n_samples
       scores(i) = 2.0_dp ** (-(avg_h(i) / forest%n_trees) / c_psi)
    end do
    deallocate(XT, avg_h)
  end subroutine

  ! Descend every sample through one tree. The flat tree arrays stay hot while
  ! the sample columns of XT stream past. This is the hot path.
  subroutine accumulate_tree(t, XT, n, avg_h)
    type(Tree), intent(in) :: t
    real(dp), intent(in) :: XT(:,:)
    integer, intent(in) :: n
    real(dp), intent(inout) :: avg_h(:)
    integer :: i, node, depth

    do i = 1, n
       node = 1
       depth = 0
       do while (t%feat(node) >= 0)
          if (XT(t%feat(node), i) < t%thr(node)) then
             node = t%left(node)
          else
             node = t%right(node)
          end if
          depth = depth + 1
       end do
       avg_h(i) = avg_h(i) + real(depth, dp) + cfactor(t%nsize(node))
    end do
  end subroutine accumulate_tree

  ! ---- tree construction (transient pointer form) -------------------------

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

  recursive subroutine free_node(node)
    type(TreeNode), pointer, intent(inout) :: node
    if (.not. associated(node)) return
    call free_node(node%left)
    call free_node(node%right)
    deallocate(node)
  end subroutine free_node

  ! ---- flatten the pointer tree into contiguous arrays --------------------

  subroutine flatten(root, t)
    type(TreeNode), pointer, intent(in) :: root
    type(Tree), intent(out) :: t
    integer :: cnt, pos

    cnt = count_nodes(root)
    allocate(t%feat(cnt), t%thr(cnt), t%left(cnt), t%right(cnt), t%nsize(cnt))
    pos = 0
    call fill(root, t, pos)
  end subroutine

  recursive function count_nodes(node) result(c)
    type(TreeNode), pointer, intent(in) :: node
    integer :: c
    if (.not. associated(node)) then
       c = 0
    else
       c = 1 + count_nodes(node%left) + count_nodes(node%right)
    end if
  end function count_nodes

  recursive subroutine fill(node, t, pos)
    type(TreeNode), pointer, intent(in) :: node
    type(Tree), intent(inout) :: t
    integer, intent(inout) :: pos
    integer :: me

    pos = pos + 1
    me = pos
    t%nsize(me) = node%size
    if (node%is_leaf) then
       t%feat(me) = -1
       t%thr(me) = 0.0_dp
       t%left(me) = 0
       t%right(me) = 0
    else
       t%feat(me) = node%split_feature
       t%thr(me) = node%split_value
       t%left(me) = pos + 1
       call fill(node%left, t, pos)
       t%right(me) = pos + 1
       call fill(node%right, t, pos)
    end if
  end subroutine fill

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

end module iforest
