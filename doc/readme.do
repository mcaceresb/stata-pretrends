mata {
    st_matrix("beta",  PreTrendsExampleBeta())
    st_matrix("sigma", PreTrendsExampleSigma())
}
pretrends, numpre(3) b(beta) v(sigma) power(0.5) coefplot
return list
matlist r(results)
graph export doc/plot50.png, replace

mata st_matrix("deltaquad", 0.024 * ((-4::3) :- (-1)):^2)
pretrends, numpre(3) b(beta) v(sigma) deltatrue(deltaquad) coefplot
return list
graph export doc/plotQuad.png, replace
