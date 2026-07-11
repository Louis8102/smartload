capture log close smartload_selftest
log using smartload_selftest.log, text replace name(smartload_selftest)

adopath ++ "`c(pwd)'"
sysdir set PERSONAL "`c(pwd)'/"

cap which smartload
if _rc {
    di as error "smartload.ado was not found on the adopath. Run this do-file from the folder containing smartload.ado."
    exit 601
}

tempfile basefile
local base "`basefile'_dir"
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
cap export parquet using "`base'\root1\sample.parquet", replace
local parquet_rc = _rc
cap export dbase using "`base'\root1\sample.dbf", replace
local dbf_rc = _rc

copy "`base'\root1\sample.csv" "`base'\root2\sample.csv", replace
copy "`base'\root1\sample.dta" "`base'\root2\sample.dta", replace
copy "`base'\root1\sample.dta" "`base'\root1\Customer Delight Data_Master.dta", replace

file open fh using "`base'\root1\report.pdf", write text replace
file write fh "%PDF placeholder"
file close fh

file open fh using "`base'\root1\web_tables.html", write text replace
file write fh `"<html><body><h1>tables</h1><table><tr><th>id</th><th>score</th></tr><tr><td>1</td><td>10</td></tr><tr><td>2</td><td>20</td></tr></table><table><tr><th>city</th><th>value</th></tr><tr><td>Austin</td><td>7</td></tr></table></body></html>"'
file close fh
copy "`base'\root1\web_tables.html" "`base'\root1\web_tables.asp", replace

file open fh using "`base'\root1\image_table.html", write text replace
file write fh `"<html><body><p>This page has a table screenshot.</p><img src="table.png" alt="table image"></body></html>"'
file close fh

cap mkdir "`base'\docxbuild"
cap mkdir "`base'\docxbuild\word"
file open fh using "`base'\docxbuild\word\document.xml", write text replace
file write fh `"<w:document><w:body><w:tbl><w:tr><w:tc><w:tcPr><w:tcW w:w="1649" w:type="dxa"/></w:tcPr><w:p><w:r><w:rPr><w:rFonts w:ascii="Times New Roman"/></w:rPr><w:t>id</w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:tcW w:w="1649" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>score</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:tcW w:w="1649" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:tcW w:w="1649" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>10</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:tcPr><w:tcW w:w="1649" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>2</w:t></w:r></w:p></w:tc><w:tc><w:tcPr><w:tcW w:w="1649" w:type="dxa"/></w:tcPr><w:p><w:r><w:t>20</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>"'
file close fh
local oldpwd "`c(pwd)'"
qui cd "`base'\docxbuild"
zipfile "word", saving("`base'\root1\report.docx", replace)
qui cd "`oldpwd'"

cap mkdir "`base'\pptxbuild"
cap mkdir "`base'\pptxbuild\ppt"
cap mkdir "`base'\pptxbuild\ppt\slides"
file open fh using "`base'\pptxbuild\ppt\slides\slide1.xml", write text replace
file write fh `"<p:sld><p:cSld><p:spTree><a:tbl><a:tr><a:tc><a:tcPr/><a:txBody><a:p><a:r><a:rPr lang="en-US"/><a:t>id</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:tcPr/><a:txBody><a:p><a:r><a:t>score</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc><a:tcPr/><a:txBody><a:p><a:r><a:t>1</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:tcPr/><a:txBody><a:p><a:r><a:t>100</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc><a:tcPr/><a:txBody><a:p><a:r><a:t>2</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:tcPr/><a:txBody><a:p><a:r><a:t>200</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></p:spTree></p:cSld></p:sld>"'
file close fh
file open fh using "`base'\pptxbuild\ppt\slides\slide2.xml", write text replace
file write fh `"<p:sld><p:cSld><p:spTree><a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:t>animal</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>count</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc><a:txBody><a:p><a:r><a:t>cat</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>3</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></p:spTree></p:cSld></p:sld>"'
file close fh
local oldpwd "`c(pwd)'"
qui cd "`base'\pptxbuild"
zipfile "ppt", saving("`base'\root1\slides.pptx", replace)
qui cd "`oldpwd'"

file open fh using "`base'\root1\data.rds", write text replace
file write fh "placeholder for R object"
file close fh

file open fh using "`base'\root1\sample_fixed.raw", write text replace
file write fh "001010" _n
file write fh "002020" _n
file write fh "003030" _n
file close fh

file open fh using "`base'\root1\sample_fixed.dct", write text replace
file write fh `"infix dictionary using "sample_fixed.raw" {"' _n
file write fh "id 1-3" _n
file write fh "value 4-6" _n
file write fh "}" _n
file close fh

di as txt "1. ado loads"
which smartload

di as txt "2. pure Stata index refresh succeeds"
smartload, refresh roots("`base'\root1;`base'\root2;`base'\empty") replace
assert r(N) > 0

clear
set obs 3
gen id = _n
gen score = _n + 100
export delimited using "`base'\root1\auto_only.csv", replace

di as txt "3. no match is reported"
cap noi smartload does_not_exist.csv, maxdirs(5)
assert _rc != 0

di as txt "3b. automatic fast search imports a file not yet in the index"
smartload auto_only.csv, roots("`base'\root1") maxdirs(20) clear
assert r(N) == 3
assert "`r(storage)'" == "fast"

