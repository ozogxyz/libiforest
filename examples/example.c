#include <stdio.h>
#include <stdlib.h>
#include "iforest.h"

int main(void)
{
    int n = 200, m = 2, i;
    double *X = malloc((size_t)n * m * sizeof(double));

    for (i = 0; i < n - 1; i++) {       /* a tight diagonal line of inliers */
        X[i * m + 0] = i * 0.01;
        X[i * m + 1] = i * 0.01;
    }
    X[(n - 1) * m + 0] =  100.0;        /* one obvious outlier */
    X[(n - 1) * m + 1] = -100.0;

    iforest_t h = iforest_train(X, n, m, 100, 0);   /* psi = 0 -> auto */

    double *s = malloc((size_t)n * sizeof(double));
    iforest_score(h, X, n, m, s);
    printf("inlier  score = %.3f\n", s[0]);
    printf("outlier score = %.3f\n", s[n - 1]);

    iforest_free(h);
    free(X); free(s);
    return 0;
}
