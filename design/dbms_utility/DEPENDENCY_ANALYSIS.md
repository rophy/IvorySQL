# Cross-Module Dependency Analysis

## The Problem

DBMS_UTILITY's `FORMAT_ERROR_BACKTRACE` function needs to access PL/iSQL's exception context, creating a cross-module dependency.

## Current Implementation

### Module Structure

IvorySQL has two separate compilation units:

```
src/pl/plisql/src/          →  plisql.so (language runtime)
contrib/ivorysql_ora/       →  ivorysql_ora.so (Oracle compatibility extension)
```

These compile to **separate shared libraries** that are loaded independently.

### Dependency Chain

```
User SQL:
  DBMS_UTILITY.FORMAT_ERROR_BACKTRACE

↓ Calls (via package body)

C Function (in ivorysql_ora.so):
  sys.ora_format_error_backtrace()

↓ Needs access to

PL/iSQL Internals (in plisql.so):
  PLiSQL_execstate->err_text
  Error stack information
  Exception context
```

### Current Implementation Files

**contrib/ivorysql_ora/src/builtin_functions/dbms_utility.c:**
```c
#include "postgres.h"
#include "plisql.h"  // ← From src/pl/plisql/src/plisql.h

PG_FUNCTION_INFO_V1(ora_format_error_backtrace);

Datum
ora_format_error_backtrace(PG_FUNCTION_ARGS)
{
    // Needs access to:
    PLiSQL_execstate *estate = ...;  // PL/iSQL execution state
    char *err_text = estate->err_text;  // Exception context
    // ...
}
```

**contrib/ivorysql_ora/Makefile (line 79):**
```makefile
# Include path for PL/iSQL headers (needed for DBMS_UTILITY.FORMAT_ERROR_BACKTRACE)
PG_CPPFLAGS += -I$(top_srcdir)/src/pl/plisql/src
```

## Why This Is Problematic

### 1. Layering Violation

```
┌─────────────────────────────────┐
│  User Code                      │
└─────────────────┬───────────────┘
                  │
┌─────────────────▼───────────────┐
│  contrib/ivorysql_ora           │  ← Extension layer
│  (Oracle compatibility)         │
└─────────────────┬───────────────┘
                  │
                  │ ❌ SHOULD NOT ACCESS INTERNALS
                  │
┌─────────────────▼───────────────┐
│  src/pl/plisql/src              │  ← Language layer
│  (PL/iSQL runtime internals)    │
└─────────────────────────────────┘
```

**Principle:** Higher-level modules (extensions) should NOT depend on lower-level module internals.

### 2. Encapsulation Break

`plisql.h` contains **private implementation details**:
- `PLiSQL_execstate` structure layout
- Internal error handling mechanisms
- Memory management details

These are **not intended as a public API**. Changes to PL/iSQL internals will break `ivorysql_ora`.

### 3. Maintenance Burden

**Scenario:** PL/iSQL team refactors exception handling
```c
// Before (in plisql.h)
typedef struct PLiSQL_execstate {
    char *err_text;
} PLiSQL_execstate;

// After (refactored)
typedef struct PLiSQL_execstate {
    ErrorData *error_data;  // Changed!
} PLiSQL_execstate;
```

**Result:** `dbms_utility.c` breaks because it depends on internal structure.

### 4. Binary Compatibility

Two separate shared libraries (`plisql.so` and `ivorysql_ora.so`) must maintain **ABI compatibility**:
- If `plisql.so` is upgraded, `ivorysql_ora.so` may break
- Versioning becomes complex
- Testing matrix increases (all combinations of versions)

## Dependency Patterns in PostgreSQL

### How PL/pgSQL Handles This

PostgreSQL's PL/pgSQL **does NOT** expose internals to extensions. Instead:

**Option 1: Public API Functions**
```c
// In src/pl/plpgsql/src/pl_funcs.c (exported)
Datum plpgsql_get_error_info(PG_FUNCTION_ARGS) {
    // Access internals safely
    return internal_data;
}
```

Extensions call public functions, not access internals directly.

**Option 2: Callback Mechanism**
```c
// Language registers callbacks that extensions can use
void register_error_callback(ErrorCallbackFunc func);
```

**Option 3: Shared State in Core**
```c
// In src/backend/utils/error/elog.c (core PostgreSQL)
ErrorData *current_error_data;  // Accessible to all
```

All modules access shared state in core, not each other's internals.

### What IvorySQL Should Do

**Current (Bad):**
```
ivorysql_ora.so  →  #include "plisql.h"  →  Access internals directly
```

**Better (Good):**
```
ivorysql_ora.so  →  Call plisql_get_exception_context()  →  plisql.so handles internals
```

## Proposed Solutions

### Solution 1: Move DBMS_UTILITY to PL/iSQL

