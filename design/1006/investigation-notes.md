# Issue #1006 Investigation Notes

## Problem Statement

When calling package procedures or subprocedures with mixed positional and named parameters where variables are used as named argument values, the call fails with:
```
ERROR: failed to find conversion function from unknown to varchar2
```

## Root Cause

When `plisql_expand_and_reorder_functionargs()` reorders the argument list to match the procedure's parameter order and inserts default values, the type arrays were not properly aligned:

1. **For Package Functions**: The `actual_arg_types` array in `ParseFuncOrColumn()` was not updated to reflect the new ordering.

2. **For Subprocedures**: The `true_typeids` (which becomes `declared_arg_types`) was stored in **call order** for overload resolution, but `fargs` was reordered to **declared order**. This mismatch caused type coercion to fail.

## Code Flow Analysis

### Package Functions (FUNC_FROM_PACKAGE)

1. `LookupPkgFunc()` is called at parse_func.c:344
2. Internally calls `plisql_expand_and_reorder_functionargs()` to reorder `fargs`
3. Returns with:
   - `fargs` = reordered to declared order
   - `declared_arg_types` = NULL (not set by package functions)
   - `actual_arg_types` = still in original call order
4. **Fix**: Rebuild `actual_arg_types` from reordered `fargs` at parse_func.c:377-391

### Subprocedures (FUNC_FROM_SUBPROCFUNC)

1. `plisql_subprocfunc_ref()` → `plisql_get_subprocfunc_detail()` is called at parse_func.c:316
2. At pl_subproc_function.c:1469: Sets `*true_typeids = best_candidate->args`
   - `best_candidate->args` is in **call order** (reordered at lines 1981-1998 for overload matching)
3. At pl_subproc_function.c:1520: Calls `plisql_expand_and_reorder_functionargs()` to reorder `fargs` to **declared order**
4. Returns with:
   - `fargs` = declared order
   - `declared_arg_types` = call order (MISMATCH!)
   - `actual_arg_types` = call order
5. **Fix**: After reordering `fargs`, also rebuild `true_typeids` from `subprocfunc->arg` in declared order

## Final Resolution

### Two-Part Fix

**Part 1: parse_func.c (line 377-391)**

Rebuild `actual_arg_types` from reordered `fargs` for both package functions and subprocedures:

```c
if ((function_from == FUNC_FROM_PACKAGE ||
     function_from == FUNC_FROM_SUBPROCFUNC) &&
    fdresult != FUNCDETAIL_NOTFOUND)
{
    ListCell   *lc;
    int        i = 0;

    foreach(lc, fargs)
    {
        Node       *arg = lfirst(lc);
        actual_arg_types[i++] = exprType(arg);
    }
    nargs = i;
}
```

**Part 2: pl_subproc_function.c (line 1531-1545)**

After reordering `fargs`, rebuild `true_typeids` in declared order:

```c
if (fargnames != NIL || defaultnumber != NIL)
{
    *fargs = plisql_expand_and_reorder_functionargs(...);

    /* Rebuild true_typeids in declared order to match reordered fargs */
    if (best_candidate->argnumbers != NULL)
    {
        Oid        *declared_order_types;
        ListCell   *lc;
        int         i = 0;

        declared_order_types = palloc(best_candidate->nargs * sizeof(Oid));
        foreach(lc, subprocfunc->arg)
        {
            PLiSQL_function_argitem *argitem = lfirst(lc);
            declared_order_types[i++] = argitem->type->typoid;
        }
        *true_typeids = declared_order_types;
    }
}
```

### Why This Works

1. **Overload resolution is preserved**: The overload matching at lines 1416-1460 uses `argtypes` (call order) vs `tmp_candidate->args` (call order). This happens BEFORE our fix, so overloading still works correctly.

2. **Type coercion is fixed**: After our fix:
   - `fargs` = declared order
   - `actual_arg_types` = declared order (rebuilt from fargs)
   - `declared_arg_types` = declared order (rebuilt from subprocfunc->arg)

   All three arrays are now aligned!

## Status

**All tests pass:**
- ✅ Package procedures with mixed parameters and variables
- ✅ Subprocedures with mixed parameters and variables
- ✅ Subprocedure overloading (not broken by the fix)
- ✅ All 17 PL/iSQL regression tests
- ✅ All Oracle compatibility tests (oracle-check-world)
- ✅ All PostgreSQL compatibility tests (check)

## Test Files

- Package procedure tests: `src/pl/plisql/src/sql/plisql_call.sql` lines 613-681
- Subprocedure tests: `src/pl/plisql/src/sql/plisql_call.sql` lines 683-762
- Subprocedure overloading tests: `src/pl/plisql/src/sql/plisql_nested_subproc.sql` line 346

## Key Code Locations

- Fix location #1: `src/backend/parser/parse_func.c:377-391`
- Fix location #2: `src/pl/plisql/src/pl_subproc_function.c:1531-1545`
- Package function reordering: Called from `LookupPkgFunc()`
- Subprocedure reordering: `src/pl/plisql/src/pl_subproc_function.c:1520`
- Subprocedure overload resolution: `src/pl/plisql/src/pl_subproc_function.c:1416-1460`
- Type coercion: `src/backend/parser/parse_func.c:2133`
