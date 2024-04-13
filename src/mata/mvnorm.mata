cap mata mata drop PreTrends_mvnorm_mean()
cap mata mata drop PreTrends_dtmvnorm_marginal()
cap mata mata drop PreTrends_inverse()
cap mata mata drop PreTrends_mvnormalcv()

mata
real vector function PreTrends_mvnorm_mean(real vector mu, real matrix sigma, real vector lb, real vector ub)
{
    real matrix F
    real scalar i, k, s, a, b
    real vector lower, upper

    k = length(mu)
    if ( k == 1 ) {
        s = sqrt(sigma)
        a = (lb - mu) / s
        b = (ub - mu) / s
        return(mu + ((normalden(a) - normalden(b)) / (normal(b) - normal(a))) * s)
    }
    else {
        lower = lb :- mu
        upper = ub :- mu
        F     = J(2, k, .)
        for (i = 1; i <= k; i++) {
            F[.,i] = PreTrends_dtmvnorm_marginal((lower[i] \ upper[i]), i, J(1,k,0), sigma, lower, upper)
        }
        return(mu + ((F[1,.] - F[2,.]) * sigma))
    }
}

real vector function PreTrends_dtmvnorm_marginal(real vector xn,
                                                 real scalar ix,
                                                 real vector mu,
                                                 real matrix sigma,
                                                 real vector lower,
                                                 real vector upper)
{
    real scalar i, k, c_ix, mu_ix, p
    real vector inv, c, mu_1, m, f_xn
    real matrix A, A_1, A_1_inv

    // Partition mu, vcov omitting index and collecting the rest
    k       = length(mu)
    inv     = PreTrends_inverse(ix, k)

    mu_1    = mu[inv]
    mu_ix   = mu[ix]

    A       = invsym(sigma)
    A_1     = A[inv, inv]
    A_1_inv = invsym(A_1)

    c_ix    = sigma[ix, ix]
    c       = sigma[ix, inv]

    // Compute truncated marginal density
    p    = PreTrends_mvnormalcv(lower, upper, mu, sigma)
    f_xn = J(rows(xn), cols(xn), .)
    for (i = 1; i <= length(xn); i++) {
        m = mu_1 :+ (xn[i] :- mu_ix) :* c :/ c_ix
        f_xn[i] = exp(-0.5 * (xn[i] - mu_ix)^2 / c_ix) * PreTrends_mvnormalcv(lower[inv], upper[inv], m, A_1_inv)
    }

    return(f_xn / sqrt(2 * pi() * c_ix) / p)
}

real matrix function PreTrends_inverse(real vector ix, real scalar n)
{
    real vector sel
    if (rows(ix) > cols(ix)) {
        sel = J(n, 1, 1)
        sel[ix] = J(length(ix), 1, 0)
    }
    else {
        sel = J(1, n, 1)
        sel[ix] = J(1, length(ix), 0)
    }
    return(selectindex(sel))
}

