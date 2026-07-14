capture log close smartload_selftest
log using smartload_selftest.log, text replace name(smartload_selftest)

adopath ++ "`c(pwd)'"
sysdir set PERSONAL "`c(pwd)'/"

cap which smartload
if _rc {
    di as error "smartload.ado was not found on the adopath. Run this do-file from the folder containing smartload.ado."
    exit 601
}
which smartload

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
file open fh using "`base'\root1\sample.csv2", write text replace
file write fh "id;value;name" _n
file write fh `"1;10,5;row1"' _n
file write fh `"2;20,5;row2"' _n
file close fh

confirm file "example_data/smartload_example_map.shp"
confirm file "example_data/smartload_example_map.dbf"
confirm file "example_data/smartload_example_map.shx"
confirm file "example_data/smartload_example_map.prj"
copy "example_data/smartload_example_map.shp" "`base'/root1/smartload_geo_selftest.shp", replace
copy "example_data/smartload_example_map.dbf" "`base'/root1/smartload_geo_selftest.dbf", replace
copy "example_data/smartload_example_map.shx" "`base'/root1/smartload_geo_selftest.shx", replace
copy "example_data/smartload_example_map.prj" "`base'/root1/smartload_geo_selftest.prj", replace
confirm file "example_data/smartload_example.docx"
confirm file "example_data/smartload_example.pptx"
confirm file "example_data/smartload_example.pdf"
copy "example_data/smartload_example.docx" "`base'/root1/smartload_quality_office_test.docx", replace
copy "example_data/smartload_example.pptx" "`base'/root1/smartload_quality_office_test.pptx", replace
copy "example_data/smartload_example.pdf" "`base'/root1/smartload_pdf_table_test.pdf", replace
file open fh using "`base'\root1\sample.psv", write text replace
file write fh "id|value|name" _n
file write fh "1|10|row1" _n
file write fh "2|20|row2" _n
file close fh
file open fh using "`base'\root1\sample.tab", write text replace
file write fh "id" _tab "value" _tab "name" _n
file write fh "1" _tab "10" _tab "row1" _n
file write fh "2" _tab "20" _tab "row2" _n
file close fh
cap export excel using "`base'\root1\sample.xlsx", firstrow(variables) replace
local xlsx_rc = _rc
cap export parquet using "`base'\root1\sample.parquet", replace
local parquet_rc = _rc
cap export dbase using "`base'\root1\sample.dbf", replace
local dbf_rc = _rc
cap export spss using "`base'\root1\sample.zsav", replace
local zsav_rc = _rc

copy "`base'\root1\sample.csv" "`base'\root2\sample.csv", replace
copy "`base'\root1\sample.dta" "`base'\root2\sample.dta", replace
copy "`base'\root1\sample.dta" "`base'\root1\Customer Delight Data_Master.dta", replace

file open fh using "`base'\root1\web_tables.html", write text replace
file write fh `"<html><body><h1>tables</h1><table><tr><th>id</th><th>score</th></tr><tr><td>1</td><td>10</td></tr><tr><td>2</td><td>20</td></tr></table><table><tr><th>city</th><th>value</th></tr><tr><td>Austin</td><td>7</td></tr></table></body></html>"'
file close fh
copy "`base'\root1\web_tables.html" "`base'\root1\web_tables.asp", replace

file open fh using "`base'\root1\image_table.html", write text replace
file write fh `"<html><body><p>This page has a table screenshot.</p><img src="table.png" alt="table image"></body></html>"'
file close fh

file open fh using "`base'\root1\encoded_tables.html", write text replace
file write fh `"<html><body><pre>&lt;table&gt;&lt;tr&gt;&lt;th&gt;first&lt;/th&gt;&lt;th&gt;last&lt;/th&gt;&lt;th&gt;idnum&lt;/th&gt;&lt;/tr&gt;&lt;tr&gt;&lt;td&gt;Sarah&lt;/td&gt;&lt;td&gt;Johnson&lt;/td&gt;&lt;td&gt;54&lt;/td&gt;&lt;/tr&gt;&lt;tr&gt;&lt;td&gt;Michael&lt;/td&gt;&lt;td&gt;Chen&lt;/td&gt;&lt;td&gt;4567&lt;/td&gt;&lt;/tr&gt;&lt;/table&gt;</pre></body></html>"'
file close fh

cap mkdir "`base'\docxbuild"
cap mkdir "`base'\docxbuild\word"
file open fh using "`base'\docxbuild\word\document.xml", write text replace
file write fh `"<w:document><w:body><w:tbl><w:tr><w:tc><w:p><w:r><w:t>id</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>name</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>location</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>1</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Alice</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t xml:space="preserve">New </w:t></w:r><w:r><w:t>York</w:t></w:r></w:p></w:tc></w:tr><w:tr><w:tc><w:p><w:r><w:t>2</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Bob Smith</w:t></w:r></w:p></w:tc><w:tc><w:p><w:r><w:t>Chicago</w:t></w:r></w:p></w:tc></w:tr></w:tbl></w:body></w:document>"'
file close fh
local oldpwd "`c(pwd)'"
qui cd "`base'\docxbuild"
zipfile "word", saving("`base'\root1\report.docx", replace)
qui cd "`oldpwd'"

