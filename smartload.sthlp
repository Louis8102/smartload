{smcl}
{* *! version 0.1.0 09jul2026}{...}
{vieweralsosee "[D] import" "help import"}{...}
{vieweralsosee "[D] use" "help use"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{hi:smartload} {hline 2}}Find a named data file and load it into Stata when the format is safely supported{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:smartload} {it:filename}
[{cmd:,}
{cmd:search(}{it:roots}{cmd:)}
{cmd:drives(}{it:drive-list|all}{cmd:)}
{cmd:clear}
{cmd:sheet(}{it:sheetname}{cmd:)}
{cmd:firstrow}
{cmd:encoding(}{it:encoding}{cmd:)}
{cmd:table(}{it:name}{cmd:)}
{cmd:object(}{it:name}{cmd:)}
{cmd:layer(}{it:name}{cmd:)}
{cmd:member(}{it:name}{cmd:)}
{cmd:slide(}{it:#}{cmd:)}
{cmd:tableindex(}{it:#}{cmd:)}
{cmd:doctable(}{it:#}{cmd:)}
{cmd:pdftable(}{it:#}{cmd:)}
{cmd:ppttable(}{it:#}{cmd:)}
{cmd:cloud(}{it:providers}{cmd:)}
{cmd:cloudroot(}{it:roots}{cmd:)}
{cmd:force}
{cmd:exhaustive}
{cmd:nonetwork}
{cmd:ocr}
{cmd:log}
{cmd:replace}]

{title:Requirements}

{pstd}
{cmd:smartload} V0.1 requires the SSC package {cmd:filelist}.  The command uses
{cmd:filelist} for recursive exact-name file searches.

{pstd}
Install the dependency before using {cmd:smartload}:

{phang2}{cmd:. ssc install filelist}{p_end}

{title:Installation}

{pstd}
V0.1 is SSC-style but is not an official SSC-hosted package unless accepted by
SSC.  Install from the GitHub raw URL:

{phang2}{cmd:. ssc install filelist}{p_end}
{phang2}{cmd:. net install smartload, from("https://raw.githubusercontent.com/USERNAME/smartload/main") replace}{p_end}
{phang2}{cmd:. help smartload}{p_end}

{pstd}
Replace {cmd:USERNAME} with the GitHub account or organization name.  If the
default branch is {cmd:master}, replace {cmd:main} with {cmd:master}.

{title:Description}

{pstd}
{cmd:smartload} is an SSC-style universal data finder and cautious data loader.
The user supplies a file name.  If no {cmd:search()}, {cmd:drives()},
{cmd:cloudroot()}, or {cmd:cloud()} option is specified, {cmd:smartload}
defaults to searching all available drive letters from C through Z, but requires
{cmd:force} before starting that broad recursive search.  If exactly one matching file is found, the command
detects the extension and imports only formats that Stata can load reliably in
the current version.

{pstd}
The command does not fabricate conversion support.  Files that require R,
Python, ODBC, GIS tools, archive tools, OCR tools, or document parsers are
detected and reported as {cmd:detected_not_imported} unless a tested conversion
path is implemented.

{title:Options}

{phang}
{cmd:search(}{it:roots}{cmd:)} recursively searches one or more local roots.
Separate multiple roots with semicolons, for example
{cmd:search("D:\Research;E:\Data;F:\Backup")}.

{phang}
{cmd:drives(}{it:drive-list|all}{cmd:)} searches selected Windows drive
letters such as {cmd:drives(C D E F)} or all available drive letters from C
through Z with {cmd:drives(all)}.

{phang}
{cmd:clear} passes {cmd:clear} to supported Stata import commands.

{phang}
{cmd:sheet()}, {cmd:firstrow}, and {cmd:encoding()} are passed to relevant
native import commands when supported.

{phang}
{cmd:table()}, {cmd:object()}, {cmd:layer()}, {cmd:member()}, {cmd:slide()},
{cmd:tableindex()}, {cmd:doctable()}, {cmd:pdftable()}, and {cmd:ppttable()}
are reserved selectors for files with internal objects.  Current version uses
them for clear user-facing guidance, not for untested external conversion.

{phang}
{cmd:cloudroot(}{it:roots}{cmd:)} searches additional local synced folders.
Multiple roots may be separated by semicolons.

{phang}
{cmd:cloud(}{it:providers}{cmd:)} searches common local synced-folder paths
under {cmd:C:\Users\}{it:username}: Dropbox, OneDrive, Google Drive, My Drive,
and Box.  Missing folders are skipped.

{phang}
{cmd:force} is required for {cmd:drives(all)} and for the default no-location
mode, which is equivalent to {cmd:drives(all)}.

{phang}
{cmd:exhaustive} disables filtering of obvious system-folder matches.  Version
0.1 still relies on {cmd:filelist} for traversal; the filter prevents matching
system paths but does not optimize traversal.

{phang}
{cmd:nonetwork} attempts to skip mapped network drives when drive detection is
possible.

{phang}
{cmd:ocr} is a reserved explicit request for future OCR workflows. OCR is not
used by default.

{phang}
{cmd:log} writes {cmd:smartload_log.txt} in the current directory.  {cmd:replace}
overwrites the log; otherwise log entries are appended.

{title:Search roots}

{pstd}
The command uses the SSC package {cmd:filelist} to recursively search requested
roots.  Exact file-name matches are required.  If no match is found,
{cmd:smartload} stops.  If multiple matches are found across all requested
locations, it lists them and stops.

{title:Drive discovery and whole-drive search}

{pstd}
{cmd:drives(C D E F)} checks whether each requested drive root exists before
searching it.  Unavailable drives are skipped without error.  {cmd:drives(all)}
checks drive letters C through Z and requires {cmd:force}, because whole-drive
searches may be slow.  If neither {cmd:search()} nor {cmd:drives()} nor cloud
options are specified, {cmd:smartload} defaults to {cmd:drives(all)} and also
requires {cmd:force}.  {cmd:exhaustive} disables default system-path filtering.
{cmd:nonetwork} requests mapped-network-drive skipping when detection succeeds.

{title:Cloud-synced folder search}

{pstd}
Version 0.1 searches only local synced folders or explicit {cmd:cloudroot()}
directories.  It does not connect to cloud APIs and does not download files
from Dropbox, OneDrive, Google Drive, or Box.

{title:Supported native formats}

{pstd}
The following formats are imported with Stata commands when a unique file is
found:

{p 8 12 2}
{cmd:.dta} via {cmd:use}; {cmd:.xlsx} and {cmd:.xls} via {cmd:import excel};
{cmd:.csv}, {cmd:.txt}, {cmd:.tsv}, and text-like {cmd:.dat} via
{cmd:import delimited}; {cmd:.sav} and {cmd:.por} via {cmd:import spss};
{cmd:.sas7bdat} via {cmd:import sas}; {cmd:.xpt} via {cmd:import sasxport}.
{p_end}

{title:Recognized conversion-based formats}

{pstd}
The command recognizes but does not falsely import R files, Python/data-science
files, databases, GIS files, archives, PDF files, Word files, and PowerPoint
files unless future tested conversion engines are added.

{title:Compressed archive behavior}

{pstd}
Archive formats such as {cmd:.zip}, {cmd:.gz}, {cmd:.7z}, {cmd:.tar}, and
{cmd:.tar.gz} are detected but not extracted in version 0.1.  Future archive
support should inspect member lists, ignore media and executables, prevent
path traversal, and extract only one selected supported data member.

{title:Document and presentation table extraction}

{pstd}
Word, PDF, and PowerPoint files are document or presentation containers, not
ordinary rectangular datasets.  Current version detects them and stops with
honest messages.  Future versions may add table extraction only after a real
engine is implemented and tested.

{title:SQL/database notes}

{pstd}
{cmd:.sql} files are usually scripts or dumps.  SQLite, DuckDB, Access, and
similar database files require table inspection through a tested bridge such as
ODBC, Python, or R.

{title:R/Python notes}

{pstd}
R and Python files may contain one table, many objects, nested structures, or
unsafe serialized objects.  They require inspected conversion before import.
Pickle files are not imported automatically.

{title:GIS notes}

{pstd}
GIS files require a tested GIS conversion path.  Shapefiles also require
companion files such as {cmd:.shx} and {cmd:.dbf}.

{title:PDF notes}

{pstd}
PDF files, including PDFs that visually contain Excel-like tables, are not
directly importable Stata datasets.  Text-based PDF table extraction may later
use pdfplumber, camelot, or tabula.  Scanned PDFs require OCR; OCR is never
used by default and any OCR-derived output must be labeled as such.

{title:Word notes}

{pstd}
Future {cmd:.docx} support may use python-docx or another tested engine to
detect zero, one, or multiple tables.  Legacy {cmd:.doc} files require
conversion before table extraction.

{title:PowerPoint notes}

{pstd}
Future {cmd:.pptx} support may use python-pptx or another tested engine to
extract real table objects.  Images, screenshots, charts, and table-like
pictures are not reliable tables.  Legacy {cmd:.ppt} files require conversion.

{title:Non-unique file names}

{pstd}
If more than one file with the exact requested name is found, {cmd:smartload}
lists all matches and stops.  It does not guess.

{title:Internal object selection}

{pstd}
When a format contains multiple internal objects, a reliable implementation
must list objects and require a selector such as {cmd:sheet()}, {cmd:table()},
{cmd:object()}, {cmd:layer()}, {cmd:member()}, {cmd:slide()}, or
{cmd:tableindex()}.  Current version implements native Excel sheet selection.

{title:Returned results}

{pstd}
After successful import, {cmd:smartload} returns:

{p 8 12 2}
{cmd:r(filepath)}, {cmd:r(filename)}, {cmd:r(extension)}, {cmd:r(importcmd)},
{cmd:r(storage)}, {cmd:r(sourcekind)}, {cmd:r(N)}, and {cmd:r(k)}.
{p_end}

{pstd}
For detected but not imported files, it returns {cmd:r(filepath)},
{cmd:r(filename)}, {cmd:r(extension)}, and {cmd:r(status)} set to
{cmd:detected_not_imported}.

{title:Examples}

{phang2}{cmd:. smartload mydata.xlsx, force firstrow clear}{p_end}
{phang2}{cmd:. smartload mydata.xlsx, search("C:\Users\YOURNAME\Documents") firstrow clear}{p_end}
{phang2}{cmd:. smartload school_data.dta, search("C:\ANOVA") clear}{p_end}
{phang2}{cmd:. smartload survey.sav, search("C:\Users\YOURNAME\Downloads") clear}{p_end}
{phang2}{cmd:. smartload mydata.csv, search("D:\Research") clear}{p_end}
{phang2}{cmd:. smartload mydata.xlsx, search("D:\Research;E:\Data;F:\Backup") clear}{p_end}
{phang2}{cmd:. smartload mydata.xlsx, drives(C D E F) clear}{p_end}
{phang2}{cmd:. smartload mydata.xlsx, drives(all) force clear}{p_end}
{phang2}{cmd:. smartload report.pdf, search("D:\Research") pdftable(1) clear}{p_end}

{title:Performance warnings}

{pstd}
Whole-drive recursive search can be slow, especially on mapped network drives
and large external drives.  Prefer specific {cmd:search()} roots when possible.

{title:Safety limitations}

{pstd}
{cmd:smartload} is for data files and extractable rectangular tables only.  It
does not process images, video, audio, executables, unknown binary files, or
adult media.  It does not use OCR by default.

{title:License}

{pstd}
MIT License.  See {cmd:LICENSE} in the distribution files.

{title:Author}

{pstd}
Hao Ma.
