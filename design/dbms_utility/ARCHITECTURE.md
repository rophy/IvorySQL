# DBMS_UTILITY Architecture Discussion

## Context

IvorySQL is implementing Oracle-compatible DBMS packages. This document discusses the architectural decisions for where DBMS package implementations should live in the codebase.

## Current State

### Existing Built-in Packages

As of Nov 2025, IvorySQL upstream has **ZERO** built-in DBMS packages.

**DBMS_UTILITY** (current work)
- Location: `contrib/ivorysql_ora/src/builtin_functions/dbms_utility.c` (to be refactored)
- Status: In development
- Functions: FORMAT_ERROR_BACKTRACE (and more planned)

This is the **first** built-in Oracle DBMS package being implemented for IvorySQL.

### IvorySQL Module Structure

IvorySQL has two key modules that compile into separate shared libraries:

1. **PL/iSQL Language Runtime** (`src/pl/plisql/src/`)
   - Compiles to: `plisql.so`
   - Purpose: PL/iSQL procedural language implementation
   - Components: Parser, compiler, executor, exception handling
   - Exports: Language handler, validator functions
   - Key files: `pl_handler.c`, `pl_exec.c`, `pl_comp.c`, `plisql.h`

2. **Oracle Compatibility Extension** (`contrib/ivorysql_ora/`)
   - Compiles to: `ivorysql_ora.so`
   - Purpose: Oracle-compatible datatypes, functions, and packages
   - Components: Datatypes (CHAR, VARCHAR2, DATE, etc.), built-in functions, DBMS packages
   - Key files: Various C implementations merged into one extension

## Architectural Question

**Where should DBMS package implementations live when they need access to PL/iSQL internals?**

### Two Possible Architectures

#### Architecture 1: Contrib-based (Current Implementation)

```
contrib/ivorysql_ora/
├── src/builtin_functions/
│   ├── dbms_utility.c          ← C implementation with PL/iSQL internals access
│   └── dbms_utility--1.0.sql   ← SQL package specification and body
└── Makefile
    ├── OBJS += dbms_utility.o
    └── PG_CPPFLAGS += -I$(top_srcdir)/src/pl/plisql/src  ← Cross-dependency!
```

**Key characteristic:** Extension code depends on language internals (cross-module dependency).

#### Architecture 2: PL/iSQL-based (Proposed)

```
src/pl/plisql/src/
├── dbms_utility.c              ← C implementation as part of language
├── plisql.h                    ← Exports function declarations
└── Makefile
    └── OBJS += dbms_utility.o

contrib/ivorysql_ora/
└── src/builtin_functions/
    └── dbms_utility--1.0.sql   ← SQL package wrapper calling plisql functions
```

**Key characteristic:** Language provides native functions; extension wraps them in Oracle syntax.

## Analysis

### Current Cross-Module Dependency

The current implementation requires `contrib/ivorysql_ora` to access PL/iSQL internals:

```c
// In contrib/ivorysql_ora/src/builtin_functions/dbms_utility.c
#include "plisql.h"  // From src/pl/plisql/src/

// Accesses:
// - PLiSQL_execstate (exception context)
// - Error stack information
// - PL/iSQL internal data structures
```

```makefile
# In contrib/ivorysql_ora/Makefile (line 79)
PG_CPPFLAGS += -I$(top_srcdir)/src/pl/plisql/src
```

This creates a **layering violation**: an extension (contrib) depends on a core language module's private headers.

### Trade-offs Comparison

| Aspect | Architecture 1 (Contrib) | Architecture 2 (PL/iSQL) |
|--------|-------------------------|--------------------------|
| **Dependency Direction** | Extension → Language (bad) | Language is self-contained (good) |
| **Code Organization** | All Oracle features in one place | Split: internals in language, wrappers in extension |
| **Versioning** | Can version extension independently | DBMS packages tied to language version |
| **Maintainability** | Cross-module changes harder | Changes contained in language module |
| **Encapsulation** | Violates module boundaries | Respects module boundaries |
| **Optionality** | Can load/unload extension | Always available with language |
| **Consistency** | All DBMS packages in same location | Some in language, some in extension |

