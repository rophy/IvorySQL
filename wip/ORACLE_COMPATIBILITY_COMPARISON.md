# Oracle Compatibility: IvorySQL vs PostgreSQL+Orafce vs MariaDB

Comprehensive comparison of Oracle PL/SQL compatibility across three solutions.

## Feature Comparison Matrix

| Feature | IvorySQL | PostgreSQL + Orafce | MariaDB SQL_MODE=ORACLE | Notes |
|---------|----------|---------------------|------------------------|-------|
| **Core PL/SQL Syntax** |
| `PACKAGE` / `PACKAGE BODY` | ✅ YES | ❌ NO | ❌ NO | **IvorySQL only** |
| `FOR var IN (SELECT ...)` | ✅ YES | ❌ NO | ✅ YES | Orafce needs RECORD declaration |
| User-defined `EXCEPTION` type | ✅ YES | ❌ NO | ✅ YES | IvorySQL & MariaDB |
| `%ROWTYPE` | ✅ YES | ✅ YES | ✅ YES | All support |
| `%TYPE` | ❌ NO | ✅ YES | ✅ YES | Orafce & MariaDB |
| **Data Types** |
| `VARCHAR2` | ✅ YES | ✅ YES (oracle.varchar2) | ✅ YES | Orafce needs prefix |
| `NUMBER` | ✅ YES | ❌ NO | ✅ YES (→DECIMAL) | IvorySQL & MariaDB |
| `DATE` | ✅ YES | ✅ YES (oracle.date) | ✅ YES (→DATETIME) | All support |
| **DBMS_OUTPUT Package** |
| `DBMS_OUTPUT.PUT_LINE()` | ✅ YES | ✅ YES | ❌ NO | IvorySQL & Orafce |
| `DBMS_OUTPUT.PUT()` | ✅ YES | ✅ YES | ❌ NO | IvorySQL & Orafce |
| `DBMS_OUTPUT.ENABLE()` | ✅ YES | ✅ YES | ❌ NO | IvorySQL & Orafce |
| `DBMS_OUTPUT.DISABLE()` | ❌ NO | ✅ YES | ❌ NO | **Orafce only** |
| `DBMS_OUTPUT.NEW_LINE()` | ❌ NO | ✅ YES | ❌ NO | **Orafce only** |
| **DBMS_UTILITY Package** |
| `DBMS_UTILITY.FORMAT_CALL_STACK()` | ❌ NO | ✅ YES | ❌ NO | **Orafce only** |
| `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE()` | ❌ NO | ❌ NO | ❌ NO | None support |
| **Functions** |
| `DECODE()` | ❌ NO | ✅ YES (oracle.decode) | ✅ YES | Orafce & MariaDB |
| `ADD_MONTHS()` | ❌ NO | ✅ YES (oracle.add_months) | ✅ YES | Orafce & MariaDB |
| `LAST_DAY()` | ❌ NO | ✅ YES (oracle.last_day) | ❌ NO | **Orafce only** |
| `NEXT_DAY()` | ❌ NO | ✅ YES (oracle.next_day) | ❌ NO | **Orafce only** |
| `SYS_GUID()` | ❌ NO | ❌ NO | ✅ YES | **MariaDB only** |
| `SYS_CONTEXT()` | ❌ NO | ❌ NO | ❌ NO | None support |
| **Advanced Features** |
| `PRAGMA AUTONOMOUS_TRANSACTION` | ❌ NO | ❌ NO | ❌ NO | None support |
| `CONNECT BY` | ❌ NO | ❌ NO | ❌ NO | None support (removed) |
| `ROWID` pseudocolumn | ❌ NO | ❌ NO | ❌ NO | None support |

## PL/SQL Package Compatibility Score

Based on testing with Oracle packages:

| Solution | Compatibility | Strengths | Weaknesses |
|----------|--------------|-----------|------------|
| **IvorySQL** | **~55%** | ✅ Package structure<br>✅ Implicit cursors<br>✅ User exceptions<br>✅ DBMS_OUTPUT | ❌ Missing utility functions (DECODE, date functions)<br>❌ No SYS_CONTEXT<br>❌ No autonomous transactions |
| **PostgreSQL + Orafce** | **~25%** | ✅ DBMS_OUTPUT<br>✅ DECODE<br>✅ Date functions<br>✅ DBMS_UTILITY | ❌ No package structure<br>❌ No implicit cursors<br>❌ No user exceptions<br>❌ Schema prefix required |
| **MariaDB** | **~20%** | ✅ Implicit cursors<br>✅ User exceptions<br>✅ DECODE<br>✅ SYS_GUID | ❌ No package structure<br>❌ No DBMS_OUTPUT<br>❌ Limited PL/SQL syntax |