**Rationale:** If it needs PL/iSQL internals, it IS part of PL/iSQL.

```
src/pl/plisql/src/
├── pl_dbms_utility.c       ← Native implementation (can access internals)
├── plisql--1.0.sql         ← Export as sys.ora_format_error_backtrace()
└── plisql.h                ← No need to expose, internal use only

contrib/ivorysql_ora/
└── dbms_utility--1.0.sql   ← CREATE PACKAGE wrapper (calls plisql functions)
```

**Pros:**
- ✅ No cross-module dependency
- ✅ Clean encapsulation
- ✅ Natural architecture: "internal to language"

**Cons:**
- ❌ Splits DBMS packages across two locations
- ❌ Makes DBMS_UTILITY part of core (harder to make optional)

### Solution 2: Create Public API in PL/iSQL

**Rationale:** PL/iSQL exports exception info through a stable API.

```c
// In src/pl/plisql/src/pl_public_api.c (NEW FILE)
PG_FUNCTION_INFO_V1(plisql_get_exception_context);

Datum plisql_get_exception_context(PG_FUNCTION_ARGS) {
    // Access internal PLiSQL_execstate
    // Return formatted error info
    return error_context_string;
}
```

```c
// In contrib/ivorysql_ora/src/builtin_functions/dbms_utility.c
// NO #include "plisql.h" needed!

Datum ora_format_error_backtrace(PG_FUNCTION_ARGS) {
    // Call public API
    return DirectFunctionCall0(plisql_get_exception_context);
}
```

**Pros:**
- ✅ Keeps all DBMS packages in one location (contrib)
- ✅ Stable API (internals can change without breaking extension)
- ✅ Follows PostgreSQL patterns

**Cons:**
- ❌ More boilerplate (need public API layer)
- ❌ PL/iSQL must maintain backward compatibility for API

### Solution 3: Use Core PostgreSQL Error System

**Rationale:** PostgreSQL core already tracks errors; use that instead.

```c
// In contrib/ivorysql_ora/src/builtin_functions/dbms_utility.c
#include "utils/elog.h"  // Core PostgreSQL, not plisql.h

Datum ora_format_error_backtrace(PG_FUNCTION_ARGS) {
    ErrorData *edata = current_error_data;  // From core
    // Format Oracle-style backtrace
    return backtrace_string;
}
```

**Pros:**
- ✅ No dependency on PL/iSQL
- ✅ Works with ANY procedural language (PL/Python, PL/Perl, etc.)
- ✅ Most general solution

**Cons:**
- ❌ PostgreSQL's error context format differs from Oracle's
- ❌ May not have PL/iSQL-specific details (procedure names, line numbers)
- ❌ Requires translation layer

## Recommendation

**Use Solution 1 for now, plan for Solution 2 long-term:**

1. **Short-term (current implementation):**
   - Move `dbms_utility.c` to `src/pl/plisql/src/pl_dbms_utility.c`
   - Keep SQL wrapper in `contrib/ivorysql_ora/`
   - Clean dependency: no cross-module includes

2. **Long-term (if more extensions need error context):**
   - Extract public API: `src/pl/plisql/src/pl_public_api.c`
   - Export stable functions for exception context
   - Move `pl_dbms_utility.c` back to `contrib` using public API

3. **Future consideration:**
   - If many DBMS packages need PL/iSQL internals, they should ALL be in `src/pl/plisql/src/`
   - If only DBMS_UTILITY needs it, keep it there as a special case

## Comparison with Other Systems

### Oracle

Oracle's DBMS packages are **part of the database core**, not extensions:
- Built into the database binary
- No separation between "language" and "packages"
- Tightly integrated with PL/SQL runtime

### EDB Postgres Advanced Server (EPAS)

EPAS implements Oracle compatibility as **built-in features**:
- Not separate extensions
- DBMS packages compiled into server
- Similar to Solution 1 (part of core)

### Orafce (PostgreSQL Extension)

Orafce implements Oracle compatibility as a **pure extension**:
- Does NOT access PL/pgSQL internals
- Reimplements functionality using PostgreSQL public APIs
- Similar to Solution 3 (use core APIs only)

## Decision Criteria

**Choose Solution 1 if:**
- Tight coupling to PL/iSQL is acceptable
- We want native Oracle behavior (exact error formats)
- We're okay with DBMS packages as "part of the language"

**Choose Solution 2 if:**
- We want clean separation of concerns
- We expect many extensions to need error context
- We value modularity and independent versioning

**Choose Solution 3 if:**
- We want maximum portability
- We're okay with "Oracle-like" instead of "exact Oracle"
- We want DBMS packages to work with any procedural language

---

**Document Status:** Analysis complete, decision pending
**Last Updated:** 2025-11-30
**Authors:** Rophy Tsai, Claude
