*! version 0.4.3 09Oct2023 Mauricio Caceres Bravo, mauricio.caceres.bravo@gmail.com
*! Power calculations and visualization for pre-trends tests (translation of R package)

* xx need more unit testing for pre/post and time/ref combinations
capture program drop pretrends
program pretrends, rclass
    version 15.1

    local powermain power(passthru)            //  target power for pre-test: reject if any pre-treatment coef is significant at alpha
    local poweropts b(str)                     /// name of coefficient vector; default is e(b)
                    Vcov(str)                  /// name of vcov matrix; default is e(V)
                                               ///
                    omit                       /// Omit levels parsing b vector column names
                    alpha(passthru)            /// significance level
                    NUMPREperiods(int 0)       /// number of pre-treatment periods
                    PREperiodindices(numlist)  /// pre-period indices
                    POSTperiodindices(numlist) /// post-period indices
                    TIMEvector(numlist)        /// time vector
                    REFerenceperiod(str)       /// reference period
                    customreference            /// ignored unless both pre/post and time/ref are specified.
                                               /// allows the reference period to be in pre or post.
    local fullopts  slope(passthru)            /// hypothesized difference in trends
                    DELTAtrue(str)             /// name of matrix with hypothesized trend
                                               ///
                    MATAsave(str)              /// Save resulting mata object
                    nocoefplot                 /// Coefficient  plot
                    cached                     /// Use cached results
                    colorspec(str asis)        /// special color handling
                    ciopt(str)                 //

    syntax [anything(everything)], [*]
    gettoken anything power: anything
    local anything `anything'
    if ( `"`anything'"' == "power" ) {
        confirm number `power'
        local power power(`power')
        local poweronly = 1
        syntax [anything(everything)], ///
        [                              ///
            `poweropts'                ///
        ]
    }
    else {
        local poweronly = 0
        syntax,         ///
        [               ///
            `powermain' ///
            `poweropts' ///
            `fullopts'  ///
            *           /// Options for coefplot
        ]
    }

    if "`matasave'" == "" local results PreTrendsResults
    else local results: copy local matasave

    if ( "`cached'" != "" ) {
        local results `r(PreTrendsResults)'
        cap mata mata desc `results'
        if ( _rc ) {
            disp as err "Cached results not found"
            exit 198
        }
    }

    * Specify only ONE of
    *
    *     numpreperiods()
    *
    * OR
    *
    *     preperiodindices() and postperiodindices()
    *
    * OR
    *
    *     timevector() and referenceperiod()
    *
    *
    * numpre() cannot be combined with either but time()/ref() and
    * pre()/post() may be combined with each other.  If numpreperiods() is
    * specified, then
    *
    *     preperiodindices(1 to numpreperiods)
    *     postperiodindices(numpreperiods+1 to length(e(b)))
    *
    *     timevector(preperiodindices, numpreperiods+1, postperiodindices)
    *     referenceperiod(numpreperiods+1)
    *
    * are assumed. If timevector() and referenceperiod() are specified, then
    *
    *     numpreperiods  = # time vector < referenceperiod
    *     numpostperiods = # time vector > referenceperiod
    *     preperiodindices(1 to numpreperiods)
    *     postperiodindices(numpreperiods+1 to numpreperiods+numpostperiods+1)
    *
    * are assumed. You can force pre/post to be taken as reference and for time/ref
    * via the -customreference- option

    local dopretrends = ("`b'`v'`alpha'`preperiodindices'`postperiodindices'`timevector'`referenceperiod'`power'`slope'`deltatrue'" != "")
    local dopretrends = `dopretrends' | (`numpreperiods' != 0)
    if ( `dopretrends' & ("`cached'" != "") ) {
        disp as txt "{bf:warning:} cached results ignored if modifications are specified"
        local cached
    }

    if ( `dopretrends' | ("`cached'" == "") ) {
        PreTrendsSanityChecks, b(`b') vcov(`vcov') deltatrue(`deltatrue') ///
            `alpha' `power' `slope' numpre(`numpreperiods')               ///
            pre(`preperiodindices') post(`postperiodindices')             ///
            time(`timevector') ref(`referenceperiod') `customreference'
    }
    else {
        local alpha = 0.05
        local power = 0.5
        local slope = .
    }

    * local PretOpt_Caller pretrends
    mata {
        if ( `dopretrends' | ("`cached'" == "") ) {
            `results' = PreTrends("`b'",                 ///
                                  "`vcov'",              ///
                                  `numpreperiods',       ///
                                  "`preperiodindices'",  ///
                                  "`postperiodindices'", ///
                                  "`timevector'",        ///
                                  "`referenceperiod'",   ///
                                  `alpha', `power', `slope', "`deltatrue'", "`omit'", `poweronly')
        }
    }

    if ( `poweronly' ) {
        tempname slope
        mata st_numscalar(st_local("slope"), `results'.slope)
        mata printf("Slope for %s power = %9.6g\n", strtrim(sprintf("%9.6g%%", 100 * `results'.power)), `results'.slope)
        return scalar Power = `power'
        return scalar slope = `slope'
        mata mata drop `results'
        exit 0
    }

    * Coef plot
    tempname plotmatrix cimatrix dummycoef deltamat meanBeta labels
    if ( "`coefplot'" != "nocoefplot" ) {
        cap which coefplot
        if ( _rc ) {
            disp as err "-coefplot- not found; please install or use option -nocoefplot-"
            exit _rc
        }
    }

    mata {
        if ( "`coefplot'" != "nocoefplot" ) {
            `plotmatrix' = `results'.ES
            `labels' = strofreal(`plotmatrix'[., 1]')
            st_matrix("`cimatrix'", `plotmatrix'[., 3::4]')
            st_matrix("`dummycoef'",`plotmatrix'[., 2]')
            st_matrix("`deltamat'", `results'.ES[.,5]')
            st_matrix("`meanBeta'", `results'.ES[.,6]')
            st_local("cimatlab", invtokens(`labels'))
        }
    }

    if ( "`coefplot'" != "nocoefplot" ) {
        matrix colnames `cimatrix'  = `cimatlab'
        matrix rownames `cimatrix'  = lb ub
        matrix colnames `dummycoef' = `cimatlab'
        matrix colnames `deltamat'  = `cimatlab'
        matrix colnames `meanBeta'  = `cimatlab'

        if `"`colorspec'"' == "" local colorspec `""66 66 66" "183 28 28" "2 136 209""'
        local optionsbak: copy local options
        local 0, `ciopt'
        syntax, [LColor(str) Color(str) *]
        local options: copy local optionsbak

        if ( `"`ciopt'"' == "" ) local ciopt ciopt(recast(rcap) lcolor("`:word 1 of `colorspec''"))
        else local ciopt ciopt(recast(rcap) `ciopt')

        local coefplot  matrix(`dummycoef'), at(_coef) ci(`cimatrix') `ciopt' label(Estimated Coefs)
        local deltaline matrix(`deltamat'),  at(_coef) recast(line) lcolor("`:word 2 of `colorspec''") label(Hypothesized Trend)
        local meansline matrix(`meanBeta'),  at(_coef) recast(line) lcolor("`:word 3 of `colorspec''") label(Expectation After Pre-testing) lpattern(dash)
        qui coefplot (`coefplot') (`deltaline') (`meansline'), vertical yline(0) `options'
    }

    return local PreTrendsResults = "`results'"
    mata PreTrendsPost(`results')
    return add
end

capture program drop PreTrendsSanityChecks
program PreTrendsSanityChecks
    syntax ,                       ///
    [                              ///
        b(str)                     /// name of coefficient matrix; default is e(b)
        vcov(str)                  /// name of vcov matrix; default is e(V)
        slope(str)                 /// hypothesized difference in trends
        power(str)                 /// target power for pre-test: reject if any pre-treatment coef is significant at alpha
        deltatrue(str)             /// name of matrix with hypothesized trend
        alpha(real 0.05)           /// 1 - level of CI
        NUMPREperiods(int 0)       /// number of pre-treatment periods
        PREperiodindices(numlist)  /// pre-period indices
        POSTperiodindices(numlist) /// post-period indices
        TIMEvector(numlist)        /// time vector
        REFerenceperiod(str)       /// reference period
        customreference            /// ignored unless both pre/post and time/ref are specified.
                                   /// allows the reference period to be in pre or post.
    ]

    if ( "`slope'`power'`deltatrue'" == "" ) {
        disp as err "At least one of slope(), power(), or delta() must be specified."
        exit 198
    }
    else if ( (("`slope'" != "") + ("`power'" != "") + ("`deltatrue'" != "")) > 1 ) {
        disp as err "Only one of slope(), power(), or delta() can be specified."
        exit 198
    }

    if ( "`slope'" != "" ) {
        cap confirm number `slope'
        if ( _rc ) {
            disp as err "slope() must be a number"
            exit 7
        }
    }
    else local slope .

    if ( "`power'" != "" ) {
        cap confirm number `power'
        if ( _rc ) {
            disp as err "power() must be a number"
            exit 7
        }

        if ( (`power' <= 0) | (`power' >= 1) ) {
            disp as err "power() must be between 0 and 1"
            exit 198
        }
    }
    else local power .

    if ( (`alpha' <= 0) | (`alpha' >= 1) ) {
        disp as err "alpha() must be between 0 and 1"
        exit 198
    }

    if ((`numpreperiods' != 0) & "`preperiodindices'`postperiodindices'" != "") {
        disp as err "Specify only one of numpre() or pre() and post()"
        exit 198
    }

    if ((`numpreperiods' != 0) & "`timevector'`referenceperiod'" != "") {
        disp as err "Specify only one of numpre() or time() and ref()"
        exit 198
    }

    local indices = ("`preperiodindices'" != "") & ("`postperiodindices'" != "")
    local timevec = ("`timevector'"       != "") & ("`referenceperiod'"   != "")
    if ((`numpreperiods' == 0) & (!`indices') & (!`timevec') ) {
        disp as err "Specify either numpre(), both pre() and post(), or both timevector() and referenceperiod()"
        exit 198
    }

    if ( ("`preperiodindices'" != "") & ("`postperiodindices'" == "") ) {
        disp as err "pre() can only be used with post()"
        exit 198
    }

    if ( ("`preperiodindices'" == "") & ("`postperiodindices'" != "") ) {
        disp as err "post() can only be used with pre()"
        exit 198
    }

    if ( ("`timevector'" != "") & ("`referenceperiod'" == "") ) {
        disp as err "time() can only be used with ref()"
        exit 198
    }

    if ( ("`timevector'" == "") & ("`referenceperiod'" != "") ) {
        disp as err "ref() can only be used with time()"
        exit 198
    }

    if ( `numpreperiods' < 0 ) {
        disp as err "numpre() must be positive"
        exit 198
    }

    tempname bb VV
    if ( "`b'" == "" ) {
        if ( "`vcov'" != "" ) {
            disp as txt "{bf:warning:} option vcov() detected without option b()"
        }
        local b e(b)
        cap confirm matrix e(b)
        if ( _rc ) {
            disp as err "Last estimation coefficients not found; please specify vector via b()."
            exit 198
        }
        matrix `bb' = e(b)
        local rowsb = rowsof(`bb')
        local colsb = colsof(`bb')
    }
    else {
        confirm matrix `b'
        local rowsb = rowsof(`b')
        local colsb = colsof(`b')
    }

    if ( "`vcov'" == "" ) {
        if ( "`b'" != "" ) {
            disp as txt "{bf:warning:} option b() detected without option vcov()"
        }
        local vcov e(V)
        cap confirm matrix e(V)
        if ( _rc ) {
            disp as err "Last estimation vcov matrix not found; please specify matrix via vcov()."
            exit 198
        }
        matrix `VV' = e(V)
        local rowsV = rowsof(`VV')
        local colsV = colsof(`VV')
    }
    else {
        confirm matrix `vcov'
        local rowsV = rowsof(`vcov')
        local colsV = colsof(`vcov')
    }

    if ( (`rowsb' != 1) & (`colsb' != 1) ) {
        disp as err "b() must be a vector; was `rowsb' x `colsb'"
        exit 198
    }

    if ( `rowsV' != `colsV' ) {
        disp as err "V() must be square"
        exit 198
    }

    if ( max(`rowsb', `colsb') != `rowsV' ) {
        disp as err "V() was `rowsV' x `colsV' not conformable with b() `rowsb' x `colsb'"
        exit 198
    }

    if ( (`numpreperiods' == 0) & `indices' ) {
        local npre:  list sizeof preperiodindices
        local npost: list sizeof postperiodindices
        if ( max(`rowsb', `colsb') < (`npre' + `npost') ) {
            disp as err "Coefficient vector must be at least # pre + # post"
            exit 198
        }
    }

    if ( (`numpreperiods' == 0) & `timevec' ) {
        cap confirm number `referenceperiod'
        if ( _rc ) {
            disp as err "ref() reference period must be a number"
            exit 198
        }
        mata st_local("npre",  strofreal(sum(strtoreal(tokens("`timevector'")) :< `referenceperiod')))
        mata st_local("npost", strofreal(sum(strtoreal(tokens("`timevector'")) :> `referenceperiod')))
        if ( `npre' <= 0 ) {
            disp as err "No time periods in time vector less than referenceperiod `referenceperiod' found"
            exit 198
        }
        if ( `npost' <= 0 ) {
            disp as err "No time periods in time vector greater than referenceperiod `referenceperiod' found"
            exit 198
        }
        if ( max(`rowsb', `colsb') < (`npre' + `npost') ) {
            disp as err "Coefficient vector must be at least # pre + # post"
            exit 198
        }
    }

    if ( (`numpreperiods' == 0) & `indices' & `timevec' & ("`customreference'" == "") ) {
        local npreA:  list sizeof preperiodindices
        local npostA: list sizeof postperiodindices
        mata st_local("npreB",  strofreal(sum(strtoreal(tokens("`timevector'")) :< `referenceperiod')))
        mata st_local("npostB", strofreal(sum(strtoreal(tokens("`timevector'")) :> `referenceperiod')))
        if ( (`npreA' != `npreB') | (`npostA' != `npostB') ) {
            disp as err "Shape implied by pre()/post() does not match shape implied by time()/ref()"
            exit 198
        }
    }

    if ( `numpreperiods' > 0 ) {
        if ( max(`rowsb', `colsb') <= `numpreperiods' ) {
            disp as err "Coefficient vector must be at least 1 + number of pre-treatment periods"
            exit 198
        }
    }

    if ( "`deltatrue'" != "" ) confirm matrix `deltatrue'

    c_local alpha: copy local alpha
    c_local b:     copy local b
    c_local vcov:  copy local vcov
    c_local power: copy local power
    c_local slope: copy local slope
end
