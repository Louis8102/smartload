{smcl}
{* *! version 0.7.3 14jul2026}{...}
{vieweralsosee "[D] import" "help import"}{...}
{vieweralsosee "[D] use" "help use"}{...}
{vieweralsosee "[RPT] pdf2txt" "help pdf2txt"}{...}
{vieweralsosee "[SP] spshape2dta" "help spshape2dta"}{...}
{viewerjumpto "Syntax" "smartload##syntax"}{...}
{viewerjumpto "Description" "smartload##description"}{...}
{viewerjumpto "Options" "smartload##options"}{...}
{viewerjumpto "Remarks" "smartload##remarks"}{...}
{viewerjumpto "Examples" "smartload##examples"}{...}
{viewerjumpto "Stored results" "smartload##results"}{...}
{viewerjumpto "Author" "smartload##author"}{...}

{title:Title}

{p2colset 5 19 21 2}{...}
{p2col:{hi:smartload} {hline 2}}Find a named data file and load it into Stata{p_end}
{p2colreset}{...}

{marker syntax}{...}
{title:Syntax}

{p 8 17 2}
{cmd:smartload} {it:filename}
[{cmd:,}
{cmd:clear}
{cmd:firstrow}
{cmd:sheet(}{it:sheetname}{cmd:)}
{cmd:encoding(}{it:encoding}{cmd:)}
{cmd:choice(}{it:#}{cmd:)}
{cmd:table(}{it:#}{cmd:)}
{cmd:roots(}{it:roots}{cmd:)}
{cmd:maxdirs(}{it:#}{cmd:)}
{cmd:log}
{cmd:replace}]

{p 8 17 2}
{cmd:smartload, setup}

{p 8 17 2}
{cmd:smartload, refresh}
[{cmd:roots(}{it:roots}{cmd:)}
{cmd:drives(}{it:drive-list|all}{cmd:)}
{cmd:replace}]

{p 8 17 2}
{cmd:smartload, installes}

{marker description}{...}
{title:Description}

{pstd}
{cmd:smartload} loads a data file when the user knows the file name but not
the folder path.  It searches for the named file, prompts when more than one
matching file is found, and then dispatches to an appropriate Stata command
according to the file type.

{pstd}
Its defining feature is path-free loading across local disks and locally
available cloud-sync folders.  A cloud provider's desktop client must be
installed and signed in, and the files must appear in Windows File Explorer
or as an ordinary operating-system path.  Browser login alone is not
sufficient.  Online-only placeholders may need to be downloaded by the cloud
client before Stata can read them.

{pstd}
Its second defining feature is direct loading from public web URLs, including
Stata-readable data files, public Google Sheets, GitHub data files, and true
HTML tables.  Login-protected pages, JavaScript-rendered grids, screenshots,
and image tables are not treated as directly readable HTML tables.

{pstd}
{cmd:smartload} is a targeted data loader, not a web crawler.  It processes
the file name or URL supplied by the user and does not traverse links or
bulk-harvest websites.

{pstd}
{cmd:net install smartload} installs the command and this help file.  Stata
treats the included example datasets and documents as ancillary files.  To
copy them into the current working directory, type
{cmd:net get smartload, from("https://raw.githubusercontent.com/Louis8102/smartload/main") replace}.

{pstd}
For local file names, {cmd:smartload} first uses Everything's command-line
interface {cmd:es.exe} on Windows when available.  If that is unavailable, it
checks a saved {cmd:smartload_index.dta} index and then runs a bounded search
of common local locations.  It does not run a deep full-drive search unless the
user explicitly requests one through {cmd:setup} or {cmd:refresh}.

{pstd}
For URL inputs beginning with {cmd:http://} or {cmd:https://},
{cmd:smartload} imports directly from the URL rather than searching the local
computer.  Public Google Sheets links are converted to CSV export links.
Public Google Docs links are converted to HTML export links and scanned for
true HTML tables.  Public Google Slides links are converted to PPTX export
links and scanned for native PowerPoint tables.  Common GitHub {cmd:blob}
URLs are converted to raw URLs.

{marker options}{...}
{title:Options}

{phang}
{cmd:clear} clears the current dataset before loading, when supported by the
underlying Stata command.  {cmd:smartload} does not silently discard data in
memory; if Stata reports that data would be lost, save those data if needed
and rerun the command with {cmd:clear}.

{phang}
{cmd:firstrow} treats the first row as variable names for Excel, delimited
text, Google Sheets CSV export, and HTML tables.

{phang}
{cmd:sheet(}{it:sheetname}{cmd:)} specifies the Excel worksheet to import.

{phang}
{cmd:encoding(}{it:encoding}{cmd:)} passes an encoding to
{cmd:import delimited} for delimited text files.

{phang}
{cmd:choice(}{it:#}{cmd:)} selects one file when several files with the same
name are found.  If {cmd:choice()} is omitted in interactive Stata,
{cmd:smartload} displays numbered choices and prompts for a selection.

{phang}
{cmd:table(}{it:#}{cmd:)} selects one table from HTML, DOCX, or PPTX input.
If exactly one table is found, it is imported automatically.  If more than
one table is found, interactive Stata users are prompted unless {cmd:table()}
is specified.

{phang}
{cmd:roots(}{it:roots}{cmd:)} restricts file lookup or index refresh to one or
more root folders.  Separate multiple roots with semicolons.

{phang}
{cmd:maxdirs(}{it:#}{cmd:)} sets the maximum number of folders checked by the
bounded fast search after an index miss.  The default is {cmd:maxdirs(2500)}.

{phang}
{cmd:log} writes a short import log to {cmd:smartload_log.txt}.

{phang}
{cmd:replace} replaces an existing log when {cmd:log} is specified.  For a
local ESRI shapefile, it also rebuilds both translated Stata spatial files.

{phang}
{cmd:setup} starts an interactive setup menu for building an index over common
user folders, the current project folder, selected folders, or full drives.

{phang}
{cmd:refresh} rebuilds the saved Stata index.  Without {cmd:roots()} or
{cmd:drives()}, common user folders are indexed.

{phang}
{cmd:drives(}{it:drive-list|all}{cmd:)} specifies drives to index with
{cmd:refresh}.  {cmd:drives(all)} may be slow on large computers.

{phang}
{cmd:installes} installs the Everything command-line interface {cmd:es.exe}
under the user's PERSONAL ado folder.  This option is Windows-only.  Everything
itself must already be installed and running for {cmd:es.exe} searches to work.

{marker remarks}{...}
{title:Remarks}

{pstd}
{cmd:smartload} is intended for rectangular data files and for a small number
of Stata-native text extraction workflows.

{pstd}
On Windows, Everything plus {cmd:es.exe} provides the fastest local file-name
lookup.  Without {cmd:es.exe}, {cmd:smartload} falls back to its Stata index
and bounded fast search.

{pstd}
Everything provides near-instant lookup only when the Everything application
and its index are available and {cmd:es.exe} can communicate with it.  Without
Everything, building a broad Stata index can take minutes on large drives and
the bounded fallback cannot promise one-second full-drive results.  The saved
Stata index survives Stata and computer restarts.

{pstd}
Organization-managed computers may prohibit installing Everything, running
its service, or accessing restricted folders.  {cmd:smartload} does not bypass
operating-system permissions.  Users in that situation should index approved
data folders or consult their IT administrator.

{pstd}
Supported native Stata imports include {cmd:.dta}, {cmd:.xlsx}, {cmd:.xls},
{cmd:.csv}, {cmd:.csv2}, {cmd:.txt}, {cmd:.tsv}, {cmd:.tab}, {cmd:.psv},
text-like {cmd:.dat}, {cmd:.sav}, {cmd:.zsav}, {cmd:.por},
{cmd:.sas7bdat}, {cmd:.xpt}, {cmd:.v8xpt}, {cmd:.parquet},
{cmd:.dbf}, local ESRI {cmd:.shp} plus matching {cmd:.dbf}, and fixed-format
{cmd:.dct} dictionaries.

{pstd}
For {cmd:map.shp}, the matching {cmd:map.dbf} must be in the same folder.
{cmd:smartload} calls Stata's native {cmd:spshape2dta} and creates persistent
{cmd:map_smartload.dta} and {cmd:map_smartload_shp.dta} files in Stata's
current working directory.  A numeric suffix avoids collisions between
different source paths.  Existing translations from the same source are
reused.  Specify {cmd:replace} to rebuild both after the source changes.  A
remote {cmd:.shp} URL alone is insufficient because the companion {cmd:.dbf}
is also required.

{pstd}
Native {cmd:.docx} Word tables and {cmd:.pptx} PowerPoint tables are extracted
from Office Open XML.  Cells may contain numbers, text, dates represented as
text, or mixed textual content.  Multiple tables are displayed as numbered
choices.  Specify {cmd:table(#)} to choose directly and {cmd:firstrow} when
the first table row contains variable names.

{pstd}
The ancillary files {cmd:smartload_example.docx} and
{cmd:smartload_example.pptx} each contain one native table with black cell
borders, 20 columns, and 8 data rows plus a header row.  Their content matches
the other non-geospatial examples and contains ASCII characters only.  Use
{cmd:net get smartload} to copy the examples into the current working directory.

{pstd}
{cmd:.csv2} is treated as semicolon-delimited text with comma decimals;
{cmd:.psv} uses a pipe delimiter; and {cmd:.tsv}/{cmd:.tab} use a tab
delimiter.  Compressed SPSS {cmd:.zsav} files are passed to
{cmd:import spss, zsav}, which retains the native SPSS import behavior for
variable labels, numeric value labels, dates, and missing values.

{pstd}
PDF support uses StataNow's {cmd:pdf2txt} command when available.  A PDF file
is converted to plain text and imported as two variables: line number and text.
This is not OCR and does not reconstruct PDF tables.

{pstd}
HTML support is limited to true {cmd:<table>} elements and escaped table code
examples.  {cmd:smartload} does not infer tables from screenshots, images, CSS
grid layouts, JavaScript-rendered layouts, or ordinary page text.

{pstd}
R files, legacy binary DOC/PPT files, GIS containers other than the native
ESRI shapefile workflow, archives, and most database containers are detected
but not imported.  Save legacy Office files as DOCX or PPTX, or convert other files to a
Stata-readable format such as {cmd:.dta}, {cmd:.csv}, {cmd:.xlsx}, or
{cmd:.parquet} before using {cmd:smartload}.

{pstd}
Web-page URL downloads use Stata's native downloader first and the system
{cmd:curl} command as a fallback when available.  PowerShell is not used.
Some servers still require authentication, browser JavaScript, or anti-bot
checks.  In those cases, save the page locally as an HTML file and run
{cmd:smartload} on the saved file.

{pstd}
Local synced cloud-drive folders are treated as ordinary local folders.
Browser login to a cloud provider is not equivalent to local file access.

{marker examples}{...}
{title:Examples}

{pstd}Load common local data files{p_end}
{phang2}{cmd:. smartload auto.dta, clear}{p_end}
{phang2}{cmd:. smartload survey.sav, clear}{p_end}
{phang2}{cmd:. smartload compressed_survey.zsav, clear}{p_end}
{phang2}{cmd:. smartload european.csv2, firstrow clear}{p_end}
{phang2}{cmd:. smartload extract.psv, firstrow clear}{p_end}
{phang2}{cmd:. smartload city.sas7bdat, clear}{p_end}
{phang2}{cmd:. smartload workbook.xlsx, firstrow clear}{p_end}
{phang2}{cmd:. smartload panel.parquet, clear}{p_end}
{phang2}{cmd:. smartload table.dbf, clear}{p_end}
{phang2}{cmd:. smartload counties.shp, clear}{p_end}

{pstd}Import native Office tables, including text cells{p_end}
{phang2}{cmd:. smartload report.docx, table(1) firstrow clear}{p_end}
{phang2}{cmd:. smartload slides.pptx, table(2) firstrow clear}{p_end}
{phang2}{cmd:. smartload smartload_example.docx, table(1) firstrow clear}{p_end}
{phang2}{cmd:. smartload smartload_example.pptx, table(1) firstrow clear}{p_end}

{pstd}Convert a PDF to plain text and import the text lines{p_end}
{phang2}{cmd:. smartload report.pdf, clear}{p_end}

{pstd}Build or refresh an index{p_end}
{phang2}{cmd:. smartload, setup}{p_end}
{phang2}{cmd:. smartload, refresh roots("D:\Data;F:\Project")}{p_end}

{pstd}Select among duplicate file names{p_end}
{phang2}{cmd:. smartload source_data.xlsx, choice(2) firstrow clear}{p_end}

{pstd}Load from public URLs{p_end}
{phang2}{cmd:. smartload "https://www.stata-press.com/data/r18/auto.dta", clear}{p_end}
{phang2}{cmd:. smartload "https://github.com/user/repo/blob/main/data.csv", clear}{p_end}
{phang2}{cmd:. smartload "https://docs.google.com/spreadsheets/d/FILEID/edit#gid=0", firstrow clear}{p_end}
{phang2}{cmd:. smartload "https://docs.google.com/presentation/d/FILEID/edit", table(1) firstrow clear}{p_end}

{pstd}Extract a true HTML table{p_end}
{phang2}{cmd:. smartload page.html, table(1) firstrow clear}{p_end}

{marker results}{...}
{title:Stored results}

{pstd}
{cmd:smartload} stores the following in {cmd:r()} after successful import:

{synoptset 18 tabbed}{...}
{synopt:{cmd:r(filepath)}}full path or URL used{p_end}
{synopt:{cmd:r(filename)}}file name{p_end}
{synopt:{cmd:r(extension)}}detected extension{p_end}
{synopt:{cmd:r(importcmd)}}Stata command or extraction method used{p_end}
{synopt:{cmd:r(storage)}}source category, such as local, index, fast, cloud, or url{p_end}
{synopt:{cmd:r(N)}}number of observations after import{p_end}
{synopt:{cmd:r(k)}}number of variables after import{p_end}
{synopt:{cmd:r(table)}}selected HTML table number, when applicable{p_end}
{synopt:{cmd:r(ntables)}}number of HTML tables found, when applicable{p_end}
{synopt:{cmd:r(spatialdata)}}translated spatial-unit .dta file, for .shp input{p_end}
{synopt:{cmd:r(shapefile)}}translated linked _shp.dta file, for .shp input{p_end}

{pstd}
After {cmd:smartload, refresh}, {cmd:r(N)} contains the number of indexed
files and {cmd:r(indexfile)} contains the saved index path.

{marker author}{...}
{title:Author}

{pstd}
Hao Ma{p_end}

{title:Also see}

{psee}
Manual:  {manhelp import D}, {manhelp use D}, {manhelp pdf2txt RPT},
{manhelp spshape2dta SP}
{p_end}
