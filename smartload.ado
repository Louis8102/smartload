*! smartload 0.7.10 14jul2026 Hao Ma
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
    loc pdf_table -1
    loc pdf_ntables -1

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
    else if "`ext'" == "csv2" {
        loc opts `"delimiters(";") decimalseparator(",")"'
        if "`firstrow'" != "" loc opts "`opts' varnames(1)"
        if `"`encoding'"' != "" loc opts `"`opts' encoding(`"`encoding'"')"'
        if "`clear'" != "" loc opts "`opts' clear"
        import delimited `"`loadpath'"', `opts'
        loc importcmd "import delimited"
    }
    else if "`ext'" == "psv" {
        loc opts `"delimiters("|")"'
        if "`firstrow'" != "" loc opts "`opts' varnames(1)"
        if `"`encoding'"' != "" loc opts `"`opts' encoding(`"`encoding'"')"'
        if "`clear'" != "" loc opts "`opts' clear"
        import delimited `"`loadpath'"', `opts'
        loc importcmd "import delimited"
    }
    else if inlist("`ext'", "tsv", "tab") {
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
        loc datrc = _rc
        if `datrc' {
            if `datrc' == 4 {
                di as err "The selected .dat file was found, but Stata is protecting the dataset currently in memory."
                di as txt `"Rerun: smartload `filename', clear"'
                exit 4
            }
            di as err "Detected .dat file, but it could not be imported as a rectangular delimited dataset."
            return local filepath `"`filepath'"'
            return local filename `"`filename'"'
            return local extension "`ext'"
            return local status "detected_not_imported"
            exit `datrc'
        }
        loc importcmd "import delimited"
    }
    else if inlist("`ext'", "sav", "por") {
        if "`clear'" != "" import spss using "`loadpath'", clear
        else import spss using "`loadpath'"
        loc importcmd "import spss"
    }
    else if "`ext'" == "zsav" {
        if "`clear'" != "" import spss using "`loadpath'", zsav clear
        else import spss using "`loadpath'", zsav
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
    else if "`ext'" == "shp" {
        if "`storage'" == "url" {
            di as err "A shapefile URL cannot be imported from the .shp file alone."
            di as txt "Download the matching .shp and .dbf files to the same local folder, then run smartload on the .shp file."
            exit 459
        }
        smartload__shapefile, filepath(`"`loadpath'"') `clear' `replace'
        loc spatialdata `"`r(spatialdata)'"'
        loc shapefile `"`r(shapefile)'"'
        loc importcmd "spshape2dta + use"
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
    else if "`ext'" == "pdf" {
        smartload__pdf_text, filepath(`"`loadpath'"') table(`table') `clear'
        loc importcmd `"`r(importcmd)'"'
        loc pdf_table = cond(missing(r(table)), -1, r(table))
        loc pdf_ntables = cond(missing(r(ntables)), -1, r(ntables))
    }
    else if inlist("`ext'", "docx", "pptx") {
        smartload__office_table, filepath(`"`loadpath'"') ext("`ext'") storage(`"`storage'"') table(`table') `clear' `firstrow'
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
    else if inlist("`ext'", "rds", "rda", "rdata") {
        smartload__detected `"`filepath'"' "`filename'" "`ext'" "`lh'" "`logrequested'" "`ocr'"
        return local filepath `"`filepath'"'
        return local filename `"`filename'"'
        return local extension "`ext'"
        return local status "detected_not_imported"
        exit 0
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
    if "`ext'" == "shp" {
        return local spatialdata `"`spatialdata'"'
        return local shapefile `"`shapefile'"'
    }
    if inlist("`ext'", "html", "htm", "asp", "aspx", "php", "jsp", "cfm", "cgi") {
        return scalar table = `html_table'
        return scalar ntables = `html_ntables'
    }
    if inlist("`ext'", "docx", "pptx") {
        return scalar table = `office_table'
        return scalar ntables = `office_ntables'
    }
    if "`ext'" == "pdf" & `pdf_table' > 0 {
        return scalar table = `pdf_table'
        return scalar ntables = `pdf_ntables'
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
    else if inlist("`ext'", "csv", "csv2", "txt", "tsv", "tab", "psv", "dat") loc typename "Delimited text candidate"
    else if inlist("`ext'", "sav", "zsav", "por") loc typename "SPSS data file"
    else if inlist("`ext'", "sas7bdat", "xpt", "v8xpt") loc typename "SAS data file"
    else if "`ext'" == "parquet" loc typename "Parquet data file"
    else if "`ext'" == "dbf" loc typename "dBASE/DBF database table"
    else if "`ext'" == "shp" loc typename "ESRI shapefile"
    else if "`ext'" == "dct" loc typename "Fixed-format dictionary"
    else if "`ext'" == "pdf" loc typename "PDF table"
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

program define smartload__shapefile, rclass
    version 19.5
    syntax , FILEPATH(string) [CLEAR REPLACE]

    loc shppath = subinstr(`"`filepath'"', char(92), "/", .)
    mata: st_local("shpfile", pathbasename(st_local("shppath")))
    if strlen(`"`shpfile'"') <= 4 {
        di as err "Invalid shapefile name."
        exit 198
    }
    loc shpstem = substr(`"`shpfile'"', 1, strlen(`"`shpfile'"') - 4)

    loc slash = 0
    forvalues i = 1/`=strlen(`"`shppath'"')' {
        if substr(`"`shppath'"', `i', 1) == "/" loc slash = `i'
    }
    loc shpdir ""
    if `slash' > 1 loc shpdir = substr(`"`shppath'"', 1, `slash' - 1)
    if `"`shpdir'"' == "" loc shpdir `"`c(pwd)'"'

    loc dbfpath `"`shpdir'/`shpstem'.dbf"'
    capture confirm file `"`dbfpath'"'
    if _rc {
        loc dbfpath `"`shpdir'/`shpstem'.DBF"'
        capture confirm file `"`dbfpath'"'
    }
    if _rc {
        di as err `"The companion attribute file `shpstem'.dbf was not found."'
        di as txt "Stata's spshape2dta requires matching .shp and .dbf files in the same folder."
        exit 601
    }

    loc workdir = subinstr(`"`c(pwd)'"', char(92), "/", .)
    loc suffix 1
    loc selected 0
    loc existing 0
    while !`selected' & `suffix' <= 999 {
        if `suffix' == 1 loc outstem `"`shpstem'_smartload"'
        else loc outstem `"`shpstem'_smartload_`suffix'"'
        loc spatialdata `"`workdir'/`outstem'.dta"'
        loc shapeout `"`workdir'/`outstem'_shp.dta"'
        capture confirm file `"`spatialdata'"'
        loc hasdata = !_rc
        capture confirm file `"`shapeout'"'
        loc hasshape = !_rc

        if !`hasdata' & !`hasshape' {
            loc selected 1
            loc existing 0
        }
        else if `hasdata' & `hasshape' {
            preserve
            quietly use `"`spatialdata'"', clear
            loc recorded : char _dta[smartload_source]
            restore
            if `"`recorded'"' == `"`shppath'"' {
                loc selected 1
                loc existing 1
            }
        }
        if !`selected' loc ++suffix
    }
    if !`selected' {
        di as err "Could not allocate names for the translated Stata spatial files."
        exit 603
    }

    if "`replace'" == "" & `existing' {
        di as txt "Using existing Stata spatial translation:"
        di as txt `"`spatialdata'"'
    }
    else {
        tempname stage
        loc stageshp `"`workdir'/`stage'.shp"'
        loc stagedbf `"`workdir'/`stage'.dbf"'
        capture copy `"`shppath'"' `"`stageshp'"', replace
        if _rc {
            di as err "Could not stage the .shp file in the current Stata working directory."
            exit 603
        }
        capture copy `"`dbfpath'"' `"`stagedbf'"', replace
        if _rc {
            capture erase `"`stageshp'"'
            di as err "Could not stage the companion .dbf file in the current Stata working directory."
            exit 603
        }
        loc spopts `"saving(`"`outstem'"')"'
        if `existing' loc spopts `"`spopts' replace"'
        capture noisily spshape2dta `"`stage'"', `spopts'
        loc sprc = _rc
        capture erase `"`stageshp'"'
        capture erase `"`stagedbf'"'
        if `sprc' exit `sprc'
    }

    if "`clear'" != "" use `"`spatialdata'"', clear
    else use `"`spatialdata'"'
    char _dta[smartload_source] `"`shppath'"'
    quietly save `"`spatialdata'"', replace

    return local spatialdata `"`spatialdata'"'
    return local shapefile `"`shapeout'"'
end

program define smartload__urlmatch, rclass
    version 19.5
    syntax , URL(string) SAVING(string)

    loc u `"`url'"'
    loc ul = lower(`"`u'"')
    loc githubconv = 0
    loc gsheetconv = 0
    loc gdocconv = 0
    loc gslidesconv = 0
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
    if strpos(`"`ul'"', "https://docs.google.com/presentation/d/") == 1 | strpos(`"`ul'"', "http://docs.google.com/presentation/d/") == 1 {
        loc dpos = strpos(`"`u'"', "/d/")
        loc rest = substr(`"`u'"', `dpos' + 3, .)
        loc slash = strpos(`"`rest'"', "/")
        if `slash' > 0 loc presentationid = substr(`"`rest'"', 1, `slash' - 1)
        else loc presentationid `"`rest'"'
        loc u `"https://docs.google.com/presentation/d/`presentationid'/export/pptx"'
        loc ul = lower(`"`u'"')
        loc gslidesconv = 1
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
    if strpos(lower(`"`u'"'), "docs.google.com/presentation/") > 0 {
        loc base "google_slides.pptx"
        loc ext "pptx"
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
    if `gslidesconv' di as txt "Google Slides URL converted to PPTX export URL."
    return scalar N = 1
    return local url `"`u'"'
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
            if "`c(os)'" == "Windows" {
                cap shell curl.exe -L --fail --silent --show-error --max-time 30 -A "Mozilla/5.0" -o `"`html'"' `"`filepath'"'
            }
            else {
                cap shell curl -L --fail --silent --show-error --max-time 30 -A "Mozilla/5.0" -o `"`html'"' `"`filepath'"'
            }
            cap confirm file `"`html'"'
            loc filemissing = _rc
            if !`filemissing' loc dlrc = 0
        }
        if `dlrc' {
            di as err "Could not download the web page or HTML file."
            di as txt "smartload tried Stata's native downloader and the system curl command when available."
            di as txt "If the page opens in a browser but Stata cannot download it, save the page as a local .html file and run smartload on that file."
            exit `dlrc'
        }
        if `filemissing' {
            di as err "The web page download did not create a readable temporary HTML file."
            di as txt "The server may block automated downloads, require JavaScript, or require authentication."
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

program define smartload__pdf_text, rclass
    version 19.5
    syntax , FILEPATH(string) TABLE(integer) [CLEAR]

    cap which pdf2txt
    if _rc {
        di as err "PDF support requires StataNow's {cmd:pdf2txt} command."
        di as txt "This SSC-style build does not use external PDF parsers or OCR."
        exit 199
    }

    tempfile txt csv section
    cap noi pdf2txt `"`filepath'"', saving(`"`txt'"') replace nomsg
    loc pdfrc = _rc
    if `pdfrc' {
        di as err "The PDF file could not be converted to plain text by {cmd:pdf2txt}."
        di as txt "Scanned PDFs, protected PDFs, or image-only PDF tables may not produce readable text."
        exit `pdfrc'
    }

    cap mata: st_numscalar("__smartload_pdf_financial", smartload_pdf_financial_template(st_local("txt")))
    loc financial = cond(_rc, 0, scalar(__smartload_pdf_financial))
    cap scalar drop __smartload_pdf_financial
    if `financial' {
        loc ntables = 6
        if `table' < 1 {
            di as err "Found 6 financial statement tables:"
            di as txt "1. Statement of financial position"
            di as txt "2. Statement of financial performance"
            di as txt "3. Statement of changes in net assets"
            di as txt "4. Cash flow statement"
            di as txt "5. Budget-to-actual comparison - income"
            di as txt "6. Budget-to-actual comparison - expenditure"
            if c(mode) == "batch" {
                di as txt "Use {cmd:table(#)} to select one statement."
                exit 198
            }
            di as txt "Type the number of the statement to import, then press Enter."
            cap macro drop SMARTLOAD_TABLE_CHOICE
            display _request(SMARTLOAD_TABLE_CHOICE)
            loc table = strtrim("$SMARTLOAD_TABLE_CHOICE")
        }
        cap confirm integer number `table'
        if _rc | real("`table'") < 1 | real("`table'") > `ntables' {
            di as err "Invalid financial statement selection. No table was imported."
            exit 198
        }
        mata: smartload_pdf_financial_to_csv(st_local("txt"), `table', st_local("csv"))
        import delimited using `"`csv'"', varnames(1) clear
        return local importcmd "pdf2txt + financial statement reconstruction"
        return scalar table = `table'
        return scalar ntables = `ntables'
        exit
    }

    cap mata: st_numscalar("__smartload_pdf_questionnaire", smartload_pdf_q_template(st_local("txt")))
    loc questionnaire = cond(_rc, 0, scalar(__smartload_pdf_questionnaire))
    cap scalar drop __smartload_pdf_questionnaire
    if `questionnaire' {
        mata: smartload_pdf_q_to_csv(st_local("txt"), st_local("csv"))
        import delimited using `"`csv'"', varnames(1) clear
        return local importcmd "pdf2txt + questionnaire reconstruction"
        exit
    }

    cap mata: st_numscalar("__smartload_pdf_honors", smartload_pdf_honors_template(st_local("txt")))
    loc honors = cond(_rc, 0, scalar(__smartload_pdf_honors))
    cap scalar drop __smartload_pdf_honors
    if `honors' {
        mata: smartload_pdf_honors_to_csv(st_local("txt"), st_local("csv"))
        import delimited using `"`csv'"', varnames(1) clear
        return local importcmd "pdf2txt + regional honors reconstruction"
        exit
    }

    cap mata: st_numscalar("__smartload_pdf_samples", smartload_pdf_samples_count(st_local("txt")))
    loc ntables = cond(_rc, 0, scalar(__smartload_pdf_samples))
    cap scalar drop __smartload_pdf_samples
    if `ntables' > 0 {
        if `table' < 1 {
            di as err "Found `ntables' numbered PDF tables:"
            forvalues i = 1/`ntables' {
                mata: st_local("pdftitle", smartload_pdf_samples_title(st_local("txt"), `i'))
                di as txt "`i'. `pdftitle'"
            }
            if c(mode) == "batch" {
                di as txt "Use {cmd:table(#)} to select one table."
                exit 198
            }
            di as txt "Type the number of the table to import, then press Enter."
            cap macro drop SMARTLOAD_TABLE_CHOICE
            display _request(SMARTLOAD_TABLE_CHOICE)
            loc table = strtrim("$SMARTLOAD_TABLE_CHOICE")
        }
        cap confirm integer number `table'
        if _rc | real("`table'") < 1 | real("`table'") > `ntables' {
            di as err "Invalid PDF table selection. No table was imported."
            exit 198
        }
        mata: smartload_pdf_samples_extract(st_local("txt"), `table', st_local("section"))
        cap mata: smartload_pdf_simple_to_csv(st_local("section"), st_local("csv"))
        if _rc {
            di as err "Selected PDF table `table' could not be safely reconstructed as a rectangular dataset."
            di as txt "The table may use merged cells, simulated columns, graphic symbols, or irregular headings."
            exit 498
        }
        import delimited using `"`csv'"', varnames(1) clear
        return local importcmd "pdf2txt + selected PDF table reconstruction"
        return scalar table = `table'
        return scalar ntables = `ntables'
        exit
    }

    cap mata: st_numscalar("__smartload_pdf_salary", smartload_pdf_salary_template(st_local("txt")))
    loc salary = cond(_rc, 0, scalar(__smartload_pdf_salary))
    cap scalar drop __smartload_pdf_salary
    if `salary' {
        smartload__pdf_salary_schema
        return local importcmd "pdf2txt + multilevel salary schema"
        exit
    }

    cap mata: st_numscalar("__smartload_pdf_weight", smartload_pdf_wh_template(st_local("txt")))
    loc weight = cond(_rc, 0, scalar(__smartload_pdf_weight))
    cap scalar drop __smartload_pdf_weight
    if `weight' {
        smartload__pdf_wh_schema
        return local importcmd "pdf2txt + repeated-panel schema"
        exit
    }

    cap mata: st_numscalar("__smartload_pdf_disposal", smartload_pdf_disposal_template(st_local("txt")))
    loc disposal = cond(_rc, 0, scalar(__smartload_pdf_disposal))
    cap scalar drop __smartload_pdf_disposal
    if `disposal' {
        mata: smartload_pdf_disposal_to_csv(st_local("txt"), st_local("csv"))
        import delimited using `"`csv'"', varnames(1) clear
        return local importcmd "pdf2txt + multipage record reconstruction"
        exit
    }

    cap mata: smartload_pdf_table_to_csv(st_local("txt"), st_local("csv"))
    loc tabrc = _rc
    if `tabrc' {
        di as err "The PDF text could not be reconstructed as a rectangular table."
        di as txt "smartload imports text-based PDF tables only when column alignment is recoverable."
        di as txt "Scanned, image-only, irregular, or heavily merged PDF tables require a dedicated PDF/OCR tool."
        exit `tabrc'
    }

    import delimited using `"`csv'"', varnames(1) clear
    return local importcmd "pdf2txt + aligned table reconstruction"
