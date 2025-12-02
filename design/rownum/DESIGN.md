# ROWNUM Implementation Design

## Overview

ROWNUM is an Oracle pseudocolumn that assigns a unique number to each row as it is retrieved from a query. IvorySQL implements ROWNUM to provide Oracle compatibility.

## Oracle ROWNUM Semantics

In Oracle:
1. ROWNUM is assigned to each row **before** the WHERE clause is evaluated (for ROWNUM conditions)
2. ROWNUM is assigned only to rows that pass **non-ROWNUM filters**
3. ROWNUM values are sequential starting from 1
4. Each query block (including UNION branches) has its own independent ROWNUM counter
5. Correlated subqueries reset ROWNUM for each invocation

### Key Oracle Behaviors

```sql
-- Returns exactly 5 rows
SELECT * FROM t WHERE ROWNUM <= 5;

-- Returns 0 rows (ROWNUM starts at 1, so first row has ROWNUM=1, fails ROWNUM > 5)
SELECT * FROM t WHERE ROWNUM > 5;

-- Returns 0 rows (first row has ROWNUM=1, fails ROWNUM = 2, no second row to check)
SELECT * FROM t WHERE ROWNUM = 2;

-- ROWNUM only assigned to rows passing id >= 5
SELECT ROWNUM, id FROM t WHERE id >= 5;  -- Returns ROWNUM 1,2,3... for id 5,6,7...

-- Each UNION branch has independent ROWNUM
SELECT ROWNUM, id FROM t WHERE id <= 3
UNION
SELECT ROWNUM, id FROM t WHERE id > 7;
-- Oracle: rn=1,1,2,2,3,3 for id=1,8,2,9,3,10
```

## IvorySQL Implementation

### Architecture

The ROWNUM counter is stored in the executor state (`EState->es_rownum`) and is managed during query execution.

### Key Source Files

| File | Purpose |
|------|---------|
| `src/include/nodes/execnodes.h` | Defines `es_rownum` in EState, `rownum_reset` in SubqueryScanState |
| `src/include/executor/execScan.h` | ROWNUM increment/revert logic in ExecScanExtended |
| `src/backend/executor/execExprInterp.c` | ExecEvalRownum reads es_rownum |
| `src/backend/executor/nodeSubqueryscan.c` | SubqueryScan ROWNUM reset logic |
| `src/backend/executor/nodeSubplan.c` | Correlated subquery ROWNUM save/restore |
| `src/backend/executor/execUtils.c` | es_rownum initialization |

### Execution Flow

#### Basic ROWNUM in WHERE Clause

For a query like `SELECT * FROM t WHERE ROWNUM <= 5`:

1. The planner transforms `ROWNUM <= N` to a `Limit` node (optimization)
2. Each row fetched by the scan increments `es_rownum`
3. The Limit node stops after N rows

#### ROWNUM with Non-ROWNUM Filters

For a query like `SELECT ROWNUM, id FROM t WHERE id >= 5`:

```
ExecScanExtended:
1. Fetch row from table
2. Pre-increment es_rownum (tentative assignment)
3. Evaluate qual (id >= 5)
4. If qual passes:
   - Keep the increment
   - Project tuple (ROWNUM reads es_rownum)
   - Return row
5. If qual fails:
   - Revert es_rownum (decrement)
   - Try next row
```

This ensures ROWNUM is only assigned to rows that pass non-ROWNUM filters.

#### ROWNUM with ROWNUM Conditions

For a query like `SELECT * FROM t WHERE ROWNUM <= 5 AND id > 2`:

1. es_rownum is pre-incremented before qual check
2. Both conditions are evaluated together
3. If `id > 2` fails, es_rownum is reverted
4. If `ROWNUM <= 5` fails (after 5 rows), execution continues but all subsequent rows fail

#### SubqueryScan with ORDER BY

For a query like `SELECT ROWNUM FROM (SELECT * FROM t ORDER BY value DESC) sub`:

```
Plan Structure:
SubqueryScan (projects ROWNUM)
  -> Sort (ORDER BY value DESC)
       -> SeqScan on t

Execution:
1. Sort buffers all tuples from SeqScan (SeqScan increments es_rownum)
2. SubqueryNext is called for first tuple
3. On first call, es_rownum is reset to 0 (via rownum_reset flag)
4. SubqueryScan increments es_rownum for each tuple it returns
5. ROWNUM projection reads the correct value (1, 2, 3...)
```

#### Correlated Subqueries

For a query like:
```sql
SELECT id, (SELECT ROWNUM FROM t2 WHERE t2.id = t1.id) as rn FROM t1;
```

```
Execution:
1. Outer scan fetches row from t1
2. ExecSubPlan is called for the scalar subquery
3. ExecSubPlan saves es_rownum, resets to 0
4. Inner scan executes (increments es_rownum for its rows)
5. ExecSubPlan restores es_rownum
6. This ensures each subquery invocation starts fresh at ROWNUM=1
```

### Code Changes Summary

#### execScan.h - Pre-increment with Revert

