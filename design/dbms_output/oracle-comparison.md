# DBMS_OUTPUT Oracle Compatibility Test Results

**Test Date**: 2025-12-01
**Oracle Version**: 23.26.0.0 Free
**IvorySQL Branch**: test/dbms_output

## Test Methodology

Equivalent test cases were executed on both IvorySQL and Oracle Database to verify behavioral compatibility. Tests use PUT followed by GET to verify actual buffer content rather than just syntax validation.

## Section 1: Basic PUT_LINE and GET_LINE

### Test 1.1: Simple PUT_LINE verified by GET_LINE

**IvorySQL**:
```
NOTICE:  Test 1.1 - Line: [Hello, World!], Status: 0
```

**Oracle**:
```
Test 1.1 - Line: [Hello, World!], Status: 0
```

**Result**: ✅ MATCH

---

### Test 1.2: Multiple PUT_LINE calls verified by GET_LINES

**IvorySQL**:
```
NOTICE:  Test 1.2 - Retrieved 3 lines
NOTICE:    Line 1: [First line]
NOTICE:    Line 2: [Second line]
NOTICE:    Line 3: [Third line]
```

**Oracle**:
```
Test 1.2 - Retrieved 3 lines
  Line 1: [First line]
  Line 2: [Second line]
  Line 3: [Third line]
```

**Result**: ✅ MATCH

---

### Test 1.3: Empty string handling

**IvorySQL**:
```
NOTICE:  Test 1.3 - Empty string: [], Status: 0
```

**Oracle**:
```
Test 1.3 - Empty string: [], Status: 0
```

**Result**: ✅ MATCH

---

### Test 1.4: NULL handling

**IvorySQL**:
```
NOTICE:  Test 1.4 - NULL input: [], Status: 0
```

**Oracle**:
```
Test 1.4 - NULL input: [<NULL>], Status: 0
```

**Result**: ❌ DIFFERENCE

**Analysis**: IvorySQL converts NULL to empty string before storing. Oracle preserves NULL as a distinct value. Both return status 0 indicating a line was stored.

---

### Test 1.5: GET_LINE when buffer is empty

**IvorySQL**:
```
NOTICE:  Test 1.5 - Empty buffer: Line=[<NULL>], Status=1
```

**Oracle**:
```
Test 1.5 - Empty buffer: Line=[<NULL>], Status=1
```

**Result**: ✅ MATCH

---

## Section 2: PUT and NEW_LINE

### Test 2.1: PUT followed by NEW_LINE

**IvorySQL**:
```
NOTICE:  Test 2.1 - Combined: [First part second part], Status: 0
```

**Oracle**:
```
Test 2.1 - Combined: [First part second part], Status: 0
```

**Result**: ✅ MATCH

---

### Test 2.2: PUT with NULL

**IvorySQL**:
```
NOTICE:  Test 2.2 - PUT with NULL: [BeforeAfter], Status: 0
```

**Oracle**:
```
Test 2.2 - PUT with NULL: [BeforeAfter], Status: 0
```

**Result**: ✅ MATCH

---

### Test 2.3: Multiple PUT calls building one line

**IvorySQL**:
```
NOTICE:  Test 2.3 - Multiple PUTs: [ABCD], Status: 0
```

**Oracle**:
```
Test 2.3 - Multiple PUTs: [ABCD], Status: 0
```

**Result**: ✅ MATCH

---

### Test 2.4: PUT + NEW_LINE + PUT_LINE creates two lines

**IvorySQL**:
```
NOTICE:  Test 2.4 - Retrieved 2 lines
NOTICE:    Line 1: [Partial]
NOTICE:    Line 2: [Complete]
```

**Oracle**:
```
Test 2.4 - Retrieved 2 lines
  Line 1: [Partial]
  Line 2: [Complete]
```

**Result**: ✅ MATCH

---

## Section 3: ENABLE and DISABLE behavior

### Test 3.1: DISABLE prevents output from being buffered

**IvorySQL**:
```
NOTICE:  Test 3.1 - After disable/enable cycle: [After re-enable], Status: 0
```

**Oracle**:
```
Test 3.1 - After disable/enable cycle: [After re-enable], Status: 0
```

**Result**: ✅ MATCH

---

### Test 3.2: DISABLE clears existing buffer

**IvorySQL**:
```
NOTICE:  Test 3.2 - Buffer after disable: [<NULL>], Status: 1
```

**Oracle**:
```
Test 3.2 - Buffer after disable: [<NULL>], Status: 1
```

**Result**: ✅ MATCH

---

### Test 3.3: Re-ENABLE clears buffer

**IvorySQL**:
```
NOTICE:  Test 3.3 - After re-enable: [<NULL>], Status: 1
```

**Oracle**:
```
Test 3.3 - After re-enable: [First enable content], Status: 0
```

