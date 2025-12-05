# IvorySQL Built-in Oracle Packages

## Summary

As of November 2025, IvorySQL upstream has **ZERO** built-in Oracle DBMS packages.

**DBMS_UTILITY** is the **first** Oracle-compatible DBMS package implemented for IvorySQL.

## Current State

### Upstream IvorySQL

IvorySQL provides:
- ✅ Oracle package syntax (CREATE PACKAGE, package spec/body)
- ✅ Oracle-compatible datatypes (VARCHAR2, NUMBER, DATE, etc.)
- ✅ Oracle-compatible functions (NVL, DECODE, TO_CHAR, etc.)
- ❌ No built-in DBMS packages

### This Implementation

**DBMS_UTILITY** (first package):
- Location: `src/pl/plisql/src/` (part of PL/iSQL extension)
- Functions: FORMAT_ERROR_BACKTRACE ✅
- Status: Implemented and tested

## Comparison with Oracle

Oracle Database provides 100+ built-in DBMS packages. Common ones:

| Package | Oracle | IvorySQL |
|---------|--------|----------|
| DBMS_OUTPUT | ✅ | ✅ (via plisql) |
| DBMS_UTILITY | ✅ | 🚧 1 function |
| DBMS_RANDOM | ✅ | ❌ |
| DBMS_SQL | ✅ | ❌ |
| DBMS_LOB | ✅ | ❌ |
| DBMS_SCHEDULER | ✅ | ❌ |

## Architecture Pattern

DBMS_UTILITY establishes the pattern for future packages:

| Package Needs | Location |
|--------------|----------|
| PL/iSQL internals | `src/pl/plisql/src/` |
| Oracle datatypes only | `contrib/ivorysql_ora/` |
| Both | Split implementation |

## References

- [Oracle DBMS_UTILITY](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_UTILITY.html)
- [IvorySQL Packages](https://www.ivorysql.org/docs/compatibillity_features/package/)

---

**Last Updated:** 2025-11-30
