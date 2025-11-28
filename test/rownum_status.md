# ROWNUM Implementation Status

## ✅ Working Features

### 1. Basic ROWNUM Functionality
- ✅ `SELECT ROWNUM FROM dual` → Returns 1
- ✅ `SELECT ROWNUM, * FROM table` → Returns 1, 2, 3, 4, 5
- ✅ ROWNUM correctly renumbers after WHERE clause filters
- ✅ `WHERE ROWNUM > 1` → Returns 0 rows (Oracle special behavior)
- ✅ ROWNUM works with JOINs
- ✅ EXPLAIN shows ROWNUM in output columns

### 2. Parser & Infrastructure
- ✅ ROWNUM keyword recognized in Oracle mode only
- ✅ RownumExpr node fully integrated
- ✅ Expression evaluation in executor
- ✅ View definitions display ROWNUM correctly
- ✅ EXPLAIN VERBOSE works without errors

## ❌ Known Issues

### Issue 1: ORDER BY Shows All ROWNUM = 1
**Symptom:**
```sql
SELECT ROWNUM, name FROM test_table ORDER BY id DESC;
-- Expected: ROWNUM = 1, 2, 3, 4, 5 (in original scan order)
-- Actual: ROWNUM = 1, 1, 1, 1, 1
```

**Root Cause:** When ORDER BY is present, a Sort node materializes tuples. ROWNUM is being evaluated multiple times or the counter is being reset.

**Plan:**
```
Sort  (cost=88.17..91.35 rows=1270 width=44)
  Output: (ROWNUM), name, id
  Sort Key: test_table.id
  ->  Seq Scan on public.test_table
        Output: ROWNUM, name, id
```

**Status:** Requires executor investigation

---

### Issue 2: ROWNUM Predicates Don't Filter
**Symptom:**
```sql
SELECT ROWNUM, id FROM test_table WHERE ROWNUM <= 3;
-- Expected: 3 rows
-- Actual: 5 rows (all rows returned)

SELECT ROWNUM, id FROM test_table WHERE ROWNUM = 1;
-- Expected: 1 row
-- Actual: 5 rows (all rows returned)
```

**Root Cause:** ROWNUM predicates are recognized as "One-Time Filter" but not actually enforced. The planner sees these but doesn't convert them to LIMIT clauses.

**Plan:**
```
Result  (cost=0.00..22.70 rows=1270 width=4)
  Output: id
  One-Time Filter: (ROWNUM <= 3)    <-- Recognized but not enforced
  ->  Seq Scan on public.test_table
```

**Status:** Requires Phase 3 (optimizer transformations) to convert ROWNUM predicates to LIMIT

---

## 📊 Test Results Summary

| Test Case | Expected | Actual | Status |
|-----------|----------|--------|--------|
| SELECT ROWNUM FROM dual | 1 | 1 | ✅ PASS |
| Basic table scan | 1,2,3,4,5 | 1,2,3,4,5 | ✅ PASS |
| With WHERE filter | 1,2,3 (renumbered) | 1,2,3 | ✅ PASS |
| WHERE ROWNUM > 1 | 0 rows | 0 rows | ✅ PASS |
| WHERE ROWNUM = 1 | 1 row | 5 rows | ❌ FAIL |
| WHERE ROWNUM <= 3 | 3 rows | 5 rows | ❌ FAIL |
| With ORDER BY | 1,2,3,4,5 | 1,1,1,1,1 | ❌ FAIL |
| With JOIN | 1,2 | 1,2 | ✅ PASS |
| EXPLAIN output | Shows ROWNUM | Shows ROWNUM | ✅ PASS |

**Pass Rate: 6/9 (67%)**

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
- `src/backend/executor/execMain.c` - Increment counter before each ExecProcNode
- `src/include/executor/execExpr.h` - EEOP_ROWNUM opcode
- `src/backend/executor/execExpr.c` - RownumExpr evaluation setup
- `src/backend/executor/execExprInterp.c` - ROWNUM evaluation function

**Support Functions:**
- `src/backend/nodes/nodeFuncs.c` - Type (INT8OID), collation support
- `src/backend/utils/adt/ruleutils.c` - EXPLAIN/view deparsing

---

## 🎯 Next Steps

### Priority 1: Fix ORDER BY Issue
Investigate why ROWNUM shows all 1's when ORDER BY is present. The counter increments correctly without ORDER BY, so the issue is specific to how Sort nodes interact with expression evaluation.

**Hypothesis:** The target list projection might be happening at the wrong level when a Sort node is present.

### Priority 2: Implement Optimizer Transformations (Phase 3)
Transform ROWNUM predicates to LIMIT clauses:
- `WHERE ROWNUM <= N` → `LIMIT N`
- `WHERE ROWNUM = 1` → `LIMIT 1`
- `WHERE ROWNUM < N` → `LIMIT N-1`

These transformations should occur during query planning.

### Priority 3: Comprehensive Testing
Once Issues 1 & 2 are resolved, port all 15 Oracle test cases from the design document to the regression test suite.

---

## 📝 Notes

- ROWNUM > 1 works correctly because it's detected as an always-false condition early in execution
- Binary compatibility required full `make clean && make` after adding es_rownum to EState struct
- ROWNUM is only active when `database_mode = 'oracle'`
- ROWNUM returns INT8 (bigint) to match Oracle behavior
