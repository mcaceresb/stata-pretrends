#ifndef PRETRENDS_MVNORM
#define PRETRENDS_MVNORM

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#define PRETRENDS_MVNORM_VERSION "0.1.0"

#define PRETRENDS_MVNORM_CHAR(cvar, len)                \
    char *(cvar) = malloc(sizeof(char) * (len)); \
    memset ((cvar), '\0', sizeof(char) * (len))

#define PRETRENDS_MVNORM_PWMAX(a, b) ( (a) > (b) ? (a) : (b) )
#define PRETRENDS_MVNORM_PWMIN(a, b) ( (a) > (b) ? (b) : (a) )

ST_retcode pretrends_mvnorm_read_vector(char *, ST_double *);
ST_retcode pretrends_mvnorm_read_scalar(char *, int32_t *);
ST_retcode pretrends_mvnorm();
void mvtdst_(int32_t *, int32_t *,
             ST_double *, ST_double *, int32_t *,
             ST_double *, ST_double *,
             int32_t *, ST_double *, ST_double *,
             ST_double *, ST_double *, int32_t *);

#endif
