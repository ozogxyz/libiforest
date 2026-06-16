import numpy as np

sk = np.loadtxt("bench/sk.txt")
ours = np.loadtxt("bench/ours.txt")
y = np.loadtxt("bench/y.txt").astype(int)


def spearman(a, b):
    ra = np.argsort(np.argsort(a))
    rb = np.argsort(np.argsort(b))
    return np.corrcoef(ra, rb)[0, 1]


def auc(label, score):
    ranks = np.argsort(np.argsort(score)) + 1
    npos = int(label.sum())
    nneg = len(label) - npos
    return (ranks[label == 1].sum() - npos * (npos + 1) / 2) / (npos * nneg)


k = 30
top_ours = set(np.argsort(-ours)[:k])
top_sk = set(np.argsort(-sk)[:k])

print(f"Spearman(ours, sklearn) = {spearman(ours, sk):.3f}")
print(f"AUC ours    vs labels   = {auc(y, ours):.3f}")
print(f"AUC sklearn vs labels   = {auc(y, sk):.3f}")
print(f"top-{k} anomaly overlap  = {len(top_ours & top_sk) / k:.2f}")
