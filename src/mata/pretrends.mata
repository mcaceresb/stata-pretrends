cap mata mata drop PreTrendsResults()
cap mata mata drop PreTrends()
cap mata mata drop PreTrendsPower()
cap mata mata drop PreTrendsParse()
cap mata mata drop PreTrendsPowerFun()
cap mata mata drop PreTrendsRejectionProb()
cap mata mata drop PreTrendsBisect()
cap mata mata drop PreTrendsMeansBetaPost()
cap mata mata drop PreTrendsExampleBeta()
cap mata mata drop PreTrendsExampleSigma()
cap mata mata drop PreTrendsPost()

mata:
// b             = "`b'"
// V             = "`vcov'"
// numPrePeriods = `numpreperiods'
// pre           = "`preperiodindices'"
// post          = "`postperiodindices'"
// alpha         = `alpha'
// power         = `power'
// delta         = `delta'
// omit          = "`omit'"

struct PreTrendsResults {
    // Problem results
    real scalar slope
    real scalar Power
    real scalar Bayes
    real scalar LR
    real matrix ES
    real vector deltatrue

    // Problem info
    real vector betahat
    real matrix sigma
    real vector timeVec
    real vector referencePeriod
    real scalar numPrePeriods
    real scalar numPostPeriods
    real vector prePeriodIndices
    real vector postPeriodIndices
    real scalar alpha
    real scalar power
    real scalar delta
    real scalar omit
}

struct PreTrendsResults scalar PreTrends(string scalar b,
                                         string scalar V,
                                         real scalar numPrePeriods,
                                         string scalar pre,
                                         string scalar post,
                                         real scalar alpha,
                                         real scalar power,
                                         real scalar delta,
                                         string scalar deltatrue,
                                         string scalar omit)
{
    struct PreTrendsResults scalar results
    real scalar power_against_betatrue, power_against_0, likelihood_betatrue, likelihood_0, meanBetaPre, meanBetaPost
    real scalar thresh
    real vector bb, se, ub, mm, betaPreActual, betaPreAlt
    real matrix sigmaPre, CI

    // Setup
    results = PreTrendsParse(b, V, numPrePeriods, pre, post, alpha, power, delta, omit)
    if ( deltatrue == "" ) {
        results.slope     = results.delta == .? PreTrendsPower(results): results.delta
        results.deltatrue = results.slope * (results.timeVec :- results.referencePeriod)
    }
    else {
        results.slope     = .
        results.deltatrue = rowshape(st_matrix(deltatrue), 1)
    }

    thresh    = invnormal(1-results.alpha/2)

    // Extract the objets corresponding with the pre-period
    betaPreActual = results.betahat[results.prePeriodIndices]
    betaPreAlt    = results.deltatrue[results.prePeriodIndices]
    sigmaPre      = results.sigma[results.prePeriodIndices, results.prePeriodIndices]

    // Compute power against the alt trend and power against 0 (i.e. size of test)
    power_against_betatrue = PreTrendsRejectionProb(     betaPreAlt, sigmaPre, thresh)
    power_against_0        = PreTrendsRejectionProb(0 :* betaPreAlt, sigmaPre, thresh)

    // Compute likelihoods under beta=betaPreAlt and beta=0
    if ( results.numPrePeriods == 1 ) {
        likelihood_betatrue = normalden(betaPreActual,      betaPreAlt, sqrt(sigmaPre))
        likelihood_0        = normalden(betaPreActual, 0 :* betaPreAlt, sqrt(sigmaPre))
    }
    else {
        likelihood_betatrue = exp(lnmvnormalden(betaPreActual, sigmaPre,      betaPreAlt))
        likelihood_0        = exp(lnmvnormalden(betaPreActual, sigmaPre, 0 :* betaPreAlt))
    }

    // Compute the means after pre-testing
    ub           = rowshape(sqrt(diagonal(sigmaPre)),1) * thresh
    meanBetaPre  = PreTrends_mvnorm_mean(betaPreAlt, sigmaPre, -ub, ub)
    meanBetaPost = PreTrendsMeansBetaPost(results)
    mm           = (meanBetaPre, 0, meanBetaPost)'

    // Put all the results together
    se = sqrt(diagonal(results.sigma))
    bb = colshape(results.betahat,1)
    CI = bb, (bb :- thresh :* se, bb :+ thresh :* se)
    CI = CI[results.prePeriodIndices,.] \ (0, 0, 0) \ CI[results.postPeriodIndices,.]
    results.Power = power_against_betatrue
    results.Bayes = (1-power_against_betatrue) / (1-power_against_0)
    results.LR    = likelihood_betatrue / likelihood_0
    results.ES    = colshape(results.timeVec,1), CI, colshape(results.deltatrue,1), mm
    return(results)
}

