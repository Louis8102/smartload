*! smartload 0.6.8 11jul2026 Hao Ma
program define smartload, rclass
    version 19.5
    syntax [anything(name=fname id="file name")] [, SETUP INSTALLES REFRESH ROOTS(string) ///
        DRIVES(string) CHOICE(integer -1) CLEAR SHEET(string) FIRSTROW ///
        ENCODING(string) OCR LOG REPLACE MAXDIRS(integer 2500) TABLE(integer -1)]

    smartload__indexpath
    loc indexfile `"`r(indexfile)'"'

    if "`setup'" != "" {
        smartload__setup, indexfile(`"`indexfile'"')
        return local indexfile `"`indexfile'"'
        exit
    }

    if "`installes'" != "" {
        smartload__installes
        exit
    }

    if "`refresh'" != "" {
        smartload__refresh, indexfile(`"`indexfile'"') roots(`"`roots'"') drives(`"`drives'"')
        return local indexfile `"`indexfile'"'
        return scalar N = r(N)
        exit
    }

    loc filename `"`fname'"'
    loc filename = strtrim(`"`filename'"')
    loc stripped 1
    while `stripped' {
        loc stripped 0
        loc wc : word count `filename'
        if `wc' > 1 {
            loc last : word `wc' of `filename'
            loc lastlow = lower(`"`last'"')
            if `"`lastlow'"' == "clear" & "`clear'" == "" {
                loc clear "clear"
                loc filename = substr(`"`filename'"', 1, strlen(`"`filename'"') - strlen(`"`last'"'))
                loc filename = strtrim(`"`filename'"')
                loc stripped 1
            }
            else if `"`lastlow'"' == "firstrow" & "`firstrow'" == "" {
                loc firstrow "firstrow"
                loc filename = substr(`"`filename'"', 1, strlen(`"`filename'"') - strlen(`"`last'"'))
                loc filename = strtrim(`"`filename'"')
                loc stripped 1
            }
            else if `"`lastlow'"' == "log" & "`log'" == "" {
                loc log "log"
                loc filename = substr(`"`filename'"', 1, strlen(`"`filename'"') - strlen(`"`last'"'))
                loc filename = strtrim(`"`filename'"')
                loc stripped 1
            }
            else if `"`lastlow'"' == "replace" & "`replace'" == "" {
                loc replace "replace"
                loc filename = substr(`"`filename'"', 1, strlen(`"`filename'"') - strlen(`"`last'"'))
                loc filename = strtrim(`"`filename'"')
                loc stripped 1
            }
        }
    }
    local filename = subinstr(`"`filename'"', char(34), "", .)
    loc source `"`filename'"'
    loc isurl = inlist(substr(lower(`"`source'"'), 1, 7), "http://") | inlist(substr(lower(`"`source'"'), 1, 8), "https://")
    if !`isurl' {
        mata: st_local("filename", pathbasename(st_local("filename")))
    }
    else {
        loc urlclean `"`source'"'
        loc qpos = strpos(`"`urlclean'"', "?")
        if `qpos' > 0 loc urlclean = substr(`"`urlclean'"', 1, `qpos' - 1)
        loc hpos = strpos(`"`urlclean'"', "#")
        if `hpos' > 0 loc urlclean = substr(`"`urlclean'"', 1, `hpos' - 1)
        mata: st_local("filename", pathbasename(st_local("urlclean")))
        if `"`filename'"' == "" loc filename "index.html"
    }
    if `"`filename'"' == "" {
        di as err "Please specify a file name, or run {cmd:smartload, setup}."
        exit 198
    }

    loc logrequested = "`log'" != ""
    loc logfile "smartload_log.txt"
    tempname lh
    if `logrequested' {
        if "`replace'" != "" file open `lh' using "`logfile'", write text replace
        else file open `lh' using "`logfile'", write text append
        file write `lh' "Command: smartload `filename'" _n
        file write `lh' "Date/time: `c(current_date)' `c(current_time)'" _n
    }

    tempfile sysmatches
    if `isurl' {
        smartload__urlmatch, url(`"`source'"') saving(`"`sysmatches'"')
        loc sysN = r(N)
    }
    else {
        smartload__everything, filename(`"`filename'"') saving(`"`sysmatches'"')
        loc sysN = r(N)
    }

    preserve
    if `sysN' > 0 {
        qui use `"`sysmatches'"', clear
        if !`isurl' & `"`roots'"' == "" {
            smartload__cloudroots
            if `"`r(roots)'"' != "" {
                tempfile cloudmatches
                smartload__quickfind, filename(`"`filename'"') roots(`"`r(roots)'"') maxdirs(`maxdirs') saving(`"`cloudmatches'"') storage(cloud) quiet
                append using `"`cloudmatches'"'
            }
        }
    }
    else {
        cap confirm file `"`indexfile'"'
        if !_rc {
        qui use `"`indexfile'"', clear
        cap confirm var filename
        if _rc {
            restore
            di as err "smartload index is invalid. Rebuild it with {cmd:smartload, setup} or {cmd:smartload, refresh}."
            exit 459
        }
        qui keep if lower(filename) == lower(`"`filename'"')
        if `"`roots'"' != "" {
            smartload__filterroots, roots(`"`roots'"')
        }
        }
        else {
            smartload__empty_matches
        }
    }

    qui count
    loc nmatch = r(N)
    if `nmatch' == 0 {
        restore
        di as txt "No indexed match for `filename'. Running automatic fast search..."
        tempfile quickmatches
        smartload__quickfind, filename(`"`filename'"') roots(`"`roots'"') maxdirs(`maxdirs') saving(`"`quickmatches'"')
        loc matchfile `"`quickmatches'"'
        preserve
        qui use `"`matchfile'"', clear
        qui count
        loc nmatch = r(N)
    }

    if `nmatch' == 0 {
        restore
        di as err "No file named `filename' was found in the index or fast search."
        di as txt "Run {cmd:smartload, setup} to build an index, or {cmd:smartload, refresh roots(...)} for selected work folders."
        if `logrequested' {
            file write `lh' "Result: failure - no match" _n _n
            file close `lh'
        }
        exit 601
    }

    qui gen str2045 __fp_l = lower(filepath)
    qui duplicates drop __fp_l, force
    qui drop __fp_l
    qui count
    loc nmatch = r(N)

    if `nmatch' > 1 {
        di as err "Found multiple files named `filename':"
        forvalues i = 1/`nmatch' {
            loc p = filepath[`i']
            di as txt "`i'. `p'"
        }

        if `choice' >= 1 {
            loc selected = `choice'
        }
        else {
            if c(mode) == "batch" {
                restore
                di as err "File name is not unique. Batch mode cannot prompt for a choice."
                di as txt "Use {cmd:choice(#)}."
                exit 459
            }
            di as txt "Type the number of the file to import, then press Enter."
            cap macro drop SMARTLOAD_CHOICE
            display _request(SMARTLOAD_CHOICE)
            loc selected = strtrim("$SMARTLOAD_CHOICE")
        }

        cap confirm integer number `selected'
        if _rc | real("`selected'") < 1 | real("`selected'") > `nmatch' {
            restore
            di as err "Invalid selection. No file was imported."
            exit 198
        }
        qui keep in `selected'
    }

    loc filepath = filepath[1]
    loc storage = storage[1]
    loc matchedext = ext[1]
    restore

    loc loadpath = subinstr(`"`filepath'"', char(92), "/", .)
    loc extpath `"`filepath'"'
    loc qpos = strpos(`"`extpath'"', "?")
    if `qpos' > 0 loc extpath = substr(`"`extpath'"', 1, `qpos' - 1)
    loc hpos = strpos(`"`extpath'"', "#")
    if `hpos' > 0 loc extpath = substr(`"`extpath'"', 1, `hpos' - 1)
    mata: st_local("ext", strlower(pathsuffix(st_local("extpath"))))
    loc ext : subinstr loc ext "." "", all
    if `"`matchedext'"' != "" loc ext `"`matchedext'"'
    if `isurl' & `"`ext'"' == "" loc ext "html"
    if `isurl' & inlist("`ext'", "asp", "aspx", "php", "jsp", "cfm", "cgi") loc ext "html"
    loc importcmd ""

    if `logrequested' {
        file write `lh' "Matched file: `filepath'" _n
        file write `lh' "Storage location: `storage'" _n
        file write `lh' "Detected extension: `ext'" _n
    }

    if "`ext'" == "dta" {
        if "`clear'" != "" use `"`loadpath'"', clear
        else use `"`loadpath'"'
        loc importcmd "use"
    }
    else if inlist("`ext'", "xlsx", "xls") {
        loc opts ""
        if "`firstrow'" != "" loc opts "`opts' firstrow"
        if `"`sheet'"' != "" loc opts `"`opts' sheet(`"`sheet'"')"'
        if "`clear'" != "" loc opts "`opts' clear"
        if `"`opts'"' != "" import excel `"`loadpath'"', `opts'
        else import excel `"`loadpath'"'
        loc importcmd "import excel"
    }
    else if inlist("`ext'", "csv", "txt") {
        loc opts ""
        if "`firstrow'" != "" loc opts "`opts' varnames(1)"
        if `"`encoding'"' != "" loc opts `"`opts' encoding(`"`encoding'"')"'
        if "`clear'" != "" loc opts "`opts' clear"
        if `"`opts'"' != "" import delimited `"`loadpath'"', `opts'
        else import delimited `"`loadpath'"'
        loc importcmd "import delimited"
    }
    else if "`ext'" == "tsv" {
        loc opts "delimiters(tab)"
        if "`firstrow'" != "" loc opts "`opts' varnames(1)"
        if `"`encoding'"' != "" loc opts `"`opts' encoding(`"`encoding'"')"'
        if "`clear'" != "" loc opts "`opts' clear"
        import delimited `"`loadpath'"', `opts'
        loc importcmd "import delimited"
    }
    else if "`ext'" == "dat" {
        loc opts ""
        if "`clear'" != "" loc opts "clear"
        if "`opts'" != "" cap noi import delimited `"`loadpath'"', `opts'
        else cap noi import delimited `"`loadpath'"'
        if _rc {
            di as err "Detected .dat file, but it could not be imported as a rectangular delimited dataset."
            return local filepath `"`filepath'"'
            return local filename `"`filename'"'
            return local extension "`ext'"
            return local status "detected_not_imported"
            exit 459
        }
        loc importcmd "import delimited"
    }
    else if inlist("`ext'", "sav", "por") {
        if "`clear'" != "" import spss using "`loadpath'", clear
        else import spss using "`loadpath'"
        loc importcmd "import spss"
    }
    else if "`ext'" == "sas7bdat" {
        if "`clear'" != "" import sas using "`loadpath'", clear
        else import sas using "`loadpath'"
        loc importcmd "import sas"
    }
    else if "`ext'" == "xpt" {
        if "`clear'" != "" import sasxport5 using "`loadpath'", clear
        else import sasxport5 using "`loadpath'"
        loc importcmd "import sasxport5"
    }
    else if "`ext'" == "v8xpt" {
        if "`clear'" != "" import sasxport8 using "`loadpath'", clear
        else import sasxport8 using "`loadpath'"
        loc importcmd "import sasxport8"
    }
    else if "`ext'" == "parquet" {
        if "`clear'" != "" import parquet using "`loadpath'", clear
        else import parquet using "`loadpath'"
        loc importcmd "import parquet"
    }
    else if "`ext'" == "dbf" {
        if "`clear'" != "" import dbase using "`loadpath'", clear
        else import dbase using "`loadpath'"
        loc importcmd "import dbase"
    }
    else if "`ext'" == "dct" {
        if "`storage'" == "url" {
            di as err "URL .dct files are not safely importable because the dictionary usually references a companion raw data file."
            di as txt "Download the .dct and its raw data file to the same local folder, then run smartload on the local .dct."
            return local filepath `"`filepath'"'
            return local filename `"`filename'"'
            return local extension "`ext'"
            return local status "detected_not_imported"
            exit 459
        }
        if "`clear'" != "" clear
        loc dctpath = subinstr(`"`loadpath'"', char(92), "/", .)
        mata: st_local("dctbase", pathbasename(st_local("dctpath")))
        loc slash = 0
        forvalues i = 1/`=strlen(`"`dctpath'"')' {
            if substr(`"`dctpath'"', `i', 1) == "/" loc slash = `i'
        }
        loc dctdir = ""
        if `slash' > 1 loc dctdir = substr(`"`dctpath'"', 1, `slash' - 1)
        loc oldpwd `"`c(pwd)'"'
        if `"`dctdir'"' != "" qui cd `"`dctdir'"'
        cap noi infix using `"`dctbase'"'
        loc dctrc = _rc
        qui cd `"`oldpwd'"'
        if `dctrc' exit `dctrc'
        loc importcmd "infix using"
    }
    else if inlist("`ext'", "docx", "pptx") {
        if "`storage'" == "url" {
            di as err "URL .`ext' table extraction is not enabled."
            di as txt "Download the Office file locally, then run smartload on the local .`ext' file."
            return local filepath `"`filepath'"'
            return local filename `"`filename'"'
            return local extension "`ext'"
            return local status "detected_not_imported"
            exit 459
        }
        smartload__office_table, filepath(`"`loadpath'"') ext(`"`ext'"') table(`table') `clear' `firstrow'
        loc office_table = r(table)
        loc office_ntables = r(ntables)
        loc importcmd "office table extraction"
    }
    else if inlist("`ext'", "html", "htm", "asp", "aspx", "php", "jsp", "cfm", "cgi") {
        smartload__html_table, filepath(`"`loadpath'"') storage(`"`storage'"') table(`table') `clear' `firstrow'
        loc html_table = r(table)
        loc html_ntables = r(ntables)
        loc importcmd "html table extraction"
    }
    else {
        smartload__detected `"`filepath'"' "`filename'" "`ext'" "`lh'" "`logrequested'" "`ocr'"
        return local filepath `"`filepath'"'
        return local filename `"`filename'"'
        return local extension "`ext'"
        return local status "detected_not_imported"
        exit 0
    }

    return local filepath `"`filepath'"'
    return local filename `"`filename'"'
    return local extension "`ext'"
    return local importcmd "`importcmd'"
    return local storage "`storage'"
    return local indexfile `"`indexfile'"'
    if inlist("`ext'", "docx", "pptx") {
        return scalar table = `office_table'
        return scalar ntables = `office_ntables'
    }
    if inlist("`ext'", "html", "htm", "asp", "aspx", "php", "jsp", "cfm", "cgi") {
        return scalar table = `html_table'
        return scalar ntables = `html_ntables'
    }
    qui ds
    loc k : word count `r(varlist)'
    loc N = _N
    return scalar N = `N'
    return scalar k = `k'

    di as res "Successfully imported file:"
    di as txt `"`filepath'"'
    loc typename "Recognized data file"
    if "`ext'" == "dta" loc typename "Stata dataset"
    else if inlist("`ext'", "xlsx", "xls") loc typename "Excel workbook"
    else if inlist("`ext'", "csv", "txt", "tsv", "dat") loc typename "Delimited text candidate"
    else if inlist("`ext'", "sav", "por") loc typename "SPSS data file"
    else if inlist("`ext'", "sas7bdat", "xpt", "v8xpt") loc typename "SAS data file"
    else if "`ext'" == "parquet" loc typename "Parquet data file"
    else if "`ext'" == "dbf" loc typename "dBASE/DBF database table"
    else if "`ext'" == "dct" loc typename "Fixed-format dictionary"
    else if "`ext'" == "docx" loc typename "Word table"
    else if "`ext'" == "pptx" loc typename "PowerPoint table"
    else if inlist("`ext'", "html", "htm", "asp", "aspx", "php", "jsp", "cfm", "cgi") loc typename "HTML table"
    di as txt "Detected type: `typename'"
    di as txt "Command used: `importcmd'"
    di as txt "Storage location: `storage'"
    di as txt "Observations: " as res `N'
    di as txt "Variables: " as res `k'

    if `logrequested' {
        file write `lh' "Import command used: `importcmd'" _n
        file write `lh' "Result: success" _n
        file write `lh' "Observations: `N'" _n
        file write `lh' "Variables: `k'" _n _n
        file close `lh'
    }
end

program define smartload__urlmatch, rclass
    version 19.5
    syntax , URL(string) SAVING(string)

    loc u `"`url'"'
    loc ul = lower(`"`u'"')
    loc githubconv = 0
    loc gsheetconv = 0
    loc gdocconv = 0
    if strpos(`"`ul'"', "https://github.com/") == 1 & strpos(`"`ul'"', "/blob/") > 0 {
        loc u = subinstr(`"`u'"', "https://github.com/", "https://raw.githubusercontent.com/", 1)
        loc u = subinstr(`"`u'"', "/blob/", "/", 1)
        loc githubconv = 1
    }
    if strpos(`"`ul'"', "http://github.com/") == 1 & strpos(`"`ul'"', "/blob/") > 0 {
        loc u = subinstr(`"`u'"', "http://github.com/", "https://raw.githubusercontent.com/", 1)
        loc u = subinstr(`"`u'"', "/blob/", "/", 1)
        loc githubconv = 1
    }
    if strpos(`"`ul'"', "https://docs.google.com/spreadsheets/d/") == 1 | strpos(`"`ul'"', "http://docs.google.com/spreadsheets/d/") == 1 {
        loc dpos = strpos(`"`u'"', "/d/")
        loc rest = substr(`"`u'"', `dpos' + 3, .)
        loc slash = strpos(`"`rest'"', "/")
        if `slash' > 0 loc gid = substr(`"`rest'"', 1, `slash' - 1)
        else loc gid `"`rest'"'
        loc sheetgid "0"
        loc gidpos = strpos(lower(`"`u'"'), "gid=")
        if `gidpos' > 0 {
            loc aftergid = substr(`"`u'"', `gidpos' + 4, .)
            loc amp = strpos(`"`aftergid'"', "&")
            loc hash = strpos(`"`aftergid'"', "#")
            loc stop = 0
            if `amp' > 0 loc stop = `amp'
            if `hash' > 0 & (`stop' == 0 | `hash' < `stop') loc stop = `hash'
            if `stop' > 0 loc sheetgid = substr(`"`aftergid'"', 1, `stop' - 1)
            else loc sheetgid `"`aftergid'"'
        }
        loc u `"https://docs.google.com/spreadsheets/d/`gid'/export?format=csv&gid=`sheetgid'"'
        loc ul = lower(`"`u'"')
        loc gsheetconv = 1
    }
    if strpos(`"`ul'"', "https://docs.google.com/document/d/") == 1 | strpos(`"`ul'"', "http://docs.google.com/document/d/") == 1 {
        loc dpos = strpos(`"`u'"', "/d/")
        loc rest = substr(`"`u'"', `dpos' + 3, .)
        loc slash = strpos(`"`rest'"', "/")
        if `slash' > 0 loc docid = substr(`"`rest'"', 1, `slash' - 1)
        else loc docid `"`rest'"'
        loc u `"https://docs.google.com/document/d/`docid'/export?format=html"'
        loc ul = lower(`"`u'"')
        loc gdocconv = 1
    }

    loc clean `"`u'"'
    loc qpos = strpos(`"`clean'"', "?")
    if `qpos' > 0 loc clean = substr(`"`clean'"', 1, `qpos' - 1)
    loc hpos = strpos(`"`clean'"', "#")
    if `hpos' > 0 loc clean = substr(`"`clean'"', 1, `hpos' - 1)

    mata: st_local("base", pathbasename(st_local("clean")))
    if `"`base'"' == "" loc base "index.html"
    mata: st_local("ext", strlower(pathsuffix(st_local("clean"))))
    loc ext : subinstr loc ext "." "", all
    if strpos(lower(`"`u'"'), "docs.google.com/spreadsheets/") > 0 {
        loc base "google_sheet.csv"
        loc ext "csv"
    }
    if strpos(lower(`"`u'"'), "docs.google.com/document/") > 0 {
        loc base "google_doc.html"
        loc ext "html"
    }
    if `"`ext'"' == "" loc ext "html"
    if inlist("`ext'", "asp", "aspx", "php", "jsp", "cfm", "cgi") loc ext "html"

    loc slash = 0
    forvalues i = 1/`=strlen(`"`clean'"')' {
        if substr(`"`clean'"', `i', 1) == "/" loc slash = `i'
    }
    loc dir = ""
    if `slash' > 1 loc dir = substr(`"`clean'"', 1, `slash' - 1)

    tempname posth
    postfile `posth' str2045 filepath str255 filename str2045 dirname str32 ext str20 storage using `"`saving'"', replace
    post `posth' (`"`u'"') (`"`base'"') (`"`dir'"') (`"`ext'"') ("url")
    postclose `posth'

    di as txt "Detected URL input; smartload will import directly from the URL."
    if `githubconv' di as txt "GitHub blob URL converted to raw URL."
    if `gsheetconv' di as txt "Google Sheets URL converted to CSV export URL."
    if `gdocconv' di as txt "Google Docs URL converted to HTML export URL."
    return scalar N = 1
    return local url `"`u'"'
