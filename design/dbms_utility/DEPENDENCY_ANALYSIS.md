# Cross-Module Dependency Analysis

## The Problem

DBMS_UTILITY's `FORMAT_ERROR_BACKTRACE` needs PL/iSQL exception context. This document analyzes the dependency problem and the chosen solution.

## Module Structure

IvorySQL has two independent modules:

```
src/pl/plisql/src/          →  plisql.so (language runtime)
contrib/ivorysql_ora/       →  ivorysql_ora.so (Oracle compatibility)
```

**Upstream design:** These modules have NO cross-dependencies.

## The Challenge

```
User SQL:
  DBMS_UTILITY.FORMAT_ERROR_BACKTRACE

↓ Needs access to

PL/iSQL Exception Context:
  - Error message and context string
  - Call stack information
  - Only available inside exception handler
```

## Why Cross-Module Dependency Is Bad

If `ivorysql_ora.so` included `plisql.h`:

1. **Layering Violation:** Extension depends on language internals
2. **Encapsulation Break:** Internal structures exposed
3. **Maintenance Burden:** Changes to PL/iSQL break extension
4. **Binary Compatibility:** Version coupling between shared libraries

## Solution: Keep It In PL/iSQL

**Decision:** Implement DBMS_UTILITY entirely in `src/pl/plisql/src/`

### Implementation Approach

Instead of accessing `PLiSQL_execstate` directly from a C function, use session-level storage:

```c
// pl_exec.c - Session storage
static char *plisql_current_exception_context = NULL;

// Store context when entering exception handler
// (in exec_stmt_block, within PG_CATCH block)
if (edata->context)
{
    plisql_current_exception_context =
        MemoryContextStrdup(TopMemoryContext, edata->context);
}

// Public API for retrieval
const char *
plisql_get_current_exception_context(void)
{
    return plisql_current_exception_context;
}
```

### Why This Works

1. **Exception handler stores context:** When PL/iSQL catches an exception, it saves the context string in session storage before user code runs.

2. **C function retrieves via API:** The `ora_format_error_backtrace()` function calls `plisql_get_current_exception_context()` - a simple public API.

3. **No direct struct access:** The C function doesn't need to know about `PLiSQL_execstate` internals.

4. **Clean memory management:** Context stored in `TopMemoryContext`, cleared when exiting handler.

### Data Flow

```
1. Exception occurs in PL/iSQL code
   ↓
2. PL/iSQL catches exception (PG_CATCH in exec_stmt_block)
   ↓
3. Context stored: plisql_current_exception_context = edata->context
   ↓
4. User's EXCEPTION block runs
   ↓
5. User calls DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
   ↓
6. Package body calls sys.ora_format_error_backtrace()
   ↓
7. C function calls plisql_get_current_exception_context()
   ↓
8. Returns stored context string
   ↓
9. C function transforms to Oracle format
   ↓
10. Exception handler exits, context cleared
```

## Alternatives Considered

### Alternative: Public API in PL/iSQL (Not Chosen)

Export exception context via SQL-callable function:

```c
// plisql.so exports:
PG_FUNCTION_INFO_V1(plisql_get_exception_context);

// ivorysql_ora.so calls:
DirectFunctionCall0(plisql_get_exception_context);
```

**Why not chosen:** More complex, still requires coordination between modules. Simpler to keep everything in one place.

### Alternative: Use Core PostgreSQL Error System (Not Chosen)

Access `ErrorData` from PostgreSQL's elog.c instead of PL/iSQL.

**Why not chosen:** The error context string with PL/iSQL procedure names and line numbers is only available through PL/iSQL's exception handling.

## Final Architecture

```
src/pl/plisql/src/
├── pl_exec.c               ← Exception context storage + API
├── pl_dbms_utility.c       ← Format transformation
├── plisql.h                ← API declaration
└── plisql--1.0.sql         ← Package definition
```

**Benefits:**
- ✅ No cross-module dependency
- ✅ Self-contained in PL/iSQL
- ✅ Clean public API (`plisql_get_current_exception_context`)
- ✅ Respects upstream module boundaries

---

**Status:** Implemented
**Last Updated:** 2025-11-30
