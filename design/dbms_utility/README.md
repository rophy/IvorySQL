# DBMS_UTILITY Design Documentation

This directory contains design documentation and architectural discussions for implementing Oracle-compatible DBMS packages in IvorySQL.

## Decision Summary

**Decision:** Put DBMS_UTILITY entirely in `src/pl/plisql/src/`

```
src/pl/plisql/src/
├── pl_dbms_utility.c           ← C implementation
├── plisql--1.0.sql             ← CREATE FUNCTION + CREATE PACKAGE
└── Makefile                    ← Add pl_dbms_utility.o to OBJS
```

**Rationale:**
- DBMS_UTILITY needs PL/iSQL internals (exception context)
- Upstream IvorySQL has `plisql` and `ivorysql_ora` as independent modules
- Putting it in `plisql` avoids introducing cross-module dependencies
- `plisql--1.0.sql` runs at `CREATE EXTENSION plisql` time, when the language is available
- DBMS_UTILITY doesn't need Oracle types, so no dependency on `ivorysql_ora`

See [ARCHITECTURE.md](./ARCHITECTURE.md) for full decision details.

## Documents

### 1. [ARCHITECTURE.md](./ARCHITECTURE.md)
**Architectural decision and rationale** ✅ DECISION MADE

Contains:
- Analysis of two architectures (contrib-based vs. PL/iSQL-based)
- Load order analysis (`initdb -m oracle` sequence)
- Final decision: Architecture 2 (PL/iSQL-based)
- Guidelines for future DBMS packages

### 2. [EXISTING_PACKAGES.md](./EXISTING_PACKAGES.md)
**Status of built-in Oracle packages in IvorySQL**

Key findings:
- IvorySQL upstream has **ZERO** built-in DBMS packages
- DBMS_UTILITY is the **first** built-in package being implemented
- Web search confirms: No pre-existing DBMS packages in IvorySQL docs

### 3. [DEPENDENCY_ANALYSIS.md](./DEPENDENCY_ANALYSIS.md)
**Deep dive into the cross-module dependency problem**

Detailed analysis:
- Why DBMS_UTILITY needs PL/iSQL internals (exception context)
- Why cross-module dependency is problematic (layering violation)
- How PostgreSQL/EPAS/Orafce handle similar issues

## Guidelines for Future DBMS Packages

| Package Needs | Location |
|--------------|----------|
| PL/iSQL internals (exception context, call stack, etc.) | `src/pl/plisql/src/` |
| Only Oracle datatypes, no PL/iSQL internals | `contrib/ivorysql_ora/` |
| Both PL/iSQL internals AND Oracle types | Split: C in plisql, SQL wrapper in ivorysql_ora |

## Current Status

**DBMS_UTILITY:**
- ✅ FORMAT_ERROR_BACKTRACE implemented (in contrib, needs refactoring)
- ✅ Architecture decision made
- ⏳ Refactor to `src/pl/plisql/src/`
- ⏳ More functions to implement (FORMAT_ERROR_STACK, FORMAT_CALL_STACK, etc.)

## Next Steps

1. ✅ Document architecture decision
2. ⏳ Refactor DBMS_UTILITY to `src/pl/plisql/src/`
3. ⏳ Update regression tests
4. ⏳ Update CLAUDE.md with guidelines
5. ⏳ Continue DBMS_UTILITY implementation (more functions)

## References

**IvorySQL:**
- Website: https://www.ivorysql.org/
- Docs: https://www.ivorysql.org/docs/
- GitHub: https://github.com/IvorySQL/IvorySQL

**Oracle Documentation:**
- DBMS_UTILITY: https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_UTILITY.html

**Related Projects:**
- Orafce: https://github.com/orafce/orafce (Oracle compatibility for PostgreSQL)
- EDB EPAS: https://www.enterprisedb.com/ (Commercial Oracle-compatible PostgreSQL)

---

**Last Updated:** 2025-11-30
**Authors:** Rophy Tsai, Claude
**Status:** Decision made, implementation pending
