# DBMS_OUTPUT Package Design

## Overview

DBMS_OUTPUT is an Oracle-compatible package that provides a simple interface for displaying output from PL/SQL (PL/iSQL) blocks, stored procedures, functions, and triggers. It buffers text output during execution and allows retrieval via GET_LINE/GET_LINES procedures.

## Architecture

### Module Location

```
contrib/ivorysql_ora/
├── src/builtin_packages/dbms_output/
│   └── dbms_output.c           # C implementation
├── sql/ora_dbms_output.sql     # Test SQL
├── expected/ora_dbms_output.out # Expected test output
├── ivorysql_ora_merge_sqls     # SQL merge configuration
└── Makefile                    # Build configuration
```

**Design Decision**: DBMS_OUTPUT is implemented within the `ivorysql_ora` extension because:

1. **Extension ordering**: `plisql` loads before `ivorysql_ora` during database initialization (see `initdb.c`). This allows `ivorysql_ora` to use `PACKAGE` syntax which requires PL/iSQL.

2. **Oracle package grouping**: DBMS_OUTPUT belongs with other Oracle-compatible built-in packages in `ivorysql_ora`.

3. **Type compatibility**: Uses PostgreSQL native `TEXT` type instead of `VARCHAR2` to avoid circular dependencies. Implicit casts between TEXT and VARCHAR2 ensure transparent compatibility.

### Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      User Session                            │
├─────────────────────────────────────────────────────────────┤
│  PL/iSQL Block                                               │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  dbms_output.put_line('Hello');                     │    │
│  │  dbms_output.get_line(line, status);                │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  PACKAGE dbms_output (ivorysql_ora--1.0.sql)        │    │
│  │  - Wrapper procedures with Oracle-compatible API    │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  C Functions (dbms_output.c)                        │    │
│  │  - ora_dbms_output_enable()                         │    │
│  │  - ora_dbms_output_put_line()                       │    │
│  │  - ora_dbms_output_get_line()                       │    │
│  │  - etc.                                             │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                  │
│                           ▼                                  │
│  ┌─────────────────────────────────────────────────────┐    │
│  │  Session-level Buffer (TopMemoryContext)            │    │
│  │  - StringInfo for line buffer                       │    │
│  │  - List of completed lines                          │    │
│  │  - Buffer size tracking                             │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
```

### Memory Management

- **Buffer Storage**: Uses `TopMemoryContext` for session-level persistence
- **Transaction Callbacks**: Registered via `RegisterXactCallback` to clear buffer on transaction end
- **Line Storage**: Completed lines stored in a `List` structure
- **Partial Line**: Current incomplete line stored in `StringInfo`

## API Reference

### ENABLE

```sql
PROCEDURE enable(buffer_size INTEGER DEFAULT 20000);
```

Enables output buffering with specified buffer size.

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| buffer_size | INTEGER | 20000 | Buffer size in bytes (2000-1000000) |

**Notes**:
- NULL buffer_size uses default (20000 bytes)
- Re-calling ENABLE clears existing buffer
- Buffer size below 2000 or above 1000000 raises error

### DISABLE

```sql
PROCEDURE disable;
```

Disables output buffering and clears the buffer.

### PUT

```sql
PROCEDURE put(a TEXT);
```

Appends text to current line without newline.

| Parameter | Type | Description |
|-----------|------|-------------|
| a | TEXT | Text to append (NULL is ignored) |

### PUT_LINE

```sql
PROCEDURE put_line(a TEXT);
```

Appends text and completes the line.

| Parameter | Type | Description |
|-----------|------|-------------|
| a | TEXT | Text to output (NULL outputs empty line) |

### NEW_LINE

```sql
PROCEDURE new_line;
```

Completes current line (adds newline to buffer).

### GET_LINE

```sql
PROCEDURE get_line(line OUT TEXT, status OUT INTEGER);
```

Retrieves one line from the buffer.

| Parameter | Direction | Type | Description |
|-----------|-----------|------|-------------|
| line | OUT | TEXT | Retrieved line (NULL if none) |
| status | OUT | INTEGER | 0=success, 1=no more lines |

### GET_LINES

```sql
PROCEDURE get_lines(lines OUT TEXT[], numlines IN OUT INTEGER);
```

Retrieves multiple lines from the buffer.

| Parameter | Direction | Type | Description |
|-----------|-----------|------|-------------|
| lines | OUT | TEXT[] | Array of retrieved lines |
| numlines | IN OUT | INTEGER | Requested/actual count |

## Implementation Details

### Buffer Structure

```c
typedef struct {
    bool        enabled;
    int         buffer_size;
    int         current_size;
    StringInfo  current_line;    /* Partial line being built */
    List       *lines;           /* Completed lines */
} DbmsOutputBuffer;
```

### Error Handling

| Error Code | Message | Condition |
|------------|---------|-----------|
| ORU-10027 | buffer overflow, limit of N bytes | Buffer size exceeded |
| ERROR | buffer size must be between 2000 and 1000000 | Invalid buffer_size parameter |

### Transaction Behavior

- Buffer persists across statements within a transaction
- Buffer is cleared on transaction commit/abort
- DISABLE clears buffer immediately

## Test Coverage

Tests located in `contrib/ivorysql_ora/sql/ora_dbms_output.sql`

| Section | Tests | Coverage |
|---------|-------|----------|
| 1. Basic PUT_LINE/GET_LINE | 5 | Content verification, empty/NULL handling, empty buffer status |
| 2. PUT and NEW_LINE | 4 | Multi-PUT, NULL handling, line creation |
| 3. ENABLE/DISABLE | 4 | Disable prevents buffering, clears buffer, re-enable behavior |
| 4. Buffer size limits | 5 | Min/max bounds, error cases, NULL default |
| 5. Buffer overflow | 1 | ORU-10027 error generation |
| 6. GET behavior | 3 | FIFO order, partial retrieval, numlines adjustment |
| 7. Procedures/Functions | 2 | Output preserved across proc/func calls |
| 8. Special cases | 6 | Special chars, numerics, long lines, exceptions, nesting |

**Total: 30 test cases**

## Oracle Compatibility

### Comparison Summary

| Feature | IvorySQL | Oracle | Compatible |
|---------|----------|--------|------------|
| PUT_LINE basic | ✓ | ✓ | Yes |
| PUT + NEW_LINE | ✓ | ✓ | Yes |
| GET_LINE/GET_LINES | ✓ | ✓ | Yes |
| DISABLE behavior | ✓ | ✓ | Yes |
| Buffer overflow error | ORU-10027 | ORU-10027 | Yes |
| Proc/Func output | ✓ | ✓ | Yes |
| Exception handling | ✓ | ✓ | Yes |
| NULL in PUT_LINE | Empty string | NULL | **No** |
| Re-ENABLE behavior | Clears buffer | Preserves | **No** |
| Buffer size range | 2000-1000000 | 2000-unlimited | **No** |
| Max line length | No limit | 32767 bytes | **No** ([#21](https://github.com/rophy/IvorySQL/issues/21)) |

### Detailed Differences

#### 1. NULL Handling in PUT_LINE

**IvorySQL**:
```sql
dbms_output.put_line(NULL);
dbms_output.get_line(line, status);
-- line = '' (empty string), status = 0
```

**Oracle**:
```sql
DBMS_OUTPUT.PUT_LINE(NULL);
DBMS_OUTPUT.GET_LINE(line, status);
-- line = NULL, status = 0
```

**Impact**: Low. Most applications check for empty output rather than distinguishing NULL from empty string.

#### 2. Re-ENABLE Behavior

**IvorySQL**:
```sql
dbms_output.enable();
dbms_output.put_line('First');
dbms_output.enable();  -- Clears buffer
dbms_output.get_line(line, status);
-- status = 1 (no lines)
```

**Oracle**:
```sql
DBMS_OUTPUT.ENABLE();
DBMS_OUTPUT.PUT_LINE('First');
DBMS_OUTPUT.ENABLE();  -- Preserves buffer
DBMS_OUTPUT.GET_LINE(line, status);
-- line = 'First', status = 0
```

**Impact**: Medium. Applications that call ENABLE() multiple times may see different behavior.

#### 3. Buffer Size Limits (Bug: [#22](https://github.com/rophy/IvorySQL/issues/22))

**IvorySQL**: Enforces strict range 2000-1000000 bytes, rejects values outside.

**Oracle**: Minimum 2000 bytes (values below silently adjusted up), maximum unlimited. Per [Oracle docs](https://docs.oracle.com/en/database/oracle/oracle-database/19/arpls/DBMS_OUTPUT.html#GUID-CEC56D3F-3BA6-4CA0-8D53-E286AB6A0269).

**Impact**: Low. IvorySQL is stricter but catches invalid values early.

**Status**: Open issue - should silently adjust values below 2000 instead of rejecting.

#### 4. Max Line Length (Bug: [#21](https://github.com/rophy/IvorySQL/issues/21))

**IvorySQL**: No line length limit enforced.

**Oracle**: Maximum 32767 bytes per line. Exceeding raises:
```
ORU-10028: line length overflow, limit of 32767 bytes
```

**Impact**: Medium. Applications relying on Oracle's line length limit for validation will behave differently.

**Status**: Open issue - needs implementation.

### Compatibility Recommendations

1. **For maximum compatibility**:
   - Always call ENABLE() once at the start
   - Avoid relying on NULL vs empty string distinction
   - Use buffer sizes within 2000-1000000

2. **Migration considerations**:
   - Audit code for multiple ENABLE() calls
   - Test NULL handling in PUT_LINE if application depends on it

## Files Modified

| File | Changes |
|------|---------|
| `contrib/ivorysql_ora/src/builtin_packages/dbms_output/dbms_output.c` | C implementation |
| `contrib/ivorysql_ora/src/builtin_packages/dbms_output/dbms_output--1.0.sql` | Package SQL definition |
| `contrib/ivorysql_ora/Makefile` | Added dbms_output.o to OBJS |
| `contrib/ivorysql_ora/meson.build` | Added dbms_output.c to sources |
| `contrib/ivorysql_ora/ivorysql_ora_merge_sqls` | Added dbms_output SQL merge entry |

## Future Enhancements

1. **SERVEROUTPUT setting**: Add psql-like automatic output display
2. **Strict Oracle mode**: Option to match Oracle NULL behavior exactly
3. **Buffer size flexibility**: Consider removing upper limit like Oracle
