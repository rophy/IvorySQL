# Fix mixed parameter notation with variables in package procedures

## Summary

Fixed type coercion failure when calling package procedures with mixed positional and named parameters where variables are used as named argument values.

## Problem

When calling a package procedure with:
- Mixed positional and named parameters (e.g., `proc('a', p3=>v_val)`)
- Variables as named parameter values
- Default parameters that are skipped

The call failed with:
```
ERROR: failed to find conversion function from unknown to varchar2
```

## Root Cause

When `plisql_expand_and_reorder_functionargs()` reordered the argument list to match the procedure's parameter order and insert default values, the `actual_arg_types` array in `ParseFuncOrColumn()` was not updated to reflect the new ordering. This caused type coercion to fail because argument types no longer matched their positions.

## Solution

After package function resolution completes and potentially reorders `fargs`, rebuild the `actual_arg_types` array by calling `exprType()` on each reordered argument.

**File modified:** `src/backend/parser/parse_func.c`
- Added 25 lines after `cancel_parser_errposition_callback()`
- Only applies to `FUNC_FROM_PACKAGE` (not subprocedures)

## Testing

Added comprehensive regression tests in `src/pl/plisql/src/sql/plisql_call.sql`:
- All positional parameters
- All named parameters with variables
- Mixed positional/named with literals
- Mixed positional/named with variables (the bug case)
- Multiple variables with mixed notation

Verified that:
- ✅ Tests pass with the fix
- ✅ Tests fail without the fix (with expected error)
- ✅ All 17 existing PL/iSQL tests pass

## Compatibility

This fix aligns IvorySQL behavior with Oracle Database, which correctly handles this syntax.

## Commits

- `847f93cb7a` - fix: rebuild arg types after package function reordering
- `b9a576c90f` - test: add regression test for issue #1006

Fixes #1006
