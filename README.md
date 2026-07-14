# smartload V0.7.3

`smartload` is an SSC-style Stata command. Its defining feature is path-free data loading: the user supplies a file name, and `smartload` finds and imports the file without requiring a drive letter, folder path, or cloud-sync location.

It searches local disks and locally available cloud-sync folders. For OneDrive, Google Drive for desktop, Dropbox, Box Drive, or SharePoint Sync, the provider's desktop client must be installed and signed in, and the files must appear in Windows File Explorer or as an ordinary operating-system path. Browser login alone is not sufficient. Files already available offline can be searched and loaded like ordinary disk files. Online-only placeholders may require the cloud client to download the content before Stata can read it, so their import time depends on the provider and network connection.

Its second defining feature is direct web-data loading. A public URL can point to a Stata-readable data file, a public Google Sheet, a GitHub data file, or a web page containing true HTML tables. `smartload` normalizes supported links and imports the data without requiring the user to download and locate a local copy first. Login-protected pages, JavaScript-rendered grids, screenshots, and image tables require a different access or extraction method and are not presented as direct HTML-table imports.

`smartload` is a targeted data loader, not a web crawler. It processes the file name or URL supplied by the user; it does not traverse links, crawl websites, or bulk-harvest pages.

## Installation

Install from GitHub:

```stata
net install smartload, from("https://raw.githubusercontent.com/Louis8102/smartload/main") replace
help smartload
```

To copy the optional example datasets into Stata's current working directory:

```stata
net get smartload, from("https://raw.githubusercontent.com/Louis8102/smartload/main") replace
```

Stata treats datasets and demonstration documents as ancillary files: `net install` installs the command and help, while `net get` copies the examples. A ZIP download of the repository keeps them grouped under `example_data`.

This folder is the speed-first build. The search accelerator and fallback behavior are described below.

## Basic Usage

```stata
smartload Indicator.dta, clear
smartload survey.sav, clear
smartload compressed_survey.zsav, clear
smartload european.csv2, firstrow clear
smartload extract.psv, firstrow clear
smartload city.sas7bdat, clear
smartload workbook.xlsx, firstrow clear
smartload panel.parquet, clear
smartload table.dbf, clear
smartload counties.shp, clear
smartload fixed_dictionary.dct, clear
smartload report.pdf, clear
smartload report.docx, table(1) firstrow clear
smartload slides.pptx, table(1) firstrow clear
smartload web_tables.html, table(1) firstrow clear
smartload "https://www.stata-press.com/data/r18/auto.dta", clear
smartload "https://docs.google.com/spreadsheets/d/FILEID/edit#gid=0", firstrow clear
smartload "https://docs.google.com/document/d/FILEID/edit", table(1) firstrow clear
smartload "https://docs.google.com/presentation/d/FILEID/edit", table(1) firstrow clear
```

The standard Stata syntax uses a comma before options: `smartload filename.ext, clear`.

`smartload` never silently discards a dataset already in memory. If Stata reports that data in memory would be lost, rerun the selected file with `, clear` after saving anything you need.

## Search Behavior

For local file names, V0.7.3 uses this order:

1. Use Everything through `es.exe` on Windows, when available.
2. Search the saved `smartload_index.dta`, if it exists.
3. Run a bounded fast search over common local folders.
4. Ask the user to run `smartload, setup` or refresh selected folders if no match is found.

On Windows, Everything plus `es.exe` is the route that provides near-instant file-name lookup on indexed local volumes. `smartload, installes` installs only the small Everything command-line client; the Everything application and its index must also be installed and running. When that route is available, users normally do not need to build a separate `smartload` full-drive index.

Without Everything, `smartload` remains usable through its saved Stata index and bounded folder search, but the initial index build can take minutes on large drives and a broad fallback search cannot promise one-second results. The saved index persists across Stata restarts and computer shutdowns; rebuild it only after relevant files have been added, moved, renamed, or deleted.

On organization-managed computers, administrator policy may prohibit installing Everything, running its service, or viewing restricted folders. `smartload` does not bypass operating-system permissions. In that situation, use an index over approved data folders or ask the organization's IT administrator whether Everything is permitted.

For a guided setup:

```stata
smartload, setup
```

For selected folders:

```stata
smartload, refresh roots("F:\Project;G:\Data;H:\Shared")
```

If Everything is installed but `es.exe` is missing, run:

```stata
smartload, installes
```

`es.exe` is the Everything command-line interface. Everything itself must already be installed and running.

## Supported Imports

V0.7.3 imports Stata-readable data files and native document tables through Stata:

- `.dta` via `use`
- `.xlsx` and `.xls` via `import excel`
- `.csv`, `.txt`, and text-like `.dat` via `import delimited`
- `.csv2` as semicolon-delimited text with comma decimals
- `.psv` as pipe-delimited text; `.tsv` and `.tab` as tab-delimited text
- `.sav`, compressed `.zsav`, and `.por` via `import spss`
- `.sas7bdat` via `import sas`
- `.xpt` via `import sasxport5`
- `.v8xpt` via `import sasxport8`
- `.parquet` via `import parquet`
- `.dbf` via `import dbase`
- local ESRI `.shp` plus its matching `.dbf` via `spshape2dta`
- `.dct` fixed-format dictionaries via `infix using`
- `.pdf` via StataNow `pdf2txt`, imported as plain text lines
- `.docx` native Word tables through Office Open XML table extraction
- `.pptx` native PowerPoint tables through Office Open XML table extraction
- `.html`, `.htm`, `.asp`, `.aspx`, `.php`, `.jsp`, `.cfm`, and `.cgi` true HTML tables

