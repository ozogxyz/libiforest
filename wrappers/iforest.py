"""ctypes wrapper over libiforest's C ABI. Build the shared lib first: make shared."""
import ctypes
import os

import numpy as np

_so = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "build", "libiforest.so"))
_lib = ctypes.CDLL(_so)

_dp = ctypes.POINTER(ctypes.c_double)
_ip = ctypes.POINTER(ctypes.c_int)
_lib.iforest_train.restype = ctypes.c_void_p
_lib.iforest_train.argtypes = [_dp, ctypes.c_int, ctypes.c_int, ctypes.c_int, ctypes.c_int]
_lib.iforest_score.argtypes = [ctypes.c_void_p, _dp, ctypes.c_int, ctypes.c_int, _dp]
_lib.iforest_predict.argtypes = [ctypes.c_void_p, _dp, ctypes.c_int, ctypes.c_int, _ip, ctypes.c_double]
_lib.iforest_free.argtypes = [ctypes.c_void_p]


class IsolationForest:
    def __init__(self, n_trees=100, psi=0):
        self.n_trees = n_trees
        self.psi = psi
        self._h = None

    def fit(self, X):
        X = np.ascontiguousarray(X, dtype=np.float64)   # row-major, as the C ABI expects
        n, m = X.shape
        self._h = _lib.iforest_train(X.ctypes.data_as(_dp), n, m, self.n_trees, self.psi)
        return self

    def score(self, X):
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, m = X.shape
        s = np.empty(n, dtype=np.float64)
        _lib.iforest_score(self._h, X.ctypes.data_as(_dp), n, m, s.ctypes.data_as(_dp))
        return s

    def predict(self, X, threshold=0.5):
        X = np.ascontiguousarray(X, dtype=np.float64)
        n, m = X.shape
        lab = np.empty(n, dtype=np.int32)
        _lib.iforest_predict(self._h, X.ctypes.data_as(_dp), n, m,
                             lab.ctypes.data_as(_ip), ctypes.c_double(threshold))
        return lab

    def __del__(self):
        if self._h:
            _lib.iforest_free(self._h)
            self._h = None


if __name__ == "__main__":
    rng = np.random.default_rng(0)
    X = np.vstack([rng.standard_normal((500, 4)), [[8, 8, 8, 8]]])   # 500 inliers + 1 outlier
    f = IsolationForest().fit(X)
    s = f.score(X)
    lab = f.predict(X, threshold=0.6)
    print(f"inlier mean = {s[:500].mean():.3f}  outlier = {s[-1]:.3f}  flagged = {int(lab.sum())}")
    assert s[-1] > s[:500].mean(), "outlier should score higher"
    print("ctypes wrapper OK")
