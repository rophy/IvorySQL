# ROWNUM Pseudocolumn Implementation Design

This document provides comprehensive design documentation for implementing Oracle ROWNUM pseudocolumn support in IvorySQL.

**Related Issues**:
- Upstream: https://github.com/IvorySQL/IvorySQL/issues/41
- Fork: https://github.com/rophy/IvorySQL/issues/10

## Overview

ROWNUM is an Oracle pseudocolumn that returns a number indicating the order in which Oracle selects rows from a table or set of joined rows. The first row selected has a ROWNUM of 1, the second has 2, and so on.

## Oracle Test Results

**Test Environment**: Oracle Database 23.26 Free
**Test Date**: 2025-11-28
**Test File**: `design/rownum/test_rownum_oracle.sql`

All 15 comprehensive test cases have been executed against Oracle Database 23.26 to verify expected ROWNUM behavior. See `design/rownum/test_rownum_oracle_results.md` for complete results.

## Critical ROWNUM Behaviors

### 1. Sequential Assignment

ROWNUM starts at 1 and increments sequentially as rows are retrieved from the query.

```sql
SELECT ROWNUM, emp_id, emp_name FROM employees;
-- ROWNUM: 1, 2, 3, 4, 5...
```

### 2. Special WHERE Clause Semantics

ROWNUM has unique behavior with WHERE clause conditions:

| Condition | Works? | Returns |
|-----------|--------|---------|
| `ROWNUM = 1` | ✅ Yes | First row only |
| `ROWNUM <= N` | ✅ Yes | First N rows |
| `ROWNUM < N` | ✅ Yes | First N-1 rows |
| `ROWNUM BETWEEN 1 AND N` | ✅ Yes | First N rows |
| `ROWNUM > 1` | ❌ No | **No rows** |
| `ROWNUM >= 2` | ❌ No | **No rows** |
| `ROWNUM = N` (N>1) | ❌ No | **No rows** |
| `ROWNUM BETWEEN N AND M` (N>1) | ❌ No | **No rows** |

⚠️ **Critical**: Conditions like `ROWNUM > 1` always return zero rows because ROWNUM is evaluated row-by-row. The first row would have ROWNUM=1, which fails the test, so it's not returned and subsequent rows never get a chance to increment ROWNUM.

### 3. Assignment Timing

- ROWNUM is assigned **BEFORE** ORDER BY execution
- ROWNUM is assigned **AFTER** FROM/WHERE/JOIN processing

**Example**:
```sql
-- WRONG: ROWNUM assigned before ordering, values will be non-sequential
SELECT ROWNUM, emp_name, salary
FROM employees
ORDER BY salary DESC;
-- Result: ROWNUM values like 8, 10, 4, 6, 2, 5, 9, 1, 3, 7

-- CORRECT: Use subquery to order first, then assign ROWNUM
SELECT ROWNUM, emp_name, salary
FROM (SELECT * FROM employees ORDER BY salary DESC)
WHERE ROWNUM <= 10;
-- Result: ROWNUM values 1, 2, 3, 4, 5, 6, 7, 8, 9, 10
```

### 4. Supported Contexts

ROWNUM must work in:
- ✅ SELECT lists
- ✅ WHERE clauses
- ✅ Subqueries
- ✅ JOINs
- ✅ UPDATE/DELETE statements
- ✅ After GROUP BY (applied to result set)

### 5. Standard Pagination Pattern

Oracle uses a double-nested subquery for pagination:

```sql
SELECT * FROM (
    SELECT ROWNUM rnum, t.* FROM (
        SELECT * FROM employees ORDER BY emp_id
    ) t
    WHERE ROWNUM <= end_row
)
WHERE rnum >= start_row;
```

## Test Cases Summary

### Basic Tests (1-4)
1. ✅ **Basic ROWNUM** - Sequential numbering 1-10
2. ✅ **WHERE ROWNUM <= 5** - Returns first 5 rows
3. ✅ **WHERE ROWNUM < 3** - Returns first 2 rows
4. ✅ **WHERE ROWNUM = 1** - Returns exactly first row

### Special Semantics Tests (5-8)
5. ✅ **WHERE ROWNUM > 1** - Returns **NO ROWS** (critical behavior!)
6. ✅ **WHERE ROWNUM >= 2** - Returns **NO ROWS**
7. ✅ **ORDER BY with ROWNUM** - ROWNUM assigned before ordering (non-sequential)
8. ✅ **Top-N with subquery** - Correct pattern for ordered top-N

