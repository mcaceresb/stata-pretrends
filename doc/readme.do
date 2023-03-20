mata {
    st_matrix("beta",  PreTrendsExampleBeta())
    st_matrix("sigma", PreTrendsExampleSigma())
}
pretrends power 0.5, numpre(3) b(beta) v(sigma)
return list

pretrends, numpre(3) b(beta) v(sigma) slope(`r(slope)')
matlist r(results)
return list
graph export doc/plot50.png, replace

pretrends, numpre(3) b(beta) v(sigma) power(0.5) nocoefplot
matlist r(results)
return list

mata st_matrix("deltaquad", 0.024 * ((-4::3) :- (-1)):^2)
pretrends, numpre(3) b(beta) v(sigma) deltatrue(deltaquad) coefplot
matlist r(results)
return list
graph export doc/plotQuad.png, replace
