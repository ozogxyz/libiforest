/* Each thread trains and scores its OWN forest via its OWN handle, concurrently.
 * The C ABI keeps no shared state, so per-handle use is thread-safe.
 *
 * Build: see `make threads`. */
#include <stdio.h>
#include <stdlib.h>
#include <omp.h>
#include "iforest.h"

enum { T = 4, N = 2000, M = 8 };

int main(void)
{
    double outlier[T];

    #pragma omp parallel num_threads(T)
    {
        int t = omp_get_thread_num();
        unsigned seed = (unsigned)(t * 2654435761u + 1u);
        double *X = malloc((size_t)N * M * sizeof(double));

        for (int i = 0; i < N; i++)
            for (int j = 0; j < M; j++)
                X[i * M + j] = (double)rand_r(&seed) / RAND_MAX;
        for (int j = 0; j < M; j++)
            X[(N - 1) * M + j] = 10.0;          /* one obvious outlier */

        iforest_t h = iforest_train(X, N, M, 100, 0);
        double *s = malloc((size_t)N * sizeof(double));
        iforest_score(h, X, N, M, s);
        outlier[t] = s[N - 1];

        iforest_free(h);
        free(X);
        free(s);
    }

    for (int t = 0; t < T; t++)
        printf("thread %d: outlier score = %.3f\n", t, outlier[t]);
    return 0;
}
