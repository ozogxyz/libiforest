/* Train a forest and score a batch: 100 inliers plus one outlier. */
#include <stdio.h>
#include <stdlib.h>
#include "iforest.h"

int main(void)
{
    int n = 101, m = 2, i;
    double *X = malloc(sizeof(double) * n * m);

    for (i = 0; i < 100; i++) {            /* 100 inliers */
        X[i * m + 0] = (double)rand() / RAND_MAX;
        X[i * m + 1] = (double)rand() / RAND_MAX;
    }
    X[100 * m + 0] = 5.0;                   /* 1 outlier */
    X[100 * m + 1] = 5.0;

    iforest_t f = iforest_train(X, n, m, 100, 0);   /* psi = 0 -> auto */
    double *s = malloc(sizeof(double) * n);
    iforest_score(f, X, n, m, s);
    printf("inlier %.3f   outlier %.3f\n", s[0], s[100]);

    iforest_free(f);
    free(X);
    free(s);
    return 0;
}