cap mkdir "`base'\pptxbuild"
cap mkdir "`base'\pptxbuild\ppt"
cap mkdir "`base'\pptxbuild\ppt\slides"
file open fh using "`base'\pptxbuild\ppt\slides\slide1.xml", write text replace
file write fh `"<p:sld><p:cSld><p:spTree><a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:t>category</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>description</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc><a:txBody><a:p><a:r><a:t>A</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>Customer service</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></p:spTree></p:cSld></p:sld>"'
file close fh
file open fh using "`base'\pptxbuild\ppt\slides\slide2.xml", write text replace
file write fh `"<p:sld><p:cSld><p:spTree><a:tbl><a:tr><a:tc><a:txBody><a:p><a:r><a:t>item</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>count</a:t></a:r></a:p></a:txBody></a:tc></a:tr><a:tr><a:tc><a:txBody><a:p><a:r><a:t>alpha</a:t></a:r></a:p></a:txBody></a:tc><a:tc><a:txBody><a:p><a:r><a:t>3</a:t></a:r></a:p></a:txBody></a:tc></a:tr></a:tbl></p:spTree></p:cSld></p:sld>"'
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

di as txt "8a. .dat without clear preserves changed data and returns r(4)"
generate __smartload_memory_guard = 1
replace __smartload_memory_guard = 2 in 1
capture noisily smartload sample.dat
assert _rc == 4
confirm variable __smartload_memory_guard

di as txt "8. .dat text-delimited candidate succeeds with clear"
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

di as txt "9d. ESRI shapefile pair translates, loads, and remains spset"
loc before_geo_pwd `"`c(pwd)'"'
quietly cd "`base'"
smartload smartload_geo_selftest.shp, roots("`base'/root1") maxdirs(20) clear replace
assert r(N) == 8
assert r(k) == 9
assert "`r(extension)'" == "shp"
assert "`r(importcmd)'" == "spshape2dta + use"
confirm file "`r(spatialdata)'"
confirm file "`r(shapefile)'"
spset
assert CITY[1] == "Houston"
assert abs(LONGITUDE[1] - (-95.3698)) < .000001
smartload smartload_geo_selftest.shp, roots("`base'/root1") maxdirs(20) clear
assert r(N) == 8
assert CITY[2] == "Chicago"
quietly cd `"`before_geo_pwd'"'

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

di as txt "16. aligned text-based PDF table is reconstructed"
smartload smartload_pdf_table_test.pdf, clear
assert "`r(importcmd)'" == "pdf2txt + aligned table reconstruction"
assert r(k) == 20
assert r(N) == 8
assert inspect_id[1] == "A7K2M9Q4T6X1"
assert check_date[1] == "2026-01-05"
assert issue[1] == "Seal ring does not close tightly"
assert check_mode[1] == "Warehouse sampling"
assert remarks[2] == "Crack length exceeds acceptance limit"
assert remarks[7] == "Repeat measurement remains out of tolerance"
assert issue[8] == "Damaged moisture-proof package seal"

di as txt "7b. .csv2 semicolon and comma-decimal import succeeds"
smartload sample.csv2, firstrow clear
assert r(N) == 2
assert r(k) == 3
assert value[1] == 10.5

di as txt "7c. .psv pipe-delimited import succeeds"
smartload sample.psv, firstrow clear
assert r(N) == 2
assert r(k) == 3
assert value[2] == 20

di as txt "7d. .tab tab-delimited import succeeds"
smartload sample.tab, firstrow clear
assert r(N) == 2
assert r(k) == 3
assert name[1] == "row1"

di as txt "7e. .zsav import succeeds if compressed SPSS export was available"
if `zsav_rc' == 0 {
    smartload sample.zsav, clear
    assert r(N) == 5
    assert r(k) == 3
    assert "`r(importcmd)'" == "import spss"
}
else {
    di as txt "Skipped .zsav import test because compressed SPSS export was unavailable."
}

di as txt "16b. DOCX native table preserves numeric and text cells"
smartload report.docx, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 3
assert "`r(importcmd)'" == "office table extraction"
assert id[1] == 1
assert name[2] == "Bob Smith"
assert location[1] == "New York"

di as txt "16c. PPTX native tables are numbered in slide order"
smartload slides.pptx, table(1) firstrow clear
assert r(N) == 1
assert r(k) == 2
assert r(ntables) == 2
assert category[1] == "A"
assert description[1] == "Customer service"

di as txt "16d. PPTX second native table can be selected"
smartload slides.pptx, table(2) firstrow clear
assert r(N) == 1
assert r(table) == 2
assert item[1] == "alpha"
assert count[1] == 3

di as txt "16e. packaged DOCX has one 20-column by 8-row quality table"
smartload smartload_quality_office_test.docx, table(1) firstrow clear
assert r(ntables) == 1
assert r(N) == 8
assert r(k) == 20
assert inspect_id[1] == "A7K2M9Q4T6X1"
assert issue[8] == "Damaged moisture-proof package seal"

di as txt "16f. packaged PPTX has one 20-column by 8-row quality table"
smartload smartload_quality_office_test.pptx, table(1) firstrow clear
assert r(ntables) == 1
assert r(N) == 8
assert r(k) == 20
assert inspect_id[1] == "A7K2M9Q4T6X1"
assert issue[8] == "Damaged moisture-proof package seal"

di as txt "17. HTML true table imports"
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

di as txt "18f. Encoded HTML table code block imports"
smartload encoded_tables.html, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 3
assert first[1] == "Sarah"
assert idnum[2] == 4567

di as txt "18g. Server-page extension with HTML table imports"
smartload web_tables.asp, table(1) firstrow clear
assert r(N) == 2
assert r(k) == 2
assert "`r(importcmd)'" == "html table extraction"
assert id[1] == 1
assert score[2] == 20

di as txt "18h. URL ending in slash is treated as HTML page"
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

di as txt "22. Google URL normalization is exercised through the public URL tests"
di as txt "Private smartload helper programs are intentionally not called directly."
cap noi smartload "https://docs.google.com/presentation/d/abc123/edit", table(1) clear
assert _rc != 198

di as result "All runnable smartload V0.7.10 tests completed."
log close smartload_selftest
exit, clear