PDF support is plain-text support. It does not perform OCR and does not reconstruct PDF tables.

DOCX and PPTX support reads native Office table objects, including numeric cells, text cells, dates stored as text, and mixed textual content. It does not require every cell to be numeric. If one native table is present, it is selected automatically. If several tables are present, `smartload` lists numbered previews and asks which table to import; `table(#)` selects one directly. Use `firstrow` when the first table row contains variable names.

Pictures, screenshots, scanned tables, charts, and ordinary document text are not treated as native tables. Legacy binary `.doc` and `.ppt` files must first be saved as `.docx` or `.pptx`; merely renaming the extension does not convert the file.

For an ESRI shapefile, keep `map.shp` and `map.dbf` together. `smartload map.shp, clear` creates persistent `map_smartload.dta` and `map_smartload_shp.dta` files in Stata's current working directory and loads the first one as an `spset` dataset. If that name belongs to another source path, a numeric suffix is added automatically. Existing translated files from the same source are reused for speed. Use `smartload map.shp, clear replace` after the source shapefile changes. Other companion files such as `.shx` and `.prj` may remain in the source folder, but Stata's native translator requires the `.shp` and `.dbf` pair.

## URLs and Cloud Folders

Direct `http://` and `https://` data-file URLs are imported with Stata's native commands when possible. Common GitHub `blob` URLs are converted to raw URLs automatically.

For HTML pages, `smartload` first uses Stata's native downloader and then tries the system `curl` command when available. PowerShell is not used. This improves compatibility with public websites that reject Stata's downloader, but it cannot bypass authentication, anti-bot controls, JavaScript-only rendering, or network policy.

Public Google Sheets share URLs are converted to CSV export URLs. Public Google Docs share URLs are converted to HTML export URLs and scanned for true HTML tables. Public Google Slides links are converted to PPTX export URLs and scanned for native PowerPoint table objects.

The Google file must be publicly accessible to the link. `smartload` does not request, store, or bypass Google account credentials. Creating or modifying files inside a user's Google account would require a separate OAuth-authorized Drive integration and is outside this loader's scope.

Local synced cloud-drive folders, such as OneDrive, Google Drive for desktop, Dropbox, Box Drive, and SharePoint Sync, are treated as ordinary local folders. Browser-only cloud files are not searched unless they are exposed through a local path or public URL.

## Detected But Not Imported

These files are detected but not automatically imported in this build:

- R files: `.rds`, `.rda`, `.RData`, `.r`
- Legacy binary Office containers: `.doc`, `.ppt`
- Image-only PDFs or scanned tables requiring OCR
- Python/data-science containers other than native Parquet: `.feather`, `.pkl`, `.pickle`, `.arrow`, `.h5`, `.hdf5`, `.json`, `.jsonl`
- GIS containers other than Stata's native ESRI shapefile workflow, database containers, and archives

Convert these files to `.dta`, `.csv`, `.xlsx`, or `.parquet` before using `smartload`.

## Package Files

```text
smartload/
  README.md
  LICENSE
  smartload.ado
  smartload.sthlp
  smartload.pkg
  stata.toc
  test_smartload.do
```

The repository includes an `example_data` directory so a reader can download it and try `smartload` immediately. `net get smartload` copies the same ancillary files into Stata's current working directory. The non-geospatial files all contain the same ASCII-only product-quality dataset: 8 observations and 20 variables. The examples cover DTA, CSV, CSV2, DAT, TXT, TSV, Excel, SPSS, SAS, Parquet, DBF, PDF, HTML, DOCX, and PPTX. The Word and PowerPoint files each contain one native editable table with black cell borders; they are not screenshots. The ESRI shapefile example is necessarily a separate spatial dataset and includes a same-name `.shp` and `.dbf` pair.

```stata
smartload smartload_example.dta, clear
smartload smartload_example.csv, firstrow clear
smartload smartload_example.csv2, firstrow clear
smartload smartload_example.xlsx, firstrow clear
smartload smartload_example.parquet, clear
smartload smartload_example.dbf, clear
smartload smartload_example.pdf, clear
smartload smartload_example_map.shp, clear
smartload smartload_example.html, table(1) firstrow clear
smartload smartload_example.docx, table(1) firstrow clear
smartload smartload_example.pptx, table(1) firstrow clear
```

The self-test creates temporary fixtures and copies the packaged shapefile pair into its temporary workspace before testing. Public URL examples remain network-dependent and are not treated as mandatory offline tests.

## Version

- Version: 0.7.3
- Date: 2026-07-14
- Author: Hao Ma
- License: MIT
- Tested target: StataNow/MP 19.5
