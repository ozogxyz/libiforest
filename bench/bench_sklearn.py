import sys
import time
import resource
import numpy as np
from sklearn.ensemble import IsolationForest

n_jobs = int(sys.argv[1]) if len(sys.argv) > 1 else 1
n, m = 100000, 16
rng = np.random.default_rng(0)
X = rng.standard_normal((n, m))

# same data for the fortran side
with open("bench/Xbig.txt", "w") as fh:
    fh.write(f"{n} {m}\n")
    np.savetxt(fh, X, fmt="%.8e")

clf = IsolationForest(n_estimators=100, max_samples=256, random_state=0, n_jobs=n_jobs)

t0 = time.perf_counter(); clf.fit(X); t_fit = time.perf_counter() - t0
t0 = time.perf_counter(); clf.score_samples(X); t_score = time.perf_counter() - t0
rss = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024.0  # KB -> MB

print(f"n={n} m={m}  trees=100  max_samples=256  n_jobs={n_jobs}")
print(f"sklearn train:    {t_fit:8.3f} s")
print(f"sklearn score:    {t_score:8.3f} s")
print(f"sklearn peak RSS: {rss:8.0f} MB")
