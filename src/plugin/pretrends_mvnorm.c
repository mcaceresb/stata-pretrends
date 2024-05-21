// 17290 - failed to init
// 17291 - unable to achieve desired precision
// 17292 - unable to handle problems of requested size
// 17293 - vcov not PSD

#include "stplugin.h"
#include "pretrends_mvnorm.h"
#include "sf_printf.c"

STDLL stata_call(int argc, char * argv[])
{
    ST_retcode rc = 0;
    PRETRENDS_MVNORM_CHAR(todo, strlen(argv[0]) + 1);
    strcpy(todo, argv[0]);
    if ( strcmp(todo, "_plugin_check") == 0 ) {
        sf_printf("(note: pretrends_mvnorm_plugin v"PRETRENDS_MVNORM_VERSION" successfully loaded)\n");
    }
    else if ( strcmp(todo, "_plugin_run") == 0 ) {
        rc = pretrends_mvnorm();
    }
    else {
        sf_printf("unknown option %s\n", todo);
        rc = 198;
    }
    return(rc);
}

ST_retcode pretrends_mvnorm()
{
    ST_retcode rc = 0;
    int32_t i;

    // Please see documentation of MVTDST subroutine in ./mvtdstpack.f
    int32_t   N;
    int32_t   NU;
    int32_t   MAXPTS;
    ST_double ABSEPS;
    ST_double RELEPS;
    ST_double ERROR;
    ST_double VALUE;
    int32_t   INFORM;
    ST_double *LOWER  = NULL;
    ST_double *UPPER  = NULL;
    int32_t   *INFIN  = NULL;
    ST_double *CORREL = NULL;
    ST_double *DELTA  = NULL;

    // Read problem data
    // -----------------

    if ( (rc = pretrends_mvnorm_read_scalar("__pretrends_mvnorm_N",      &N     )) ) goto exit;
    if ( (rc = pretrends_mvnorm_read_scalar("__pretrends_mvnorm_NU",     &NU    )) ) goto exit;
    if ( (rc = pretrends_mvnorm_read_scalar("__pretrends_mvnorm_MAXPTS", &MAXPTS)) ) goto exit;

    if ( (rc = SF_scal_use("__pretrends_mvnorm_ABSEPS", &ABSEPS)) ) goto exit;
    if ( (rc = SF_scal_use("__pretrends_mvnorm_RELEPS", &RELEPS)) ) goto exit;

    if ((rc = ((LOWER  = calloc(N,             sizeof *LOWER))  == NULL))) goto exit;
    if ((rc = ((UPPER  = calloc(N,             sizeof *UPPER))  == NULL))) goto exit;
    if ((rc = ((INFIN  = calloc(N,             sizeof *INFIN))  == NULL))) goto exit;
    if ((rc = ((CORREL = calloc(N * (N - 1)/2, sizeof *CORREL)) == NULL))) goto exit;
    if ((rc = ((DELTA  = calloc(N,             sizeof *DELTA))  == NULL))) goto exit;

    if ( (rc = pretrends_mvnorm_read_vector("__pretrends_mvnorm_LOWER",  LOWER))  ) goto exit;
    if ( (rc = pretrends_mvnorm_read_vector("__pretrends_mvnorm_UPPER",  UPPER))  ) goto exit;
    if ( (rc = pretrends_mvnorm_read_vector("__pretrends_mvnorm_CORREL", CORREL)) ) goto exit;
    if ( (rc = pretrends_mvnorm_read_vector("__pretrends_mvnorm_DELTA",  DELTA))  ) goto exit;

    // Parse integration limits
    // ------------------------

    for (i = 0; i < N; i++) {
             if (  SF_is_missing(LOWER[i]) &&  SF_is_missing(UPPER[i]) ) INFIN[i] = -1;
        else if (  SF_is_missing(LOWER[i]) && !SF_is_missing(UPPER[i]) ) INFIN[i] =  0;
        else if ( !SF_is_missing(LOWER[i]) &&  SF_is_missing(UPPER[i]) ) INFIN[i] =  1;
        else if ( !SF_is_missing(LOWER[i]) && !SF_is_missing(UPPER[i]) ) INFIN[i] =  2;
    }

    // Run
    // ---

    mvtdst_(&N,
            &NU,
            LOWER,
            UPPER,
            INFIN,
            CORREL,
            DELTA,
            &MAXPTS,
            &ABSEPS,
            &RELEPS,
            &ERROR,
            &VALUE,
            &INFORM);

    if ( (rc = SF_scal_save("__pretrends_mvnorm_ERROR",  ERROR))  ) goto exit;
    if ( (rc = SF_scal_save("__pretrends_mvnorm_VALUE",  VALUE))  ) goto exit;
    if ( (rc = SF_scal_save("__pretrends_mvnorm_INFORM", INFORM)) ) goto exit;

    // Cleanup
    // -------

exit:

    if ( LOWER  ) free(LOWER);
    if ( UPPER  ) free(UPPER);
    if ( INFIN  ) free(INFIN);
    if ( CORREL ) free(CORREL);
    if ( DELTA  ) free(DELTA);

    return(rc);
}

ST_retcode pretrends_mvnorm_read_vector(char *st_matrix, ST_double *v)
{
    ST_retcode rc = 0;
    uint32_t i;
    int32_t ncol = SF_col(st_matrix);
    int32_t nrow = SF_row(st_matrix);
    if ( (ncol > 1) & (nrow > 1) ) {
        sf_errprintf("tried to read a %d by %d matrix into an array\n", nrow, ncol);
        return (198);
    }
    if ( ncol > 1 ) {
        for (i = 0; i < ncol; i++) {
            if ( (rc = SF_mat_el(st_matrix, 1, i + 1, v + i)) )
                return (rc);
        }
    }
    else {
        for (i = 0; i < nrow; i++) {
            if ( (rc = SF_mat_el(st_matrix, i + 1, 1, v + i)) )
                return (rc);
        }
    }
    return(rc);
}

ST_retcode pretrends_mvnorm_read_scalar (char *st_scalar, int32_t *sval)
{
    ST_retcode rc = 0;
    ST_double _double;
    if ( (rc = SF_scal_use(st_scalar, &_double)) ) {
        return (rc);
    }
    else {
        *sval = (int32_t) _double;
    }
    return (rc);
}
