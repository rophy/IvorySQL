-- Oracle ROWNUM Compatibility Test
-- This file tests Oracle's ROWNUM pseudocolumn behavior
-- Run in Oracle Database to verify expected behavior

SET SERVEROUTPUT ON;
SET LINESIZE 200;
SET PAGESIZE 100;

PROMPT ========================================
PROMPT Test 1: Basic ROWNUM usage
PROMPT ========================================

-- Create test table with sample data
DROP TABLE test_emp CASCADE CONSTRAINTS;

CREATE TABLE test_emp (
    emp_id NUMBER,
    emp_name VARCHAR2(50),
    salary NUMBER
);

INSERT INTO test_emp VALUES (1, 'Alice', 5000);
INSERT INTO test_emp VALUES (2, 'Bob', 6000);
INSERT INTO test_emp VALUES (3, 'Charlie', 4500);
INSERT INTO test_emp VALUES (4, 'David', 7000);
INSERT INTO test_emp VALUES (5, 'Eve', 5500);
INSERT INTO test_emp VALUES (6, 'Frank', 6500);
INSERT INTO test_emp VALUES (7, 'Grace', 4000);
INSERT INTO test_emp VALUES (8, 'Henry', 8000);
INSERT INTO test_emp VALUES (9, 'Ivy', 5200);
INSERT INTO test_emp VALUES (10, 'Jack', 7500);
COMMIT;

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp;

PROMPT ========================================
PROMPT Test 2: ROWNUM with WHERE clause (<=)
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM <= 5;

PROMPT ========================================
PROMPT Test 3: ROWNUM with WHERE clause (< N)
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM < 3;

PROMPT ========================================
PROMPT Test 4: ROWNUM = 1 (should return first row)
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM = 1;

PROMPT ========================================
PROMPT Test 5: ROWNUM > 1 (should return NO rows)
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM > 1;

PROMPT ========================================
PROMPT Test 6: ROWNUM >= 2 (should return NO rows)
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM >= 2;

PROMPT ========================================
PROMPT Test 7: ROWNUM with ORDER BY (direct)
PROMPT Note: ROWNUM assigned BEFORE ordering
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
ORDER BY salary DESC;

PROMPT ========================================
PROMPT Test 8: Top-N query (correct pattern with subquery)
PROMPT Get top 5 highest salaries
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM (
    SELECT emp_id, emp_name, salary
    FROM test_emp
    ORDER BY salary DESC
)
WHERE ROWNUM <= 5;

PROMPT ========================================
PROMPT Test 9: ROWNUM in SELECT without FROM
PROMPT ========================================

SELECT ROWNUM FROM dual;

PROMPT ========================================
PROMPT Test 10: ROWNUM with BETWEEN (special case)
PROMPT BETWEEN 1 AND 5 should work
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM BETWEEN 1 AND 5;

PROMPT ========================================
PROMPT Test 11: ROWNUM with BETWEEN (2 AND 5)
PROMPT Should return NO rows (ROWNUM can't skip first row)
PROMPT ========================================

SELECT ROWNUM, emp_id, emp_name, salary
FROM test_emp
WHERE ROWNUM BETWEEN 2 AND 5;

PROMPT ========================================
PROMPT Test 12: Pagination pattern (rows 6-10)
PROMPT Correct way to paginate with ROWNUM
PROMPT ========================================

SELECT * FROM (
    SELECT ROWNUM rnum, emp_id, emp_name, salary
    FROM (
        SELECT emp_id, emp_name, salary
        FROM test_emp
        ORDER BY emp_id
    )
    WHERE ROWNUM <= 10
)
WHERE rnum >= 6;

PROMPT ========================================
PROMPT Test 13: ROWNUM in JOIN
PROMPT ========================================

SELECT ROWNUM, t1.emp_id, t1.emp_name, t2.emp_name as manager
FROM test_emp t1
LEFT JOIN test_emp t2 ON t1.emp_id = t2.emp_id + 1
WHERE ROWNUM <= 5;

PROMPT ========================================
PROMPT Test 14: ROWNUM with GROUP BY
PROMPT ========================================

SELECT ROWNUM, salary_range, emp_count
FROM (
    SELECT
        CASE
            WHEN salary < 5000 THEN 'Low'
            WHEN salary < 7000 THEN 'Medium'
            ELSE 'High'
        END as salary_range,
        COUNT(*) as emp_count
    FROM test_emp
    GROUP BY
        CASE
            WHEN salary < 5000 THEN 'Low'
            WHEN salary < 7000 THEN 'Medium'
            ELSE 'High'
        END
);

PROMPT ========================================
PROMPT Test 15: Update with ROWNUM
PROMPT ========================================

CREATE TABLE test_update AS SELECT * FROM test_emp;

UPDATE test_update
SET salary = salary + 1000
WHERE ROWNUM <= 3;

SELECT emp_id, emp_name, salary FROM test_update ORDER BY emp_id;

PROMPT ========================================
PROMPT Cleanup
PROMPT ========================================

DROP TABLE test_emp CASCADE CONSTRAINTS;
DROP TABLE test_update CASCADE CONSTRAINTS;

PROMPT ========================================
PROMPT Test Complete
PROMPT ========================================