**Result**: ❌ DIFFERENCE

**Analysis**: This is a significant behavioral difference:
- IvorySQL: Calling ENABLE() when already enabled clears the buffer
- Oracle: Calling ENABLE() when already enabled preserves existing buffer content

This affects applications that call ENABLE() multiple times during execution.

---

### Test 3.4: Output while disabled is silently ignored

**IvorySQL**:
```
NOTICE:  Test 3.4 - Only visible after enable: [Visible], Status: 0
```

**Oracle**:
```
Test 3.4 - Only visible after enable: [Visible], Status: 0
```

**Result**: ✅ MATCH

---

## Section 4: Buffer size limits

### Test 4.1: Buffer size below minimum (1000)

**IvorySQL**:
```
ERROR:  buffer size must be between 2000 and 1000000
```

**Oracle**:
```
Test 4.1 - 1000 buffer: succeeded
```

**Result**: ❌ DIFFERENCE

**Analysis**: IvorySQL enforces minimum buffer size of 2000, Oracle accepts smaller values.

---

### Test 4.2: Buffer size at minimum (2000)

**IvorySQL**:
```
NOTICE:  Test 4.2 - Min buffer: [Min buffer works]
```

**Oracle**:
```
Test 4.2 - Min buffer: [Min buffer works]
```

**Result**: ✅ MATCH

---

### Test 4.3: Buffer size at maximum (1000000)

**IvorySQL**:
```
NOTICE:  Test 4.3 - Max buffer: [Max buffer works]
```

**Oracle**:
```
Test 4.3 - Max buffer: [Max buffer works]
```

**Result**: ✅ MATCH

---

### Test 4.4: Buffer size above maximum (1000001)

**IvorySQL**:
```
ERROR:  buffer size must be between 2000 and 1000000
```

**Oracle**:
```
Test 4.4 - 1000001 buffer: succeeded
```

**Result**: ❌ DIFFERENCE

**Analysis**: IvorySQL enforces maximum buffer size of 1000000, Oracle accepts larger values.

---

### Test 4.5: NULL buffer size uses default

**IvorySQL**:
```
NOTICE:  Test 4.5 - NULL buffer: [NULL buffer uses default]
```

**Oracle**:
```
Test 4.5 - NULL buffer: [NULL buffer uses default]
```

**Result**: ✅ MATCH

---

## Section 5: Buffer overflow

### Test 5.1: Buffer overflow produces error

**IvorySQL**:
```
NOTICE:  Test 5.1 - Overflow at line 47: ORU-10027: buffer overflow, limit of 2000 bytes
```

**Oracle**:
```
ORA-20000: ORU-10027: buffer overflow, limit of 2000 bytes
(Overflow at line 47)
```

**Result**: ✅ MATCH

**Analysis**: Both produce the same Oracle-compatible error code (ORU-10027) and overflow occurs at approximately the same line count.

---

## Section 6: GET_LINE and GET_LINES behavior

### Test 6.1: GET_LINE returns lines in order

**IvorySQL**:
```
NOTICE:  Test 6.1a - First: [Line A]
NOTICE:  Test 6.1b - Second: [Line B]
NOTICE:  Test 6.1c - Third: [Line C]
NOTICE:  Test 6.1d - Fourth (empty): [<NULL>], Status: 1
```

**Oracle**:
```
Test 6.1a - First: [Line A]
Test 6.1b - Second: [Line B]
Test 6.1c - Third: [Line C]
Test 6.1d - Fourth (empty): [<NULL>], Status: 1
```

**Result**: ✅ MATCH

---

### Test 6.2: GET_LINES with numlines larger than available

**IvorySQL**:
```
NOTICE:  Test 6.2 - Requested 100, got 3
NOTICE:    Line 1: [Only]
NOTICE:    Line 2: [Three]
NOTICE:    Line 3: [Lines]
```

**Oracle**:
```
Test 6.2 - Requested 100, got 3
  Line 1: [Only]
  Line 2: [Three]
  Line 3: [Lines]
```

**Result**: ✅ MATCH

---

### Test 6.3: GET_LINES with numlines smaller than available

**IvorySQL**:
```
NOTICE:  Test 6.3a - Got 2 lines with GET_LINES
NOTICE:    Line 1: [One]
NOTICE:    Line 2: [Two]
NOTICE:  Test 6.3b - Remaining: [Three], Status: 0
NOTICE:  Test 6.3c - Remaining: [Four], Status: 0
```

**Oracle**:
```
Test 6.3a - Got 2 lines with GET_LINES
  Line 1: [One]
  Line 2: [Two]
Test 6.3b - Remaining: [Three], Status: 0
Test 6.3c - Remaining: [Four], Status: 0
```

**Result**: ✅ MATCH

---

