capture log close smartload_selftest
log using smartload_selftest.log, text replace name(smartload_selftest)

adopath ++ "`c(pwd)'"

cap which smartload
if _rc {
    di as error "smartload.ado was not found on the adopath. Run this do-file from the folder containing smartload.ado."
    exit 601
}

cap which filelist
if _rc {
    di as error "The SSC package filelist is required."
    di as txt "Run: ssc install filelist"
    exit 499
}

local base "`c(tmpdir)'smartload_test"
cap mkdir "`base'"
cap mkdir "`base'\root1"
cap mkdir "`base'\root2"
cap mkdir "`base'\empty"

clear
set obs 5
gen id = _n
gen value = _n * 10
gen name = "row" + string(_n)
save "`base'\root1\sample.dta", replace
export delimited using "`base'\root1\sample.csv", replace
export delimited using "`base'\root1\sample.dat", replace
cap export excel using "`base'\root1\sample.xlsx", firstrow(variables) replace
local xlsx_rc = _rc

copy "`base'\root1\sample.csv" "`base'\root2\sample.csv", replace

file open fh using "`base'\root1\future.parquet", write text replace
file write fh "placeholder for unsupported conversion-based file"
file close fh

file open fh using "`base'\root1\report.pdf", write text replace
file write fh "%PDF placeholder"
file close fh

file open fh using "`base'\root1\report.docx", write text replace
file write fh "placeholder"
file close fh

file open fh using "`base'\root1\slides.pptx", write text replace
file write fh "placeholder"
file close fh

di as txt "1. ado loads"
which smartload

di as txt "2. default no-location search no longer requires force"
di as txt "   skipped here to avoid a whole-drive scan during the self-test"

di as txt "3. no match is reported"
cap noi smartload does_not_exist.csv, search("`base'\empty")
assert _rc != 0

di as txt "4. multiple same-name files stop"
cap noi smartload sample.csv, search("`base'\root1;`base'\root2") clear
assert _rc != 0

di as txt "5. .dta import succeeds"
smartload sample.dta, search("`base'\root1") clear log replace
assert r(N) == 5
assert r(k) == 3
assert "`r(extension)'" == "dta"

di as txt "6. .csv import succeeds"
smartload sample.csv, search("`base'\root1") clear
assert r(N) == 5
assert r(k) == 3
assert "`r(importcmd)'" == "import delimited"

di as txt "7. .xlsx import succeeds if export excel was available"
if `xlsx_rc' == 0 {
    smartload sample.xlsx, search("`base'\root1") firstrow clear
    assert r(N) == 5
    assert r(k) == 3
}
else {
    di as txt "Skipped xlsx import test because export excel failed on this Stata installation."
}

di as txt "8. .dat text-delimited candidate succeeds"
smartload sample.dat, search("`base'\root1") clear
assert r(N) == 5

di as txt "9. conversion-based file is detected but not imported"
smartload future.parquet, search("`base'\root1") clear
assert "`r(status)'" == "detected_not_imported"

di as txt "10. log output exists"
confirm file smartload_log.txt

di as txt "11. help file opens"
cap noi help smartload
assert _rc == 0

di as txt "12. multiple semicolon roots accepted"
smartload sample.dta, search("`base'\empty;`base'\root1") clear
assert r(N) == 5

di as txt "13. noeverything option is accepted"
smartload sample.dta, search("`base'\root1") noeverything clear
assert r(N) == 5

di as txt "14. bare clear without comma is accepted in current-directory fast search"
local oldpwd "`c(pwd)'"
cd "`base'\root1"
smartload sample.dta clear
assert r(N) == 5
cd "`oldpwd'"

di as txt "15. selected unavailable drive letters are skipped"
cap noi smartload definitely_absent_smartload_file.dta, drives(Z) clear
assert _rc != 0

di as txt "16. PDF is detected without pretending direct import"
smartload report.pdf, search("`base'\root1") clear
assert "`r(status)'" == "detected_not_imported"

di as txt "17. DOCX is detected"
smartload report.docx, search("`base'\root1") clear
assert "`r(status)'" == "detected_not_imported"

di as txt "18. PPTX is detected"
smartload slides.pptx, search("`base'\root1") clear
assert "`r(status)'" == "detected_not_imported"

di as result "All runnable smartload V0.1 tests completed."
log close smartload_selftest
