/* libiforest - Isolation Forest anomaly detection. C ABI.
 *
 * Data is row-major: X[i*m + j] is sample i, feature j. n*m must fit in int.
 * Score is in (0, 1]: ~0.5 nominal, -> 1 more anomalous.
 */
#ifndef IFOREST_H
#define IFOREST_H

#ifdef __cplusplus
extern "C" {
#endif

/* Opaque handle to a trained forest. */
typedef void *iforest_t;

/* Train on X (n rows x m cols, row-major).
 * n_trees <= 0 -> 100; psi <= 0 -> min(256, n); both are clamped to valid ranges.
 * Returns NULL if n < 2 or m < 1. Release the handle with iforest_free. */
iforest_t iforest_train(const double *X, int n, int m, int n_trees, int psi);

/* Score n points (row-major) into scores[0..n-1]: caller-allocated, >= n doubles,
 * higher = more anomalous. No-op (scores left untouched) if h is NULL or m differs
 * from the m used at train time. */
void iforest_score(iforest_t h, const double *X, int n, int m, double *scores);

/* Free a forest returned by iforest_train (NULL is ignored). */
void iforest_free(iforest_t h);

#ifdef __cplusplus
}
#endif

#endif /* IFOREST_H */
