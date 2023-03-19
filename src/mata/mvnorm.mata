cap mata mata drop PreTrends_mvnorm_mean()
cap mata mata drop PreTrends_dtmvnorm_marginal()
cap mata mata drop PreTrends_inverse()

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
    p    = mvnormalcv(lower, upper, mu, vech(sigma)')
    f_xn = J(rows(xn), cols(xn), .)
    for (i = 1; i <= length(xn); i++) {
        m = mu_1 :+ (xn[i] :- mu_ix) :* c :/ c_ix
        f_xn[i] = exp(-0.5 * (xn[i] - mu_ix)^2 / c_ix) * mvnormalcv(lower[inv], upper[inv], m, vech(A_1_inv)')
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
end
