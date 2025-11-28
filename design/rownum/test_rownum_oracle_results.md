# Oracle ROWNUM Behavior - Test Results

**Test Environment**: Oracle Database 23.26 Free (container-registry.oracle.com/database/free:23.26.0.0-lite)
**Test File**: `test/test_rownum_oracle.sql`
**Date**: 2025-11-28

## Summary

All 15 tests executed successfully in Oracle Database, confirming ROWNUM behavior for IvorySQL implementation reference.

## Test Results

### Test 1: Basic ROWNUM usage ✅
**Query**: `SELECT ROWNUM, emp_id, emp_name, salary FROM test_emp;`

**Result**: Returns all 10 rows with ROWNUM from 1-10 in insertion order.

```
    ROWNUM     EMP_ID EMP_NAME       SALARY
---------- ---------- -------------- ----------
         1          1 Alice               5000
         2          2 Bob                 6000
         ...
        10         10 Jack                7500
```

**Key Behavior**: ROWNUM is assigned sequentially as rows are retrieved.

---

### Test 2: ROWNUM with WHERE clause (<=) ✅
**Query**: `WHERE ROWNUM <= 5`

**Result**: Returns first 5 rows only.

**Key Behavior**: This is the standard way to limit results in Oracle (similar to LIMIT in PostgreSQL).

---

### Test 3: ROWNUM with WHERE clause (< N) ✅
**Query**: `WHERE ROWNUM < 3`

**Result**: Returns first 2 rows.

**Key Behavior**: `<` operator works as expected with ROWNUM.

---

### Test 4: ROWNUM = 1 ✅
**Query**: `WHERE ROWNUM = 1`

**Result**: Returns exactly 1 row (the first row).

**Key Behavior**: Equality works ONLY for `ROWNUM = 1`. Other equality checks fail.

---

### Test 5: ROWNUM > 1 ✅
**Query**: `WHERE ROWNUM > 1`

**Result**: **NO ROWS SELECTED**

**Key Behavior**: ⚠️ **Critical** - This is Oracle's special ROWNUM semantics. Since ROWNUM starts at 1 for the first row, a condition like `> 1` can never be satisfied (the first row would have ROWNUM=1, which fails the test, so it's not returned and subsequent rows never increment ROWNUM).

---

### Test 6: ROWNUM >= 2 ✅
**Query**: `WHERE ROWNUM >= 2`

**Result**: **NO ROWS SELECTED**

**Key Behavior**: Same as Test 5 - cannot skip the first row using ROWNUM directly.

---

### Test 7: ROWNUM with ORDER BY (direct) ✅
**Query**: `SELECT ROWNUM, ... FROM test_emp ORDER BY salary DESC;`

**Result**: ROWNUM values are NOT sequential (8, 10, 4, 6, 2, 5, 9, 1, 3, 7)

```
    ROWNUM     EMP_ID EMP_NAME       SALARY
---------- ---------- -------------- ----------
         8          8 Henry              8000  (highest salary)
        10         10 Jack               7500
         4          4 David              7000
         ...
```

**Key Behavior**: ⚠️ **ROWNUM is assigned BEFORE ORDER BY**. To get sequential numbers after ordering, use a subquery (see Test 8).

---

### Test 8: Top-N query (correct pattern with subquery) ✅
**Query**:
```sql
SELECT ROWNUM, emp_id, emp_name, salary
FROM (
    SELECT emp_id, emp_name, salary
    FROM test_emp
    ORDER BY salary DESC
)
WHERE ROWNUM <= 5;
```

**Result**: Top 5 highest salaries with sequential ROWNUM (1-5)

```
    ROWNUM     EMP_ID EMP_NAME       SALARY
---------- ---------- -------------- ----------
         1          8 Henry              8000
         2         10 Jack               7500
         3          4 David              7000
         4          6 Frank              6500
         5          2 Bob                6000
```

**Key Behavior**: This is the **correct Oracle pattern** for Top-N queries - order in subquery, then apply ROWNUM.

---

### Test 9: ROWNUM from dual ✅
**Query**: `SELECT ROWNUM FROM dual;`

**Result**: Returns `1`

**Key Behavior**: ROWNUM works even without a real table.

---

### Test 10: ROWNUM BETWEEN 1 AND 5 ✅
**Query**: `WHERE ROWNUM BETWEEN 1 AND 5`

**Result**: Returns first 5 rows.

**Key Behavior**: BETWEEN works when the range starts at 1.

---

### Test 11: ROWNUM BETWEEN 2 AND 5 ✅
**Query**: `WHERE ROWNUM BETWEEN 2 AND 5`

**Result**: **NO ROWS SELECTED**

**Key Behavior**: Cannot skip the first row (same reason as Test 5/6).

---

### Test 12: Pagination pattern (rows 6-10) ✅
**Query**: Double-nested subquery with `rnum` alias
```sql
SELECT * FROM (
    SELECT ROWNUM rnum, emp_id, emp_name, salary
    FROM (
        SELECT emp_id, emp_name, salary
        FROM test_emp
        ORDER BY emp_id
    )
    WHERE ROWNUM <= 10
) WHERE rnum >= 6;
```

