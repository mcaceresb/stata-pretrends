version 15.1
qui do test/unit-tests-basic.do

capture program drop main
program main
    unit_test basic_failures, xx
    unit_test basic_checks,   xx
end

capture program drop unit_test
program unit_test
    syntax namelist(min=1 max=1), [NOIsily tab(int 4) *]
    cap `noisily' `namelist', `options'
    if ( _rc ) {
        di as error _col(`=`tab'+1') `"test(failed): `namelist', `options'"'
        exit _rc
    }
    else di as txt _col(`=`tab'+1') `"test(passed): `namelist', `options'"'
end

main