## Section 7: Usage in procedures and functions

### Test 7.1: Output from procedure

**IvorySQL**:
```
NOTICE:  Test 7.1 - From procedure: [Proc says: Hello from procedure]
```

**Oracle**:
```
Test 7.1 - From procedure: [Proc says: Hello from procedure]
```

**Result**: ✅ MATCH

---

### Test 7.2: Output from function

**IvorySQL**:
```
NOTICE:  Test 7.2 - Function returned: 10
NOTICE:    Output 1: [Func input: 5]
NOTICE:    Output 2: [Func output: 10]
```

**Oracle**:
```
Test 7.2 - Function returned: 10
  Output 1: [Func input: 5]
  Output 2: [Func output: 10]
```

**Result**: ✅ MATCH

---

## Section 8: Special cases

### Test 8.1: Special characters

**IvorySQL**:
```
NOTICE:  Test 8.1 - Special chars: 3 lines
NOTICE:    [Tab:	here]
NOTICE:    [Quote: 'single' "double"]
NOTICE:    [Backslash: \ forward: /]
```

**Oracle**:
```
Test 8.1 - Special chars: 3 lines
  [Tab:	here]
  [Quote: 'single' "double"]
  [Backslash: \ forward: /]
```

**Result**: ✅ MATCH

---

### Test 8.2: Numeric values via concatenation

**IvorySQL**:
```
NOTICE:  Test 8.2 - Numeric: [Number: 42]
```

**Oracle**:
```
Test 8.2 - Numeric: [Number: 42]
```

**Result**: ✅ MATCH

---

### Test 8.3: Very long line

**IvorySQL**:
```
NOTICE:  Test 8.3 - Long line length: 1000
```

**Oracle**:
```
Test 8.3 - Long line length: 1000
```

**Result**: ✅ MATCH

---

### Test 8.4: Exception handling preserves buffer

**IvorySQL**:
```
NOTICE:  Test 8.4a - [Before exception]
NOTICE:  Test 8.4b - [Caught: Test error]
NOTICE:  Test 8.4c - [After exception]
```

**Oracle**:
```
Test 8.4a - [Before exception]
Test 8.4b - [Caught: ORA-20001: Test error]
Test 8.4c - [After exception]
```

**Result**: ✅ MATCH (error message format differs but behavior matches)

---

### Test 8.5: Nested blocks

**IvorySQL**:
```
NOTICE:  Test 8.5 - Nested blocks: 4 lines
NOTICE:    [Outer]
NOTICE:    [Inner 1]
NOTICE:    [Inner 2]
NOTICE:    [Back to outer]
```

**Oracle**:
```
Test 8.5 - Nested blocks: 4 lines
  [Outer]
  [Inner 1]
  [Inner 2]
  [Back to outer]
```

**Result**: ✅ MATCH

---

### Test 8.6: Loop output

**IvorySQL**:
```
NOTICE:  Test 8.6 - Loop: 3 lines
NOTICE:    [Iteration 1]
NOTICE:    [Iteration 2]
NOTICE:    [Iteration 3]
```

**Oracle**:
```
Test 8.6 - Loop: 3 lines
  [Iteration 1]
  [Iteration 2]
  [Iteration 3]
```

**Result**: ✅ MATCH

---

## Summary

| Category | Tests | Passed | Failed |
|----------|-------|--------|--------|
| Section 1: Basic PUT_LINE/GET_LINE | 5 | 4 | 1 |
| Section 2: PUT and NEW_LINE | 4 | 4 | 0 |
| Section 3: ENABLE/DISABLE | 4 | 3 | 1 |
| Section 4: Buffer size limits | 5 | 3 | 2 |
| Section 5: Buffer overflow | 1 | 1 | 0 |
| Section 6: GET behavior | 3 | 3 | 0 |
| Section 7: Procedures/Functions | 2 | 2 | 0 |
| Section 8: Special cases | 6 | 6 | 0 |
| **Total** | **30** | **26** | **4** |

**Compatibility Rate**: 87% (26/30 tests)

## Differences Summary

| Test | Issue | Severity | Recommendation |
|------|-------|----------|----------------|
| 1.4 | NULL stored as empty string vs NULL | Low | Document difference |
| 3.3 | Re-ENABLE clears buffer vs preserves | Medium | Consider Oracle behavior |
| 4.1 | Minimum buffer 2000 vs no minimum | Low | Document difference |
| 4.4 | Maximum buffer 1000000 vs unlimited | Low | Document difference |

## Recommendations

1. **High Priority**: Consider matching Oracle's re-ENABLE behavior (preserving buffer) as this could affect migrated applications.

2. **Low Priority**: The NULL handling and buffer size differences are edge cases unlikely to affect most applications.

3. **Documentation**: All differences should be documented in user-facing documentation for migration guidance.
