*! smartload 0.3.3 10jul2026 Hao Ma
program define smartload, rclass
    version 19.5
    syntax [anything(name=fname id="file name")] [, SETUP INSTALLES REFRESH ROOTS(string) ///
        DRIVES(string) CHOICE(integer -1) CLEAR SHEET(string) FIRSTROW ///
        ENCODING(string) OCR LOG REPLACE MAXDIRS(integer 2500)]

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
    local filename = subinstr(`"`filename'"', char(34), "", .)
    mata: st_local("filename", pathbasename(st_local("filename")))
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
    smartload__everything, filename(`"`filename'"') saving(`"`sysmatches'"')
    loc sysN = r(N)

    preserve
    if `sysN' > 0 {
        qui use `"`sysmatches'"', clear
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
    restore

    loc loadpath = subinstr(`"`filepath'"', char(92), "/", .)
    mata: st_local("ext", strlower(pathsuffix(st_local("filepath"))))
    loc ext : subinstr loc ext "." "", all
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
        if `"`encoding'"' != "" loc opts `"`opts' encoding(`"`encoding'"')"'
        if "`clear'" != "" loc opts "`opts' clear"
        if `"`opts'"' != "" import delimited `"`loadpath'"', `opts'
        else import delimited `"`loadpath'"'
        loc importcmd "import delimited"
    }
    else if "`ext'" == "tsv" {
        loc opts "delimiters(tab)"
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
        if "`clear'" != "" import sasxport using "`loadpath'", clear
        else import sasxport using "`loadpath'"
        loc importcmd "import sasxport"
    }
    else if "`ext'" == "parquet" {
        if "`clear'" != "" import parquet using "`loadpath'", clear
        else import parquet using "`loadpath'"
        loc importcmd "import parquet"
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
    else if inlist("`ext'", "sas7bdat", "xpt") loc typename "SAS data file"
    else if "`ext'" == "parquet" loc typename "Parquet data file"
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
                mata: st_local("dir", pathdirname(st_local("p")))
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
                foreach ok in dta xlsx xls csv txt tsv dat sav por sas7bdat xpt parquet pdf docx doc pptx ppt rds rda rdata r feather pkl pickle arrow h5 hdf5 json jsonl sql sqlite db duckdb accdb mdb shp geojson gpkg kml kmz gdb zip gz 7z tar {
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
    syntax , FILENAME(string) SAVING(string) [ROOTS(string) MAXDIRS(integer 2500)]
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
                    post `posth' (`"`full'"') (`"`f'"') (`"`root'"') ("`target_ext'") ("fast")
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
                    post `posth' (`"`full'"') (`"`f'"') (`"`cur'"') ("`target_ext'") ("fast")
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

    di as txt "Fast search checked `visited' folders."
    return local matchfile `"`saving'"'
    return scalar N = `n'
    return scalar visited = `visited'
end

program define smartload__detected, rclass
    args filepath filename ext lh logrequested ocr
    loc kind "unsupported"
    if inlist("`ext'", "pdf") loc kind "PDF/document-table"
    else if inlist("`ext'", "docx", "doc") loc kind "Word/document-table"
    else if inlist("`ext'", "pptx", "ppt") loc kind "PowerPoint/presentation-table"
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
    else if inlist("`ext'", "docx", "doc", "pptx", "ppt", "pdf") {
        di as err "Document table extraction is not enabled in this version."
        di as txt "DOCX, PPTX, and PDF may contain tables, but they are document containers, not reliable rectangular data files."
    }
    else {
        di as err "This file type is detected but not safely importable by smartload in this version."
    }
    if "`logrequested'" == "1" {
        file write `lh' "Result: detected_not_imported" _n _n
        file close `lh'
    }
end