## Feature Category Summary

### ✅ IvorySQL Advantages
1. **PACKAGE/PACKAGE BODY** - Critical for Oracle code structure
2. **Implicit FOR loop cursors** - Simplifies Oracle code migration
3. **User-defined EXCEPTION types** - Proper error handling
4. **DBMS_OUTPUT** - Standard Oracle debugging package
5. **Native type aliases** - No schema prefix needed

### ✅ Orafce Advantages
1. **DECODE()** - Oracle's inline conditional function
2. **Oracle date functions** - add_months, last_day, next_day, months_between
3. **DBMS_UTILITY.FORMAT_CALL_STACK** - Call stack debugging
4. **String utilities** - PLVstr, PLVchr, PLVsubst packages
5. **Lightweight** - Extension for existing PostgreSQL

### ✅ MariaDB Advantages
1. **DECODE()** - Native function, no prefix
2. **SYS_GUID()** - UUID generation
3. **Implicit cursors** - FOR loop syntax works
4. **User exceptions** - Custom exception types
5. **%TYPE/%ROWTYPE** - Variable type inference

### ❌ All Solutions Missing
- `SYS_CONTEXT()` - Session context information
- `PRAGMA AUTONOMOUS_TRANSACTION` - Independent transactions
- `CONNECT BY` - Hierarchical queries (removed from IvorySQL v3.0)
- `ROWID` - Physical row address pseudocolumn
- `DBMS_UTILITY.FORMAT_ERROR_BACKTRACE()` - Error backtrace

## Recommendation by Use Case

### Enterprise Oracle Package Migration → **IvorySQL**
**Why:**
- Only solution supporting PACKAGE/PACKAGE BODY structure
- Implicit FOR loop cursors reduce code changes
- User-defined exceptions work as expected
- DBMS_OUTPUT for debugging/logging

**Gap:** Missing utility functions (DECODE, date functions) - implement these for better coverage

### Adding Oracle Functions to PostgreSQL → **Orafce**
**Why:**
- Lightweight extension, no database fork
- Rich function library (DECODE, date functions)
- DBMS_OUTPUT for compatibility
- Works with existing PostgreSQL infrastructure

**Gap:** Cannot support package structure or advanced PL/SQL syntax

### Simple Procedure Migration (no packages) → **MariaDB**
**Why:**
- Good function compatibility (DECODE, SYS_GUID)
- Implicit cursor support
- User exception types work
- No schema prefixes needed

**Gap:** No package support, missing DBMS_OUTPUT

## Hybrid Strategy for IvorySQL

To achieve ~80%+ Oracle compatibility, IvorySQL could integrate:

1. **From Orafce:**
   - DECODE() function (**Easy**)
   - Date functions: ADD_MONTHS, LAST_DAY, NEXT_DAY (**Easy**)
   - DBMS_UTILITY.FORMAT_CALL_STACK (**Medium**)
   - String utility functions (**Easy**)

2. **From MariaDB approach:**
   - SYS_GUID() function (**Easy**)

3. **New implementations:**
   - SYS_CONTEXT() wrapper (**Easy** - map to PostgreSQL functions)
   - DBMS_OUTPUT.NEW_LINE/DISABLE (**Easy**)
   - ROWID pseudocolumn (**Medium** - stable row identifier)
   - PRAGMA AUTONOMOUS_TRANSACTION (**Hard** - requires dblink or new isolation)
   - CONNECT BY (**Hard** - restore v2.x implementation)

## Test Environment

- **IvorySQL**: master branch, Oracle mode (`initdb -m oracle`)
- **PostgreSQL**: 16 + orafce extension 4.16.2
- **MariaDB**: latest with SQL_MODE=ORACLE
- **Test package**: Oracle PL/SQL package with typical enterprise features

## Conclusion

**For Oracle package migration:**
1. **IvorySQL** is the clear winner (55% vs 25% vs 20%)
2. Package structure support is fundamental and non-negotiable
3. IvorySQL + orafce-like functions could achieve 80%+ compatibility

**For function-level compatibility:**
1. **Orafce** provides best function coverage
2. **MariaDB** has good built-in functions but missing key packages
3. All solutions lack critical Oracle features (SYS_CONTEXT, autonomous transactions, CONNECT BY)

**Strategic recommendation:**
- Use **IvorySQL** as base for Oracle migration projects
- Integrate **orafce-inspired functions** for utility coverage
- Implement **SYS_CONTEXT wrapper** for quick wins
- Consider restoring **CONNECT BY** from v2.x for hierarchical queries