// Parse stata options
struct PreTrendsResults scalar PreTrendsParse(string scalar b,
                                              string scalar V,
                                              real scalar numPrePeriods,
                                              string scalar pre,
                                              string scalar post,
                                              real scalar alpha,
                                              real scalar power,
                                              real scalar delta,
                                              string scalar omit)
{
    struct PreTrendsResults scalar results
    real vector selomit, sel

    stata(sprintf("_ms_omit_info %s", b))
    selomit = selectindex(!editvalue(st_matrix("r(omit)"), omit == "", 0))
    if ( omit != "" ) {
        if ( rows(st_matrix(b)) > cols(st_matrix(b)) ) {
            printf("-omit- requires b() to be a cow vector; option ignored\n")
            omit    = ""
            selomit = 1..length(st_matrix(b))
        }
    }

    if ( rows(st_matrix(V)) != cols(st_matrix(V)) ) {
        errprintf("vcov() is not a square matrix\n")
        _error(198)
    }

    if ( max((rows(st_matrix(b)), cols(st_matrix(b)))) != rows(st_matrix(V)) ) {
        errprintf("b() and vcov() not conformable\n")
        _error(198)
    }

    results = PreTrendsResults()
    if ( numPrePeriods > 0 ) {
        results.betahat = rowshape(st_matrix(b), 1)[selomit]
        results.sigma   = st_matrix(V)[selomit, selomit]
        results.numPrePeriods     = numPrePeriods
        results.numPostPeriods    = length(results.betahat)-numPrePeriods
        results.prePeriodIndices  = 1..numPrePeriods
        results.postPeriodIndices = (numPrePeriods+1)..length(results.betahat)
    }
    else {
        results.prePeriodIndices  = strtoreal(tokens(pre))
        results.postPeriodIndices = strtoreal(tokens(post))
        sel = results.prePeriodIndices, results.postPeriodIndices
        results.betahat = rowshape(st_matrix(b), 1)[selomit][sel]
        results.sigma   = st_matrix(V)[selomit, selomit][sel, sel]
        results.numPrePeriods  = length(results.prePeriodIndices)
        results.numPostPeriods = length(results.postPeriodIndices)
    }

    results.omit    = (omit != "")
    results.alpha   = alpha
    results.power   = power
    results.delta   = delta
    results.timeVec = (results.prePeriodIndices, results.numPrePeriods+1, (results.postPeriodIndices:+1)) :- (results.numPrePeriods+2)
    results.referencePeriod = -1

    return(results)
}

// Find slope that tives requested power
real scalar function PreTrendsPower(struct PreTrendsResults scalar results)
{
    real matrix sigmaPre
    real vector relative
    real scalar thresh, lower, upper

    thresh   = invnormal(1-results.alpha/2)
    sigmaPre = results.sigma[results.prePeriodIndices, results.prePeriodIndices]
    relative = results.timeVec[results.prePeriodIndices] :- results.referencePeriod
    lower    = 0
    upper    = 8 * max(sqrt(diagonal(sigmaPre)))
    // Max expected iterations are upper * log(1/epsilon(1)^0.75)/log(2), which is 39 * upper (so 1k is plenty)

    return(PreTrendsBisect(&PreTrendsPowerFun(), lower, upper, results.power, 1000, sigmaPre, thresh, relative))
}

real scalar function PreTrendsPowerFun(real scalar slope, real matrix sigmaPre, real scalar thresh, real vector relative)
{
    return(PreTrendsRejectionProb(relative * slope, sigmaPre, thresh))
}

