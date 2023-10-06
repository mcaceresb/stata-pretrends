{smcl}
{* *! version 0.4.1 06Oct2023}{...}
{viewerdialog pretrends "dialog pretrends"}{...}
{vieweralsosee "[R] pretrends" "mansection R pretrends"}{...}
{viewerjumpto "Syntax" "pretrends##syntax"}{...}
{viewerjumpto "Description" "pretrends##description"}{...}
{viewerjumpto "Options" "pretrends##options"}{...}
{viewerjumpto "Examples" "pretrends##examples"}{...}
{title:Title}

{p2colset 5 18 18 2}{...}
{p2col :{cmd:pretrends} {hline 2}}Stata implementation of the pretrends R package{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{pstd}
Stata version of the pretrends R package, which implements power calculations and visualization for pre-trends tests.

{p 8 15 2}
{cmd:pretrends}
{cmd:,}
[{it:{help pretrends##table_options:options}} {it:{help coefplot:coefplot_options}}]

{pstd}
At least one of {opt numpre()}, {opt pre()} and {opt post()}, or {opt time()} and {opt ref()} are required options to indicate which portion of the vector correspond to the pre and post periods; at least one of {opt slope()} or {opt delta()} must be specified as well. In addition, power calculations can be done sepparately (computes the slope of a linear trend for which pre-trends tests have a given power level):

{p 8 15 2}
{cmd:pretrends} power #.#
{cmd:,}
[{it:{help pretrends##table_options:options}}]

{synoptset 25 tabbed}{...}
{marker table_options}{...}
{synopthdr}
{synoptline}
{syntab :Power or Test}
{synopt :{opth b(str)}} name of coefficient matrix; default is e(b){p_end}
{synopt :{opth v:cov(str)}} name of vcov matrix; default is e(V){p_end}
{synopt :{opth numpre:periods(int)}} number of pre-treatment periods; rest vector entries are assumed to be post-treatment (required or specify pre()/post() or time()/ref()){p_end}
{synopt :{opth pre:periodindex(numlist)}} pre-period indices (required or specify numpreperiods() or time()/ref()){p_end}
{synopt :{opth post:periodindex(numlist)}} post-period indices (required or specify numpreperiods() or time()/ref()){p_end}
{synopt :{opth time:vector(numlist)}} time vector to use (required or specify numpreperiods() or pre()/post()){p_end}
{synopt :{opth ref:erenceperiod(numlist)}} reference period for time vec (required or specify numpreperiods() or pre()/post()){p_end}
{synopt :{opt omit}} omit dropped levels from {cmd:b} and {cmd:vcov} parsing names of {cmd:b} (e.g. omitted variables in regression) {p_end}
{synopt :{opth alpha(real)}} 1 - confidence level; default 0.05{p_end}

{syntab :Test Only}
{synopt :{opth slope(real)}} hypothesized linear trend (can specify undocumented option {opt power()} to find slope for given power internally){p_end}
{synopt :{opth delta:true(str)}} name of vector with hypothesized trend (specify {opt slope()} for linear slope){p_end}
{synopt :{opt mata:save(str)}} save resulting mata object (default: PreTrendsResults){p_end}
{synopt :{opt nocoefplot}} supress coefficient plot ({cmd:coefplot} package required by default){p_end}
{synopt :{opt colorspec(str)}} the first color is taken as the color of the event study bars; the second and third are passed to {cmd:ciopts(lcolor())} for the linear trend and pre/post means.{p_end}
{synopt :{opt cached}} use cached results for coefficient plot{p_end}

{p2colreset}{...}
{p 4 6 2}

{marker description}{...}
{title:Description}

{pstd}
See the {browse "https://github.com/mcaceresb/stata-pretrends#readme":package Github page} for detailed examples, including how to import results from common packages such as reghdfe. Below are some stylized examples using saved results from the example on the Github page.

{marker examples}{...}
{title:Example 1: Slope with power}

{phang2}{cmd:. tempname beta sigma                                      }{p_end}
{phang2}{cmd:. mata {c -(}                                              }{p_end}
{phang2}{cmd:      st_matrix(st_local("beta"),  PreTrendsExampleBeta()) }{p_end}
{phang2}{cmd:      st_matrix(st_local("sigma"), PreTrendsExampleSigma())}{p_end}
{phang2}{cmd:  {c )-}                                                   }{p_end}
{phang2}{cmd:. pretrends power 0.5, numpre(3) b(`beta') v(`sigma')      }{p_end}

{title:Example 2: Linear Trend}

{phang2}{cmd:. pretrends, numpre(3) b(`beta') v(`sigma') slope(`r(slope)')}{p_end}

{title:Example 3: Quadratic Custom Trend}

{phang2}{cmd:. mata st_matrix("deltatrue", 0.024 * ((-4::3) :- (-1)):^2)              }{p_end}
{phang2}{cmd:. pretrends, numpre(3) b(`beta') v(`sigma') deltatrue(deltatrue) coefplot}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:pretrends} stores the following in {cmd:r()}:

{synoptset 13 tabbed}{...}
{p2col 5 23 26 2: Scalars}{p_end}
{synopt:{cmd:r(slope)}}linear slope if one was provided or calculated{p_end}
{synopt:{cmd:r(Power)}}estimated power (probability that we find a significant pre-trend under hypothesized trend){p_end}
{synopt:{cmd:r(Bayes)}}ratio of probability of passing pre-test under hypothesized trend relative to parallel trends (not available with {cmd:power} sub-command){p_end}
{synopt:{cmd:r(LR)   }}likelihood ratio of observed coefficients under hypothesized trend relative to parallel trends (not available with {cmd:power} sub-command){p_end}

{p2col 5 23 26 2: Macros}{p_end}
{synopt:{cmd:r(mata)}}name of mata object where results are stored (see below; not available with {cmd:power} sub-command){p_end}

{p2col 5 23 26 2: Matrices}{p_end}
{synopt:{cmd:r(results)}}collected results (time vector, coef, CI bounds, hypothesized trend, means after testing; not available with {cmd:power} sub-command){p_end}
{synopt:{cmd:r(deltatrue)}}hypothesized trend (not available with {cmd:power} sub-command){p_end}

{marker mata}{...}
{pstd}
The following data are available in {cmd:r(mata)} (default name: PreTrendsResults; not available with {cmd:power} sub-command):

        real scalar slope
            computed slope (or missing if delta was supplied)

        real scalar deltatrue
            hypothesized trend (computed or delta if the latter was provided)

        real scalar Power
            estimated power

        real scalar Bayes
            bayes factor

        real scalar LR
            likelihood ratio

        real matrix ES
            matrix with collected results for event study plots (time
            vector, coef, CI bounds, hypothesized trend, means after testing)

{marker references}{...}
{title:References}

{pstd}
See the paper by {browse "https://www.jonathandroth.com/assets/files/roth_pretrends_testing.pdf":Roth (2022)}.