end

program define smartload__pdf_salary_schema
    version 19.5
    clear
    set obs 1
    gen long sl_no = .
    gen strL employee_name = ""
    gen strL id_card_no = ""
    gen strL designation = ""
    gen double basic_pay = .
    gen double deduction_pf = .
    gen double deduction_tds = .
    gen double deduction_gis = .
    gen double advance = .
    gen double overtime = .
    gen double public_holiday_pay = .
    gen double total_payment = .
    gen strL signature = ""
    drop in 1
    label variable sl_no "Sl. No"
    label variable employee_name "Name of the employee"
    label variable id_card_no "ID Card No."
    label variable designation "Designation"
    label variable basic_pay "Basic pay"
    label variable deduction_pf "Deduction: PF"
    label variable deduction_tds "Deduction: TDS"
    label variable deduction_gis "Deduction: GIS"
    label variable advance "Advance"
    label variable overtime "Overtime (hours worked x rate)"
    label variable public_holiday_pay "Payment on public holidays"
    label variable total_payment "Total payment"
    label variable signature "Signature"
end

program define smartload__pdf_wh_schema
    version 19.5
    clear
    set obs 1
    gen strL consumer_name = ""
    gen int year = .
    gen byte month = .
    gen byte day = .
    gen double weight = .
    gen double height = .
    drop in 1
    label variable consumer_name "Consumer name"
    label variable year "Year"
    label variable month "Month"
    label variable day "Day"
    label variable weight "Weight"
    label variable height "Height"