real scalar function PreTrendsRejectionProb(real vector betaPre, real matrix sigmaPre, real scalar thresh)
{
    real rowvector ub
    ub = rowshape(sqrt(diagonal(sigmaPre)), 1) * thresh
    return(1 - mvnormalcv(-ub, ub, rowshape(betaPre, 1), vech(sigmaPre)'))
}

// Find zero of a function via bisection; while this is semi-generically
// written it's actually tailored specifically for PreTrendsPowerFun
real scalar function PreTrendsBisect(pointer(real scalar function)f,
                                     real scalar lower,
                                     real scalar upper,
                                     | real scalar target,
                                     real scalar maxiter,
                                     real matrix sigmaPre,
                                     real scalar thresh,
                                     real vector relative)
{
    if ( args() < 4 ) target   = 0
    if ( args() < 5 ) maxiter  = 1000
    if ( args() < 6 ) sigmaPre = .
    if ( args() < 7 ) thresh   = .
    if ( args() < 8 ) relative = .
    real scalar reltol, tol, i, x, fx, xdiff, fprod

    if ( lower >= upper ) {
        errprintf("PreTrendsBisect(): Invalid starting points (lower >= upper)\n")
        _error(198)
    }

    if ( ((*f)(lower, sigmaPre, thresh, relative) - target) * ((*f)(upper, sigmaPre, thresh, relative) - target) > 0 ) {
        errprintf("PreTrendsBisect(): Invalid starting points (f(lower) * f(upper) > 0)\n")
        _error(198)
    }

    i      = 0
    tol    = epsilon(1)^0.75
    reltol = epsilon(1)
    fx     = 1 + tol
    xdiff  = 1 + reltol
    while ( (++i <= maxiter) & (abs(fx) > tol) & (xdiff > reltol) ) {
        x     = (lower + upper) / 2
        fx    = (*f)(x, sigmaPre, thresh, relative) - target
        xdiff = (upper - lower) / (1 + abs(lower) + abs(upper))
        fprod = ((*f)(lower, sigmaPre, thresh, relative) - target) * fx
        if ( fprod > 0 ) {
            lower = x
        }
        else if ( fprod < 0 ) {
            upper = x
        }
    }

    if ( abs(fx) > tol ) {
        if ( i <= maxiter ) {
            errprintf("No further improvements can be made. Relative distance upper - lower\n")
            errprintf("was %7.5g. < %7.5g. Current value was f(%7.5g) - %7.5g = %7.5g.\n", xdiff, reltol, x, target, fx)
            _error(198)
        }
        else {
            errprintf("Maximum number of iterations reached (%g) before desired\n", maxiter)
            errprintf("tolerance (%7.5g). Current value was f(%7.5g) - %7.5g = %7.5g.\n", tol, x, target, fx)
            _error(198)
        }
    }
    else {
        return((lower + upper) / 2)
    }
}

real vector function PreTrendsMeansBetaPost(struct PreTrendsResults scalar results)
{
    real scalar thresh
    real vector ub, betaPre, betaPost
    real matrix sigmaPre, sigma21

    betaPre   = results.deltatrue[results.prePeriodIndices]
    sigmaPre  = results.sigma[results.prePeriodIndices, results.prePeriodIndices]
    betaPost  = results.deltatrue[1 :+ results.postPeriodIndices]
    sigma21   = results.sigma[results.prePeriodIndices, results.postPeriodIndices]
    thresh    = invnormal(1-results.alpha/2)
    ub        = rowshape(sqrt(diagonal(sigmaPre)), 1) * thresh

    return(betaPost + (PreTrends_mvnorm_mean(betaPre, sigmaPre, -ub, ub) - betaPre) * invsym(sigmaPre) * sigma21)
}

void function PreTrendsPost(struct PreTrendsResults scalar results)
{
    string colvector header
    header = ("t" \ "betahat" \ "lb" \ "ub" \ "deltatrue" \ "meanAfterPretesting")
    st_rclear()
    st_matrix("r(delta)",    results.deltatrue)
    st_matrix("r(results)",  results.ES)
    st_matrixcolstripe("r(results)",  (J(length(header), 1, ""), header))
    st_numscalar("r(slope)", results.slope)
    st_numscalar("r(Power)", results.Power)
    st_numscalar("r(Bayes)", results.Bayes)
    st_numscalar("r(LR)",    results.LR)
}

real vector PreTrendsExampleBeta()
{
    return((0.0667031482, -0.0077017923, -0.0307690538, 0.084030658, 0.2424418181, 0.2198789865, 0.1910925359 ))
}

real matrix PreTrendsExampleSigma()
{
    return((0.0089065712, 0.0044883136, 0.0014587025, 0.0012157689, 0.0020327645, 0.0013225015, 0.0019617728)\
           (0.0044883136, 0.0059369169, 0.0027500791, 0.0013505858, 0.0014315459, 0.0012067792, 0.0013847158)\
           (0.0014587025, 0.0027500791, 0.0030386248, 0.0009056166, 0.0006791299, 0.0010167636, 0.0007090144)\
           (0.0012157689, 0.0013505858, 0.0009056166, 0.0039247409, 0.002596118,  0.0017326149, 0.0022345525)\
           (0.0020327645, 0.0014315459, 0.0006791299,  0.002596118,  0.008065897, 0.0058753751, 0.0037414359)\
           (0.0013225015, 0.0012067792, 0.0010167636, 0.0017326149, 0.0058753751,  0.007881579, 0.0036507095)\
           (0.0019617728, 0.0013847158, 0.0007090144, 0.0022345525, 0.0037414359, 0.0036507095, 0.0097884266))
}
end
