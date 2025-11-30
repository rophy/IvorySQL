# DBMS_UTILITY Design Documentation

Design documentation for IvorySQL's first Oracle-compatible DBMS package.

## Implementation Summary

**DBMS_UTILITY** is implemented in `src/pl/plisql/src/` as part of the PL/iSQL extension.

```
src/pl/plisql/src/
├── pl_dbms_utility.c           ← C implementation (format transformation)
├── pl_exec.c                   ← Session-level exception context storage
├── plisql.h                    ← API export declaration
├── plisql--1.0.sql             ← Package definition
├── sql/dbms_utility.sql        ← Regression tests
└── expected/dbms_utility.out   ← Expected test output
```

**Current Functions:**
- `FORMAT_ERROR_BACKTRACE` - Returns Oracle-formatted call stack in exception handlers

## Key Design Decisions

1. **Location:** `src/pl/plisql/src/` (not `contrib/ivorysql_ora/`)
   - Avoids cross-module dependencies
   - Has direct access to PL/iSQL exception handling

2. **Exception Context Storage:** Session-level static variable in `pl_exec.c`
   - Stored when entering exception handler
   - Retrieved via `plisql_get_current_exception_context()` API
   - Cleared when exiting exception handler

3. **Output Format:** Transforms PostgreSQL error context to Oracle format
   - `ORA-06512: at "SCHEMA.FUNCTION", line N`
   - `ORA-06512: at line N` (for anonymous blocks)

## Documents

| Document | Description |
|----------|-------------|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Implementation details and rationale |
| [DEPENDENCY_ANALYSIS.md](./DEPENDENCY_ANALYSIS.md) | Analysis of cross-module dependency problem |
| [EXISTING_PACKAGES.md](./EXISTING_PACKAGES.md) | Survey of Oracle packages in IvorySQL |

## Implementation Status

- ✅ FORMAT_ERROR_BACKTRACE implemented
- ✅ Regression tests passing
- ⏳ Future: FORMAT_ERROR_STACK, FORMAT_CALL_STACK

## References

- [Oracle DBMS_UTILITY Documentation](https://docs.oracle.com/en/database/oracle/oracle-database/23/arpls/DBMS_UTILITY.html)
- [IvorySQL Documentation](https://www.ivorysql.org/docs/)

---

**Last Updated:** 2025-11-30
