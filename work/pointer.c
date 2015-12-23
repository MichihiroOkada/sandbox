#include<stdio.h>

int main(void)
{
    int i, j, k;
    int a[2][3][4] = {1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24};
    int (*b)[3][4] = a;
    int *c[2][3] = {a[0][0], a[0][1], a[0][2], a[1][0], a[1][1], a[1][2]};
    int *(*d)[3] = c;
    int **e[2]= {d[0], d[1]};
    int ***f = e;
    int (*g[2])[4] = {a[0], a[1]};
    int (**h)[4] = g;

    printf("a[0] = %8p, a[1] = %8p, a[2] = %8p\n", a[0], a[1], a[2]);

    printf("%3s\t%3s\t%3s\t%3s\t%3s\t%3s\t%3s\t%3s\n", "a", "b", "c", "d", "e", "f", "g", "h");
    printf("------------------------------------------------------------------\n");
    for(i = 0; i < 2; i++) {
        for(j = 0; j < 3; j++) {
            for(k = 0; k < 4; k++) {
                printf("%3d",   a[i][j][k]);
                printf("\t%3d", b[i][j][k]);
                printf("\t%3d", c[i][j][k]);
                printf("\t%3d", d[i][j][k]);
                printf("\t%3d", e[i][j][k]);
                printf("\t%3d", f[i][j][k]);
                printf("\t%3d", g[i][j][k]);
                printf("\t%3d", h[i][j][k]);
                printf("\n");
            }
        }
    }

    return 0;
}

