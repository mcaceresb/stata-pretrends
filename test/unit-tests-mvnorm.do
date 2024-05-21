capture program drop mvnorm_checks
program mvnorm_checks
    syntax, [*]

    if ( inlist("`c(os)'", "MacOSX") | strpos("`c(machine_type)'", "Mac") ) {
        local c_os_ macosxarm64
        cap program drop pretrends_mvnorm_plugin
        cap program pretrends_mvnorm_plugin, plugin using("pretrends_mvnorm_`c_os_'.plugin")
        if _rc {
            local c_os_ macosx86_64
            cap program pretrends_mvnorm_plugin, plugin using("pretrends_mvnorm_`c_os_'.plugin")
        }
    }
    else {
        local c_os_: di lower("`c(os)'")
        cap program drop pretrends_mvnorm_plugin
        cap program pretrends_mvnorm_plugin, plugin using("pretrends_mvnorm_`c_os_'.plugin")
    }

    local N=100
    mata N=`N'
    mata M=round(3 * rnormal(N, 1, 0, 1), 1)/3
    mata S=variance(rowshape(rnormal(N * N, N, 0, 1) * sqrt(abs(M)), N))
    mata L=-round(max(diag(S)) * runiform(N, 1), 1)
    mata U= round(max(diag(S)) * runiform(N, 1), 1)
    mata timer_clear(99)
    forvalues n = 1 / `N' {
        mata timer_on(99)
        mata n=`n'
        mata P=PreTrends_mvnormalcv(L[1..n], U[1..n], M[1..n], S[1::n, 1..n], 0, ., ., ., 1)
        mata timer_off(99)
        mata st_local("print", sprintf("n = %5.0f in %5.3fs: %9.6g (eps: %9.6g)", `n', timer_value(99)[1], P[1], P[2]))
        disp _col(4) `"mvnorm (fortran): `print'"'
        mata timer_clear(99)
    }

    mata {
        bound = (0.580, 0.970, 0.771, 0.914, 0.673, 1.068, 0.810, 0.592, 1.271)
        means = J(1, 9, 0)
        sigma = 0.088,
                0.104,
                0.023,
                0.070,
                0.046,
                0.136,
                0.100,
                0.025,
                0.074,
                0.245,
                -0.032,
                0.130,
                0.100,
                0.215,
                0.116,
                -0.015,
                0.143,
                0.155,
                -0.077,
                -0.026,
                -0.004,
                0.027,
                0.024,
                -0.173,
                0.218,
                0.060,
                0.137,
                0.103,
                -0.008,
                0.139,
                0.118,
                0.119,
                0.018,
                -0.037,
                0.094,
                0.297,
                0.106,
                -0.029,
                0.171,
                0.171,
                0.055,
                0.056,
                0.091,
                -0.011,
                0.420
        S = invvech(sigma')
    }

    forvalues n = 1 / 7 {
        mata n=`n'
        mata P=PreTrends_mvnormalcv(-bound[1..n], bound[1..n], means[1..n], S[1::n, 1..n], 0, ., ., ., 1)
        mata p=mvnormalcv(-bound[1..n], bound[1..n], means[1..n], vech(S[1::n, 1..n])')
        mata st_local("print", sprintf("n = %5.0f: %9.6g vs %9.6g (eps: %9.6g)", `n', p, P[1], P[2]))
        disp _col(4) `"mvnormalcv vs mvnorm: `print'"'
        mata assert(abs(P[1] - p) <= P[2])
    }
    mata _=(length(means), ., PreTrends_mvnormalcv(-bound, bound, means, S, 0, ., ., ., 1))
end
