{smcl}
{* *! version 0.3.3 10jul2026}{...}
{vieweralsosee "[D] import" "help import"}{...}
{vieweralsosee "[D] use" "help use"}{...}
{title:Title}

{p2colset 5 20 22 2}{...}
{p2col:{hi:smartload} {hline 2}}Find a named data file and load it into Stata{p_end}
{p2colreset}{...}

{title:Syntax}

{p 8 17 2}
{cmd:smartload} {it:filename}
[{cmd:,}
{cmd:clear}
{cmd:choice(}{it:#}{cmd:)}
{cmd:roots(}{it:roots}{cmd:)}
{cmd:sheet(}{it:sheetname}{cmd:)}
{cmd:firstrow}
{cmd:encoding(}{it:encoding}{cmd:)}
{cmd:log}
{cmd:replace}
{cmd:maxdirs(}{it:#}{cmd:)}]

{p 8 17 2}
{cmd:smartload, setup}

{p 8 17 2}
{cmd:smartload, installes}

{p 8 17 2}
{cmd:smartload, refresh}
[{cmd:roots(}{it:roots}{cmd:)}
{cmd:drives(}{it:drive-list|all}{cmd:)}]

{title:Description}

{pstd}
{cmd:smartload} loads a data file by exact file name.  The user does not need
to remember the folder path.  Version 0.3.3 first uses Everything's
{cmd:es.exe} on Windows if available, then searches the saved
{cmd:smartload_index.dta}; if there is no match, it runs a bounded fast search
over common user locations.

{pstd}
Daily use:

{phang2}{cmd:. smartload Indicator.dta, clear}{p_end}
{phang2}{cmd:. smartload survey.sav, clear}{p_end}
{phang2}{cmd:. smartload panel.parquet, clear}{p_end}

{pstd}
Recommended first setup:

{phang2}{cmd:. smartload, setup}{p_end}

{title:Options}

{phang}
{cmd:setup} opens an interactive menu:
1. index common user folders; 2. index current project folder;
3. index selected folders; 4. deep full-drive index (slow).

{phang}
{cmd:installes} downloads the official 64-bit Everything command-line
interface, {cmd:ES-1.1.0.30.x64.zip}, from voidtools and places
{cmd:es.exe} under the user's PERSONAL ado folder in {cmd:smartload_bin}.
It first tries Stata's downloader and then Windows {cmd:curl.exe}.  This
option is for Windows.  It installs only ES, not Everything itself.
Everything must already be installed and running for ES searches to work.

{phang}
{cmd:refresh} rebuilds the Stata file index.  Without {cmd:roots()} or
{cmd:drives()}, common user folders are indexed.  Full-drive indexing is never
the default.

{phang}
{cmd:roots(}{it:roots}{cmd:)} restricts an index refresh or lookup to one or
more roots.  Separate multiple roots with semicolons.

{phang}
{cmd:drives(}{it:drive-list|all}{cmd:)} indexes selected drive roots when used
with {cmd:refresh}.  {cmd:drives(all)} can be slow on large computers.

{phang}
{cmd:choice(}{it:#}{cmd:)} selects a file when several files have the same
name.  Interactive Stata users can instead type the displayed number when
prompted.

{phang}
{cmd:clear}, {cmd:sheet()}, {cmd:firstrow}, and {cmd:encoding()} are passed to
the relevant Stata import commands.

{phang}
{cmd:maxdirs(}{it:#}{cmd:)} controls the folder budget for automatic fast
search after an index miss.  The default is {cmd:maxdirs(2500)}.

{pstd}
On Windows, Everything must expose the command-line interface {cmd:es.exe} for
automatic use by {cmd:smartload}.  If Everything is installed but {cmd:es.exe}
is missing, run {cmd:smartload, installes}.  If Everything itself is not
installed or not running, {cmd:smartload} falls back to its Stata index/search
path.

{title:Supported Native Formats}

{pstd}
{cmd:.dta} via {cmd:use}; {cmd:.xlsx} and {cmd:.xls} via {cmd:import excel};
{cmd:.csv}, {cmd:.txt}, {cmd:.tsv}, and text-like {cmd:.dat} via
{cmd:import delimited}; {cmd:.sav} and {cmd:.por} via {cmd:import spss};
{cmd:.sas7bdat} via {cmd:import sas}; {cmd:.xpt} via {cmd:import sasxport};
{cmd:.parquet} via {cmd:import parquet}.

{pstd}
For SPSS files, {cmd:smartload} uses Stata's native {cmd:import spss} so
variable labels and value labels are preserved whenever Stata can preserve
them.

{title:Detected But Not Imported}

{pstd}
R files ({cmd:.rds}, {cmd:.rda}, {cmd:.RData}, {cmd:.r}) are detected but not
imported automatically.  Convert them in R to {cmd:.dta}, {cmd:.parquet}, or
{cmd:.csv}, then run {cmd:smartload} again.

{pstd}
DOCX, PPTX, and PDF files may contain tables, but they are document containers.
Version 0.3.3 detects them but does not claim accurate table extraction.

{title:Duplicate File Names}

{pstd}
If the same file name appears in multiple locations, {cmd:smartload} displays
all matching paths with Arabic numerals:

{p 8 12 2}
1. C:/folder/Indicator.dta{break}
2. F:/folder/Indicator.dta
{p_end}

{pstd}
In interactive Stata, type the number to import.  In batch mode, use
{cmd:choice(#)}.

{title:Examples}

{phang2}{cmd:. smartload, setup}{p_end}
{phang2}{cmd:. smartload, installes}{p_end}
{phang2}{cmd:. smartload Indicator.dta, clear}{p_end}
{phang2}{cmd:. smartload Indicator.dta, choice(2) clear}{p_end}
{phang2}{cmd:. smartload city.sas7bdat, clear}{p_end}
{phang2}{cmd:. smartload lake.parquet, clear}{p_end}
{phang2}{cmd:. smartload workbook.xlsx, sheet("Sheet1") firstrow clear}{p_end}
{phang2}{cmd:. smartload, refresh roots("F:\Project;G:\Data")}{p_end}
{phang2}{cmd:. smartload, refresh drives(all)}   // slow{p_end}

{title:Returned Results}

{pstd}
After successful import, {cmd:smartload} returns {cmd:r(filepath)},
{cmd:r(filename)}, {cmd:r(extension)}, {cmd:r(importcmd)}, {cmd:r(storage)},
{cmd:r(indexfile)}, {cmd:r(N)}, and {cmd:r(k)}.

{title:License}

{pstd}
MIT License.  See {cmd:LICENSE}.

{title:Author}

{pstd}
Hao Ma.