end

program define smartload__office_table, rclass
    version 19.5
    syntax , FILEPATH(string) EXT(string) TABLE(integer) [CLEAR FIRSTROW]

    tempfile csv marker
    loc workdir `"`marker'_office"'
    cap mkdir `"`workdir'"'
    loc oldpwd `"`c(pwd)'"'
    qui cd `"`workdir'"'
    cap qui unzipfile `"`filepath'"', replace
    loc unzip_rc = _rc
    qui cd `"`oldpwd'"'
    if `unzip_rc' {
        di as err "Could not unzip .`ext' Office container."
        exit `unzip_rc'
    }

    loc xmlfiles ""
    if "`ext'" == "docx" {
        mata: st_local("docxml", pathjoin(pathjoin(st_local("workdir"), "word"), "document.xml"))
        cap confirm file `"`docxml'"'
        if _rc {
            di as err "No Word document.xml was found inside the DOCX file."
            exit 498
        }
        loc xmlfiles `"`docxml'"'
    }
    else if "`ext'" == "pptx" {
        mata: st_local("slidesdir", pathjoin(pathjoin(st_local("workdir"), "ppt"), "slides"))
        cap local slides : dir `"`slidesdir'"' files "slide*.xml"
        if _rc | `"`slides'"' == "" {
            di as err "No PowerPoint slide XML files were found inside the PPTX file."
            exit 498
        }
        foreach s of local slides {
            mata: st_local("slidepath", pathjoin(st_local("slidesdir"), st_local("s")))
            loc xmlfiles `"`xmlfiles';`slidepath'"'
        }
        if substr(`"`xmlfiles'"', 1, 1) == ";" loc xmlfiles = substr(`"`xmlfiles'"', 2, strlen(`"`xmlfiles'"') - 1)
    }

    mata: st_numscalar("r(ntables)", smartload_office_table_count(st_local("xmlfiles"), st_local("ext")))
    loc ntables = r(ntables)
    if `ntables' == 0 {
        di as err "No true Office tables were found in this .`ext' file."
        exit 498
    }
    if `table' < 1 {
        if `ntables' == 1 {
            loc table 1
        }
        else {
            di as err "Found multiple true Office tables in this .`ext' file:"
            forvalues i = 1/`ntables' {
                mata: st_local("preview", smartload_office_table_preview(st_local("xmlfiles"), st_local("ext"), `i'))
                di as txt "`i'. `preview'"
            }
            if c(mode) == "batch" {
                di as err "Batch mode cannot prompt for an Office table choice."
                di as txt "Use {cmd:table(#)}."
                exit 459
            }
            di as txt "Type the number of the table to import, then press Enter."
            cap macro drop SMARTLOAD_TABLE_CHOICE
            display _request(SMARTLOAD_TABLE_CHOICE)
            loc table = strtrim("$SMARTLOAD_TABLE_CHOICE")
        }
    }
    cap confirm integer number `table'
    if _rc | real("`table'") < 1 | real("`table'") > `ntables' {
        di as err "Invalid table selection. No file was imported."
        exit 198
    }
    mata: smartload_office_table_to_csv(st_local("xmlfiles"), st_local("ext"), strtoreal(st_local("table")), st_local("csv"))
    loc opts ""
    if "`firstrow'" != "" loc opts "`opts' varnames(1)"
    else loc opts "`opts' varnames(nonames)"
    if "`clear'" != "" loc opts "`opts' clear"
    import delimited using `"`csv'"', `opts'
    return local importcmd "office table extraction"
    return scalar table = `table'
    return scalar ntables = `ntables'
end

program define smartload__html_table, rclass
    version 19.5
    syntax , FILEPATH(string) STORAGE(string) TABLE(integer) [CLEAR FIRSTROW]

    tempfile htmltmp csv
    if "`storage'" == "url" {
        loc html `"`htmltmp'.html"'
        loc dlrc = 601
        loc filemissing = 1
        cap erase `"`html'"'
        cap copy `"`filepath'"' `"`html'"', replace
        loc copyrc = _rc
        cap confirm file `"`html'"'
        loc filemissing = _rc
        if !`copyrc' & !`filemissing' loc dlrc = 0
        else if `copyrc' loc dlrc = `copyrc'
        if `dlrc' {
            di as err "Could not download the web page or HTML file."
            di as txt "smartload uses Stata's native downloader for SSC-style portability."
            di as txt "If the page opens in a browser but Stata cannot download it, save the page as a local .html file and run smartload on that file."
            exit `dlrc'
        }
        if `filemissing' {
            di as err "The web page download did not create a readable temporary HTML file."
            di as txt "The server may block Stata downloads, require JavaScript, or require authentication."
            di as txt "Save the page as a local .html file and run smartload on that file."
            exit 601
        }
        loc htmlpath `"`html'"'
    }
    else {
        loc htmlpath `"`filepath'"'
    }

    mata: st_numscalar("r(ntables)", smartload_html_table_count(st_local("htmlpath")))
    loc ntables = r(ntables)
    if `ntables' == 0 {
        mata: st_numscalar("r(nimages)", smartload_html_image_count(st_local("htmlpath")))
        loc nimages = r(nimages)
        di as err "No true HTML <table> elements were found."
        if `nimages' > 0 {
            di as txt "This page contains image elements. If the table is a screenshot or picture, OCR is required and is not run automatically."
        }
        else {
            di as txt "The page may use ordinary text, CSS grid/div layout, JavaScript rendering, or another non-table structure."
        }
        exit 498
    }

    if `table' < 1 {
        if `ntables' == 1 {
            loc table 1
        }
        else {
            di as err "Found multiple true HTML tables:"
            forvalues i = 1/`ntables' {
                mata: st_local("preview", smartload_html_table_preview(st_local("htmlpath"), `i'))
                di as txt "`i'. `preview'"
            }
            if c(mode) == "batch" {
                di as err "Batch mode cannot prompt for an HTML table choice."
                di as txt "Use {cmd:table(#)}."
                exit 459
            }
            di as txt "Type the number of the table to import, then press Enter."
            cap macro drop SMARTLOAD_TABLE_CHOICE
            display _request(SMARTLOAD_TABLE_CHOICE)
            loc table = strtrim("$SMARTLOAD_TABLE_CHOICE")
        }
    }

    cap confirm integer number `table'
    if _rc | real("`table'") < 1 | real("`table'") > `ntables' {
        di as err "Invalid table selection. No file was imported."
        exit 198
    }

    mata: smartload_html_table_to_csv(st_local("htmlpath"), strtoreal(st_local("table")), st_local("csv"))
    loc opts ""
    if "`firstrow'" != "" loc opts "`opts' varnames(1)"
    else loc opts "`opts' varnames(nonames)"
    if "`clear'" != "" loc opts "`opts' clear"
    import delimited using `"`csv'"', `opts'
    return local importcmd "html table extraction"
    return scalar table = `table'
    return scalar ntables = `ntables'
end

program define smartload__everything, rclass
    version 19.5
    syntax , FILENAME(string) SAVING(string)

    tempname posth
    postfile `posth' str2045 filepath str255 filename str2045 dirname str32 ext str20 storage using `"`saving'"', replace
    loc n 0

    if "`c(os)'" != "Windows" {
        postclose `posth'
        return scalar N = 0
        exit
    }

    smartload__espath
    loc es `"`r(es)'"'

    if `"`es'"' == "" {
        cap confirm file "C:/Program Files/Everything/Everything.exe"
        if !_rc {
            di as txt "Everything is installed, but smartload did not find es.exe."
            di as txt "Install the Everything Command-line Interface (ES) from voidtools for instant smartload search."
        }
        postclose `posth'
        return scalar N = 0
        exit
    }

    tempfile out
    loc query `"`filename'"'
    loc cmd `""`es'" -n 200 -s -export-txt "`out'" "`query'""'
    qui cap shell `cmd'

    cap confirm file `"`out'"'
    if _rc {
        di as txt "Everything command-line search did not return results; falling back to smartload index/search."
        di as txt "If this persists, open Everything once and make sure it is running."
        postclose `posth'
        return scalar N = 0
        exit
    }

    tempname fh
    cap file open `fh' using `"`out'"', read text
    if _rc {
        postclose `posth'
        return scalar N = 0
        exit
    }

    file read `fh' line
    while r(eof) == 0 {
        loc p = strtrim(`"`line'"')
        if `"`p'"' != "" {
            mata: st_local("base", pathbasename(st_local("p")))
            if lower(`"`base'"') == lower(`"`filename'"') {
                loc pn = subinstr(`"`p'"', char(92), "/", .)
                loc slash = 0
                forvalues i = 1/`=strlen(`"`pn'"')' {
                    if substr(`"`pn'"', `i', 1) == "/" loc slash = `i'
                }
                loc dir = ""
                if `slash' > 1 loc dir = substr(`"`pn'"', 1, `slash' - 1)
                mata: st_local("ext", strlower(pathsuffix(st_local("p"))))
                loc ext : subinstr loc ext "." "", all
                post `posth' (`"`p'"') (`"`base'"') (`"`dir'"') (`"`ext'"') ("everything")
                loc ++n
            }
        }
        file read `fh' line
    }
    file close `fh'
    postclose `posth'

    preserve
    qui use `"`saving'"', clear
    qui count
    if r(N) > 0 {
        qui gen str2045 __fp_l = lower(filepath)
        qui duplicates drop __fp_l, force
        qui drop __fp_l
    }
    qui save `"`saving'"', replace
    qui count
    loc n = r(N)
    restore

    if `n' > 0 di as txt "Searching with Everything..."
    return scalar N = `n'
end

program define smartload__espath, rclass
    version 19.5
    loc es ""
    loc base `"`c(sysdir_personal)'"'
    if `"`base'"' == "" loc base `"`c(tmpdir)'"'
    mata: st_local("personal_es", pathjoin(pathjoin(st_local("base"), "smartload_bin"), "es.exe"))
    foreach p in ///
        `"`personal_es'"' ///
        "C:/Program Files/Everything/es.exe" ///
        "C:/Program Files (x86)/Everything/es.exe" ///
        "C:/Tools/Everything/es.exe" ///
        "C:/Users/`c(username)'/AppData/Local/Everything/es.exe" ///
        "C:/Users/`c(username)'/AppData/Roaming/Everything/es.exe" {
        cap confirm file `"`p'"'
        if !_rc & `"`es'"' == "" loc es `"`p'"'
    }
    return local es `"`es'"'
end

program define smartload__installes, rclass
    version 19.5
    if "`c(os)'" != "Windows" {
        di as err "smartload, installes is only for Windows."
        exit 459
    }

    loc base `"`c(sysdir_personal)'"'
    if `"`base'"' == "" loc base `"`c(tmpdir)'"'
    mata: st_local("bindir", pathjoin(st_local("base"), "smartload_bin"))
    cap mkdir `"`bindir'"'

    loc tmp `"`c(tmpdir)'"'
    mata: st_local("zip", pathjoin(st_local("tmp"), "smartload_es.zip"))

    di as txt "Downloading Everything Command-line Interface (ES) from voidtools..."
    loc gotzip 0
    foreach url in ///
        "https://www.voidtools.com/ES-1.1.0.30.x64.zip" ///
        "http://www.voidtools.com/ES-1.1.0.30.x64.zip" {
        cap copy `"`url'"' `"`zip'"', replace
        if !_rc {
            loc gotzip 1
            continue, break
        }
    }
    if !`gotzip' {
        di as txt "Stata download failed; trying Windows curl..."
        cap shell curl.exe -L --fail --silent --show-error -o `"`zip'"' "https://www.voidtools.com/ES-1.1.0.30.x64.zip"
        cap confirm file `"`zip'"'
        if !_rc loc gotzip 1
    }
    if !`gotzip' {
        di as err "Download failed."
        di as txt "Manual download page: https://www.voidtools.com/downloads/"
        di as txt "Choose ES-1.1.0.30.x64.zip and place es.exe in:"
        di as txt `"`bindir'"'
        di as txt "Everything itself must also be installed and running."
        exit 601
    }

    loc oldpwd `"`c(pwd)'"'
    qui cd `"`bindir'"'
    cap unzipfile `"`zip'"', replace
    loc unzip_rc = _rc
    qui cd `"`oldpwd'"'
    if `unzip_rc' {
        di as err "Downloaded ES zip, but unzip failed."
        di as txt `"`zip'"'
        exit 601
    }

    mata: st_local("es", pathjoin(st_local("bindir"), "es.exe"))
    cap confirm file `"`es'"'
    if _rc {
        di as err "Could not find es.exe after unzip."
        di as txt "Please unzip ES-1.1.0.30.x64.zip manually and place es.exe in:"
        di as txt `"`bindir'"'
        exit 601
    }

    di as res "Everything Command-line Interface installed for smartload."
    di as txt "ES path: `es'"
    di as txt "Make sure Everything is installed and running."
    return local es `"`es'"'
end

program define smartload__empty_matches
    version 19.5
    qui clear
    qui set obs 0
    qui gen str2045 filepath = ""
    qui gen str255 filename = ""
    qui gen str2045 dirname = ""
    qui gen str32 ext = ""
    qui gen str20 storage = ""
end

program define smartload__filterroots
    version 19.5
    syntax , ROOTS(string)
    qui gen str2045 __rootfilter = ""
    loc rest `"`roots'"'
    while `"`rest'"' != "" {
        loc semi = strpos(`"`rest'"', ";")
        if `semi' > 0 {
            loc root = substr(`"`rest'"', 1, `semi' - 1)
            loc rest = substr(`"`rest'"', `semi' + 1, strlen(`"`rest'"'))
        }
        else {
            loc root `"`rest'"'
            loc rest ""
        }
        loc root = strtrim(`"`root'"')
        if `"`root'"' == "" continue
        loc root = subinstr(`"`root'"', char(92), "/", .)
        qui replace __rootfilter = "1" if strpos(lower(filepath), lower(`"`root'"')) == 1
    }
    qui keep if __rootfilter == "1"
    qui drop __rootfilter
end

program define smartload__indexpath, rclass
    version 19.5
    loc base `"`c(sysdir_personal)'"'
    if `"`base'"' == "" loc base `"`c(tmpdir)'"'
    cap mkdir `"`base'"'
    mata: st_local("idx", pathjoin(st_local("base"), "smartload_index.dta"))
    return local indexfile `"`idx'"'
end

program define smartload__setup, rclass
    version 19.5
    syntax , INDEXFILE(string)
    di as txt "smartload setup"
    di as txt ""
    di as txt "1. Index common user folders only"
    di as txt "2. Index current project folder"
    di as txt "3. Index selected folders"
    di as txt "4. Deep full-drive index (slow)"
    di as txt ""
    if c(mode) == "batch" {
        di as err "setup is interactive. In batch mode, use smartload, refresh roots(...) or drives(...)."
        exit 459
    }
    di as txt "Type 1, 2, 3, or 4:"
    cap macro drop SMARTLOAD_SETUP
    display _request(SMARTLOAD_SETUP)
    loc pick = strtrim("$SMARTLOAD_SETUP")

    if "`pick'" == "1" {
        smartload__defaultroots
        smartload__refresh, indexfile(`"`indexfile'"') roots(`"`r(roots)'"')
    }
    else if "`pick'" == "2" {
        smartload__refresh, indexfile(`"`indexfile'"') roots(`"`c(pwd)'"')
    }
    else if "`pick'" == "3" {
        di as txt "Type selected folders separated by semicolons:"
        cap macro drop SMARTLOAD_ROOTS
        display _request(SMARTLOAD_ROOTS)
        loc roots `"$SMARTLOAD_ROOTS"'
        if `"`roots'"' == "" {
            di as err "No folders were specified."
            exit 198
        }
        smartload__refresh, indexfile(`"`indexfile'"') roots(`"`roots'"')
    }
    else if "`pick'" == "4" {
        di as txt "Deep full-drive indexing can take many minutes."
        smartload__refresh, indexfile(`"`indexfile'"') drives(all)
    }
    else {
        di as err "Invalid setup choice."
        exit 198
    }