**Result**: Returns rows 6-10

```
      RNUM     EMP_ID EMP_NAME       SALARY
---------- ---------- -------------- ----------
         6          6 Frank              6500
         7          7 Grace              4000
         8          8 Henry              8000
         9          9 Ivy                5200
        10         10 Jack               7500
```

**Key Behavior**: This is the **standard Oracle pagination pattern**. You must alias ROWNUM and filter in an outer query.

---

### Test 13: ROWNUM in JOIN ✅
**Query**: `FROM test_emp t1 LEFT JOIN test_emp t2 ... WHERE ROWNUM <= 5`

**Result**: Returns first 5 joined rows.

**Key Behavior**: ROWNUM works correctly in JOINs.

---

### Test 14: ROWNUM with GROUP BY ✅
**Query**: `SELECT ROWNUM, salary_range, emp_count FROM (... GROUP BY ...)`

**Result**: Returns 3 rows with ROWNUM 1-3

```
    ROWNUM SALARY  EMP_COUNT
---------- ------ ----------
         1 Medium          5
         2 Low             2
         3 High            3
```

**Key Behavior**: ROWNUM works after GROUP BY (applied to result set).

---

### Test 15: UPDATE with ROWNUM ✅
**Query**: `UPDATE test_update SET salary = salary + 1000 WHERE ROWNUM <= 3;`

**Result**: Updated exactly 3 rows (first 3 in table scan order)

```
    EMP_ID EMP_NAME       SALARY
---------- -------------- ----------
         1 Alice             6000  (+1000)
         2 Bob               7000  (+1000)
         3 Charlie           5500  (+1000)
         4 David             7000  (unchanged)
         ...
```

**Key Behavior**: ROWNUM works in UPDATE statements, limiting which rows are affected.

---

## Key Implementation Requirements for IvorySQL

### 1. **ROWNUM Assignment Timing**
- Assign ROWNUM **sequentially** as rows are retrieved (starting at 1)
- ROWNUM is assigned **BEFORE** ORDER BY clause execution
- ROWNUM is assigned **AFTER** FROM/WHERE/JOIN processing

### 2. **Special WHERE Clause Semantics**
These conditions behave differently:

| Condition | Works? | Returns |
|-----------|--------|---------|
| `ROWNUM = 1` | ✅ Yes | First row only |
| `ROWNUM <= N` | ✅ Yes | First N rows |
| `ROWNUM < N` | ✅ Yes | First N-1 rows |
| `ROWNUM BETWEEN 1 AND N` | ✅ Yes | First N rows |
| `ROWNUM > 1` | ❌ No | No rows |
| `ROWNUM >= 2` | ❌ No | No rows |
| `ROWNUM = N` (N>1) | ❌ No | No rows |
| `ROWNUM BETWEEN N AND M` (N>1) | ❌ No | No rows |

### 3. **Optimizer Hints**
For performance, detect and optimize:
- `WHERE ROWNUM <= N` → convert to `LIMIT N`
- `WHERE ROWNUM < N` → convert to `LIMIT N-1`

### 4. **Supported Contexts**
ROWNUM must work in:
- ✅ SELECT lists
- ✅ WHERE clauses
- ✅ Subqueries
- ✅ JOINs
- ✅ UPDATE statements
- ✅ With aggregation/GROUP BY (on result set)

### 5. **Pagination Pattern**
Support the standard Oracle pagination idiom:
```sql
SELECT * FROM (
    SELECT ROWNUM rnum, t.* FROM (
        SELECT * FROM table ORDER BY col
    ) t WHERE ROWNUM <= end_row
) WHERE rnum >= start_row;
```

## Implementation Architecture

Based on these tests, here's the recommended approach:

### Parser Layer
1. Recognize `ROWNUM` keyword in Oracle compatibility mode
2. Create `RownumExpr` node type

### Optimizer Layer
1. Detect `WHERE ROWNUM {<=,<} constant` patterns
2. Transform to LIMIT for performance
3. Handle the "always false" cases (`ROWNUM > N`, `ROWNUM >= N` where N>1)

### Executor Layer
1. Maintain row counter in query execution state
2. Increment counter for each emitted tuple (after WHERE but before ORDER BY)
3. Evaluate ROWNUM expressions using current counter value
4. Reset counter for each subquery execution

### Special Handling
- When `ROWNUM > 1` or `ROWNUM >= 2` detected, shortcut to return empty result
- When `ROWNUM = N` (N>1) detected, shortcut to return empty result
- Ensure ROWNUM assigned before ORDER BY processing

## Test Coverage for IvorySQL

Once ROWNUM is implemented, run the same `test_rownum_oracle.sql` file in IvorySQL and compare results. All 15 tests should produce identical output.

## References

- Oracle Documentation: https://docs.oracle.com/cd/B14117_01/server.101/b10759/pseudocolumns008.htm
- GitHub Issue: https://github.com/IvorySQL/IvorySQL/issues/41
