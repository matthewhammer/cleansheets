
CleanSheets
===============================================

A [spreadsheet-like application](https://en.wikipedia.org/wiki/Spreadsheet) for the [Internet Computer](https://dfinity.org), written in [Motoko](https://dfinity.org/faq/what-is-motoko).

Foundation and first steps
-------------------------------
- [x] Simple **expression language** based on ideas from existing functional and dataflow languages.
- [x] Expressive **value language** where each "sheet" or "cell" may have internal structures, nesting and cross-linking.
- [x] **Dependency graph** and **incremental recomputation**, based on a proven, formal theory ([Adapton project](http://adapton.org)).
  - [x] Emulate simple spreadsheet features (Excel, GoogleSheets, etc.).
  - [x] Emulate simple lab notebook features (e.g., a [Jupyter lab notebook](https://jupyter.org/)).
  - [ ] _Distributed_ dependency graphs that span multiple Internet Computer canisters (novel feature).

Future scope
---------------------
 - See also: [personal information management](https://en.wikipedia.org/wiki/Personal_information_manager#Scope).
 - Emulate other personal information management ideas in the Cloud today:
   - e.g., https://roamresearch.com/
 - Emulate uses of Cloud-based "end-user programming":
   - e.g., https://airtable.com/
 - _Replace_ (make obsolete) uses of Cloud-based "full-stack programming":
   - e.g., https://glitch.com/

Build status
-------------

[![travis-status](https://travis-ci.org/matthewhammer/cleansheets.svg?branch=master)](https://travis-ci.org/matthewhammer/cleansheets)



-------------




