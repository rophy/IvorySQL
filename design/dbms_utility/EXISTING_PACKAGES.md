# IvorySQL Built-in Oracle Packages - Current State

## Summary

As of November 2025, IvorySQL upstream **does NOT have any built-in Oracle DBMS packages**. DBMS_UTILITY is the **first** Oracle-compatible DBMS package being implemented.

## Research Findings

### Web Search Results

**IvorySQL Documentation:**
- Official docs at ivorysql.org mention **package syntax support** (CREATE PACKAGE, package spec/body)
- Documentation shows **how to create custom packages** but does NOT list built-in DBMS packages
- Blog post "Introduction to IvorySQL Packages" demonstrates user-defined packages only
- No mention of DBMS_UTILITY, DBMS_RANDOM, or other Oracle built-in packages

**Orafce Extension:**
- IvorySQL imports and enhances the **Orafce extension** for Oracle compatibility
- Orafce provides: Oracle-compatible datatypes, functions, and conversion utilities
- However, **current IvorySQL upstream does NOT include any DBMS packages from Orafce**

### Git History Analysis

**Upstream Master Branch:**
```bash
$ git ls-tree --name-only upstream/master contrib/ivorysql_ora/src/builtin_functions/
builtin_functions--1.0.sql
character_datatype_functions.c
datetime_datatype_functions.c
misc_functions.c
numeric_datatype_functions.c
```

**No DBMS packages in upstream.**

## Current Development Work

### DBMS_UTILITY Package

**Status:** In development (not merged upstream)

**Location (current, to be refactored):**
```
contrib/ivorysql_ora/src/builtin_functions/
├── dbms_utility.c          (C implementation)
└── dbms_utility--1.0.sql   (SQL package wrapper)

contrib/ivorysql_ora/sql/
└── dbms_utility.sql        (regression tests)
```

**Functions Implemented:**
1. `FORMAT_ERROR_BACKTRACE() RETURN TEXT` ✅

**Functions Planned:**
- `FORMAT_ERROR_STACK() RETURN TEXT`
- `FORMAT_CALL_STACK() RETURN TEXT`
- (More Oracle DBMS_UTILITY functions TBD)

**Key Implementation Detail:**
- Requires access to PL/iSQL exception context (`PLiSQL_execstate`)
- Current implementation includes `plisql.h` from `src/pl/plisql/src/`
- Creates **cross-module dependency** (to be resolved - see ARCHITECTURE.md)

## Comparison with Oracle

### Oracle Database 23c Built-in Packages

Oracle provides **hundreds** of built-in PL/SQL packages, including:

**Most Common DBMS Packages:**
- DBMS_OUTPUT (messaging/debugging)
- DBMS_RANDOM (random number generation)
- DBMS_UTILITY (utility functions)
- DBMS_SQL (dynamic SQL)
- DBMS_LOB (large objects)
- DBMS_SCHEDULER (job scheduling)
- DBMS_METADATA (metadata extraction)
- DBMS_CRYPTO (encryption/hashing)
- And 100+ more...

**IvorySQL Status:**
- 🚧 DBMS_UTILITY: 1/30+ functions implemented (~3%) - first package
- ❌ All other packages: 0%

## Implications for Architecture

### DBMS_UTILITY as First Package

Since DBMS_UTILITY is the **first** built-in DBMS package, the architectural decisions made here will set the pattern for future packages.

### Design Issue Identified

DBMS_UTILITY needs **PL/iSQL internals**, which initially created:
- Cross-module dependency (`contrib` → `src/pl/plisql`)
- Layering violation (extension accessing language private headers)

**Resolution:** Move DBMS_UTILITY to `src/pl/plisql/src/` (see ARCHITECTURE.md for decision details).

## References

- **IvorySQL Docs:** https://www.ivorysql.org/docs/compatibillity_features/package/
- **Oracle DBMS_UTILITY:** https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_UTILITY.html
- **Orafce Project:** https://github.com/orafce/orafce

---

**Document Status:** Research complete, decision made
**Last Updated:** 2025-11-30
**Authors:** Rophy Tsai, Claude