### Advanced Tests (9-15)
9. ✅ **ROWNUM from dual** - Works without table
10. ✅ **ROWNUM BETWEEN 1 AND 5** - Works when starting at 1
11. ✅ **ROWNUM BETWEEN 2 AND 5** - Returns **NO ROWS**
12. ✅ **Pagination pattern** - Double-nested subquery (standard Oracle idiom)
13. ✅ **ROWNUM in JOIN** - Works correctly
14. ✅ **ROWNUM with GROUP BY** - Applied to result set
15. ✅ **UPDATE with ROWNUM** - Limits rows affected

Full test results: `design/rownum/test_rownum_oracle_results.md`

## Implementation Architecture

### Parser Layer

**Files**:
- `src/backend/parser/gram.y`
- `src/backend/parser/parse_expr.c`
- `src/include/nodes/primnodes.h`

**Tasks**:

1. Add `ROWNUM` as an unreserved keyword (Oracle mode only)

2. Create `RownumExpr` node type:
   ```c
   typedef struct RownumExpr
   {
       Expr    xpr;
       int     location;  /* token location */
   } RownumExpr;
   ```

3. Recognize ROWNUM in column references when `compatible_mode = 'oracle'`

4. Handle parsing in SELECT lists, WHERE clauses, and other contexts

### Optimizer Layer

**Files**:
- `src/backend/optimizer/plan/planner.c`
- `src/backend/optimizer/prep/prepqual.c`

**Tasks**:

1. **Pattern Detection**: Detect `WHERE ROWNUM {<=,<} constant` patterns

2. **LIMIT Optimization**: Transform to LIMIT for performance
   - `WHERE ROWNUM <= N` → `LIMIT N`
   - `WHERE ROWNUM < N` → `LIMIT N-1`

3. **False Condition Detection**: Detect "always false" patterns and shortcut to empty result
   - `ROWNUM > 1`
   - `ROWNUM >= 2`
   - `ROWNUM = N` (where N > 1)
   - `ROWNUM BETWEEN N AND M` (where N > 1)

4. **Avoid Over-Optimization**: Ensure ROWNUM in subqueries is not incorrectly optimized away

### Executor Layer

**Files**:
- `src/backend/executor/execExpr.c`
- `src/backend/executor/execMain.c`
- `src/include/nodes/execnodes.h`

**Tasks**:

1. **State Management**: Add row counter to executor state
   ```c
   typedef struct EState
   {
       ...
       int64  es_rownum;  /* current ROWNUM value */
       ...
   } EState;
   ```

2. **Evaluation Function**: Implement `ExecEvalRownum()` function
   ```c
   static void
   ExecEvalRownum(ExprState *state, ExprEvalStep *op)
   {
       ExprContext *econtext = state->parent->ecxt_estate;
       *op->resvalue = Int64GetDatum(econtext->ecxt_estate->es_rownum);
       *op->resnull = false;
   }
   ```

3. **Counter Management**:
   - Initialize counter to 0 at query start
   - Increment counter for each emitted tuple (after WHERE, before ORDER BY)
   - Reset counter for each subquery execution

4. **Timing**: Ensure ROWNUM is assigned after WHERE clause evaluation but before ORDER BY processing

### Mode Check

Only enable ROWNUM when `compatible_mode = 'oracle'`. In PostgreSQL mode, ROWNUM should be treated as a regular column name.

**Check pattern**:
```c
if (compatible_mode == COMPATIBLE_MODE_ORACLE)
{
    /* Handle ROWNUM as pseudocolumn */
}
else
{
    /* Treat as regular identifier */
}
```

## Implementation Checklist

### Phase 1: Parser
- [ ] Add ROWNUM as unreserved keyword in `gram.y`
- [ ] Create `RownumExpr` node type in `primnodes.h`
- [ ] Add node support functions (copy, equal, out, read)
- [ ] Implement ROWNUM recognition in parse_expr.c
- [ ] Add compatible_mode check

### Phase 2: Optimizer
- [ ] Implement pattern detection for `ROWNUM <= N` and `ROWNUM < N`
- [ ] Add LIMIT transformation optimization
- [ ] Implement "always false" condition detection
- [ ] Handle ROWNUM in subquery contexts
- [ ] Test optimization correctness

### Phase 3: Executor
- [ ] Add es_rownum field to EState structure
- [ ] Implement ExecEvalRownum() function
- [ ] Add counter initialization in executor startup
- [ ] Add counter increment in tuple emission path
- [ ] Add counter reset for subquery execution
- [ ] Ensure correct timing (after WHERE, before ORDER BY)

### Phase 4: UPDATE/DELETE Support
- [ ] Test ROWNUM in UPDATE statements
- [ ] Test ROWNUM in DELETE statements
- [ ] Verify row limiting works correctly

