cap noi ado uninstall pretrends
cap noi net uninstall pretrends
mata: mata clear
mata: mata set matastrict on
mata: mata set mataoptimize on
cap mkdir src
cap mkdir src/build
cap noi erase src/build/lpretrends.mlib
qui {
    do src/mata/pretrends.mata
    do src/mata/mvnorm.mata
}
mata: mata mlib create lpretrends, dir("src/build") replace
mata: mata mlib add lpretrends PreTrends*(), dir("src/build") complete
net install pretrends, from(`c(pwd)') replace