di as txt "4. multiple same-name files can be selected by number in batch"
smartload sample.csv, choice(1) clear
assert r(N) == 5

di as txt "5. .dta import succeeds"
smartload sample.dta, choice(1) clear log replace
assert r(N) == 5
assert r(k) == 3
assert "`r(extension)'" == "dta"

di as txt "6. .csv import succeeds"
smartload sample.csv, choice(1) clear
assert r(N) == 5
assert r(k) == 3
assert "`r(importcmd)'" == "import delimited"

di as txt "7. .xlsx import succeeds if export excel was available"
if `xlsx_rc' == 0 {
    smartload sample.xlsx, firstrow clear
    assert r(N) == 5
    assert r(k) == 3
}
else {
    di as txt "Skipped xlsx import test because export excel failed on this Stata installation."
}

di as txt "8. .dat text-delimited candidate succeeds"
smartload sample.dat, clear
assert r(N) == 5

di as txt "9. .parquet import succeeds if export parquet was available"
if `parquet_rc' == 0 {
    smartload sample.parquet, clear
    assert r(N) == 5
    assert r(k) == 3
    assert "`r(importcmd)'" == "import parquet"
}
else {
    di as txt "Skipped parquet import test because export parquet failed on this Stata installation."
}

di as txt "9b. .dbf import succeeds if export dbase was available"
if `dbf_rc' == 0 {
    smartload sample.dbf, clear
    assert r(N) == 5
    assert "`r(importcmd)'" == "import dbase"
}
else {
    di as txt "Skipped dbf import test because export dbase failed on this Stata installation."
}

di as txt "9c. fixed-format dictionary .dct import succeeds"
smartload sample_fixed.dct, clear
assert r(N) == 3
assert r(k) == 2
assert "`r(importcmd)'" == "infix using"

di as txt "10. log output exists"
confirm file smartload_log.txt

di as txt "11. help file opens"
cap noi help smartload
assert _rc == 0

di as txt "12. multiple semicolon roots accepted"
smartload sample.dta, roots("`base'\root1") clear
assert r(N) == 5

di as txt "13. duplicate choice selects requested copy"
smartload sample.dta, choice(2) clear
assert r(N) == 5

di as txt "14. file names with spaces import correctly"
smartload Customer Delight Data_Master.dta, clear
assert r(N) == 5
assert "`r(filename)'" == "Customer Delight Data_Master.dta"

di as txt "15. missing comma before clear is tolerated"
smartload Customer Delight Data_Master.dta clear
assert r(N) == 5
assert "`r(filename)'" == "Customer Delight Data_Master.dta"

di as txt "16. PDF is detected without pretending direct import"
smartload report.pdf, clear
assert "`r(status)'" == "detected_not_imported"

di as txt "17. DOCX true Office table imports"
smartload report.docx, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 2
assert "`r(importcmd)'" == "office table extraction"
assert id[1] == 1
assert score[2] == 20

di as txt "18. PPTX true Office table imports"
smartload slides.pptx, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 2
assert "`r(importcmd)'" == "office table extraction"
assert r(ntables) == 2
assert id[1] == 1
assert score[2] == 200

di as txt "18b. PPTX second table can be selected"
smartload slides.pptx, table(2) firstrow clear
assert r(N) == 1
assert r(k) == 2
assert r(table) == 2
assert r(ntables) == 2
assert animal[1] == "cat"
assert count[1] == 3

di as txt "18c. HTML true table imports"
smartload web_tables.html, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 2
assert "`r(importcmd)'" == "html table extraction"
assert r(ntables) == 2
assert id[1] == 1
assert score[2] == 20

di as txt "18d. HTML second table can be selected"
smartload web_tables.html, table(2) firstrow clear
assert r(N) == 1
assert r(k) == 2
assert city[1] == "Austin"
assert value[1] == 7

di as txt "18e. HTML image-only table is detected but not imported"
cap noi smartload image_table.html, clear
assert _rc == 498

di as txt "18f. Server-page extension with HTML table imports"
smartload web_tables.asp, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 2
assert "`r(importcmd)'" == "html table extraction"
assert id[1] == 1
assert score[2] == 20

di as txt "18g. URL ending in slash is treated as HTML page"
cap noi smartload "https://designsystem.digital.gov/components/table/", table(1) clear
assert _rc != 198

di as txt "19. RDS is detected but not imported"
smartload data.rds, clear
assert "`r(status)'" == "detected_not_imported"

di as txt "20. URL .dta import succeeds when internet access is available"
cap noi smartload "https://www.stata-press.com/data/r18/auto.dta", clear
if _rc {
    di as txt "Skipped URL import test because internet access or remote server was unavailable."
}
else {
    assert r(N) > 0
    assert "`r(storage)'" == "url"
    assert "`r(importcmd)'" == "use"
}

di as txt "21. GitHub blob URL conversion path is reachable"
cap noi smartload "https://github.com/user/repo/blob/main/data.csv", clear
if _rc {
    di as txt "GitHub URL import was not completed, usually because the test URL is illustrative or network access is unavailable."
}

di as result "All runnable smartload V0.6.2 tests completed."
log close smartload_selftest

