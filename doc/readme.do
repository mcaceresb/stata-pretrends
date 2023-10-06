* From the README:
* use "https://media.githubusercontent.com/media/mcaceresb/stata-pretrends/main/data/workfile_AEJ.dta", clear
* reghdfe l_poor_reg_rate Lead_D4_plus Lead_D3 Lead_D2 D0 Lag_D1 Lag_D2 Lag_D3_plus, absorb(v_id year) cluster(v_id)
* matrix sigma = e(V)
* matrix beta  = e(b)
* matrix beta  = beta[., 1..7]
* matrix sigma = sigma[1..7, 1..7]

* Cached:
mata {
    st_matrix("beta",  PreTrendsExampleBeta())
    st_matrix("sigma", PreTrendsExampleSigma())
}
pretrends power 0.5, pre(1/3) post(4/7) b(beta) v(sigma)
return list

pretrends, numpre(3) b(beta) v(sigma) slope(`r(slope)')
matlist r(results)
return list
graph export doc/plot50.png, replace

pretrends, time(-4(1)3) ref(-1) b(beta) v(sigma) power(0.5) nocoefplot
matlist r(results)
return list

mata st_matrix("deltaquad", 0.024 * ((-4::3) :- (-1)):^2)
pretrends, time(-4(1)3) ref(-1) b(beta) v(sigma) deltatrue(deltaquad) coefplot
matlist r(results)
return list
graph export doc/plotQuad.png, replace
