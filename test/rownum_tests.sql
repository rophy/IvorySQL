-- ROWNUM Test Cases from design/rownum/design.md
-- These tests validate Oracle ROWNUM compatibility in IvorySQL

-- Setup
DROP TABLE IF EXISTS emp CASCADE;
CREATE TABLE emp (empno INT, ename TEXT, sal NUMERIC);
INSERT INTO emp VALUES
    (1, 'SMITH', 800),
    (2, 'ALLEN', 1600),
    (3, 'WARD', 1250),
    (4, 'JONES', 2975);

-- Test 1: Basic ROWNUM
-- Expected: 1
SELECT ROWNUM FROM dual;

-- Test 2: ROWNUM with table scan
-- Expected: 1, 2, 3, 4
SELECT ROWNUM, empno, ename FROM emp;

-- Test 3: ROWNUM with WHERE (assigned after WHERE clause)
-- Expected: 1, 2, 3 (renumbered after filter, not 2, 3, 4)
SELECT ROWNUM, empno, ename FROM emp WHERE sal > 1000;

-- Test 4: ROWNUM > 1 (Oracle special case)
-- Expected: 0 rows (Oracle-specific behavior)
SELECT ROWNUM, empno, ename FROM emp WHERE ROWNUM > 1;

-- Test 5: ROWNUM = 1
-- Expected: 1 row (but currently returns all rows - needs optimizer)
-- TODO: Requires optimizer transformation
SELECT ROWNUM, empno, ename FROM emp WHERE ROWNUM = 1;

-- Test 6: ROWNUM <= N
-- Expected: 3 rows (but currently returns all rows - needs optimizer)
-- TODO: Requires optimizer transformation
SELECT ROWNUM, empno, ename FROM emp WHERE ROWNUM <= 3;

-- Test 7: ROWNUM with ORDER BY (assigned before ORDER BY)
-- Expected: ROWNUM values in original scan order, results sorted by sal
-- TODO: Currently showing all ROWNUM = 1, needs investigation
SELECT ROWNUM, empno, ename, sal FROM emp ORDER BY sal;

-- Test 8: Subquery with ROWNUM (classic Oracle pattern for TOP-N)
-- Expected: Top 2 highest salaries
-- TODO: Requires optimizer transformation for inner query
SELECT * FROM (
    SELECT ROWNUM as rn, empno, ename, sal
    FROM emp
    WHERE ROWNUM <= 2
) ORDER BY sal DESC;

-- Cleanup
DROP TABLE emp;