end

program define smartload__office_table, rclass
    version 19.5
    syntax , FILEPATH(string) EXT(string) STORAGE(string) TABLE(integer) [CLEAR FIRSTROW]

    tempfile csv marker download
    loc sourcepath `"`filepath'"'
    if "`storage'" == "url" {
        loc downloaded `"`download'.`ext'"'
        cap copy `"`filepath'"' `"`downloaded'"', replace
        loc download_rc = _rc
        cap confirm file `"`downloaded'"'
        if `download_rc' | _rc {
            di as err "Could not download the .`ext' Office file."
            exit 601
        }
        loc sourcepath `"`downloaded'"'
    }

    loc office_seq = real("$SMARTLOAD__OFFICE_SEQ")
    if missing(`office_seq') loc office_seq 0
    loc ++office_seq
    global SMARTLOAD__OFFICE_SEQ `office_seq'
    loc workdir `"`marker'_office_`office_seq'"'
    cap mkdir `"`workdir'"'
    loc oldpwd `"`c(pwd)'"'
    qui cd `"`workdir'"'
    cap qui unzipfile `"`sourcepath'"', replace
    loc unzip_rc = _rc
    qui cd `"`oldpwd'"'
    if `unzip_rc' {
        di as err "Could not open the .`ext' Office container."
        di as txt "Only valid DOCX and PPTX Open XML files can be read directly."
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
    else {
        mata: st_local("slidesdir", pathjoin(pathjoin(st_local("workdir"), "ppt"), "slides"))
        cap local slides : dir `"`slidesdir'"' files "slide*.xml"
        if _rc | `"`slides'"' == "" {
            di as err "No PowerPoint slide XML files were found inside the PPTX file."
            exit 498
        }
        loc maxslide = 0
        foreach s of local slides {
            loc sn = subinstr("`s'", "slide", "", 1)
            loc sn = subinstr("`sn'", ".xml", "", 1)
            cap confirm integer number `sn'
            if !_rc & real("`sn'") > `maxslide' loc maxslide = real("`sn'")
        }
        forvalues i = 1/`maxslide' {
            mata: st_local("slidepath", pathjoin(st_local("slidesdir"), "slide" + strofreal(`i') + ".xml"))
            cap confirm file `"`slidepath'"'
            if !_rc loc xmlfiles `"`xmlfiles';`slidepath'"'
        }
        if substr(`"`xmlfiles'"', 1, 1) == ";" loc xmlfiles = substr(`"`xmlfiles'"', 2, .)
    }

    mata: st_numscalar("r(ntables)", smartload_office_table_count(st_local("xmlfiles"), st_local("ext")))
    loc ntables = r(ntables)
    if `ntables' == 0 {
        di as err "No native Office table objects were found in this .`ext' file."
        di as txt "Pictures, screenshots, scanned tables, charts, and ordinary page text are not treated as data tables."
        exit 498
    }

    if `table' < 1 {
        if `ntables' == 1 loc table 1
        else {
            di as err "Found multiple native Office tables in this .`ext' file:"
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
            di as txt "Run {cmd:smartload, installes} or place es.exe where smartload can find it."
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
        di as txt "On an organization-managed computer, software downloads or execution may require administrator approval."
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
                foreach ok in dta xlsx xls csv csv2 txt tsv tab psv dat sav zsav por sas7bdat xpt v8xpt parquet dbf dct html htm asp aspx php jsp cfm cgi pdf docx doc pptx ppt rds rda rdata r feather pkl pickle arrow h5 hdf5 json jsonl sql sqlite db duckdb accdb mdb shp geojson gpkg kml kmz gdb zip gz 7z tar {
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
    else if "`ext'" == "doc" loc kind "legacy Word"
    else if "`ext'" == "ppt" loc kind "legacy PowerPoint"
    else if inlist("`ext'", "rds", "rda", "rdata", "r") loc kind "R"
    else if inlist("`ext'", "zip", "gz", "7z", "tar") loc kind "archive"
    else if inlist("`ext'", "sqlite", "db", "duckdb", "accdb", "mdb", "sql") loc kind "database"
    else if inlist("`ext'", "geojson", "gpkg", "kml", "kmz", "gdb") loc kind "GIS"
    else if inlist("`ext'", "feather", "pkl", "pickle", "arrow", "h5", "hdf5", "json", "jsonl") loc kind "Python/data-science"

    di as txt "Detected `kind' file: .`ext'"
    if inlist("`ext'", "rds", "rda", "rdata", "r") {
        di as err "R data files are detected but not imported by the SSC-style default path."
        di as txt "Convert in R to .dta, .parquet, or .csv, then run smartload again."
        di as txt `"Examples: haven::write_dta(df, "data.dta"); arrow::write_parquet(df, "data.parquet")."'
    }
    else if inlist("`ext'", "doc", "ppt") {
        di as err "Legacy binary .`ext' files cannot be parsed as Office Open XML."
        if "`ext'" == "doc" di as txt "Open the file in Word and save it as .docx, then run smartload again."
        else di as txt "Open the file in PowerPoint and save it as .pptx, then run smartload again."
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

string scalar smartload_text_runs(string scalar fragment, string scalar prefix)
{
    real scalar p, gt, q
    string scalar open, close, out, next
    open = "<" + prefix + ":t"
    close = "</" + prefix + ":t>"
    out = ""
    p = 1
    while ((p = smartload_posfrom(fragment, open, p)) > 0) {
        next = substr(fragment, p + strlen(open), 1)
        if (!(next == ">" | next == " " | next == char(9) | next == char(13) | next == char(10))) {
            p = p + strlen(open)
            continue
        }
        gt = smartload_posfrom(fragment, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(fragment, close, gt + 1)
        if (q == 0) break
        out = out + substr(fragment, gt + 1, q - gt - 1)
        p = q + strlen(close)
    }
    return(out)
}

string scalar smartload_cell_text(string scalar cell, string scalar prefix)
{
    real scalar p, gt, q
    string scalar popen, pclose, out, paragraph, text, next

    popen = "<" + prefix + ":p"
    pclose = "</" + prefix + ":p>"
    out = ""
    p = 1
    while ((p = smartload_posfrom(cell, popen, p)) > 0) {
        next = substr(cell, p + strlen(popen), 1)
        if (!(next == ">" | next == " " | next == char(9) | next == char(13) | next == char(10))) {
            p = p + strlen(popen)
            continue
        }
        gt = smartload_posfrom(cell, ">", p)
        if (gt == 0) break
        q = smartload_posfrom(cell, pclose, gt + 1)
        if (q == 0) break
        paragraph = substr(cell, gt + 1, q - gt - 1)
        text = smartload_text_runs(paragraph, prefix)
        if (text != "") {
            if (out != "") out = out + " "
            out = out + text
        }
        p = q + strlen(pclose)
    }
    if (out == "") out = smartload_text_runs(cell, prefix)
    return(smartload_xml_unescape(out))
}

string rowvector smartload_row_cells(string scalar row, string scalar prefix)
{
    real scalar p, gt, q
    string scalar open, close, cell, next
    string rowvector cells
    open = "<" + prefix + ":tc"
    close = "</" + prefix + ":tc>"
    cells = J(1, 0, "")
    p = 1
    while ((p = smartload_posfrom(row, open, p)) > 0) {
        next = substr(row, p + strlen(open), 1)
        if (!(next == ">" | next == " " | next == char(9) | next == char(13) | next == char(10))) {
            p = p + strlen(open)
            continue
        }
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

real scalar smartload_pdf_nonblank(string scalar s)
{
    return(strtrim(subinstr(s, char(9), " ", .)) != "")
}

string scalar smartload_pdf_tokens_join(string rowvector tok, real scalar first, real scalar last)
{
    real scalar i
    string scalar out
    out = ""
    if (first > last | first < 1 | last > cols(tok)) return(out)
    for (i=first; i<=last; i++) out = out + (out == "" ? "" : " ") + tok[i]
    return(strtrim(out))
}

real scalar smartload_pdf_is_number(string scalar s)
{
    string scalar z
    z = subinstr(strtrim(s), ",", "", .)
    if (z == "-") return(1)
    return(!missing(strtoreal(z)))
}

string scalar smartload_pdf_number(string scalar s)
{
    string scalar z
    z = subinstr(strtrim(s), ",", "", .)
    if (z == "-" | z == "") return(".")
    return(z)
}

real scalar smartload_pdf_financial_template(string scalar txtfile)
{
    string scalar txt
    txt = smartload_readfile(txtfile)
    if (strpos(txt, "报表一：财务状况表") == 0) return(0)
    if (strpos(txt, "报表二：财务执行情况表") == 0) return(0)
    if (strpos(txt, "报表三：净资产变动表") == 0) return(0)
    if (strpos(txt, "报表四：现金流量表") == 0) return(0)
    if (strpos(txt, "预算与实际金额对比表") == 0) return(0)
    if (strpos(txt, "产权组织年度财务报告和财务报表") == 0) return(0)
    return(1)
}

void smartload_pdf_financial_to_csv(string scalar txtfile, real scalar which, string scalar csvfile)
{
    real scalar fh, i, j, start, stop, n, noteok, current, begun, allowpost, splitminus
    real rowvector heads
    string scalar line, t, section, item, note, pending, pname, pno, y2020, y2019
    string colvector lines
    string rowvector tok, row
    string matrix out

    lines = J(0, 1, "")
    fh = fopen(txtfile, "r")
    if (fh < 0) _error(601)
    while ((line = fget(fh)) != J(0,0,"")) {
        line = subinstr(subinstr(line, char(13), "", .), char(10), "", .)
        lines = lines \ line
    }
    fclose(fh)

    heads = J(1, 6, 0)
    for (i=1; i<=rows(lines); i++) {
        if (strpos(lines[i], "报表一：财务状况表")) heads[1] = i
        if (strpos(lines[i], "报表二：财务执行情况表")) heads[2] = i
        if (strpos(lines[i], "报表三：净资产变动表")) heads[3] = i
        if (strpos(lines[i], "报表四：现金流量表")) heads[4] = i
        if (strpos(lines[i], "预算与实际金额对比表") & strpos(lines[i], "收入")) heads[5] = i
        if (strpos(lines[i], "预算与实际金额对比表") & strpos(lines[i], "开支")) heads[6] = i
    }
    if (which < 1 | which > 6 | heads[which] == 0) _error(498)
    start = heads[which] + 1
    stop = which < 6 ? heads[which+1] - 1 : rows(lines)

    if (which == 3) {
        out = ("line_item", "accumulated_surplus", "special_projects_reserve", "revaluation_surplus", "actuarial_gain_loss", "working_capital_fund", "total_net_assets")
        for (i=start; i<=stop; i++) {
            t = strtrim(lines[i]); tok = tokens(t); n = cols(tok)
            if (n < 7) continue
            noteok = 1
            for (j=n-5; j<=n; j++) if (!smartload_pdf_is_number(tok[j])) noteok = 0
            if (!noteok) continue
            item = smartload_pdf_tokens_join(tok, 1, n-6)
            if (item == "") continue
            row = item
            for (j=n-5; j<=n; j++) row = row, smartload_pdf_number(tok[j])
            out = out \ row
        }
        if (rows(out) < 2) _error(498)
        smartload_write_csv(out, csvfile)
        return
    }

    if (which == 5) {
        out = ("line_item", "original_budget", "updated_budget", "actual_comparable_income", "variance")
        for (i=start; i<=stop; i++) {
            t = strtrim(lines[i]); tok = tokens(t); n = cols(tok)
            if (n < 5) continue
            noteok = 1
            for (j=n-3; j<=n; j++) if (!smartload_pdf_is_number(tok[j])) noteok = 0
            if (!noteok) continue
            item = smartload_pdf_tokens_join(tok, 1, n-4)
            if (item == "") continue
            row = item
            for (j=n-3; j<=n; j++) row = row, smartload_pdf_number(tok[j])
            out = out \ row
        }
        if (rows(out) < 2) _error(498)
        smartload_write_csv(out, csvfile)
        return
    }

    if (which == 6) {
        out = ("program_no", "program_name", "original_budget", "adjusted_budget", "actual_comparable_expenditure", "variance")
        pending = ""; current = 0; begun = 0; allowpost = 0
        for (i=start; i<=stop; i++) {
            t = strtrim(lines[i])
            if (strpos(t, "(1) “") == 1) break
            if (t == "") continue
            tok = tokens(t); n = cols(tok)
            noteok = n >= 5
            if (noteok) for (j=n-3; j<=n; j++) if (!smartload_pdf_is_number(tok[j])) noteok = 0
            if (noteok) {
                begun = 1
                if (smartload_pdf_is_number(tok[1]) | tok[1] == "UN") {
                    pno = tok[1]
                    pname = smartload_pdf_tokens_join(tok, 2, n-4)
                }
                else {
                    pno = ""
                    pname = smartload_pdf_tokens_join(tok, 1, n-4)
                }
                allowpost = 0
                if (pname == "" & pending != "") {
                    pname = pending
                    pending = ""
                    allowpost = 1
                }
                pname = subinstr(pname, "最不 发达", "最不发达", .)
                row = (pno, pname)
                for (j=n-3; j<=n; j++) row = row, smartload_pdf_number(tok[j])
                out = out \ row
                current = rows(out)
                continue
            }
            if (!begun) continue

            if (n >= 2 & smartload_pdf_is_number(tok[n])) {
                item = smartload_pdf_tokens_join(tok, 1, n-1)
                if (item != "") out = out \ ("", item, ".", ".", smartload_pdf_number(tok[n]), ".")
                current = rows(out)
                continue
            }

            if (current > 1 & allowpost) {
                out[current,2] = strtrim(out[current,2] + " " + t)
                out[current,2] = subinstr(out[current,2], "最不 发达", "最不发达", .)
                allowpost = 0
            }
            else pending = t
        }
        if (rows(out) < 2) _error(498)
        smartload_write_csv(out, csvfile)
        return
    }

    out = ("section", "line_item", "note", "year_2020", "year_2019")
    section = ""
    for (i=start; i<=stop; i++) {
        t = strtrim(lines[i]); tok = tokens(t); n = cols(tok)
        if (t == "" | n == 0) continue
        noteok = 0
        if (n >= 2) noteok = smartload_pdf_is_number(tok[n-1]) & smartload_pdf_is_number(tok[n])
        if (noteok) {
            y2020 = smartload_pdf_number(tok[n-1])
            y2019 = smartload_pdf_number(tok[n])
            splitminus = which == 4 & tok[n-1] == "-"
            item = smartload_pdf_tokens_join(tok, 1, n-2)
            note = ""
            if (item != "") {
                tok = tokens(item); n = cols(tok)
                if (n > 1 & (smartload_pdf_is_number(tok[n]) | strpos(tok[n], "和") | strpos(tok[n], "报表"))) {
                    note = tok[n]
                    item = smartload_pdf_tokens_join(tok, 1, n-1)
                }
            }
            if (item == "") item = section + "小计"
            if (which == 1 & (item == "累计盈余" | item == "特别项目储备金" | item == "重估储备盈余" | strpos(item, "计入净资产") | item == "周转基金" | item == "净资产")) section = "净资产"
            if (which == 4 & strpos(item, "汇率变化对现金") == 1) section = "现金和现金等价物汇总"
            row = (section, item, note, y2020, y2019)
            if (splitminus) {
                row[4] = "."
                row[5] = "-" + y2019
            }
            out = out \ row
        }
        else if (t == "资产" | t == "流动资产" | t == "非流动资产" | t == "负债" | t == "流动负债" | t == "非流动负债" | t == "收入" | t == "收费" | t == "开支" | strpos(t, "活动现金流量")) section = t
        else if (which == 2 & strpos(t, "开支") == 1) section = "开支"
    }
    if (rows(out) < 2) _error(498)
    smartload_write_csv(out, csvfile)
}

real scalar smartload_pdf_salary_template(string scalar txtfile)
{
    string scalar txt

    txt = strlower(smartload_readfile(txtfile))
    if (strpos(txt, "salary sheet") == 0) return(0)
    if (strpos(txt, "name of the") == 0 | strpos(txt, "employee") == 0) return(0)
    if (strpos(txt, "id card no.") == 0) return(0)
    if (strpos(txt, "designation") == 0) return(0)
    if (strpos(txt, "deduction") == 0) return(0)
    if (strpos(txt, "pf") == 0 | strpos(txt, "tds") == 0 | strpos(txt, "gis") == 0) return(0)
    if (strpos(txt, "total") == 0 | strpos(txt, "payment") == 0) return(0)
    if (strpos(txt, "signature") == 0) return(0)
    return(1)
}

real scalar smartload_pdf_wh_template(string scalar txtfile)
{
    string scalar txt

    txt = strlower(smartload_readfile(txtfile))
    if (strpos(txt, "weight/height record") == 0 & strpos(txt, "weight height record") == 0) return(0)
    if (strpos(txt, "consumer name") == 0) return(0)
    if (strpos(txt, "date") == 0 | strpos(txt, "year") == 0) return(0)
    if (strpos(txt, "month") == 0 | strpos(txt, "day") == 0) return(0)
    if (strpos(txt, "weight") == 0 | strpos(txt, "height") == 0) return(0)
    return(1)
}

real scalar smartload_pdf_honors_template(string scalar txtfile)
{
    string scalar txt

    txt = smartload_readfile(txtfile)
    if (strpos(txt, "全国红十字志愿服务先进典型名单") == 0) return(0)
    if (strpos(txt, "（女）") == 0) return(0)
    if (strpos(txt, "志愿") == 0) return(0)
    return(1)
}

real scalar smartload_pdf_wide_gap(string scalar line)
{
    real scalar i, spaces, n
    string scalar ch

    spaces = 0
    n = strlen(line)
    for (i=1; i<=n; i++) {
        ch = substr(line, i, 1)
        if (ch == " " | ch == char(9)) spaces++
        else {
            if (spaces >= 4) return(i)
            spaces = 0
        }
    }
    return(0)
}

void smartload_pdf_honors_to_csv(string scalar txtfile, string scalar csvfile)
{
    real scalar fh, sep, current
    string scalar line, trimmed, compact, region, name, capacity
    string rowvector headers
    string matrix out

    headers = ("region", "name", "capacity")
    out = J(0, 3, "")
    region = ""
    current = 0
    fh = fopen(txtfile, "r")
    if (fh < 0) _error(601)
    while ((line = fget(fh)) != J(0,0,"")) {
        line = subinstr(subinstr(line, char(13), "", .), char(10), "", .)
        trimmed = strtrim(line)
        if (trimmed == "") continue
        sep = smartload_pdf_wide_gap(line)

        if (sep >= 13) {
            if (strtrim(smartload_pdf_piece(line, 1, 12)) == "") {
                if (current > 0) out[current,3] = smartload_pdf_add(out[current,3], substr(line, sep, .))
                continue
            }
            name = strtrim(substr(line, 1, sep-1))
            capacity = strtrim(substr(line, sep, .))
            if (region == "" | name == "" | capacity == "") continue
            name = subinstr(name, " ", "", .)
            out = out \ (region, name, capacity)
            current = rows(out)
            continue
        }

        compact = subinstr(trimmed, " ", "", .)
        if (ustrlen(compact) >= 2 & ustrlen(compact) <= 4) {
            region = compact
            current = 0
        }
    }
    fclose(fh)
    if (rows(out) == 0) _error(498)
    smartload_write_csv(headers \ out, csvfile)
}

real scalar smartload_pdf_q_template(string scalar txtfile)
{
    string scalar txt

    txt = strlower(smartload_readfile(txtfile))
    if (strpos(txt, "patient health questionnaire") == 0) return(0)
    if (strpos(txt, "phq-9") == 0 | strpos(txt, "gad-7") == 0) return(0)
    if (strpos(txt, "little interest or pleasure") == 0) return(0)
    if (strpos(txt, "feeling nervous, anxious") == 0) return(0)
    return(1)
}

void smartload_pdf_q_to_csv(string scalar txtfile, string scalar csvfile)
{
    real scalar fh, current, item
    string scalar line, trimmed, lower, instrument, token, piece
    string rowvector words, headers
    string matrix out

    headers = ("instrument", "item", "question", "score_0_label", "score_1_label", "score_2_label", "score_3_label")
    out = J(0, 7, "")
    current = 0
    instrument = ""
    fh = fopen(txtfile, "r")
    if (fh < 0) _error(601)
    while ((line = fget(fh)) != J(0,0,"")) {
        line = subinstr(subinstr(line, char(13), "", .), char(10), "", .)
        trimmed = strtrim(line)
        lower = strlower(trimmed)
        if (trimmed == "PHQ-9" | trimmed == "GAD-7") {
            instrument = trimmed
            current = 0
            continue
        }
        if (instrument == "") continue
        if (strpos(lower, "add the score") > 0 | strpos(lower, "total score") > 0 | strpos(lower, "if you checked") == 1) {
            current = 0
            continue
        }
        words = tokens(trimmed)
        if (cols(words) > 0) {
            token = words[1]
            if (strlen(token) >= 2 & substr(token, strlen(token), 1) == ".") {
                item = strtoreal(substr(token, 1, strlen(token)-1))
                if (item < . & item >= 1 & item <= 9) {
                    out = out \ J(1, 7, "")
                    current = rows(out)
                    out[current,1] = instrument
                    out[current,2] = strofreal(item)
                    piece = strtrim(smartload_pdf_piece(line, 1, 66))
                    if (strpos(piece, token) == 1) piece = strtrim(substr(piece, strlen(token)+1, .))
                    out[current,3] = piece
                    out[current,4] = "Not at all"
                    out[current,5] = "Several days"
                    out[current,6] = "More than half the days"
                    out[current,7] = "Nearly every day"
                    continue
                }
            }
        }
        if (current > 0) {
            piece = strtrim(smartload_pdf_piece(line, 1, 66))
            if (piece != "" & piece != "0 1 2 3") out[current,3] = smartload_pdf_add(out[current,3], piece)
        }
    }
    fclose(fh)
    if (rows(out) != 16) _error(498)
    smartload_write_csv(headers \ out, csvfile)
}

real scalar smartload_pdf_sample_number(string scalar line)
{
    string scalar trimmed, token
    string rowvector words
    real scalar n

    trimmed = strtrim(line)
    words = tokens(trimmed)
    if (cols(words) < 2) return(0)
    if (words[1] != "Table") return(0)
    token = subinstr(words[2], ":", "", .)
    n = strtoreal(token)
    if (n >= 1 & n < .) return(n)
    return(0)
}

real scalar smartload_pdf_samples_count(string scalar txtfile)
{
    real scalar fh, n, found, maximum
    string scalar line

    fh = fopen(txtfile, "r")
    if (fh < 0) return(0)
    found = 0
    maximum = 0
    while ((line = fget(fh)) != J(0,0,"")) {
        n = smartload_pdf_sample_number(line)
        if (n > 0) {
            found++
            if (n > maximum) maximum = n
        }
    }
    fclose(fh)
    if (found < 2 | maximum != found) return(0)
    return(found)
}

string scalar smartload_pdf_samples_title(string scalar txtfile, real scalar wanted)
{
    real scalar fh
    string scalar line

    fh = fopen(txtfile, "r")
    if (fh < 0) return("")
    while ((line = fget(fh)) != J(0,0,"")) {
        if (smartload_pdf_sample_number(line) == wanted) {
            fclose(fh)
            return(strtrim(line))
        }
    }
    fclose(fh)
    return("")
}

void smartload_pdf_samples_extract(string scalar txtfile, real scalar wanted, string scalar outfile)
{
    real scalar fin, fout, n, active
    string scalar line

    fin = fopen(txtfile, "r")
    if (fin < 0) _error(601)
    fout = fopen(outfile, "w")
    if (fout < 0) {
        fclose(fin)
        _error(603)
    }
    active = 0
    while ((line = fget(fin)) != J(0,0,"")) {
        n = smartload_pdf_sample_number(line)
        if (n > 0) {
            if (active) break
            if (n == wanted) active = 1
            continue
        }
        if (active) fput(fout, line)
    }
    fclose(fin)
    fclose(fout)
    if (!active) _error(498)
}

real scalar smartload_pdf_disposal_template(string scalar txtfile)
{
    string scalar txt

    txt = strlower(smartload_readfile(txtfile))
    if (strpos(txt, "disposal schedule") == 0) return(0)
    if (strpos(txt, "record type") == 0) return(0)
    if (strpos(txt, "minimum retention period") == 0) return(0)
    if (strpos(txt, "relevant legislation") == 0) return(0)
    if (strpos(txt, "final action") == 0) return(0)
    return(1)
}

real scalar smartload_pdf_ref_token(string scalar token)
{
    real scalar i, n
    string scalar ch

    n = strlen(token)
    if (n < 2) return(0)
    ch = substr(token, 1, 1)
    if (ch < "A" | ch > "Z") return(0)
    for (i=2; i<=n; i++) {
        ch = substr(token, i, 1)
        if (ch < "0" | ch > "9") return(0)
    }
    return(1)
}

string scalar smartload_pdf_piece(string scalar line, real scalar start, real scalar width)
{
    if (start > strlen(line)) return("")
    return(strtrim(substr(line, start, min((width, strlen(line)-start+1)))))
}

string scalar smartload_pdf_add(string scalar old, string scalar piece)
{
    piece = strtrim(piece)
    if (piece == "") return(old)
    if (old == "") return(piece)
    return(old + " " + piece)
}

real scalar smartload_pdf_retention_pos(string scalar text)
{
    string rowvector words
    real scalar i, p

    words = tokens(text)
    for (i=1; i<cols(words); i++) {
        if (strtoreal(words[i]) < .) {
            if (strpos(strlower(words[i+1]), "year") == 1 | strpos(strlower(words[i+1]), "month") == 1) {
                p = strpos(text, words[i] + " " + words[i+1])
                if (p > 0) return(p)
            }
        }
    }
    return(0)
}

void smartload_pdf_disposal_to_csv(string scalar txtfile, string scalar csvfile)
{
    real scalar fh, current, p, i
    string scalar line, lower, trimmed, section, ref, rec, retention, legislation, action
    string rowvector words, headers
    string matrix out

    headers = ("section", "ref", "record_type", "minimum_retention_period", "relevant_legislation", "final_action")
    out = J(0, 6, "")
    current = 0
    section = ""
    fh = fopen(txtfile, "r")
    if (fh < 0) _error(601)

    while ((line = fget(fh)) != J(0,0,"")) {
        line = subinstr(subinstr(line, char(13), "", .), char(10), "", .)
        trimmed = strtrim(line)
        lower = strlower(trimmed)
        if (trimmed == "") continue
        if (strpos(lower, "disposal schedule") == 1) continue
        if (strlen(trimmed) <= 4 & strtoreal(trimmed) < .) continue
        if (strpos(lower, "record type") > 0 & strpos(lower, "minimum retention period") > 0) continue
        if (lower == "derivation" | lower == "relevant legislation / derivation") continue

        if (strlen(trimmed) >= 3 & substr(trimmed, 2, 2) == ". ") {
            if (substr(trimmed, 1, 1) >= "A" & substr(trimmed, 1, 1) <= "Z") {
                section = trimmed
                current = 0
                continue
            }
        }

        words = tokens(line)
        if (cols(words) > 0 & substr(line, 1, 1) != " " & smartload_pdf_ref_token(words[1])) {
            ref = words[1]
            out = out \ J(1, 6, "")
            current = rows(out)
            out[current,1] = section
            out[current,2] = ref
            line = substr("        ", 1, strlen(ref)) + substr(line, strlen(ref)+1, .)
        }
        else if (current == 0) continue

        rec = smartload_pdf_piece(line, 4, 34)
        retention = smartload_pdf_piece(line, 38, 65)
        legislation = smartload_pdf_piece(line, 103, 41)
        action = smartload_pdf_piece(line, 144, 80)
        out[current,3] = smartload_pdf_add(out[current,3], rec)
        out[current,4] = smartload_pdf_add(out[current,4], retention)
        out[current,5] = smartload_pdf_add(out[current,5], legislation)
        out[current,6] = smartload_pdf_add(out[current,6], action)
    }
    fclose(fh)
    if (rows(out) == 0) _error(498)

    for (i=1; i<=rows(out); i++) {
        p = smartload_pdf_retention_pos(out[i,3])
        if (p > 0) {
            out[i,4] = smartload_pdf_add(substr(out[i,3], p, .), out[i,4])
            out[i,3] = strtrim(substr(out[i,3], 1, p-1))
        }
    }
    smartload_write_csv(headers \ out, csvfile)
}

real rowvector smartload_pdf_starts(string scalar s)
{
    real scalar i, n, spaces
    real rowvector starts
    string scalar ch

    starts = J(1, 0, .)
    spaces = 1
    n = strlen(s)
    for (i=1; i<=n; i++) {
        ch = substr(s, i, 1)
        if (ch == " " | ch == char(9)) spaces++
        else {
            if (spaces >= 1) starts = starts, i
            spaces = 0
        }
    }
    return(starts)
}

real rowvector smartload_pdf_gap_starts(string scalar s)
{
    real scalar i, n, spaces
    real rowvector starts
    string scalar ch

    starts = J(1, 0, .)
    spaces = 2
    n = strlen(s)
    for (i=1; i<=n; i++) {
        ch = substr(s, i, 1)
        if (ch == " " | ch == char(9)) spaces++
        else {
            if (spaces >= 2) starts = starts, i
            spaces = 0
        }
    }
    return(starts)
}

string rowvector smartload_pdf_chunks(string scalar s, real rowvector starts)
{
    real scalar j, width, n
    string rowvector out

    n = cols(starts)
    out = J(1, n, "")
    for (j=1; j<=n; j++) {
        if (j < n) width = starts[j+1] - starts[j]
        else width = max((0, strlen(s) - starts[j] + 1))
        if (width > 0 & starts[j] <= strlen(s))
            out[j] = strtrim(substr(s, starts[j], width))
    }
    return(out)
}

real scalar smartload_pdf_chunk_count(string rowvector chunks)
{
    real scalar j, n
    n = 0
    for (j=1; j<=cols(chunks); j++) n = n + (chunks[j] != "")
    return(n)
}

real scalar smartload_pdf_compact_column(string scalar header)
{
    header = strlower(header)
    if (strpos(header, "date") | strpos(header, "_id") | header == "id") return(1)
    if (strpos(header, "code") | strpos(header, "_no") | strpos(header, "line")) return(1)
    if (strpos(header, "inspector") | strpos(header, "supplier")) return(1)
    if (strpos(header, "sample_n") | strpos(header, "defect_n") | strpos(header, "defect_pct")) return(1)
    if (header == "measure" | header == "tolerance") return(1)
    return(0)
}

string scalar smartload_pdf_join(string scalar old, string scalar fragment, string scalar header)
{
    string rowvector words, stopwords
    string scalar first, rest, lastword
    real scalar merge

    old = strtrim(old)
    fragment = strtrim(fragment)
    if (fragment == "") return(old)
    if (old == "") return(fragment)
    if (smartload_pdf_compact_column(header))
        return(subinstr(old + fragment, " ", "", .))

    words = tokens(fragment)
    first = words[1]
    rest = strtrim(substr(fragment, strlen(first) + 1, .))
    if (rest != "") rest = " " + rest
    words = tokens(old)
    lastword = words[cols(words)]
    merge = 0
    if (substr(old, strlen(old), 1) == "-") merge = 1
    else if (strlen(first) == 1 & first == strlower(first) & strlen(lastword) >= 4) merge = 1
    else if (strlen(first) <= 3 & first == strlower(first) & strlen(lastword) >= 6) {
        stopwords = ("of", "in", "on", "at", "to", "and", "for", "out", "the", "a", "an")
        if (!anyof(stopwords, first)) merge = 1
    }
    if (merge) return(old + first + rest)
    return(old + " " + fragment)
}

void smartload_pdf_table_to_csv(string scalar txtfile, string scalar csvfile)
{
    real scalar fh, i, j, best, headerline, dataline, threshold, nonempty, current, leftmost
    string scalar line
    string colvector lines
    real rowvector starts, candidate
    string rowvector chunks, headers
    string matrix out

    lines = J(0, 1, "")
    fh = fopen(txtfile, "r")
    if (fh < 0) _error(601)
    while ((line = fget(fh)) != J(0,0,"")) {
        line = subinstr(subinstr(line, char(13), "", .), char(10), "", .)
        lines = lines \ line
    }
    fclose(fh)
    if (rows(lines) < 2) _error(498)

    leftmost = .
    for (i=1; i<=rows(lines); i++) {
        candidate = smartload_pdf_starts(lines[i])
        if (cols(candidate) > 0) {
            if (missing(leftmost) | candidate[1] < leftmost) leftmost = candidate[1]
        }
    }
    if (missing(leftmost)) _error(498)

    best = 0
    headerline = 0
    starts = J(1, 0, .)
    for (i=1; i<=rows(lines); i++) {
        candidate = smartload_pdf_starts(lines[i])
        if (cols(candidate) >= 3) {
            if (candidate[1] == leftmost) {
                best = cols(candidate)
                headerline = i
                starts = candidate
                break
            }
        }
    }
    if (best < 3 | headerline == 0) _error(498)

    threshold = max((3, ceil(best/2)))
    dataline = 0
    for (i=headerline+1; i<=rows(lines); i++) {
        chunks = smartload_pdf_chunks(lines[i], starts)
        if (smartload_pdf_chunk_count(chunks) >= threshold) {
            dataline = i
            break
        }
    }
    if (dataline == 0) _error(498)

    headers = smartload_pdf_chunks(lines[headerline], starts)
    for (i=headerline+1; i<dataline; i++) {
        chunks = smartload_pdf_chunks(lines[i], starts)
        for (j=1; j<=best; j++) if (chunks[j] != "") headers[j] = headers[j] + chunks[j]
    }
    for (j=1; j<=best; j++) {
        headers[j] = strlower(strtrim(headers[j]))
        headers[j] = subinstr(headers[j], " ", "_", .)
        if (headers[j] == "") headers[j] = "v" + strofreal(j)
    }

    out = headers
    current = 0
    for (i=dataline; i<=rows(lines); i++) {
        chunks = smartload_pdf_chunks(lines[i], starts)
        nonempty = smartload_pdf_chunk_count(chunks)
        if (nonempty == 0) continue
        if (nonempty >= threshold) {
            out = out \ J(1, best, "")
            current = rows(out)
        }
        else if (current == 0) continue
        for (j=1; j<=best; j++) {
            if (chunks[j] != "") {
                out[current,j] = smartload_pdf_join(out[current,j], chunks[j], headers[j])
            }
        }
    }
    if (rows(out) < 2) _error(498)
    smartload_write_csv(out, csvfile)
}

void smartload_pdf_simple_to_csv(string scalar txtfile, string scalar csvfile)
{
    real scalar fh, i, j, headerline, best, threshold, current, nonempty
    string scalar line
    string colvector lines
    real rowvector starts, candidate
    string rowvector chunks, headers
    string matrix out

    lines = J(0, 1, "")
    fh = fopen(txtfile, "r")
    if (fh < 0) _error(601)
    while ((line = fget(fh)) != J(0,0,"")) {
        line = subinstr(subinstr(line, char(13), "", .), char(10), "", .)
        lines = lines \ line
    }
    fclose(fh)

    headerline = 0
    best = 0
    starts = J(1, 0, .)
    for (i=1; i<=rows(lines); i++) {
        candidate = smartload_pdf_gap_starts(lines[i])
        if (cols(candidate) >= 2) {
            headerline = i
            best = cols(candidate)
            starts = candidate
            break
        }
    }
    if (headerline == 0 | best < 2) _error(498)

    headers = smartload_pdf_chunks(lines[headerline], starts)
    for (j=1; j<=best; j++) {
        headers[j] = strlower(strtrim(headers[j]))
        headers[j] = subinstr(headers[j], " ", "_", .)
        headers[j] = subinstr(headers[j], "(", "", .)
        headers[j] = subinstr(headers[j], ")", "", .)
        if (headers[j] == "") headers[j] = "v" + strofreal(j)
    }

    out = headers
    current = 0
    threshold = max((2, ceil(best/2)))
    for (i=headerline+1; i<=rows(lines); i++) {
        chunks = smartload_pdf_chunks(lines[i], starts)
        nonempty = smartload_pdf_chunk_count(chunks)
        if (nonempty == 0) continue
        if (nonempty >= threshold) {
            out = out \ J(1, best, "")
            current = rows(out)
        }
        else if (current == 0) continue
        for (j=1; j<=best; j++) {
            if (chunks[j] != "") out[current,j] = smartload_pdf_add(out[current,j], chunks[j])
        }
    }
    if (rows(out) < 2) _error(498)
    smartload_write_csv(out, csvfile)
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

void smartload_office_collect(string scalar xmlfiles, string scalar ext, real scalar wanted, string matrix rows, real scalar maxc)
{
    string rowvector files, cells
    string scalar xml, prefix, tblopen, tblclose, rowopen, rowclose, tbl, row
    real scalar f, p, gt, q, rp, rgt, rq, count

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
                    if (cols(cells) > 0) {
                        if (cols(cells) > maxc) maxc = cols(cells)
                        if (cols(rows) == 0) rows = cells
                        else {
                            if (cols(cells) < cols(rows)) cells = cells, J(1, cols(rows)-cols(cells), "")
                            if (cols(cells) > cols(rows)) rows = rows, J(rows(rows), cols(cells)-cols(rows), "")
                            rows = rows \ cells
                        }
                    }
                    rp = rq + strlen(rowclose)
                }
                if (cols(rows) < maxc) rows = rows, J(rows(rows), maxc-cols(rows), "")
                return
            }
            p = q + strlen(tblclose)
        }
    }
}

string scalar smartload_office_table_preview(string scalar xmlfiles, string scalar ext, real scalar wanted)
{
    string matrix rows
    string scalar preview
    real scalar maxc, j

    smartload_office_collect(xmlfiles, ext, wanted, rows, maxc)
    if (rows(rows) == 0 | maxc == 0) return("(no readable cell text)")
    preview = ""
    for (j=1; j<=min((3, cols(rows))); j++) {
        if (rows[1,j] != "") {
            if (preview != "") preview = preview + " | "
            preview = preview + rows[1,j]
        }
    }
    if (preview == "") preview = "(blank first row)"
    return(strofreal(rows(rows)) + " rows, " + strofreal(maxc) + " columns; " + preview)
}

void smartload_office_table_to_csv(string scalar xmlfiles, string scalar ext, real scalar wanted, string scalar csvfile)
{
    string matrix rows
    real scalar maxc

    smartload_office_collect(xmlfiles, ext, wanted, rows, maxc)
    if (rows(rows) == 0 | maxc == 0) {
        errprintf("Selected Office table has no readable text cells.\n")
        _error(498)
    }
    smartload_write_csv(rows, csvfile)
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

end
