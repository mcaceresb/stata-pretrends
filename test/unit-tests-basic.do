capture program drop basic_checks
program basic_checks
    syntax, [*]
    mata {
        st_matrix("beta",  PreTrendsExampleBeta())
        st_matrix("sigma", PreTrendsExampleSigma())
    }

    forvalues i = -50/50 {
        local s = `i' / 10
        disp "slope `s'"
        qui pretrends, numpre(3) b(beta) v(sigma) slope(`s') nocoefplot
        qui return list
    }

    * local i = 20
    tempname s1
    forvalues i = 20/99 {
        local p = `i' / 100
        qui pretrends power `p', numpre(3) b(beta) v(sigma)
        local power = r(Power)
        local slope = r(slope)
        assert r(Power) == `p'
        mata `s1' = st_numscalar("r(slope)")
        qui pretrends power `p', pre(1/3) post(4/7) b(beta) v(sigma)
        mata assert(reldif(`s1', st_numscalar("r(slope)")) < epsilon(1)^(1/5))
        disp "base power", %5.3f `p', "| est power", %5.3f `power', "| est slope 1", %7.5g `slope', "| est slope 2", %7.5g `r(slope)'
    }

    local i = 5
    forvalues i = 5(5)400 {
        local a = `i' / 1000
        qui pretrends power 0.8, numpre(3) b(beta) v(sigma) alpha(`a')
        local slope1 = r(slope)
        mata `s1' = st_numscalar("r(slope)")
        qui pretrends, pre(1/3) post(4/7) b(beta) v(sigma) slope(`r(slope)') alpha(`a') nocoefplot
        local power1 = r(Power)
        mata assert(reldif(0.8, st_numscalar("r(Power)")) < 0.01)
        qui pretrends, time(-4(1)3) ref(-1) b(beta) v(sigma) slope(`r(slope)') alpha(`a') nocoefplot
        mata assert(reldif(0.8, st_numscalar("r(Power)")) < 0.01)
        local power2 = r(Power)
        disp "80% power, base alpha", %5.3f `a', "| est slope", %7.5g `slope1', "| power 1", %5.3g `power1', "| power 2", %5.3f `power2'
        qui pretrends, time(7 10 11 12 13 19) pre(2/3) post(4 5 7) ref(11) b(beta) v(sigma) slope(`r(slope)') alpha(`a') nocoefplot
    }

    clear
    set obs 100
    gen i = _n
    expand 10
    bys i: gen t = _n
    gen g = 2 + ceil(mod(i, 5) * runiform())
    gen D = t > g
    gen Dg = t - g - 1
    egen Dt = group(Dg)
    gen y = D + t + i + g + rnormal()
    qui reghdfe y b6.Dt, absorb(i t) noconstant

    pretrends power 0.8, numpre(5)
    pretrends power 0.8, numpre(5) omit
    pretrends, pre(1/5) post(6/13) slope(`=r(slope)') omit
    return list
    matlist r(results)

    pretrends, pre(1/5) post(7/14) slope(0.2)
    return list
end

capture program drop basic_failures
program basic_failures
    syntax, [*]

    ereturn clear
    mata {
        st_matrix("beta",  PreTrendsExampleBeta())
        st_matrix("sigma", PreTrendsExampleSigma())
    }
    cap pretrends power
    assert _rc == 7

    cap pretrends power 0.5
    assert _rc == 198

    cap pretrends power 0.5, numpre(3)
    assert _rc == 198

    cap pretrends power 0.5, numpre(3) b(beta)
    assert _rc == 198

    cap pretrends power 0.5, numpre(3) b(beta) v(ZIGMA)
    assert _rc == 111

    cap pretrends power 0.5, numpre(3) b(beta) v(sigma) zz
    assert _rc == 198

    cap pretrends power 0.5, numpre(10) b(beta) v(sigma)
    assert _rc == 198

    cap pretrends power 0.5, numpre(7) b(beta) v(sigma)
    assert _rc == 198

    cap pretrends power 0.5, pre(1) post(2/10) b(beta) v(sigma)
    assert _rc == 198

    cap pretrends
    assert _rc == 198

    cap pretrends, slope(0.2)
    assert _rc == 198

    cap pretrends, slope(0.2) numpre(3)
    assert _rc == 198

    cap pretrends, slope(0.2) numpre(3) b(beta)
    assert _rc == 198

    cap pretrends, slope(0.2) numpre(3) b(beta) v(ZIGMA)
    assert _rc == 111

    cap pretrends, slope(0.2) numpre(3) b(beta) v(sigma) zz
    assert _rc == 198

    cap pretrends, slope(0.2) numpre(10) b(beta) v(sigma)
    assert _rc == 198

    cap pretrends, slope(0.2) numpre(7) b(beta) v(sigma)
    assert _rc == 198

    cap pretrends, slope(0.2) pre(1) post(2/10) b(beta) v(sigma)
    assert _rc == 198
end
