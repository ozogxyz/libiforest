/* Binary anomaly labels from C. Build via `make cdemo-predict`. */
#include <stdio.h>
#include <stdlib.h>
#include "iforest.h"

int main(void)
{
    int n = 210, m = 2, i;
    double *X = malloc((size_t)n * m * sizeof(double));
    int *lab = malloc((size_t)n * sizeof(int));

    for (i = 0; i < 200; i++) {                 /* 200 inliers */
        X[i * m + 0] = (double)rand() / RAND_MAX;
        X[i * m + 1] = (double)rand() / RAND_MAX;
    }
    for (i = 200; i < n; i++) {                 /* 10 outliers */
        X[i * m + 0] = 20.0 + (double)rand() / RAND_MAX;
        X[i * m + 1] = 20.0 + (double)rand() / RAND_MAX;
    }

    iforest_t h = iforest_train(X, n, m, 100, 0);
    iforest_predict(h, X, n, m, lab, 0.6);

    int flagged = 0;
    for (i = 0; i < n; i++) flagged += lab[i];
    printf("flagged at 0.6 = %d (of %d; ~10 are outliers)\n", flagged, n);

    iforest_free(h);
    free(X);
    free(lab);
    return 0;
}
