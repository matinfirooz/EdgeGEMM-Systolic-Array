#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#define N 4

static const int8_t A[N][N] = {
    { 1,  2,  3,  4},
    { 5,  6,  7,  8},
    {-1,  2, -3,  4},
    { 8,  0,  1, -2}
};

static const int8_t B[N][N] = {
    {1,  0,  2, -1},
    {3,  1,  0,  2},
    {2, -2,  1,  1},
    {0,  4, -1,  3}
};

static const int32_t EXPECTED[N][N] = {
    {13,  12,  1,  18},
    {37,  24,  9,  38},
    {-1,  24, -9,  14},
    {10, -10, 19, -13}
};

static void gemm(const int8_t a[N][N], const int8_t b[N][N], int32_t c[N][N]) {
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            int32_t sum = 0;
            for (int k = 0; k < N; ++k)
                sum += (int32_t)a[i][k] * (int32_t)b[k][j];
            c[i][j] = sum;
        }
    }
}

static int8_t requantize(int32_t x, unsigned shift, int relu) {
    int32_t y = x >> shift;
    if (relu && y < 0)
        y = 0;
    if (y > 127)
        y = 127;
    if (y < -128)
        y = -128;
    return (int8_t)y;
}

int main(void) {
    int32_t C[N][N];
    int errors = 0;

    gemm(A, B, C);

    puts("EdgeGEMM C golden model");
    puts("C = A x B");

    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            printf("%6d", C[i][j]);
            if (C[i][j] != EXPECTED[i][j])
                ++errors;
        }
        putchar('\n');
    }

    if (requantize(13, 0, 0) != 13) ++errors;
    if (requantize(-1, 0, 1) != 0) ++errors;
    if (requantize(500, 0, 0) != 127) ++errors;
    if (requantize(-500, 0, 0) != -128) ++errors;

    if (errors) {
        fprintf(stderr, "FAIL: %d mismatches\n", errors);
        return EXIT_FAILURE;
    }

    printf("PASS: all %d GEMM outputs and requantization checks match.\n", N*N);
    printf("Ideal %dx%d wavefront compute latency: %d cycles.\n", N, N, 3*N-2);
    return EXIT_SUCCESS;
}
