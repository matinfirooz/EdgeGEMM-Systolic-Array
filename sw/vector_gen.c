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

int main(void) {
    int32_t C[N][N];
    gemm(A, B, C);

    FILE *fa = fopen("vectors/a.hex", "w");
    FILE *fb = fopen("vectors/b.hex", "w");
    FILE *fg = fopen("vectors/golden.hex", "w");
    if (!fa || !fb || !fg) {
        perror("opening vector output");
        return EXIT_FAILURE;
    }

    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j) {
            fprintf(fa, "%02x\n", (uint8_t)A[i][j]);
            fprintf(fb, "%02x\n", (uint8_t)B[i][j]);
            fprintf(fg, "%08x\n", (uint32_t)C[i][j]);
        }
    }

    fclose(fa);
    fclose(fb);
    fclose(fg);

    puts("Generated vectors/a.hex, vectors/b.hex and vectors/golden.hex");
    puts("Golden C = A x B:");
    for (int i = 0; i < N; ++i) {
        for (int j = 0; j < N; ++j)
            printf("%6d", C[i][j]);
        putchar('\n');
    }

    return EXIT_SUCCESS;
}