### Phase 5: Testing
- [ ] Port all 15 tests from `design/rownum/test_rownum_oracle.sql`
- [ ] Add to IvorySQL regression test suite
- [ ] Verify identical behavior to Oracle 23.26
- [ ] Test edge cases and error conditions
- [ ] Performance benchmarking vs LIMIT

### Phase 6: Documentation
- [ ] Update IvorySQL documentation
- [ ] Add ROWNUM to Oracle compatibility guide
- [ ] Document differences from PostgreSQL LIMIT (if any)
- [ ] Add usage examples

## Technical Considerations

### 1. Subquery Handling

Each subquery needs its own ROWNUM counter. The implementation must:
- Reset ROWNUM to 0 when entering a subquery
- Maintain separate counters for nested subqueries
- Restore parent counter when exiting subquery

### 2. Parallel Query Execution

ROWNUM assignment depends on execution order, which may be non-deterministic in parallel queries. Consider:
- Disabling parallel execution for queries with ROWNUM
- OR: Document that ROWNUM order is not guaranteed in parallel mode
- OR: Implement deterministic ordering for parallel ROWNUM

### 3. Performance Optimization

The LIMIT transformation is critical for performance:
```sql
-- Without optimization: Full table scan
SELECT * FROM large_table WHERE ROWNUM <= 10;

-- With LIMIT optimization: Stop after 10 rows
SELECT * FROM large_table LIMIT 10;
```

### 4. Interaction with Window Functions

ROWNUM is different from `ROW_NUMBER()` window function:
- ROWNUM: Assigned during row retrieval (before ORDER BY)
- ROW_NUMBER(): Assigned after ordering within window

Both should coexist correctly.

## Testing Strategy

### Unit Tests
- Parser: Test ROWNUM recognition in various contexts
- Optimizer: Test pattern detection and transformation
- Executor: Test counter increment and reset logic

### Integration Tests
Run all 15 Oracle test cases in `design/rownum/test_rownum_oracle.sql`:
1. Basic usage
2. WHERE clauses (<=, <, =, >, >=, BETWEEN)
3. ORDER BY timing
4. Subqueries and Top-N
5. JOINs
6. GROUP BY
7. UPDATE/DELETE
8. Pagination patterns

### Regression Tests
Add to IvorySQL regression suite:
- Positive tests: Verify correct behavior
- Negative tests: Verify error handling
- Edge cases: Empty tables, single row, NULL handling
- Mode switching: ROWNUM in oracle mode vs pg mode

### Performance Tests
Benchmark against PostgreSQL LIMIT:
- Small tables (< 1000 rows)
- Large tables (> 1M rows)
- With and without indexes
- Complex queries with joins

## Expected Outcome

Once implemented, all Oracle SQL code using ROWNUM should work identically in IvorySQL when `compatible_mode = 'oracle'`, including:

✅ Top-N queries:
```sql
SELECT * FROM (SELECT * FROM t ORDER BY col DESC) WHERE ROWNUM <= 10;
```

✅ Pagination patterns:
```sql
SELECT * FROM (
    SELECT ROWNUM rnum, t.* FROM (SELECT * FROM t ORDER BY col) t
    WHERE ROWNUM <= 20
) WHERE rnum >= 11;
```

✅ Row limiting in SELECT/UPDATE/DELETE:
```sql
UPDATE employees SET status = 'updated' WHERE ROWNUM <= 100;
```

✅ All special WHERE clause semantics (including ROWNUM > 1 returning no rows)

This will significantly improve Oracle compatibility and reduce migration friction for applications using ROWNUM.

## References

- **Oracle ROWNUM Documentation**: https://docs.oracle.com/cd/B14117_01/server.101/b10759/pseudocolumns008.htm
- **Oracle 19c Pseudocolumns**: https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/Pseudocolumns.html
- **Upstream Issue**: https://github.com/IvorySQL/IvorySQL/issues/41
- **Test Files**:
  - `design/rownum/test_rownum_oracle.sql` - Test suite
  - `design/rownum/test_rownum_oracle_results.md` - Oracle test results

## Related Work

### PostgreSQL LIMIT
PostgreSQL uses `LIMIT N` instead of `WHERE ROWNUM <= N`. The ROWNUM implementation should internally optimize to LIMIT when possible.

### ROW_NUMBER() Window Function
Both Oracle and PostgreSQL support `ROW_NUMBER()` as a window function. This is different from ROWNUM:
- `ROW_NUMBER()`: Applied after ORDER BY within windows
- `ROWNUM`: Applied before ORDER BY

### IvorySQL ROWID
IvorySQL already implements Oracle's ROWID pseudocolumn (see `src/backend/catalog/heap.c:235-246`). ROWNUM implementation can follow similar patterns for:
- System attribute definition
- Compatible mode checking
- Parsing and evaluation
