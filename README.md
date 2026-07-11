# smartload V0.6.1 Notes

`smartload` is an SSC-style Stata command by Hao Ma. It loads a local data file by file name, without requiring the user to remember the folder path.

The basic idea is simple:

```stata
smartload Indicator.dta, clear
smartload survey.sav, clear
smartload city.sas7bdat, clear
smartload workbook.xlsx, firstrow clear
smartload panel.parquet, clear
smartload table.dbf, clear
smartload fixed_dictionary.dct, clear
smartload report.docx, table(1) firstrow clear
smartload slides.pptx, table(1) firstrow clear
smartload web_tables.html, table(1) firstrow clear
smartload "https://example.com/page.html", table(1) firstrow clear
smartload "https://www.w3schools.com/html/tryit.asp?filename=tryhtml_table_th_vertical", table(1) clear
smartload "https://www.stata-press.com/data/r18/auto.dta", clear
smartload "https://raw.githubusercontent.com/user/repo/main/data.csv", clear
```

The standard Stata syntax uses a comma before options: `smartload filename.ext, clear`.  V0.6.1 also tolerates common omitted-comma cases such as `smartload filename.ext clear` and treats the final `clear` as an option, not as part of the file name.

For local file names, `smartload` first tries Everything through `es.exe` on Windows, then tries its saved Stata index, then runs a bounded fast search over common locations. It does not default to a deep full-drive scan. For `http://` or `https://` URLs, `smartload` skips local search and imports directly from the URL. Direct data-file URLs are imported with Stata's native commands. Web pages are scanned for true HTML `<table>` elements.

## Installation

V0.6.1 is SSC-style, but it is not official SSC unless submitted to and accepted by SSC.

Install from GitHub:

```stata
net install smartload, from("https://raw.githubusercontent.com/Louis8102/smartload/main") replace
help smartload
```

No SSC dependency is required.

## Optional Everything Accelerator

On Windows, `smartload` can use Everything for near-instant file-name search, but Stata needs the Everything command-line interface `es.exe`.

If Everything is already installed, run this once in Stata:

```stata
smartload, installes
```

This downloads the official 64-bit `ES-1.1.0.30.x64.zip` from voidtools, unzips `es.exe`, and stores it in the user's PERSONAL ado folder under `smartload_bin`. No administrator permission is needed for this ES placement. `smartload` first uses Stata's own downloader; if that fails on Windows, it tries the system `curl.exe`.

Important: `es.exe` is not Everything itself. Everything must already be installed and running. If Everything is not installed/running, or if the computer blocks downloads from Stata, `smartload` falls back to its saved Stata index and bounded fast search.

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

V0.6.1 uses this order for local file names:

1. On Windows, use Everything's command-line interface `es.exe` if available.
2. Search `smartload_index.dta`, if it exists.
3. If no indexed match is found, run a bounded fast search over common locations.
4. If no match is found, ask the user to run `smartload, setup` or refresh selected folders.

Everything GUI alone is not enough for automatic Stata integration. `smartload` needs `es.exe`, the Everything Command-line Interface from voidtools. If Everything is installed but `es.exe` is missing, run:

```stata
smartload, installes
```

The fast search first checks direct matches in common locations, including drive roots and common drive-level data folders such as `D:\data`, `D:\Data`, `D:\datasets`, and `D:\Project`, before spending time on recursive folder traversal.

V0.6.1 does not claim pure Stata instant full-computer search. Deep full-drive indexing can take many minutes on large computers and should be explicit:

```stata
smartload, refresh drives(all)
smartload, refresh drives(C F)
```

Future versions may add additional optional accelerators such as Spotlight on macOS or locate/plocate on Linux when a stable command-line interface is available.

## Localized Cloud Drives

`smartload` supports cloud-drive files when they are locally synced or mounted as ordinary folders/drives. Examples include OneDrive, Dropbox, Google Drive for desktop, Box Drive, and SharePoint Sync when the files appear under a local path such as:

```text
C:\Users\Hao Ma\OneDrive\...
G:\My Drive\...
C:\Users\Hao Ma\Dropbox\...
```

For best speed, mark important cloud data folders as "Always keep on this device" or the equivalent setting in the cloud client, and let Everything index those local cloud folders. If a file is online-only, `smartload` may find the placeholder path but Stata import can still pause while the cloud client downloads the file.

If Everything finds a same-named file on a normal drive, V0.6.1 still performs a bounded check of common local cloud roots such as `C:\Users\...\Box`, `OneDrive`, `Dropbox`, `Google Drive`, and `SharePoint`. This prevents a local Box/OneDrive copy from being silently missed just because Everything returned another copy first.

Authenticated cloud accounts are not the same thing as local indexing. Even after a user signs in to Google Drive, OneDrive, Dropbox, Box, or SharePoint in a browser, `smartload` cannot promise instant cloud-wide search unless those files are exposed locally or a provider-specific API workflow is added. Pure browser-only cloud files without a local path are outside the instant local-search guarantee.

Without Everything, users can index selected local cloud roots:

```stata
smartload, refresh roots("C:\Users\Hao Ma\OneDrive;G:\My Drive;C:\Users\Hao Ma\Dropbox")
```

## URL and GitHub Imports

When the input starts with `http://` or `https://`, `smartload` treats it as a URL and does not search the local computer:

```stata
smartload "https://www.stata-press.com/data/r18/auto.dta", clear
smartload "https://raw.githubusercontent.com/user/repo/main/data.csv", clear
```

Common GitHub `blob` URLs are converted to raw URLs automatically:

```stata
smartload "https://github.com/user/repo/blob/main/data.csv", clear
```

URL support covers direct data-file URLs and true HTML tables in web pages. For direct data files, the URL should point to a supported extension such as `.dta`, `.csv`, `.xlsx`, `.sav`, `.sas7bdat`, `.parquet`, or `.dbf`. For web pages, `smartload` parses real HTML `<table>` elements. Web-page URLs ending in `.html`, `.htm`, `.asp`, `.aspx`, `.php`, `.jsp`, `.cfm`, or `.cgi`, and URLs without a visible extension, are treated as web pages. If exactly one table is found, it is imported directly. If several tables are found, interactive Stata users are asked to choose a numbered table; in batch mode use `table(#)`.

Web pages that only look tabular because of CSS grid/div layouts, JavaScript rendering, screenshots, or images are not imported automatically. If image elements are detected but no true `<table>` exists, `smartload` explains that OCR is required. OCR is deliberately not run by default because it is slower, less reliable, and usually requires external tools.

For `.dct`, use local files because the dictionary usually references a companion raw data file.

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

V0.6.1 imports Stata-readable data files through Stata's native commands:

- `.dta` via `use`
- `.xlsx` and `.xls` via `import excel`
- `.csv`, `.txt`, `.tsv`, and text-like `.dat` via `import delimited`
- `.sav` and `.por` via `import spss`
- `.sas7bdat` via `import sas`
- `.xpt` via `import sasxport5`
- `.v8xpt` via `import sasxport8`
- `.parquet` via `import parquet`
- `.dbf` via `import dbase`
- `.dct` fixed-format dictionaries via `infix using`
- `.docx` true Word tables via experimental Office table extraction
- `.pptx` true PowerPoint tables via experimental Office table extraction
- `.html`, `.htm`, `.asp`, `.aspx`, `.php`, `.jsp`, `.cfm`, and `.cgi` true HTML tables via experimental HTML table extraction

The same extension-based dispatch is used for direct URLs when Stata's native command can read that URL. URLs with common web-page extensions such as `.html`, `.htm`, `.asp`, `.aspx`, `.php`, `.jsp`, `.cfm`, or `.cgi`, or URLs without a visible file extension, are treated as web pages and scanned for true HTML tables.

For `.docx` and `.pptx`, `smartload` extracts real Office table XML only. It does not OCR screenshots, pictures, scanned tables, legacy `.doc`/`.ppt`, merged-cell layouts, or arbitrary page text. If exactly one true table is found, it is imported directly. If several true tables are found, interactive Stata users are asked to choose a numbered table. Use `table(#)` to select a table directly, and use `firstrow` when the first table row contains variable names.

For HTML/web-page inputs, `smartload` extracts real HTML `<table>` elements only. It does not execute JavaScript, infer visual CSS tables, or OCR image tables. Use `table(#)` to select a table and `firstrow` when the first row contains variable names.

The Stata menu also includes JDBC, ODBC, FRED, and Haver entries. These are connection/data-source workflows rather than ordinary files found by file name on disk, so they are outside the `smartload filename.ext` workflow.

For `.sav`/`.por`, `smartload` uses Stata's native `import spss` so variable labels and value labels are preserved whenever Stata can preserve them.

## Detected But Not Imported

These files are indexed/detected but not automatically imported in V0.6.1:

- R files: `.rds`, `.rda`, `.RData`, `.r`
- Document containers not supported as rectangular data: `.doc`, `.ppt`, `.pdf`
- Web/image tables without true HTML `<table>` structure
- Python/data-science containers other than native Parquet: `.feather`, `.pkl`, `.pickle`, `.arrow`, `.h5`, `.hdf5`, `.json`, `.jsonl`
- GIS, database, and archive files

R files are not imported automatically because Stata has no native `.rds`/`.RData` importer, and R files may contain non-rectangular objects or multiple objects. Convert in R to `.dta`, `.parquet`, or `.csv`, then run `smartload` again.

DOC/PPT/PDF files may contain visual tables, but they are document containers. V0.6.1 does not claim accurate table extraction for those formats. DOCX/PPTX support is limited to true Office table objects.

Web pages may contain true HTML tables, CSS/JavaScript visual tables, or image tables. V0.6.1 imports true HTML tables only. Image tables require OCR and CSS/JavaScript visual tables require a different extraction strategy, so they are detected/explained rather than silently imported.

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

- Version: 0.6.1
- Date: 2026-07-11
- Author: Hao Ma
- License: MIT
- Tested target: StataNow/MP 19.5




