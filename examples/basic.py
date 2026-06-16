"""libiforest from Python (ctypes). Run `make shared` first, then this file."""
import os
import sys

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "wrappers"))

import numpy as np
from iforest import IsolationForest

rng = np.random.default_rng(0)
X = np.vstack([rng.standard_normal((500, 4)), [[8, 8, 8, 8]]])   # 500 inliers + 1 outlier

f = IsolationForest(n_trees=100).fit(X)
s = f.score(X)
print(f"inlier mean = {s[:500].mean():.3f}   outlier = {s[-1]:.3f}")
print("anomalies (score > 0.6):", int(f.predict(X, threshold=0.6).sum()))
