PreTrends
=========

The `pretrends` package provides tools for power calculations for
pre-trends tests, and visualization of possible violations of parallel
trends. Calculations are based on [Roth (2022)](https://jonathandroth.github.io/assets/files/roth_pretrends_testing.pdf).
This is the Stata version of the [R package of the same name](https://github.com/jonathandroth/pretrends).
(Please cite the paper if you enjoy the package!)

If you’re not an R or Stata user, you may also be interested in the associated
[Shiny app](https://github.com/jonathandroth/PretrendsPower).

`version 0.2.0 19Mar2023` | [Background](#background) | [Installation](#installation) | [Examples](#examples)

## Installation

The package may be installed by using `net install`:

```stata
local github https://raw.githubusercontent.com
net install pretrends, from(`github'/mcaceresb/stata-pretrends/main) replace
```

You can also clone or download the code manually, e.g. to
`stata-pretrends-main`, and install from a local folder:

```stata
cap noi net uninstall pretrends
net install pretrends, from(`c(pwd)'/stata-pretrends-main)
```

## Application to He and Wang (2017)

We illustrate how to use the package with an application to [He and Wang
(2017)](https://www.aeaweb.org/articles?id=10.1257/app.20160079). The
analysis will be based on the event-study in Figure 2C, which looks like
this:

![He and Wang Plot.](doc/HeAndWang.png)

### Load the example data

Next we load the estimation results used for the event-plot, namely the
coefficients (*beta*), the variance-covariance matrix (*sigma*). In this
case, these coefficients come from a two-way fixed effects regression,
but the pretrends package can accommodate an event-study from any
asymptotically normal estimator, including
[Callaway and Sant’Anna (2020)](https://www.sciencedirect.com/science/article/pii/S0304407620303948?dgcid=author)
and [Sun and Abraham (2020)](https://www.sciencedirect.com/science/article/abs/pii/S030440762030378X).

```stata
mata {
    st_matrix("beta",  PreTrendsExampleBeta())
    st_matrix("sigma", PreTrendsExampleSigma())
}
matlist beta'
*              |        r1
* -------------+----------
*           c1 |  .0667031
*           c2 | -.0077018
*           c3 | -.0307691
*           c4 |  .0840307
*           c5 |  .2424418
*           c6 |   .219879
*           c7 |  .1910925
```

### Using the package

First, the user must specify the coefficient vector, variance-covariance
matrix, and the sections therein that correspond to the pre and post periods.
By default, the package tries to use `e(b)` and `e(V)`, which would be
populated after most estimation commands.

Second, the user needs to specify a hypothesized trend. The package can
compute the slope of a linear violation at a given power level via the
`power()` option; it can use a user-specified slope direcly via the `slope()`
option; or it can use an arbitrary trend via the `delta()` option.

With `power()`, it calculates the slope of a linear violation of
parallel trends that a pre-trends test would detect a specified
fraction of the time. (By detect, we mean that there is any significant
pre-treatment coefficient.)

```stata
pretrends, numpre(3) b(beta) v(sigma) power(0.5) coefplot
```

Note the `coefplot` option, which requires the package of the sanem
name. This is not required, but if specified will produce an event-study
plot and add a user-hypothesized difference in trends.  In this case, we
can see the linear trend against which pre-tests have 50 percent power.

![Power50](doc/plot50.png)

In addition, several useful statistics about the power of the pre-test
against the hypothesized trend are saved in `r()`.

```stata
return list
* scalars:
*                  r(LR) =  .1057053243787036
*               r(Bayes) =  .5690176871738699
*               r(Power) =  .5000000000006959
*               r(slope) =  .0520662478209672
*
* macros:
*    r(PreTrendsResults) : "PreTrendsResults"
*
* matrices:
*             r(results) :  8 x 6
*               r(delta) :  1 x 8
```

- **r(Power)** The probability that we would find a significant pre-trend
  under the hypothesized pre-trend. (This is 0.50, up to numerical
  precision error, by construction in our example).

- **r(BF)** (Bayes Factor) The ratio of the probability of "passing" the
  pre-test under the hypothesized trend relative to under parallel
  trends.

- **r(LR)** (Likelihood Ratio) The ratio of the likelihood of the observed
  coefficients under the hypothesized trend relative to under parallel
  trends.

Finally, `r(results)` contains the data used to make the
event-plot. Note the column `meanAfterPretesting`, which is also
plotted, shows the expected value of the coefficients conditional on
passing the pre-test under the hypothesized trend.

```stata
matlist r(results)
*              |         t    betahat         lb         ub  deltatrue  meanAft~g
* -------------+------------------------------------------------------------------
*           r1 |        -4   .0667031  -.1182677    .251674  -.1561987  -.0923171
*           r2 |        -3  -.0077018  -.1587197   .1433162  -.1041325  -.0555576
*           r3 |        -2  -.0307691  -.1388096   .0772715  -.0520662  -.0279117
*           r4 |        -1          0          0          0          0          0
*           r5 |         0   .0840307  -.0387567    .206818   .0520662   .0649147
*           r6 |         1   .2424418   .0664168   .4184668   .1041325   .1208691
*           r7 |         2    .219879   .0458768   .3938812   .1561987   .1694932
*           r8 |         3   .1910925  -.0028194   .3850045    .208265   .2245753
```

Although our example has focused on a linear violation of parallel
trends, the package allows the user to input an arbitrary non-linear
hypothesized trend. For instance, here is the event-plot and power
analysis from a quadratic trend.

```stata
mata st_matrix("deltaquad", 0.024 * ((-4::3) :- (-1)):^2)
pretrends, numpre(3) b(beta) v(sigma) deltatrue(deltaquad) coefplot
```

![Power50](doc/plotQuad.png)

```stata
return list
* scalars:
*                  r(LR) =  .4332635208743188
*               r(Bayes) =  .3841447004284795
*               r(Power) =  .6624492444726371
*               r(slope) =  .
*
* macros:
*    r(PreTrendsResults) : "PreTrendsResults"
*
* matrices:
*             r(results) :  8 x 6
*               r(delta) :  1 x 8
```