### PostgreSQL Precedent

PostgreSQL's PL/pgSQL follows a similar pattern:

```
src/pl/plpgsql/src/
├── pl_exec.c          ← Language implementation
└── (exports functions that extensions can call)

contrib/extensions/
└── (use plpgsql functions without accessing internals)
```

**Key insight:** Extensions don't include `plpgsql.h` internals. If they need internal features, those features are exported as public functions.

## Recommendations

### Recommendation 1: Split by Coupling Level

**For DBMS packages that NEED PL/iSQL internals (like DBMS_UTILITY.FORMAT_ERROR_BACKTRACE):**

Put C implementation in `src/pl/plisql/src/`:
```
src/pl/plisql/src/
├── pl_dbms_utility.c           ← Native implementation
├── plisql.h                     ← Export declarations
└── Makefile (add to OBJS)

contrib/ivorysql_ora/
└── dbms_utility--1.0.sql       ← CREATE PACKAGE wrapper
```

**For DBMS packages that DON'T need PL/iSQL internals:**

Keep in `contrib/ivorysql_ora/`:
```
contrib/ivorysql_ora/
└── src/builtin_functions/
    ├── <package>.c           ← Self-contained implementation
    └── <package>--1.0.sql    ← CREATE PACKAGE wrapper
```

### Recommendation 2: Clean Layering

Follow this dependency hierarchy:
```
1. PL/iSQL Language (src/pl/plisql/src/)
   ↓ provides functions
2. Oracle Extension (contrib/ivorysql_ora/)
   ↓ uses language functions, adds Oracle syntax
3. User Code
```

**Never:** Extension → Language internals (violates encapsulation)

### Recommendation 3: File Naming Convention

If moving DBMS packages to `src/pl/plisql/src/`, use clear naming:
- `pl_dbms_utility.c` (part of language, for DBMS_UTILITY)
- `pl_exec.c` (language execution, existing)

This distinguishes "language internals" from "language-provided DBMS packages."

## Decision: Architecture 2 - PL/iSQL-based

**Decision Date:** 2025-11-30

After detailed analysis, we chose **Architecture 2: PL/iSQL-based** for DBMS_UTILITY.

### Rationale

1. **Original Design Intent:** In upstream IvorySQL, `plisql` and `ivorysql_ora` are **independent modules** with no cross-dependencies. Both depend on core headers (`src/include/`), but neither depends on the other.

2. **Our Change Broke This:** By adding `#include "plisql.h"` in `contrib/ivorysql_ora/src/builtin_functions/dbms_utility.c`, we introduced a cross-module dependency that didn't exist before.

3. **DBMS_UTILITY Doesn't Need Oracle Types:** The C implementation only uses PostgreSQL native types (`TEXT`). It doesn't require `VARCHAR2` or other Oracle types at compile time or load time.

4. **Load Order Analysis:**
   ```
   initdb -m oracle
       │
       ├─→ preload_ora_misc.sql         (1st - basic objects, NO plisql yet)
       │
       ├─→ CREATE EXTENSION plisql      (2nd - loads plisql--1.0.sql)
       │
       └─→ CREATE EXTENSION ivorysql_ora (3rd - loads ivorysql_ora--1.0.sql)
   ```

   Since DBMS_UTILITY doesn't need Oracle types, it can be fully defined at step 2 (`plisql--1.0.sql`), before `ivorysql_ora` loads.

5. **plisql--1.0.sql is Currently Empty:** IvorySQL's `plisql--1.0.sql` is almost empty because the language is pre-defined in system catalogs (`pg_proc.dat`, `pg_language.dat`). This file is the right place to add DBMS package definitions.

### Final Structure

```
src/pl/plisql/src/
├── pl_dbms_utility.c           ← C implementation (needs plisql.h internals)
├── plisql.h                    ← Already has what we need
├── plisql--1.0.sql             ← CREATE FUNCTION for C wrapper only
└── Makefile                    ← Add pl_dbms_utility.o to OBJS

src/bin/initdb/initdb.c
└── load_plisql()               ← CREATE PACKAGE statements (requires Oracle mode)
```