real scalar function PreTrends_mvnormalcv(real vector lower, real vector upper, real vector mu, real matrix sigma,
                                          | real scalar df, real scalar maxpts, real scalar abseps, real scalar releps)
{
    real scalar i, j, p, n, warn
    real vector correl, sd

    warn = strtoreal(st_global("PRETRENDS_MVNORM_WARN"))
    n = length(mu)
    if ( n < 2 ) {
        return(normal((upper - mu) / sqrt(sigma)) - normal((lower - mu) / sqrt(sigma)))
    }

    // Check plugin
    // ------------

    stata("cap plugin call pretrends_mvnorm_plugin, _plugin_check")
    stata("scalar __pretrends_mvnorm_rc = _rc")

    if ( st_numscalar("__pretrends_mvnorm_rc") == 0 ) {

        // Parse and format input
        // ----------------------

        // NB: mvtnorm uses 1e-3 as default tolerance tho
        if ( (args() < 5) | (missing(df))     ) df     = 0
        if ( (args() < 7) | (missing(abseps)) ) abseps = epsilon(1)^(1/5)
        if ( (args() < 6) | (missing(maxpts)) ) maxpts = max((25000, ceil(n/abseps)))
        if ( (args() < 8) | (missing(releps)) ) releps = 0

        sd = sqrt(diagonal(sigma))'
        correl = J(1, n * (n - 1) / 2, .)
        for (i = 1; i <= n; i++) {
            for (j = 1; j < i; j++) {
                correl[j + (i - 2) * (i - 1)/2] = sigma[i, j] / (sd[i] * sd[j])
            }
        }

        st_numscalar("__pretrends_mvnorm_N",      n)
        st_numscalar("__pretrends_mvnorm_NU",     df)
        st_numscalar("__pretrends_mvnorm_MAXPTS", maxpts)
        st_numscalar("__pretrends_mvnorm_ABSEPS", abseps)
        st_numscalar("__pretrends_mvnorm_RELEPS", releps)

        st_matrix("__pretrends_mvnorm_LOWER",  rowshape(lower, 1) :/ sd)
        st_matrix("__pretrends_mvnorm_UPPER",  rowshape(upper, 1) :/ sd)
        st_matrix("__pretrends_mvnorm_CORREL", correl)
        st_matrix("__pretrends_mvnorm_DELTA",  rowshape(mu, 1) :/ sd)

        // Run pugin until desired tolerance
        // ---------------------------------

        st_numscalar("__pretrends_mvnorm_INFORM", 1)
        while ( (st_numscalar("__pretrends_mvnorm_INFORM") == 1) & (st_numscalar("__pretrends_mvnorm_rc") == 0) ) {
            stata("cap noi plugin call pretrends_mvnorm_plugin, _plugin_run")
            stata("scalar __pretrends_mvnorm_rc = _rc")
            maxpts = 10 * maxpts
            st_numscalar("__pretrends_mvnorm_MAXPTS", maxpts)
        }

        // Parse error code
        // ----------------

        if ( st_numscalar("__pretrends_mvnorm_rc") == 0 ) {
            if ( st_numscalar("__pretrends_mvnorm_INFORM") == 0 ) {
                p = st_numscalar("__pretrends_mvnorm_VALUE")
            }
            else {
                if ( st_numscalar("__pretrends_mvnorm_INFORM") == 1 ) {
                    if ( warn ) errprintf("ERROR: Unable to achieve desired tolerance; falling back on mata.\n")
                    
                }
                else if ( st_numscalar("__pretrends_mvnorm_INFORM") == 2 ) {
                    if ( warn ) errprintf("ERROR: Unable to handle problems of size %g; falling back on mata.\n", n)
                    
                }
                else if ( st_numscalar("__pretrends_mvnorm_INFORM") == 3 ) {
                    if ( warn ) errprintf("ERROR: vcov not PSD; falling back on mata.\n")
                    
                }
                st_numscalar("__pretrends_mvnorm_rc", 17290 + st_numscalar("__pretrends_mvnorm_INFORM"))
            }
        }
        else {
            if ( warn ) errprintf("WARNING: Unknown error; falling back on mata.\n")
        }
    }
    else {
        if ( warn ) errprintf("WARNING: Unable to load mvnormalcv() plugin; falling back on mata.\n")
    }

    // Fallback if error
    // -----------------

    if ( st_numscalar("__pretrends_mvnorm_rc") ) {
        if ( warn ) {
            errprintf("Execution may be excessively slow. If it takes more a few minutes\n")
            errprintf("we recommend using the R package.\n")
            // if ( args() >= 5 ) {
            //     errprintf("WARNING: Additional arguments ignored with fallback.\n")
            // }
            st_global("PRETRENDS_MVNORM_WARN", "0")
        }
        p = mvnormalcv(lower, upper, mu, vech(sigma)')
    }

    // Cleanup
    // -------

    st_numscalar("__pretrends_mvnorm_rc",     J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_N",      J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_NU",     J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_MAXPTS", J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_ABSEPS", J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_RELEPS", J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_ERROR",  J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_VALUE",  J(0, 0, .))
    st_numscalar("__pretrends_mvnorm_INFORM", J(0, 0, .))

    st_matrix("__pretrends_mvnorm_LOWER",  J(0, 0, .))
    st_matrix("__pretrends_mvnorm_UPPER",  J(0, 0, .))
    st_matrix("__pretrends_mvnorm_CORREL", J(0, 0, .))
    st_matrix("__pretrends_mvnorm_DELTA",  J(0, 0, .))

    return(p)
}
end