```c
/* Pre-increment ROWNUM before qual check */
if (node->ps.state)
    node->ps.state->es_rownum++;

if (qual == NULL || ExecQual(qual, econtext))
{
    /* Row passed - keep increment, project and return */
    ...
}
else
{
    /* Row failed - revert increment */
    if (node->ps.state)
        node->ps.state->es_rownum--;
    ...
}
```

#### nodeSubqueryscan.c - Reset on First Tuple

```c
typedef struct SubqueryScanState
{
    ScanState   ss;
    PlanState  *subplan;
    bool        rownum_reset;  /* has ROWNUM been reset for this scan? */
} SubqueryScanState;

static TupleTableSlot *
SubqueryNext(SubqueryScanState *node)
{
    bool first_call = !node->rownum_reset;
    if (first_call)
        node->rownum_reset = true;

    slot = ExecProcNode(node->subplan);

    /* Reset after first ExecProcNode to ignore inner plan's increments */
    if (first_call)
        node->ss.ps.state->es_rownum = 0;

    return slot;
}
```

#### nodeSubplan.c - Save/Restore for Correlated Subqueries

```c
Datum
ExecSubPlan(SubPlanState *node, ExprContext *econtext, bool *isNull)
{
    EState *estate = node->planstate->state;
    int64 save_rownum = estate->es_rownum;

    estate->es_rownum = 0;  /* Reset for subquery */

    /* Execute subplan */
    ...

    estate->es_rownum = save_rownum;  /* Restore */
    return retval;
}
```

## Oracle Compatibility Test Results

All tests verified against Oracle Database 23.26 Free container.

### Passing Tests (Match Oracle)

| Test | Query Pattern | Result |
|------|---------------|--------|
| Basic ROWNUM <= N | `WHERE ROWNUM <= 5` | 5 rows |
| ROWNUM = 1 | `WHERE ROWNUM = 1` | 1 row |
| ROWNUM < N | `WHERE ROWNUM < 4` | 3 rows |
| ROWNUM in SELECT | `SELECT ROWNUM, id WHERE ROWNUM <= 3` | ROWNUM 1,2,3 |
| Top-N pattern | `SELECT * FROM (... ORDER BY) WHERE ROWNUM <= 3` | Top 3 rows |
| ROWNUM > 0 | `WHERE ROWNUM > 0` | All rows (tautology) |
| ROWNUM > N | `WHERE ROWNUM > 5` | 0 rows |
| ROWNUM = N (N>1) | `WHERE ROWNUM = 2` | 0 rows |
| ROWNUM with filter | `WHERE id >= 5` | ROWNUM 1-6 for id 5-10 |
| Combined conditions | `WHERE ROWNUM <= 3 AND id >= 5` | ROWNUM 1-3 for id 5-7 |
| COUNT with ROWNUM | `SELECT COUNT(*) WHERE ROWNUM <= 5` | 5 |
| ORDER BY with ROWNUM | `WHERE ROWNUM <= 5 ORDER BY value` | First 5, then sorted |
| Correlated subquery | `(SELECT ROWNUM FROM sub WHERE ...)` | Resets to 1 each time |
| Nested subqueries | Multiple ROWNUM levels | Correct at each level |

### Known Limitation: UNION

**Oracle Behavior:**
```sql
SELECT ROWNUM, id FROM t WHERE id <= 3
UNION
SELECT ROWNUM, id FROM t WHERE id > 7
ORDER BY 1, 2;

-- Result: Each branch has independent ROWNUM
-- rn=1 id=1, rn=1 id=8, rn=2 id=2, rn=2 id=9, rn=3 id=3, rn=3 id=10
```

**IvorySQL Behavior:**
```sql
-- Result: Shared ROWNUM counter across branches
-- rn=1 id=1, rn=2 id=2, rn=3 id=3, rn=4 id=8, rn=5 id=9, rn=6 id=10
```

**Reason:** Oracle treats each UNION branch as an independent query block with its own ROWNUM counter. IvorySQL uses a single `es_rownum` counter per EState, which is shared across all scan nodes in the query.

**Fix Complexity:** Implementing per-query-block ROWNUM counters would require:
1. Identifying query block boundaries during planning
2. Associating a separate counter with each query block
3. Resetting counters when entering each branch of Append/MergeAppend

This is a significant architectural change and is documented as a known limitation.

## Performance Considerations

1. **Pre-increment/Revert Overhead:** Each filtered row requires an increment and a decrement. This is minimal overhead (two integer operations).

2. **Optimizer Transformations:** The planner transforms simple ROWNUM conditions to Limit nodes, avoiding the need for runtime ROWNUM checking in many cases.

3. **SubqueryScan Reset:** The `rownum_reset` flag ensures the reset only happens once per scan, not per tuple.

## Testing

The ROWNUM implementation is tested via:
- `src/oracle_test/regress/sql/rownum.sql` - Comprehensive test cases
- `src/oracle_test/regress/expected/rownum.out` - Expected output

Run tests with:
```bash
cd src/oracle_test/regress
make oracle-check
```

## Future Work

1. **UNION per-branch ROWNUM:** Implement independent ROWNUM counters for each UNION branch
2. **ROWNUM optimization:** Additional planner optimizations for complex ROWNUM patterns
3. **Parallel query support:** Ensure ROWNUM works correctly with parallel execution