**Why split between plisql--1.0.sql and initdb.c?**

1. **plisql--1.0.sql** runs during `CREATE EXTENSION plisql` with PostgreSQL parser
2. **CREATE PACKAGE** syntax requires Oracle mode (`compatible_mode=oracle`)
3. During extension creation, the session is in PostgreSQL mode
4. `initdb.c` can wrap SQL with `SET ivorysql.compatible_mode TO oracle`

**plisql--1.0.sql additions:**
```sql
-- C function wrapper (works in PG mode)
CREATE FUNCTION sys.ora_format_error_backtrace() RETURNS TEXT
  AS 'MODULE_PATHNAME', 'ora_format_error_backtrace'
  LANGUAGE C VOLATILE;
```

**initdb.c load_plisql() additions:**
```c
/* Create DBMS_UTILITY package (requires Oracle mode for CREATE PACKAGE syntax) */
PG_CMD_PUTS("SET ivorysql.compatible_mode TO oracle;\n\n");

PG_CMD_PUTS("CREATE OR REPLACE PACKAGE dbms_utility IS "
            "FUNCTION FORMAT_ERROR_BACKTRACE RETURN TEXT; "
            "END dbms_utility;\n\n");

PG_CMD_PUTS("CREATE OR REPLACE PACKAGE BODY dbms_utility IS "
            "FUNCTION FORMAT_ERROR_BACKTRACE RETURN TEXT IS "
            "BEGIN "
            "RETURN sys.ora_format_error_backtrace(); "
            "END; "
            "END dbms_utility;\n\n");

PG_CMD_PUTS("SET ivorysql.compatible_mode TO pg;\n\n");
```

**Technical Notes:**
- initdb sends raw SQL via pipe, so no "/" block terminators - use semicolons only
- Package statements must be single-line (concatenated C strings)
- Pattern follows existing `load_ivorysql_ora()` approach

### Benefits

1. **No Cross-Module Dependency:** Everything DBMS_UTILITY needs is within `src/pl/plisql/src/`
2. **Clean Architecture:** Respects original module boundaries
3. **Built-in at initdb:** Available immediately after `CREATE EXTENSION plisql`
4. **Single Compilation Unit:** C code compiles into `plisql.so`

### Trade-offs Accepted

1. **Split Location:** DBMS packages that need PL/iSQL internals live in `plisql`, others may stay in `ivorysql_ora`
2. **TEXT vs VARCHAR2:** Package returns `TEXT` instead of `VARCHAR2` (compatible in Oracle mode)

## Guidelines for Future DBMS Packages

Based on this decision:

| Package Needs | Location |
|--------------|----------|
| PL/iSQL internals (exception context, call stack, etc.) | `src/pl/plisql/src/` |
| Only Oracle datatypes, no PL/iSQL internals | `contrib/ivorysql_ora/` |
| Both PL/iSQL internals AND Oracle types | Split: C in plisql, SQL wrapper in ivorysql_ora |

## Answered Questions

1. **Extension Loading:** DBMS_UTILITY will be created when `CREATE EXTENSION plisql` runs (during `initdb -m oracle`). No separate extension needed.

2. **Future Packages:** Follow the guidelines table above based on dependencies.

## Implementation Status

1. ✅ Document architecture decision (this document)
2. ✅ Implement C function in `src/pl/plisql/src/pl_dbms_utility.c`
3. ✅ Register C function in `src/pl/plisql/src/plisql--1.0.sql`
4. ✅ Create DBMS_UTILITY package in `src/bin/initdb/initdb.c`
5. ✅ Add regression tests in `src/pl/plisql/src/sql/dbms_utility.sql`
6. ✅ All 17 plisql oracle-check tests passing

---

**Document Status:** Implementation complete
**Last Updated:** 2025-11-30
**Authors:** Rophy Tsai
