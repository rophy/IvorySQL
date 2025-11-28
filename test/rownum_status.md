# ROWNUM Implementation Status

**Last Updated**: After ORDER BY fix

## ✅ Working Features

### 1. Basic ROWNUM Functionality
- ✅ `SELECT ROWNUM FROM dual` → Returns 1
- ✅ `SELECT ROWNUM, * FROM table` → Returns 1, 2, 3, 4, 5
- ✅ ROWNUM correctly renumbers after WHERE clause filters
- ✅ `WHERE ROWNUM > 1` → Returns 0 rows (Oracle special behavior)
- ✅ ROWNUM works with JOINs
- ✅ EXPLAIN shows ROWNUM in output columns
- ✅ **ROWNUM with ORDER BY** - Shows correct values in original scan order

### 2. Parser & Infrastructure
- ✅ ROWNUM keyword recognized in Oracle mode only
- ✅ RownumExpr node fully integrated
- ✅ Expression evaluation in executor
- ✅ View definitions display ROWNUM correctly
- ✅ EXPLAIN VERBOSE works without errors
- ✅ Counter increments at correct location (ExecScanExtended)

## ❌ Known Issues

### Issue 1: ROWNUM Predicates Don't Filter (Requires Phase 3)
**Symptom:**
```sql
SELECT ROWNUM, id FROM test_table WHERE ROWNUM <= 3;
-- Expected: 3 rows
-- Actual: Shows ROWNUM = 0 for all rows (Result node evaluates before scan)

SELECT ROWNUM, id FROM test_table WHERE ROWNUM = 1;
-- Expected: 1 row
-- Actual: Shows ROWNUM = 0 (Result node evaluates before scan)
```

**Root Cause:** ROWNUM predicates are recognized as "One-Time Filter" in Result nodes, which evaluate BEFORE the scan increments the counter. These predicates should be converted to LIMIT clauses during query planning.

**Status:** Requires Phase 3 (optimizer transformations) to convert ROWNUM predicates to LIMIT

---

## 📊 Test Results Summary

| Test Case | Expected | Actual | Status |
|-----------|----------|--------|--------|
| SELECT ROWNUM FROM dual | 1 | 1 | ✅ PASS |
| Basic table scan | 1,2,3,4,5 | 1,2,3,4,5 | ✅ PASS |
| With WHERE filter | 1,2,3 (renumbered) | 1,2,3 | ✅ PASS |
| WHERE ROWNUM > 1 | 0 rows | 0 rows | ✅ PASS |
| WHERE ROWNUM = 1 | 1 row | 0 (needs optimizer) | ❌ FAIL |
| WHERE ROWNUM <= 3 | 3 rows | 0 (needs optimizer) | ❌ FAIL |
| **With ORDER BY** | **1,2,3,4,5 (scan order)** | **1,2,3,4,5** | **✅ PASS** |
| With JOIN | 1,2 | 1,2 | ✅ PASS |
| EXPLAIN output | Shows ROWNUM | Shows ROWNUM | ✅ PASS |

**Pass Rate: 7/9 (78%)**
**Improvement: +11% after ORDER BY fix**

---

## 🔧 Implementation Details

### Files Modified

**Parser Layer:**
- `src/include/oracle_parser/ora_kwlist.h` - Added ROWNUM keyword
- `src/backend/oracle_parser/ora_gram.y` - Added ROWNUM token
- `src/backend/parser/parse_expr.c` - ROWNUM recognition with Oracle mode check
- `src/include/nodes/primnodes.h` - RownumExpr node definition

**Executor Layer:**
- `src/include/nodes/execnodes.h` - Added es_rownum counter to EState
- `src/backend/executor/execUtils.c` - Initialize counter to 0
- **`src/include/executor/execScan.h`** - **Increment counter in ExecScanExtended (FIXED ORDER BY)**
- `src/include/executor/execExpr.h` - EEOP_ROWNUM opcode
- `src/backend/executor/execExpr.c` - RownumExpr evaluation setup
- `src/backend/executor/execExprInterp.c` - ROWNUM evaluation function

**Support Functions:**
- `src/backend/nodes/nodeFuncs.c` - Type (INT8OID), collation support
- `src/backend/utils/adt/ruleutils.c` - EXPLAIN/view deparsing

---

## 🎯 Recent Fixes

### ORDER BY Fix (Commit 99502d27)
**Problem:** ROWNUM showed all 1's when ORDER BY was present because counter was incremented in top-level ExecutorRun loop, but Sort node materialized tuples before that loop ran.

**Solution:** Moved counter increment to `ExecScanExtended()` in `execScan.h`, which is called:
- For each tuple retrieved from scan
- AFTER WHERE clause (qual check)
- BEFORE projection (where ROWNUM is evaluated)
- Regardless of intermediate nodes (Sort, etc.)

**Result:** ROWNUM now correctly shows values in original scan order, even when results are sorted.

---

## 🎯 Next Steps

### Priority 1: Implement Optimizer Transformations (Phase 3)
Transform ROWNUM predicates to LIMIT clauses during query planning:
- `WHERE ROWNUM <= N` → `LIMIT N`
- `WHERE ROWNUM = 1` → `LIMIT 1`
- `WHERE ROWNUM < N` → `LIMIT N-1`

These transformations occur in the planner/optimizer, likely in `src/backend/optimizer/prep/` or `src/backend/optimizer/plan/`.

### Priority 2: Comprehensive Testing
Once Phase 3 is complete, port all 15 Oracle test cases from the design document to the regression test suite.

### Priority 3: UPDATE/DELETE Testing
Verify ROWNUM works correctly with DML operations.

---

## 📝 Notes

- ROWNUM > 1 works correctly because it's detected as an always-false condition
- Binary compatibility required full `make clean && make` after adding es_rownum to EState struct
- Header file changes (execScan.h) require clean rebuild of executor directory
- ROWNUM is only active when `database_mode = 'oracle'`
- ROWNUM returns INT8 (bigint) to match Oracle behavior
- Counter increments in ExecScanExtended ensure correctneregardless of executor tree structure

---

## 🏗️ Architecture

```
Query Execution Flow:
┌─────────────┐
│ ExecutorRun │  (Top-level loop)
└──────┬──────┘
       │
       ▼
┌──────────────┐
│ ExecProcNode │  (Calls appropriate node)
└──────┬───────┘
       │
       ├─▶ [Sort Node] ──┐
       │                 │
       │                 ▼
       └─▶ [Scan Node] ──┴─▶ ExecScan
                              └─▶ ExecScanExtended
                                   ├─▶ Check qual (WHERE)
                                   ├─▶ **es_rownum++**  ◄── Counter increment
                                   └─▶ ExecProject
                                        └─▶ ExecEvalRownum() reads es_rownum
```

This architecture ensures ROWNUM is assigned:
1. After filtering (WHERE clause)
2. Before projection (target list)
3. In scan order (not sorted order)
