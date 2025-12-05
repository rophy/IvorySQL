# DBMS_UTILITY Architecture

## Context

IvorySQL is implementing Oracle-compatible DBMS packages. This document describes the architectural decisions for DBMS_UTILITY implementation.

## Implementation Summary

**DBMS_UTILITY** is the **first** built-in Oracle DBMS package in IvorySQL.

**Location:** `src/pl/plisql/src/` (part of PL/iSQL extension)

**Files:**
- `pl_dbms_utility.c` - C implementation of FORMAT_ERROR_BACKTRACE
- `pl_exec.c` - Session-level exception context storage and retrieval API
- `plisql.h` - Function declaration export
- `plisql--1.0.sql` - Package definition (CREATE PACKAGE)

**Functions Implemented:**
- `FORMAT_ERROR_BACKTRACE` - Returns Oracle-formatted call stack during exception handling

## Architecture Decision

**Decision:** DBMS_UTILITY lives entirely in `src/pl/plisql/src/` as part of the PL/iSQL extension.

**Rationale:**
1. FORMAT_ERROR_BACKTRACE needs access to PL/iSQL exception context
2. Keeping it in `plisql` avoids cross-module dependencies
3. `plisql` and `ivorysql_ora` remain independent modules (upstream design)
4. Package is available immediately after `CREATE EXTENSION plisql`

### Module Structure

IvorySQL has two independent modules:

1. **PL/iSQL Language Runtime** (`src/pl/plisql/src/` → `plisql.so`)
   - PL/iSQL procedural language implementation
   - **Now includes:** DBMS_UTILITY package (for functions needing PL/iSQL internals)

2. **Oracle Compatibility Extension** (`contrib/ivorysql_ora/` → `ivorysql_ora.so`)
   - Oracle-compatible datatypes and functions
   - Independent of PL/iSQL internals

## Implementation Details

### Exception Context Storage

The key challenge is accessing exception context from a C function that's called from PL/iSQL package body.

**Solution:** Session-level storage in `pl_exec.c`

```c
// pl_exec.c - Static session storage
static char *plisql_current_exception_context = NULL;

// When entering exception handler (in exec_stmt_block):
if (edata->context)
{
    plisql_current_exception_context =
        MemoryContextStrdup(TopMemoryContext, edata->context);
}

// When exiting exception handler:
if (plisql_current_exception_context)
{
    pfree(plisql_current_exception_context);
    plisql_current_exception_context = NULL;
}

// Public API for retrieval
const char *
plisql_get_current_exception_context(void)
{
    return plisql_current_exception_context;
}
```

**Why this approach:**
1. Exception context is stored when entering handler (before user code runs)
2. C function can retrieve it via public API without accessing `PLiSQL_execstate`
3. Context is cleared after exception handling completes
4. Memory allocated in `TopMemoryContext` survives function calls

### C Function Implementation

`pl_dbms_utility.c` transforms PostgreSQL error context to Oracle format:

```c
// Input (PostgreSQL format):
"PL/iSQL function test_level3() line 3 at RAISE"
"SQL statement \"CALL test_level3()\""
"PL/iSQL function test_level2() line 3 at CALL"

// Output (Oracle format):
"ORA-06512: at \"PUBLIC.TEST_LEVEL3\", line 3\n"
"ORA-06512: at \"PUBLIC.TEST_LEVEL2\", line 3\n"
```

Key transformations:
- Skip "SQL statement" lines
- Extract function name and line number from "PL/iSQL function" lines
- Convert to uppercase for Oracle compatibility
- Handle anonymous blocks (`inline_code_block` → `at line N`)

### Package Definition

`plisql--1.0.sql`:

```sql
-- C function wrapper
CREATE FUNCTION sys.ora_format_error_backtrace() RETURNS TEXT
  AS 'MODULE_PATHNAME', 'ora_format_error_backtrace'
  LANGUAGE C VOLATILE STRICT;

-- Package specification
CREATE OR REPLACE PACKAGE dbms_utility IS
  FUNCTION FORMAT_ERROR_BACKTRACE RETURN TEXT;
END dbms_utility;

-- Package body (calls C function)
CREATE OR REPLACE PACKAGE BODY dbms_utility IS
  FUNCTION FORMAT_ERROR_BACKTRACE RETURN TEXT IS
  BEGIN
    RETURN sys.ora_format_error_backtrace();
  END;
END dbms_utility;
```

**Note:** The extension SQL uses Oracle package syntax directly. The `CREATE EXTENSION plisql` runs in Oracle mode context (set by initdb.c's `load_plisql()`).

### initdb.c Integration

```c
// In load_plisql():
PG_CMD_PUTS("SET ivorysql.identifier_case_from_pg_dump TO true;\n");
PG_CMD_PUTS("CREATE EXTENSION plisql;\n");
```

The extension loads in Oracle mode context during `initdb -m oracle`.

## Guidelines for Future DBMS Packages

| Package Needs | Location |
|--------------|----------|
| PL/iSQL internals (exception context, call stack, etc.) | `src/pl/plisql/src/` |
| Only Oracle datatypes, no PL/iSQL internals | `contrib/ivorysql_ora/` |
| Both PL/iSQL internals AND Oracle types | Split: C in plisql, SQL wrapper in ivorysql_ora |

## Testing

Regression tests in `src/pl/plisql/src/sql/dbms_utility.sql` cover:
- Basic exception handling
- Nested procedure calls (3+ levels deep)
- Function calls
- Anonymous blocks
- No exception context (returns NULL)
- Re-raised exceptions
- Package procedures
- Schema-qualified calls

Run tests: `cd src/pl/plisql/src && make oracle-check`

## Implementation Status

- ✅ Architecture decision documented
- ✅ C function in `pl_dbms_utility.c`
- ✅ Session storage API in `pl_exec.c`
- ✅ Package definition in `plisql--1.0.sql`
- ✅ Regression tests (9 test cases)
- ✅ All plisql oracle-check tests passing

---

**Last Updated:** 2025-11-30
