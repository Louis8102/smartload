# smartload V0.1.1 Notes

`smartload` is an SSC-style Stata command for finding an exact file name under requested locations and importing it only when the current implementation can do so reliably.

## Installation

Important: V0.1 is **SSC-style**, but it is not yet an official SSC-hosted package unless and until it is submitted to and accepted by SSC. Do not tell users to run `ssc install smartload` until that happens.

### Install from GitHub

After uploading these files to the root of a GitHub repository named `smartload`, with `example_data/` as a subfolder, users can install from the raw GitHub URL:

```stata
ssc install filelist
net install smartload, from("https://raw.githubusercontent.com/Louis8102/smartload/main") replace
help smartload
```

This assumes the GitHub repository is `Louis8102/smartload` and the default branch is `main`.

The `filelist` package is required because V0.1 uses it for recursive file search.
Everything/ES is not required. If a user already has voidtools Everything and `es.exe`, `smartload` can use it as an optional speedup for whole-drive filename search.

Recommended GitHub repository layout:

```text
smartload/
  README.md
  LICENSE
  smartload.ado
  smartload.sthlp
  smartload.pkg
  stata.toc
  test_smartload.do
  example_data/
    smartload_example.dta
    smartload_example.csv
    smartload_example.xlsx
    smartload_example.dat
    smartload_example.sav
    smartload_example.sas7bdat
    smartload_example_manifest.dta
```

### If accepted by SSC in the future

Only after the package is officially hosted on SSC should users install with:

```stata
ssc install smartload
```

## Version record

- Module: `smartload`
- Version: V0.1.1
- Date: 2026-07-09
- Tested with: StataNow/MP 19.5 on Windows
- Required dependency: SSC `filelist`
- License: MIT
- Author: Hao Ma
- Distribution files: `smartload.ado`, `smartload.sthlp`, `smartload.pkg`, `stata.toc`, `test_smartload.do`, `LICENSE`, `example_data/`, and this README
- Version status: working baseline for native Stata-readable data files; conversion-heavy formats are detected but not imported

V0.1 is intentionally conservative. It imports only formats that were implemented and tested in Stata. It does not claim that PDF, Word, PowerPoint, archive, database, R, Python, or GIS files were imported unless a tested conversion path exists.

File naming note: `stata.toc` is the conventional Stata package-directory index used by `net from`. The actual package installation manifest is `smartload.pkg`.

## V0.1 syntax and examples

Basic syntax:

```stata
smartload filename [, options]
```

Default fast search. If no `search()`, `drives()`, `cloudroot()`, or `cloud()` option is supplied, V0.1 performs a fast indexed search instead of blindly crawling the whole disk. On Windows it tries, in order: optional Everything ES if already installed, Windows Search index, then common user data roots:

```stata
smartload Indicator.dta, clear
smartload city.sas7bdat, clear
smartload survey.sav, clear
smartload workbook.xlsx, firstrow clear
smartload mydata.csv, clear
```

Advanced: restrict search to a known location only when you deliberately want to narrow the result set:

```stata
smartload Indicator.dta, search("D:\Research") clear
smartload mydata.xlsx, search("D:\Research;E:\Data;F:\Backup") firstrow clear
```

Search selected drives:

```stata
smartload mydata.dta, drives(D E F) clear
smartload mydata.xlsx, drives(C D E F) firstrow clear
```

Explicit all-drive search. This still uses the fast indexed path:

```stata
smartload mydata.dta, drives(all) clear
smartload mydata.xlsx, drives(all) firstrow clear
smartload mydata.xlsx, drives(all) nonetwork firstrow clear
```

Excel options:

```stata
smartload workbook.xlsx, sheet("Sheet1") firstrow clear
smartload workbook.xls, firstrow clear
```

Delimited text options:

```stata
smartload survey.csv, clear
smartload survey.tsv, clear
smartload rawdata.dat, clear
smartload survey.csv, encoding("UTF-8") clear
```

Cloud-synced local folders:

```stata
smartload mydata.xlsx, cloud(dropbox onedrive gdrive box) firstrow clear
smartload mydata.xlsx, cloudroot("D:\Dropbox;C:\Users\YOURNAME\OneDrive") firstrow clear
```

Log output:

```stata
smartload mydata.xlsx, search("D:\Research") firstrow clear log replace
```

Recognized but not imported in V0.1:

```stata
smartload report.pdf, search("D:\Research") clear
smartload report.docx, search("D:\Research") clear
smartload slides.pptx, search("D:\Research") clear
smartload data.parquet, search("D:\Research") clear
```

PDF files that visually contain Excel-style tables are detected as PDF table-extraction cases. V0.1 does not pretend Stata can directly import them.

## Example data

The `example_data/` folder contains small files for testing the formats that V0.1 can actually import:

```text
smartload_example.dta
smartload_example.csv
smartload_example.xlsx
smartload_example.dat
smartload_example.sav
smartload_example.sas7bdat
smartload_example_manifest.dta
```

Example commands:

```stata
smartload smartload_example.dta, search("example_data") clear
smartload smartload_example.csv, search("example_data") clear
smartload smartload_example.xlsx, search("example_data") firstrow clear
smartload smartload_example.dat, search("example_data") clear
smartload smartload_example.sav, search("example_data") clear
smartload smartload_example.sas7bdat, search("example_data") clear
```

The `.sav` example is generated by Stata's `export spss`. The `.sas7bdat` example is copied from an existing local SAS sample file and is included only after confirming that it can be imported by `smartload`.

## Fully supported in V0.1

- Exact file-name search under `search()` roots, including semicolon-separated roots.
- Default fast indexed search when no `search()`, `drives()`, `cloudroot()`, or `cloud()` option is supplied.
- Optional Everything ES acceleration when already installed.
- Windows Search index fallback without requiring users to install Everything.
- Selected drive search with `drives(C D E F)` style syntax.
- `drives(all)` uses the fast indexed path rather than slow drive-wide recursion.
- Missing drive letters are skipped without error.
- Local synced-folder search through `cloudroot()` and common local cloud folders when `cloud()` is specified.
- Duplicate file detection across all searched locations. If the same file name is found more than once, `smartload` lists all matches and stops.
- Interactive duplicate-file selection: when multiple matches are found in interactive Stata, `smartload` lists the paths and asks the user to choose the file number to import.
- Native Stata-readable imports:
  - `.dta` through `use`
  - `.xlsx` and `.xls` through `import excel`
  - `.csv`, `.txt`, `.tsv`, and text-delimited `.dat` candidates through `import delimited`
  - `.sav` and `.por` through `import spss`
  - `.sas7bdat` through `import sas`
  - `.xpt` through `import sasxport`
- `r()` results after successful imports: `r(filepath)`, `r(filename)`, `r(extension)`, `r(importcmd)`, `r(storage)`, `r(sourcekind)`, `r(N)`, and `r(k)`.
- `r(status) = detected_not_imported` for recognized conversion-based formats that are detected but not imported.
- Optional `smartload_log.txt` logging with `log` and `replace`.

## Detected or reserved for future conversion support

These formats are recognized but not imported in V0.1 unless a tested external conversion path is added later:

- R: `.rds`, `.RData`, `.rdata`
- Python/data-science: `.parquet`, `.feather`, `.pkl`, `.pickle`, `.arrow`, `.h5`, `.hdf5`, `.json`, `.jsonl`
- SQL/database: `.sql`, `.sqlite`, `.db`, `.duckdb`, `.accdb`, `.mdb`
- GIS: `.shp`, `.geojson`, `.gpkg`, `.kml`, `.kmz`, `.gdb`
- Archives: `.zip`, `.gz`, `.7z`, `.tar`, `.tar.gz`
- Documents/presentations: `.pdf`, `.docx`, `.doc`, `.pptx`, `.ppt`

## Drive search behavior

`drives(C D E F)` checks each requested drive root before searching. Unavailable drives are skipped.

If no search location is supplied, `smartload` defaults to fast indexed search:

```stata
smartload mydata.xlsx, firstrow clear
```

`drives(all)` is the explicit form of the same broad search and still uses the fast indexed path:

```stata
smartload mydata.xlsx, drives(all) firstrow clear
```

For whole-drive search on Windows, `smartload` first tries voidtools Everything ES (`es.exe`) only when it can find it. Users do not need to install Everything to use `smartload`. If Everything is unavailable, `smartload` queries the built-in Windows Search index. If the index path is unavailable, it searches common user data locations: the current working directory, Desktop, Documents, Downloads, OneDrive, Dropbox, Google Drive/My Drive, and Box. It does not perform slow drive-wide recursion.

V0.1 filters out matches under obvious system folders such as `Windows`, `Program Files`, `ProgramData`, `$Recycle.Bin`, `System Volume Information`, `Recovery`, and `AppData\Local\Temp`.

`nonetwork` asks `smartload` to skip mapped network drives when detection is possible. Network-drive detection is best-effort and depends on Windows command behavior.

## Document and presentation table extraction

PDF, Word, and PowerPoint files are not rectangular Stata datasets. V0.1 detects them and stops honestly.

- PDF: includes PDFs that visually contain Excel-style tables. Stata cannot directly import those tables. Future support may use `pdfplumber`, `camelot`, `tabula-java`, or OCR when explicitly requested. OCR is not used by default.
- Word: future `.docx` support may use `python-docx` to detect zero, one, or multiple real Word table objects. Legacy `.doc` needs conversion first.
- PowerPoint: future `.pptx` support may use `python-pptx` to extract real PowerPoint table objects. Charts, screenshots, images of tables, videos, and decorative objects are not treated as reliable data tables. Legacy `.ppt` needs conversion first.

## Test file

Run `test_smartload.do` from the same folder as `smartload.ado` and `smartload.sthlp` in Stata MP 19.5:

```stata
do test_smartload.do
```

The test requires SSC `filelist`:

```stata
ssc install filelist
```