end

program define smartload__defaultroots, rclass
    version 19.5
    loc roots `"`c(pwd)'"'
    loc home "C:/Users/`c(username)'"
    foreach sub in Desktop Documents Downloads OneDrive "OneDrive/Documents" Dropbox "Google Drive" "My Drive" Box {
        loc roots `"`roots';`home'/`sub'"'
    }
    forvalues i = 67/90 {
        loc d = char(`i')
        loc root "`d':/"
        mata: st_local("direx", strofreal(direxists(st_local("root"))))
        if "`direx'" == "1" {
            loc roots `"`roots';`root'"'
            foreach sub in data Data dataset Dataset datasets Datasets project Project projects Projects {
                loc roots `"`roots';`root'`sub'"'
            }
        }
    }
    return local roots `"`roots'"'
end

program define smartload__cloudroots, rclass
    version 19.5
    loc roots ""
    loc home "C:/Users/`c(username)'"
    foreach sub in OneDrive "OneDrive/Documents" Dropbox "Google Drive" "My Drive" Box "Box Sync" "Box Drive" "SharePoint" {
        loc root `"`home'/`sub'"'
        mata: st_local("direx", strofreal(direxists(st_local("root"))))
        if "`direx'" == "1" loc roots `"`roots';`root'"'
    }
    forvalues i = 67/90 {
        loc d = char(`i')
        foreach sub in "Google Drive" "My Drive" Box Dropbox OneDrive SharePoint {
            loc root "`d':/`sub'"
            mata: st_local("direx", strofreal(direxists(st_local("root"))))
            if "`direx'" == "1" loc roots `"`roots';`root'"'
        }
    }
    if substr(`"`roots'"', 1, 1) == ";" loc roots = substr(`"`roots'"', 2, strlen(`"`roots'"') - 1)
    return local roots `"`roots'"'
end

program define smartload__refresh, rclass
    version 19.5
    syntax , INDEXFILE(string) [ROOTS(string) DRIVES(string)]

    tempfile newindex
    tempname posth
    postfile `posth' str2045 filepath str255 filename str2045 dirname str32 ext str20 storage using `"`newindex'"', replace

    if `"`roots'"' != "" {
        smartload__scanroots, roots(`"`roots'"') post(`posth') storage(local)
    }
    else if `"`drives'"' != "" {
        loc drives_l = lower(strtrim(`"`drives'"'))
        if `"`drives_l'"' == "all" {
            loc drvlist ""
            forvalues i = 67/90 {
                loc d = char(`i')
                loc drvlist "`drvlist' `d'"
            }
        }
        else loc drvlist `"`drives'"'
        foreach d of local drvlist {
            loc d = upper(strtrim("`d'"))
            local d : subinstr local d ":" "", all
            if length("`d'") != 1 continue
            loc root "`d':/"
            mata: st_local("direx", strofreal(direxists(st_local("root"))))
            if "`direx'" != "1" continue
            di as txt "Indexing `root'"
            smartload__scanroot, root(`"`root'"') post(`posth') storage(local)
        }
    }
    else {
        smartload__defaultroots
        di as txt "Indexing common user folders. Use drives(all) only for slow deep indexing."
        smartload__scanroots, roots(`"`r(roots)'"') post(`posth') storage(local)
    }

    postclose `posth'
    preserve
    qui use `"`newindex'"', clear
    qui duplicates drop filepath, force
    qui compress
    save `"`indexfile'"', replace
    qui count
    loc n = r(N)
    restore

    di as res "smartload index refreshed."
    di as txt "Index file: `indexfile'"
    di as txt "Files indexed: " as res `n'
    return local indexfile `"`indexfile'"'
    return scalar N = `n'
end

program define smartload__scanroots, rclass
    version 19.5
    syntax , ROOTS(string) POST(string) STORAGE(string)
    loc rest `"`roots'"'
    loc nroots 0
    while `"`rest'"' != "" {
        loc semi = strpos(`"`rest'"', ";")
        if `semi' > 0 {
            loc root = substr(`"`rest'"', 1, `semi' - 1)
            loc rest = substr(`"`rest'"', `semi' + 1, strlen(`"`rest'"'))
        }
        else {
            loc root `"`rest'"'
            loc rest ""
        }
        loc root = strtrim(`"`root'"')
        if `"`root'"' == "" continue
        smartload__scanroot, root(`"`root'"') post(`post') storage(`storage')
        loc ++nroots
    }
    return scalar nroots = `nroots'
end

program define smartload__scanroot, rclass
    version 19.5
    syntax , ROOT(string) POST(string) STORAGE(string)
    loc root = subinstr(`"`root'"', char(92), "/", .)
    mata: st_local("direx", strofreal(direxists(st_local("root"))))
    if "`direx'" != "1" exit

    loc root_l = lower(`"`root'"')
    foreach bad in "/windows" "/program files" "/program files (x86)" "/programdata" "/$recycle.bin" "/system volume information" "/recovery" {
        if strpos(`"`root_l'"', `"`bad'"') exit
    }

    loc posth "`post'"
    loc nfiles 0
    preserve
    qui clear
    qui set obs 1
    qui gen str2045 dirname = `"`root'"'
    qui gen byte done = 0

    qui count if done == 0
    while r(N) > 0 {
        sort done dirname
        loc cur = dirname[1]
        qui replace done = 1 in 1

        cap local files : dir `"`cur'"' files "*"
        if !_rc {
            foreach f of local files {
                mata: st_local("full", pathjoin(st_local("cur"), st_local("f")))
                mata: st_local("ext", strlower(pathsuffix(st_local("full"))))
                loc ext : subinstr loc ext "." "", all
                loc extok 0
                foreach ok in dta xlsx xls csv txt tsv dat sav por sas7bdat xpt v8xpt parquet dbf dct html htm asp aspx php jsp cfm cgi pdf docx doc pptx ppt rds rda rdata r feather pkl pickle arrow h5 hdf5 json jsonl sql sqlite db duckdb accdb mdb shp geojson gpkg kml kmz gdb zip gz 7z tar {
                    if "`ext'" == "`ok'" loc extok 1
                }
                if `extok' {
                    post `posth' (`"`full'"') (`"`f'"') (`"`cur'"') (`"`ext'"') ("`storage'")
                    loc ++nfiles
                }
            }
        }

        cap local dirs : dir `"`cur'"' dirs "*"
        if !_rc {
            foreach sub of local dirs {
                if `"`sub'"' == "." | `"`sub'"' == ".." continue
                mata: st_local("child", pathjoin(st_local("cur"), st_local("sub")))
                loc child = subinstr(`"`child'"', char(92), "/", .)
                mata: st_local("childex", strofreal(direxists(st_local("child"))))
                if "`childex'" != "1" continue
                loc child_l = lower(`"`child'"')
                loc badchild 0
                foreach bad in "/windows" "/program files" "/program files (x86)" "/programdata" "/$recycle.bin" "/system volume information" "/recovery" {
                    if strpos(`"`child_l'"', `"`bad'"') loc badchild 1
                }
                if `badchild' continue
                qui set obs `=_N + 1'
                qui replace dirname = `"`child'"' in L
                qui replace done = 0 in L
            }
        }
        qui count if done == 0
    }
    restore
    return scalar nfiles = `nfiles'
end

program define smartload__quickfind, rclass
    version 19.5
    syntax , FILENAME(string) SAVING(string) [ROOTS(string) MAXDIRS(integer 2500) STORAGE(string) QUIET]
    if `"`storage'"' == "" loc storage "fast"
    if `"`roots'"' == "" {
        smartload__defaultroots
        loc roots `"`r(roots)'"'
    }

    tempname posth
    postfile `posth' str2045 filepath str255 filename str2045 dirname str32 ext str20 storage using `"`saving'"', replace

    loc target = subinstr(`"`filename'"', char(92), "/", .)
    mata: st_local("target", pathbasename(st_local("target")))
    mata: st_local("target_l", strlower(st_local("target")))
    mata: st_local("target_ext", strlower(pathsuffix(st_local("target"))))
    loc target_ext : subinstr loc target_ext "." "", all
    loc visited 0

    preserve
    qui clear
    qui set obs 0
    qui gen str2045 dirname = ""
    qui gen byte done = 0

    loc rest `"`roots'"'
    while `"`rest'"' != "" {
        loc semi = strpos(`"`rest'"', ";")
        if `semi' > 0 {
            loc root = substr(`"`rest'"', 1, `semi' - 1)
            loc rest = substr(`"`rest'"', `semi' + 1, strlen(`"`rest'"'))
        }
        else {
            loc root `"`rest'"'
            loc rest ""
        }
        loc root = strtrim(`"`root'"')
        if `"`root'"' == "" continue
        loc root = subinstr(`"`root'"', char(92), "/", .)
        mata: st_local("direx", strofreal(direxists(st_local("root"))))
        if "`direx'" != "1" continue
        cap local files : dir `"`root'"' files "`target'"
        if !_rc {
            foreach f of local files {
                if lower(`"`f'"') == `"`target_l'"' {
                    mata: st_local("full", pathjoin(st_local("root"), st_local("f")))
                    post `posth' (`"`full'"') (`"`f'"') (`"`root'"') ("`target_ext'") (`"`storage'"')
                }
            }
        }
        qui set obs `=_N + 1'
        qui replace dirname = `"`root'"' in L
        qui replace done = 0 in L
    }

    qui count if done == 0
    while r(N) > 0 & `visited' < `maxdirs' {
        sort done dirname
        loc cur = dirname[1]
        qui replace done = 1 in 1
        loc ++visited

        cap local files : dir `"`cur'"' files "`target'"
        if !_rc {
            foreach f of local files {
                if lower(`"`f'"') == `"`target_l'"' {
                    mata: st_local("full", pathjoin(st_local("cur"), st_local("f")))
                    post `posth' (`"`full'"') (`"`f'"') (`"`cur'"') ("`target_ext'") (`"`storage'"')
                }
            }
        }

        cap local dirs : dir `"`cur'"' dirs "*"
        if !_rc {
            foreach sub of local dirs {
                if `"`sub'"' == "." | `"`sub'"' == ".." continue
                mata: st_local("child", pathjoin(st_local("cur"), st_local("sub")))
                loc child = subinstr(`"`child'"', char(92), "/", .)
                mata: st_local("childex", strofreal(direxists(st_local("child"))))
                if "`childex'" != "1" continue
                loc child_l = lower(`"`child'"')
                loc badchild 0
                foreach bad in "/windows" "/program files" "/program files (x86)" "/programdata" "/$recycle.bin" "/system volume information" "/recovery" {
                    if strpos(`"`child_l'"', `"`bad'"') loc badchild 1
                }
                if `badchild' continue
                qui set obs `=_N + 1'
                qui replace dirname = `"`child'"' in L
                qui replace done = 0 in L
            }
        }
        qui count if done == 0
    }
    restore
    postclose `posth'

    preserve
    qui use `"`saving'"', clear
    qui count
    if r(N) > 0 {
        qui duplicates drop filepath, force
    }
    qui save `"`saving'"', replace
    qui count
    loc n = r(N)
    restore

    if "`quiet'" == "" di as txt "Fast search checked `visited' folders."
    return local matchfile `"`saving'"'
    return scalar N = `n'
    return scalar visited = `visited'
end

program define smartload__detected, rclass
    args filepath filename ext lh logrequested ocr
    loc kind "unsupported"
    if inlist("`ext'", "pdf") loc kind "PDF/document-table"
    else if inlist("`ext'", "doc") loc kind "Word/document-table"
    else if inlist("`ext'", "ppt") loc kind "PowerPoint/presentation-table"
    else if inlist("`ext'", "rds", "rda", "rdata", "r") loc kind "R"
    else if inlist("`ext'", "zip", "gz", "7z", "tar") loc kind "archive"
    else if inlist("`ext'", "sqlite", "db", "duckdb", "accdb", "mdb", "sql") loc kind "database"
    else if inlist("`ext'", "shp", "geojson", "gpkg", "kml", "kmz", "gdb") loc kind "GIS"
    else if inlist("`ext'", "feather", "pkl", "pickle", "arrow", "h5", "hdf5", "json", "jsonl") loc kind "Python/data-science"

    di as txt "Detected `kind' file: .`ext'"
    if inlist("`ext'", "rds", "rda", "rdata", "r") {
        di as err "R data files are detected but not imported automatically in this version."
        di as txt "Convert in R to .dta, .parquet, or .csv, then run smartload again."
        di as txt `"Examples: haven::write_dta(df, "data.dta"); arrow::write_parquet(df, "data.parquet")."'
    }
    else if inlist("`ext'", "doc", "ppt", "pdf") {
        di as err "Document table extraction is not enabled in this version."
        di as txt "Legacy DOC/PPT and PDF may contain tables, but they are not reliable rectangular data files."
    }
    else {
        di as err "This file type is detected but not safely importable by smartload in this version."
    }
    if "`logrequested'" == "1" {
        file write `lh' "Result: detected_not_imported" _n _n
        file close `lh'
    }
end

mata:
string scalar smartload_readfile(string scalar fn)
{
    real scalar fh
    string scalar line, out
    out = ""
    fh = fopen(fn, "r")
    while ((line = fget(fh)) != J(0,0,"")) {
        out = out + line
    }
    fclose(fh)
    return(out)
}

real scalar smartload_posfrom(string scalar s, string scalar needle, real scalar start)
{
    real scalar p
    if (start < 1) start = 1
    if (start > strlen(s)) return(0)
    p = strpos(substr(s, start, .), needle)
    if (p == 0) return(0)
    return(start + p - 1)
}

string scalar smartload_xml_unescape(string scalar s)
{
    s = subinstr(s, "&amp;", "&", .)
    s = subinstr(s, "&lt;", "<", .)
    s = subinstr(s, "&gt;", ">", .)
    s = subinstr(s, "&quot;", `"""', .)
    s = subinstr(s, "&apos;", "'", .)
    return(strtrim(s))
}

string scalar smartload_cell_text(string scalar cell, string scalar prefix)
{
    real scalar p, gt, q
    string scalar open, close, out, next
    open = "<" + prefix + ":t"
    close = "</" + prefix + ":t>"
    out = ""
    p = 1
    while ((p = smartload_posfrom(cell, open, p)) > 0) {
        next = substr(cell, p + strlen(open), 1)
        if (!(next == ">" | next == " " | next == char(9) | next == char(13) | next == char(10))) {
            p = p + strlen(open)
            continue
        }
        gt = smartload_posfrom(cell, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(cell, close, gt + 1)
        if (q == 0) break
        if (out != "") out = out + " "
        out = out + substr(cell, gt + 1, q - gt - 1)
        p = q + strlen(close)
    }
    return(smartload_xml_unescape(out))
}

string rowvector smartload_row_cells(string scalar row, string scalar prefix)
{
    real scalar p, gt, q
    string scalar open, close, cell
    string rowvector cells
    open = "<" + prefix + ":tc"
    close = "</" + prefix + ":tc>"
    cells = J(1, 0, "")
    p = 1
    while ((p = smartload_posfrom(row, open, p)) > 0) {
        gt = smartload_posfrom(row, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(row, close, gt + 1)
        if (q == 0) break
        cell = substr(row, gt + 1, q - gt - 1)
        cells = cells, smartload_cell_text(cell, prefix)
        p = q + strlen(close)
    }
    return(cells)
}

string scalar smartload_csv_quote(string scalar s)
{
    s = subinstr(s, `"""', `""""', .)
    return(`"""' + s + `"""')
}

void smartload_write_csv(string matrix rows, string scalar csvfile)
{
    real scalar fh, i, j
    string scalar line
    fh = fopen(csvfile, "w")
    for (i=1; i<=rows(rows); i++) {
        line = ""
        for (j=1; j<=cols(rows); j++) {
            if (j > 1) line = line + ","
            line = line + smartload_csv_quote(rows[i,j])
        }
        fput(fh, line)
    }
    fclose(fh)
}

string rowvector smartload_semicolon_split(string scalar s)
{
    string rowvector out
    string scalar part
    real scalar p

    out = J(1, 0, "")
    while (strlen(s) > 0) {
        p = strpos(s, ";")
        if (p == 0) {
            part = strtrim(s)
            s = ""
        }
        else {
            part = strtrim(substr(s, 1, p - 1))
            s = substr(s, p + 1, .)
        }
        if (part != "") out = out, part
    }
    return(out)
}

real scalar smartload_html_image_count(string scalar htmlfile)
{
    string scalar html, lhtml
    real scalar p, count

    html = smartload_readfile(htmlfile)
    lhtml = strlower(html)
    p = 1
    count = 0
    while ((p = smartload_posfrom(lhtml, "<img", p)) > 0) {
        count++
        p = p + 4
    }
    return(count)
}

real scalar smartload_html_table_count(string scalar htmlfile)
{
    string scalar html, lhtml
    real scalar p, gt, q, count

    html = smartload_readfile(htmlfile)
    html = smartload_html_for_tables(html)
    lhtml = strlower(html)
    p = 1
    count = 0
    while ((p = smartload_posfrom(lhtml, "<table", p)) > 0) {
        gt = smartload_posfrom(lhtml, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(lhtml, "</table>", gt + 1)
        if (q == 0) break
        count++
        p = q + 8
    }
    return(count)
}

string scalar smartload_html_text(string scalar s)
{
    real scalar p, gt
    string scalar out

    out = ""
    p = 1
    while (p <= strlen(s)) {
        if (substr(s, p, 1) == "<") {
            gt = smartload_posfrom(s, ">", p)
            if (gt == 0) break
            out = out + " "
            p = gt + 1
        }
        else {
            out = out + substr(s, p, 1)
            p++
        }
    }
    out = subinstr(out, char(9), " ", .)
    out = subinstr(out, char(10), " ", .)
    out = subinstr(out, char(13), " ", .)
    out = subinstr(out, "&nbsp;", " ", .)
    out = smartload_xml_unescape(out)
    while (strpos(out, "  ") > 0) out = subinstr(out, "  ", " ", .)
    return(strtrim(out))
}

string rowvector smartload_html_row_cells(string scalar row)
{
    string scalar lrow, close, cell
    string rowvector cells
    real scalar p, ptd, pth, gt, q

    lrow = strlower(row)
    cells = J(1, 0, "")
    p = 1
    while (p <= strlen(row)) {
        ptd = smartload_posfrom(lrow, "<td", p)
        pth = smartload_posfrom(lrow, "<th", p)
        if (ptd == 0 & pth == 0) break
        if (ptd > 0 & (pth == 0 | ptd < pth)) {
            p = ptd
            close = "</td>"
        }
        else {
            p = pth
            close = "</th>"
        }
        gt = smartload_posfrom(lrow, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(lrow, close, gt + 1)
        if (q == 0) break
        cell = substr(row, gt + 1, q - gt - 1)
        cells = cells, smartload_html_text(cell)
        p = q + strlen(close)
    }
    return(cells)
}

void smartload_html_collect(string scalar htmlfile, real scalar wanted, string matrix rows, real scalar maxc)
{
    string scalar html, lhtml, tbl, row
    string rowvector cells
    real scalar p, gt, q, rp, rgt, rq, count

    html = smartload_readfile(htmlfile)
    html = smartload_html_for_tables(html)
    lhtml = strlower(html)
    p = 1
    count = 0
    rows = J(0, 0, "")
    maxc = 0

    while ((p = smartload_posfrom(lhtml, "<table", p)) > 0) {
        gt = smartload_posfrom(lhtml, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(lhtml, "</table>", gt + 1)
        if (q == 0) break
        count++
        if (count == wanted) {
            tbl = substr(html, gt + 1, q - gt - 1)
            rp = 1
            while ((rp = smartload_posfrom(strlower(tbl), "<tr", rp)) > 0) {
                rgt = smartload_posfrom(tbl, ">", rp)
                if (rgt == 0) break
                rq = smartload_posfrom(strlower(tbl), "</tr>", rgt + 1)
                if (rq == 0) break
                row = substr(tbl, rgt + 1, rq - rgt - 1)
                cells = smartload_html_row_cells(row)
                if (cols(cells) > 0) {
                    if (cols(cells) > maxc) maxc = cols(cells)
                    if (cols(rows) == 0) rows = cells
                    else {
                        if (cols(cells) < cols(rows)) cells = cells, J(1, cols(rows)-cols(cells), "")
                        if (cols(cells) > cols(rows)) rows = rows, J(rows(rows), cols(cells)-cols(rows), "")
                        rows = rows \ cells
                    }
                }
                rp = rq + 5
            }
            if (cols(rows) < maxc) rows = rows, J(rows(rows), maxc-cols(rows), "")
            return
        }
        p = q + 8
    }
}

string scalar smartload_html_for_tables(string scalar html)
{
    string scalar lhtml, decoded

    lhtml = strlower(html)
    if (strpos(lhtml, "<table") > 0) return(html)

    decoded = smartload_xml_unescape(html)
    if (strpos(strlower(decoded), "<table") > 0) return(decoded)

    return(html)
}

string scalar smartload_html_table_preview(string scalar htmlfile, real scalar wanted)
{
    string matrix rows
    string scalar preview
    real scalar maxc, j

    smartload_html_collect(htmlfile, wanted, rows, maxc)
    if (rows(rows) == 0 | maxc == 0) return("(no readable text preview)")
    preview = ""
    for (j=1; j<=min((3, cols(rows))); j++) {
        if (rows[1,j] != "") {
            if (preview != "") preview = preview + " | "
            preview = preview + rows[1,j]
        }
    }
    if (preview == "") preview = "(no readable text preview)"
    return(strofreal(rows(rows)) + " rows, " + strofreal(maxc) + " columns; " + preview)
}

void smartload_html_table_to_csv(string scalar htmlfile, real scalar wanted, string scalar csvfile)
{
    string matrix rows
    real scalar maxc

    smartload_html_collect(htmlfile, wanted, rows, maxc)
    if (rows(rows) == 0 | maxc == 0) {
        errprintf("Selected HTML table has no readable text cells.\n")
        _error(498)
    }
    smartload_write_csv(rows, csvfile)
}

real scalar smartload_office_table_count(string scalar xmlfiles, string scalar ext)
{
    string rowvector files
    string scalar xml, prefix, tblopen, tblclose
    real scalar f, p, gt, q, count

    files = smartload_semicolon_split(xmlfiles)
    prefix = (ext == "docx" ? "w" : "a")
    tblopen = "<" + prefix + ":tbl"
    tblclose = "</" + prefix + ":tbl>"
    count = 0

    for (f=1; f<=cols(files); f++) {
        xml = smartload_readfile(files[f])
        p = 1
        while ((p = smartload_posfrom(xml, tblopen, p)) > 0) {
            gt = smartload_posfrom(xml, ">", p)
            if (gt == 0) break
            q = smartload_posfrom(xml, tblclose, gt + 1)
            if (q == 0) break
            count++
            p = q + strlen(tblclose)
        }
    }
    return(count)
}

string scalar smartload_office_table_preview(string scalar xmlfiles, string scalar ext, real scalar wanted)
{
    string rowvector files, cells
    string scalar xml, prefix, tblopen, tblclose, rowopen, rowclose, tbl, row, preview
    real scalar f, p, gt, q, rp, rgt, rq, count, nrows, maxc, j

    files = smartload_semicolon_split(xmlfiles)
    prefix = (ext == "docx" ? "w" : "a")
    tblopen = "<" + prefix + ":tbl"
    tblclose = "</" + prefix + ":tbl>"
    rowopen = "<" + prefix + ":tr"
    rowclose = "</" + prefix + ":tr>"
    count = 0

    for (f=1; f<=cols(files); f++) {
        xml = smartload_readfile(files[f])
        p = 1
        while ((p = smartload_posfrom(xml, tblopen, p)) > 0) {
            gt = smartload_posfrom(xml, ">", p)
            if (gt == 0) break
            q = smartload_posfrom(xml, tblclose, gt + 1)
            if (q == 0) break
            count++
            if (count == wanted) {
                tbl = substr(xml, gt + 1, q - gt - 1)
                rp = 1
                nrows = 0
                maxc = 0
                preview = ""
                while ((rp = smartload_posfrom(tbl, rowopen, rp)) > 0) {
                    rgt = smartload_posfrom(tbl, ">", rp)
                    if (rgt == 0) break
                    rq = smartload_posfrom(tbl, rowclose, rgt + 1)
                    if (rq == 0) break
                    nrows++
                    row = substr(tbl, rgt + 1, rq - rgt - 1)
                    cells = smartload_row_cells(row, prefix)
                    if (cols(cells) > maxc) maxc = cols(cells)
                    if (preview == "" & cols(cells) > 0) {
                        for (j=1; j<=min((3, cols(cells))); j++) {
                            if (cells[j] != "") {
                                if (preview != "") preview = preview + " | "
                                preview = preview + cells[j]
                            }
                        }
                    }
                    rp = rq + strlen(rowclose)
                }
                if (preview == "") preview = "(no readable text preview)"
                return(strofreal(nrows) + " rows, " + strofreal(maxc) + " columns; " + preview)
            }
            p = q + strlen(tblclose)
        }
    }
    return("(table not found)")
}

void smartload_office_table_to_csv(string scalar xmlfiles, string scalar ext, real scalar wanted, string scalar csvfile)
{
    string rowvector files, cells
    string scalar xml, prefix, tblopen, tblclose, rowopen, rowclose, tbl, row
    real scalar f, p, gt, q, rp, rgt, rq, count, maxc, nr, i
    string matrix rows, out

    files = smartload_semicolon_split(xmlfiles)
    prefix = (ext == "docx" ? "w" : "a")
    tblopen = "<" + prefix + ":tbl"
    tblclose = "</" + prefix + ":tbl>"
    rowopen = "<" + prefix + ":tr"
    rowclose = "</" + prefix + ":tr>"
    count = 0
    rows = J(0, 0, "")
    maxc = 0

    for (f=1; f<=cols(files); f++) {
        xml = smartload_readfile(files[f])
        p = 1
        while ((p = smartload_posfrom(xml, tblopen, p)) > 0) {
            gt = smartload_posfrom(xml, ">", p)
            if (gt == 0) break
            q = smartload_posfrom(xml, tblclose, gt + 1)
            if (q == 0) break
            count++
            if (count == wanted) {
                tbl = substr(xml, gt + 1, q - gt - 1)
                rp = 1
                while ((rp = smartload_posfrom(tbl, rowopen, rp)) > 0) {
                    rgt = smartload_posfrom(tbl, ">", rp)
                    if (rgt == 0) break
                    rq = smartload_posfrom(tbl, rowclose, rgt + 1)
                    if (rq == 0) break
                    row = substr(tbl, rgt + 1, rq - rgt - 1)
                    cells = smartload_row_cells(row, prefix)
                    if (cols(cells) > maxc) maxc = cols(cells)
                    if (cols(rows) == 0) rows = cells
                    else {
                        if (cols(cells) < cols(rows)) cells = cells, J(1, cols(rows)-cols(cells), "")
                        if (cols(cells) > cols(rows)) rows = rows, J(rows(rows), cols(cells)-cols(rows), "")
                        rows = rows \ cells
                    }
                    rp = rq + strlen(rowclose)
                }
                if (rows(rows) == 0 | maxc == 0) {
                    errprintf("Selected Office table has no readable text cells.\n")
                    _error(498)
                }
                if (cols(rows) < maxc) rows = rows, J(rows(rows), maxc-cols(rows), "")
                smartload_write_csv(rows, csvfile)
                return
            }
            p = q + strlen(tblclose)
        }
    }
    errprintf("Requested Office table was not found. Tables found: %g\n", count)
    _error(498)
}
end
