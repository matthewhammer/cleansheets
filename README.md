
CleanSheets
===============================================

A [spreadsheet-like application](https://en.wikipedia.org/wiki/Spreadsheet) for the [Internet Computer](https://dfinity.org/faq/what-is-the-internet-computer), written in [Motoko](https://dfinity.org/faq/what-is-motoko).

#### Current status: _Early days.  First steps are complete, but require more testing._

Foundation and first steps
-------------------------------
- Simple **expression language** based on ideas from existing functional and dataflow languages.
- Expressive **value language** where each "sheet" or "cell" may have internal structures, nesting and cross-linking.
- Dependency graph and incremental recomputation based on ideas from the [Adapton project](http://adapton.org).

Long-term, aspirational milestones
----------------------------------
- Emulate common use cases of existing spreadsheets (Excel, GoogleSheets, etc.).
- Emulate common use cases of [Jupyter lab notebooks](https://jupyter.org/).
- _Distributed_ dependency graphs that span multiple Internet Computer canisters (novel feature).

Build status
-------------

[![travis-status](https://travis-ci.org/matthewhammer/cleansheets.svg?branch=master)](https://travis-ci.org/matthewhammer/cleansheets)



-------------




