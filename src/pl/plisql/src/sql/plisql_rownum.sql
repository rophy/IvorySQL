--
-- Tests for Oracle ROWNUM pseudocolumn compatibility
--

-- Setup test table
CREATE TABLE rownum_test (
    id INT,
    name TEXT,
    value NUMERIC
);

INSERT INTO rownum_test VALUES
    (1, 'Alice', 100),
    (2, 'Bob', 200),
    (3, 'Charlie', 150),
    (4, 'David', 300),
    (5, 'Eve', 250);

-- Test 1: Basic ROWNUM functionality
SELECT ROWNUM, id, name FROM rownum_test;

-- Test 2: ROWNUM with WHERE clause (renumbering)
SELECT ROWNUM, id, name FROM rownum_test WHERE value > 150;

-- Test 3: ROWNUM predicate with = (LIMIT transformation)
SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM = 1;

-- Test 4: ROWNUM predicate with <= (LIMIT transformation)
SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM <= 3;

-- Test 5: ROWNUM predicate with < (LIMIT transformation)
SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM < 3;

-- Test 6: ROWNUM > 1 (Oracle special case - always false)
SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM > 1;

-- Test 7: ROWNUM with ORDER BY (shows scan order, not sorted order)
SELECT ROWNUM, id, name, value FROM rownum_test ORDER BY value DESC;

-- Test 8: Subquery with ROWNUM predicate
SELECT * FROM (
    SELECT ROWNUM as rn, id, name, value
    FROM rownum_test
    WHERE ROWNUM <= 3
) sub;

-- Test 9: Classic Oracle TOP-N pattern
SELECT * FROM (
    SELECT ROWNUM as rn, id, name, value
    FROM rownum_test
    WHERE ROWNUM <= 3
) sub ORDER BY value DESC;

-- Test 10: Nested subqueries with ROWNUM
SELECT * FROM (
    SELECT * FROM (
        SELECT ROWNUM as rn, id, name
        FROM rownum_test
        WHERE ROWNUM <= 2
    ) inner_sub
) outer_sub;

-- Test 11: ROWNUM with JOIN
CREATE TABLE dept (dept_id INT, dept_name TEXT);
INSERT INTO dept VALUES (1, 'Sales'), (2, 'Engineering');

SELECT ROWNUM, r.id, r.name, d.dept_name
FROM rownum_test r
JOIN dept d ON r.id <= d.dept_id
WHERE ROWNUM <= 3;

-- Test 12: ROWNUM in SQL function (simpler than plisql)
CREATE OR REPLACE FUNCTION get_top_two() RETURNS SETOF rownum_test
LANGUAGE sql
AS $$
    SELECT * FROM rownum_test WHERE ROWNUM <= 2;
$$;
/

SELECT id, name FROM get_top_two();

-- Test 13: ROWNUM in PL/iSQL cursor
CREATE OR REPLACE FUNCTION cursor_rownum_test() RETURNS TEXT
LANGUAGE plisql
AS $$
DECLARE
    cur CURSOR FOR SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM <= 3;
    result TEXT := '';
    rec RECORD;
BEGIN
    OPEN cur;
    LOOP
        FETCH cur INTO rec;
        EXIT WHEN NOT FOUND;
        result := result || rec.rownum || ':' || rec.name || ' ';
    END LOOP;
    CLOSE cur;
    RETURN trim(result);
END;
$$;
/

SELECT cursor_rownum_test();

-- Test 14: ROWNUM with LIMIT clause (ROWNUM predicate + explicit LIMIT)
SELECT ROWNUM, id, name FROM rownum_test LIMIT 2;

-- Test 15: ROWNUM filtering in outer query vs inner query
-- This shows the difference: inner ROWNUM is evaluated during scan
SELECT * FROM (
    SELECT ROWNUM as rn, id, name FROM rownum_test WHERE ROWNUM <= 3
) sub WHERE rn <= 2;

-- Test 16: Multiple ROWNUM references
SELECT ROWNUM, ROWNUM + 10 as rn_plus_10, id, name
FROM rownum_test
WHERE ROWNUM <= 3;

-- Test 17: ROWNUM with DISTINCT
SELECT DISTINCT ROWNUM, value FROM rownum_test WHERE ROWNUM <= 3;

-- Test 18: ROWNUM in CASE expression
SELECT
    ROWNUM,
    id,
    CASE
        WHEN ROWNUM = 1 THEN 'First'
        WHEN ROWNUM = 2 THEN 'Second'
        ELSE 'Other'
    END as position
FROM rownum_test
WHERE ROWNUM <= 4;

-- Cleanup
DROP FUNCTION cursor_rownum_test();
DROP FUNCTION get_top_two();
DROP TABLE dept;
DROP TABLE rownum_test;
