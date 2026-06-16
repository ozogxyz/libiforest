import numpy as np
from sklearn.datasets import load_breast_cancer
from sklearn.ensemble import IsolationForest
from sklearn.metrics import roc_auc_score

d = load_breast_cancer()
X = d.data                         # 569 x 30, real measurements
y = (d.target == 0).astype(int)    # malignant = anomaly = 1

clf = IsolationForest(n_estimators=100, max_samples=256, random_state=0)
clf.fit(X)
sk = -clf.score_samples(X)         # higher = more anomalous (paper convention)

np.savetxt("bench/X.txt", X, header=f"{X.shape[0]} {X.shape[1]}", comments="")
np.savetxt("bench/sk.txt", sk)
np.savetxt("bench/y.txt", y, fmt="%d")

print("dataset: breast_cancer", X.shape, "anomalies:", int(y.sum()))
print("sklearn AUC:", round(roc_auc_score(y, sk), 4))
