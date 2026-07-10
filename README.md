# smartload V0.3.0 Notes

`smartload` is an SSC-style Stata command by Hao Ma. It loads a local data file by file name, without requiring the user to remember the folder path.

The basic idea is simple:

```stata
smartload Indicator.dta, clear
smartload survey.sav, clear
smartload city.sas7bdat, clear
smartload workbook.xlsx, firstrow clear
smartload panel.parquet, clear
```

`smartload` first tries its Stata index, then runs a bounded fast search over common locations. It does not default to a deep full-drive scan.

## Installation

V0.3.0 is SSC-style, but it is not official SSC unless submitted to and accepted by SSC.

Install from GitHub:

```stata
net install smartload, from("https://raw.githubusercontent.com/Louis8102/smartload/main") replace
help smartload
```

No SSC dependency is required.

## Recommended First Setup

For a guided setup:

```stata
smartload, setup
```

The setup menu offers:

```text
1. Index common user folders only
2. Index current project folder
3. Index selected folders
4. Deep full-drive index (slow)
```

For workplace computers, the recommended approach is to index business data folders, not the entire machine:

```stata
smartload, refresh roots("F:\Project;G:\Data;H:\Shared")
```

After that, daily use is just:

```stata
smartload Indicator.dta, clear
```

The index is stored as `smartload_index.dta` in the user's PERSONAL ado directory. It survives Stata restarts and computer shutdowns. Rebuild it after files are added, moved, renamed, or deleted.

## Search Behavior

When you run:

```stata
smartload filename.ext, clear
```

V0.3.0 uses this order:

1. Search `smartload_index.dta`, if it exists.
2. If no indexed match is found, run a bounded fast search over common locations.
3. If no match is found, ask the user to run `smartload, setup` or refresh selected folders.

V0.3.0 does not claim pure Stata instant full-computer search. Deep full-drive indexing can take many minutes on large computers and should be explicit:

```stata
smartload, refresh drives(all)
smartload, refresh drives(C F)
```

Future versions may add optional accelerators such as Everything on Windows, Spotlight on macOS, or locate/plocate on Linux when a stable command-line interface is available.

## Duplicate File Names

If the same file name is found in multiple locations, `smartload` lists all matches:

```text
Found multiple files named Indicator.dta:
1. C:/Users/Hao Ma/Downloads/Indicator.dta
2. F:/Project/Data/Indicator.dta
3. G:/Backup/Indicator.dta
```

In interactive Stata, type the Arabic numeral for the file to import. In batch mode, use `choice(#)`:

```stata
smartload Indicator.dta, choice(2) clear
```

## Supported Native Imports

V0.3.0 imports Stata-readable data files through Stata's native commands:

- `.dta` via `use`
- `.xlsx` and `.xls` via `import excel`
- `.csv`, `.txt`, `.tsv`, and text-like `.dat` via `import delimited`
- `.sav` and `.por` via `import spss`
- `.sas7bdat` via `import sas`
- `.xpt` via `import sasxport`
- `.parquet` via `import parquet`

For `.sav`/`.por`, `smartload` uses Stata's native `import spss` so variable labels and value labels are preserved whenever Stata can preserve them.

## Detected But Not Imported

These files are indexed/detected but not automatically imported in V0.3.0:

- R files: `.rds`, `.rda`, `.RData`, `.r`
- Document containers: `.docx`, `.doc`, `.pptx`, `.ppt`, `.pdf`
- Python/data-science containers other than native Parquet: `.feather`, `.pkl`, `.pickle`, `.arrow`, `.h5`, `.hdf5`, `.json`, `.jsonl`
- GIS, database, and archive files

R files are not imported automatically because Stata has no native `.rds`/`.RData` importer, and R files may contain non-rectangular objects or multiple objects. Convert in R to `.dta`, `.parquet`, or `.csv`, then run `smartload` again.

DOCX/PPT/PDF files may contain visual tables, but they are document containers. V0.3.0 detects them but does not claim accurate table extraction.

## Files

Recommended GitHub layout:

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
```

`stata.toc` is the Stata package-directory index used by `net install`. `smartload.pkg` is the install manifest.

## Version

- Version: 0.3.0
- Date: 2026-07-10
- Author: Hao Ma
- License: MIT
- Tested target: StataNow/MP 19.5
