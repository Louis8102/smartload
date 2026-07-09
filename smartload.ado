program define smartload, rclass
    syntax anything(name=fname id="file name") [, SEARCH(string) DRIVES(string) ///
        CLEAR SHEET(string) FIRSTROW ENCODING(string) TABLE(string) ///
        OBJECT(string) LAYER(string) MEMBER(string) SLIDE(integer -1) ///
        TABLEINDEX(integer -1) DOCTABLE(integer -1) PDFTABLE(integer -1) ///
        PPTTABLE(integer -1) CLOUD(string) CLOUDROOT(string) FORCE ///
        EXHAUSTIVE NONETWORK OCR LOG REPLACE]

    loc filename `"`fname'"'
    local filename = subinstr(`"`filename'"', char(34), "", .)
    mata: st_local("filename", pathbasename(st_local("filename")))
    if `"`filename'"' == "" {
        di as err "Please specify a file name."
        exit 198
    }

    if `"`search'"' == "" & `"`drives'"' == "" & `"`cloudroot'"' == "" & `"`cloud'"' == "" {
        loc drives "all"
        if "`force'" == "" {
            di as err "No search location was specified, so smartload will default to all available drives."
            di as err "This may take a long time."
            di as txt "To continue, rerun the command with option force."
            di as txt `"Example: smartload `filename', force clear"'
            exit 498
        }
    }

    cap which filelist
    if _rc {
        di as err "The command filelist is required. Please install it first:"
        di as txt "ssc install filelist"
        exit 499
    }

    if lower(strtrim(`"`drives'"')) == "all" & "`force'" == "" {
        di as err "You requested a search across all available drives."
        di as err "This may take a long time."
        di as txt "To continue, rerun the command with option force."
        di as txt `"Example: smartload `filename', force clear"'
        exit 498
    }

    loc cmdline `"smartload `filename'"'
    loc logrequested = "`log'" != ""
    loc logfile "smartload_log.txt"
    tempname lh
    if `logrequested' {
        if "`replace'" != "" file open `lh' using "`logfile'", write text replace
        else file open `lh' using "`logfile'", write text append
        file write `lh' "Command: `cmdline'" _n
        file write `lh' "Date/time: `c(current_date)' `c(current_time)'" _n
    }

    tempfile found one
    tempname posth
    postfile `posth' str2045 filepath str2045 root str20 storage using "`found'", replace

    if `logrequested' file write `lh' "Explicit search roots:" _n
    if `"`search'"' != "" {
        global SMARTLOAD_ROOTS "`search'"
        smartload__searchroots, filename("`filename'") post(`posth') storage(local) loghandle(`lh') log(`logrequested')
    }

    loc drives_l = lower(strtrim(`"`drives'"'))
    if `"`drives_l'"' != "" {
        if `logrequested' file write `lh' "Drives requested: `drives'" _n
        if "`drives_l'" == "all" {
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
            loc root "`d':\"
            mata: st_local("direx", strofreal(direxists(st_local("root"))))
            if "`direx'" != "1" {
                if `logrequested' file write `lh' "Unavailable drive skipped: `root'" _n
                continue
            }
            if "`nonetwork'" != "" {
                cap noi shell net use `d':
                if !_rc {
                    if `logrequested' file write `lh' "Drive skipped by nonetwork: `root'" _n
                    continue
                }
            }
            global SMARTLOAD_ROOT "`root'"
            smartload__searchone, filename("`filename'") post(`posth') storage(local) loghandle(`lh') log(`logrequested')
        }
    }

    if `logrequested' file write `lh' "Cloud roots searched:" _n
    if `"`cloudroot'"' != "" {
        global SMARTLOAD_ROOTS "`cloudroot'"
        smartload__searchroots, filename("`filename'") post(`posth') storage(cloud_synced) loghandle(`lh') log(`logrequested')
    }

    if `"`cloud'"' != "" {
        loc providers = lower(`"`cloud'"')
        loc home "C:\Users\`c(username)'"
        loc cands `"`home'\Dropbox;`home'\OneDrive;`home'\Google Drive;`home'\My Drive;`home'\Box"'
        global SMARTLOAD_ROOTS "`cands'"
        smartload__searchroots, filename("`filename'") post(`posth') storage(cloud_synced) loghandle(`lh') log(`logrequested')
    }

    postclose `posth'
    cap macro drop SMARTLOAD_ROOT
    cap macro drop SMARTLOAD_ROOTS

    preserve
    qui use "`found'", clear
    qui count
    if r(N) == 0 {
        restore
        di as err "No file named `filename' was found under the requested search locations."
        di as txt "Please check the file name or specify a different search(), drives(), cloudroot(), or cloud() option."
        if `logrequested' {
            file write `lh' "Result: failure - no match" _n _n
            file close `lh'
        }
        exit 601
    }
    qui duplicates drop filepath, force
    qui count
    if r(N) > 0 & "`exhaustive'" == "" {
        gen str2045 __smartload_path_l = lower(filepath)
        qui drop if strpos(__smartload_path_l, "\windows\") | ///
            strpos(__smartload_path_l, "\program files\") | ///
            strpos(__smartload_path_l, "\program files (x86)\") | ///
            strpos(__smartload_path_l, "\programdata\") | ///
            strpos(__smartload_path_l, "\$recycle.bin\") | ///
            strpos(__smartload_path_l, "\system volume information\") | ///
            strpos(__smartload_path_l, "\recovery\") | ///
            strpos(__smartload_path_l, "\appdata\local\temp\")
        drop __smartload_path_l
    }
    qui count
    loc nmatch = r(N)
    if `nmatch' == 0 {
        restore
        di as err "No file named `filename' was found under the requested search locations."
        di as txt "Please check the file name or specify a different search(), drives(), cloudroot(), or cloud() option."
        if `logrequested' {
            file write `lh' "Result: failure - no match" _n _n
            file close `lh'
        }
        exit 601
    }
    if `nmatch' > 1 {
        di as err "Found multiple files named `filename':"
        forvalues i = 1/`nmatch' {
            loc p = filepath[`i']
            di as txt "`i'. `p'"
        }
        di as err "File name is not unique. Please rerun smartload with a more specific search(), drives(), cloudroot(), member(), sheet(), table(), object(), layer(), slide(), or tableindex() option."
        if `logrequested' {
            file write `lh' "Result: failure - multiple matches" _n _n
            file close `lh'
        }
        restore
        exit 459
    }
    loc filepath = filepath[1]
    loc storage = storage[1]
    restore
    loc loadpath = subinstr(`"`filepath'"', char(92), "/", .)

    mata: st_local("ext", strlower(pathsuffix(st_local("filepath"))))
    loc ext : subinstr loc ext "." "", all
    loc sourcekind "native"
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
            di as err "Detected .dat file, but it could not be imported as a delimited rectangular text dataset."
            di as err ".dat is a generic extension and may require user-specified parsing rules."
            return local filepath `"`filepath'"'
            return local filename `"`filename'"'
            return local extension "`ext'"
            return local status "detected_not_imported"
            if `logrequested' {
                file write `lh' "Result: detected_not_imported - .dat import failed" _n _n
                file close `lh'
            }
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
    return local sourcekind "`sourcekind'"
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

program define smartload__searchroots
    syntax , FILENAME(string) POST(string) STORAGE(string) LOGHANDLE(string) LOG(integer)
    local filename = subinstr(`"`filename'"', char(34), "", .)
    loc rest "$SMARTLOAD_ROOTS"
    local rest = subinstr(`"`rest'"', char(34), "", .)
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
        local root = subinstr(`"`root'"', char(34), "", .)
        if `"`root'"' == "" continue
        global SMARTLOAD_ROOT "`root'"
        smartload__searchone, filename("`filename'") post(`post') storage(`storage') loghandle(`loghandle') log(`log')
    }
end

program define smartload__searchone
    syntax , FILENAME(string) POST(string) STORAGE(string) LOGHANDLE(string) LOG(integer)
    loc root "$SMARTLOAD_ROOT"
    loc posth "`post'"
    loc lh "`loghandle'"
    loc logrequested "`log'"
    local root = subinstr(`"`root'"', char(34), "", .)
    local filename = subinstr(`"`filename'"', char(34), "", .)
    mata: st_local("direx", strofreal(direxists(st_local("root"))))
    if "`direx'" != "1" {
        if "`logrequested'" == "1" file write `lh' "Skipped missing root: `root'" _n
        exit
    }
    if "`logrequested'" == "1" file write `lh' "  `root'" _n
    tempfile fl
    cap qui filelist, directory(`"`root'"') pattern(`"`filename'"') save(`"`fl'"') replace
    if _rc {
        di as err `"Could not search `root' with filelist. Root skipped."'
        if "`logrequested'" == "1" file write `lh' "Search failed: `root'" _n
        exit
    }
    preserve
    cap qui use "`fl'", clear
    if _rc {
        restore
        exit
    }
    cap confirm var filename
    if _rc {
        restore
        exit
    }
    qui keep if filename == `"`filename'"'
    cap confirm var dirname
    if _rc {
        gen strL dirname = `"`root'"'
    }
    qui count
    if r(N) == 0 {
        restore
        exit
    }
    forvalues i = 1/`r(N)' {
        loc d = dirname[`i']
        loc f = filename[`i']
        mata: st_local("full", pathjoin(st_local("d"), st_local("f")))
        post `posth' (`"`full'"') (`"`root'"') ("`storage'")
    }
    restore
end

program define smartload__detected, rclass
    args filepath filename ext lh logrequested ocr
    loc kind "unsupported"
    if inlist("`ext'", "pdf") loc kind "PDF/document-table"
    else if inlist("`ext'", "docx", "doc") loc kind "Word/document-table"
    else if inlist("`ext'", "pptx", "ppt") loc kind "PowerPoint/presentation-table"
    else if inlist("`ext'", "zip", "gz", "7z", "tar") loc kind "archive"
    else if inlist("`ext'", "sqlite", "db", "duckdb", "accdb", "mdb", "sql") loc kind "database"
    else if inlist("`ext'", "shp", "geojson", "gpkg", "kml", "kmz", "gdb") loc kind "GIS"
    else if inlist("`ext'", "rds", "rdata", "r") loc kind "R"
    else if inlist("`ext'", "parquet", "feather", "pkl", "pickle", "arrow", "h5", "hdf5", "json", "jsonl") loc kind "Python/data-science"
    di as txt "Detected `kind' file: .`ext'"
    if inlist("`ext'", "pdf") {
        di as err "PDF files are document files, not ordinary Stata datasets."
        di as txt "smartload does not import PDF tables in the current version unless a tested external extraction engine is added."
        di as txt "This includes PDFs that visually contain Excel-like tables."
        if "`ocr'" == "" {
            di as txt "Scanned or image-based PDFs require OCR and are not imported automatically."
        }
    }
    else if inlist("`ext'", "docx", "doc") {
        di as err "Word files require table extraction before Stata can import them."
        di as txt "Current version detects this file but does not claim a successful table import."
    }
    else if inlist("`ext'", "pptx", "ppt") {
        di as err "PowerPoint files require extraction of real table objects before Stata can import them."
        di as txt "Images, screenshots, charts, and table-like pictures are not treated as reliable tables."
    }
    else if inlist("`ext'", "zip", "gz", "7z", "tar") {
        di as err "Archive inspection/extraction is reserved for a tested conversion path."
        di as txt "No files were extracted."
    }
    else if inlist("`ext'", "sqlite", "db", "duckdb", "accdb", "mdb", "sql") {
        di as err "Database files require table inspection through ODBC, Python, R, or another tested bridge."
        if "`ext'" == "sql" di as txt ".sql is usually a script or dump, not a rectangular dataset."
    }
    else if inlist("`ext'", "shp", "geojson", "gpkg", "kml", "kmz", "gdb") {
        di as err "GIS files require a tested GIS conversion workflow before import."
        if "`ext'" == "shp" di as txt "A shapefile also requires companion files such as .shx and .dbf."
    }
    else if inlist("`ext'", "rds", "rdata", "r") {
        di as err "R data files require R/Rscript conversion before Stata can import them."
    }
    else if inlist("`ext'", "parquet", "feather", "pkl", "pickle", "arrow", "h5", "hdf5", "json", "jsonl") {
        di as err "Python/data-science files require inspected conversion before Stata can import them."
        if inlist("`ext'", "pkl", "pickle") di as txt "Pickle files are not imported automatically because they may be unsafe and may not contain rectangular data."
    }
    else {
        di as err "This file type is not safely importable by smartload."
    }
    if "`logrequested'" == "1" {
        file write `lh' "Result: detected_not_imported" _n _n
        file close `lh'
    }
end
