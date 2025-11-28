--
-- ROWNUM
-- Test Oracle ROWNUM pseudocolumn functionality
--

-- Setup test data
CREATE TABLE rownum_test (
    id int,
    name varchar(50),
    value int
);

INSERT INTO rownum_test VALUES
    (1, 'Alice', 100),
    (2, 'Bob', 200),
    (3, 'Charlie', 150),
    (4, 'David', 300),
    (5, 'Eve', 250),
    (6, 'Frank', 175),
    (7, 'Grace', 225),
    (8, 'Henry', 125),
    (9, 'Iris', 275),
    (10, 'Jack', 190);

--
-- Basic ROWNUM queries
--

-- ROWNUM <= N (should use LIMIT optimization)
SELECT id, name FROM rownum_test WHERE ROWNUM <= 5;

-- ROWNUM = 1 (should use LIMIT 1)
SELECT id, name FROM rownum_test WHERE ROWNUM = 1;

-- ROWNUM < N (should use LIMIT N-1)
SELECT id, name FROM rownum_test WHERE ROWNUM < 4;

-- ROWNUM in SELECT list
SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM <= 3;

--
-- ROWNUM with ORDER BY
-- (requires subquery pattern to order first, then limit)
--

-- Top-N by value (descending)
SELECT * FROM (
    SELECT id, name, value
    FROM rownum_test
    ORDER BY value DESC
) WHERE ROWNUM <= 3;

-- Top-N by name (ascending)
SELECT * FROM (
    SELECT id, name
    FROM rownum_test
    ORDER BY name
) WHERE ROWNUM <= 5;

-- ROWNUM = 1 with ORDER BY (get minimum)
SELECT * FROM (
    SELECT id, name, value
    FROM rownum_test
    ORDER BY value
) WHERE ROWNUM = 1;

--
-- ROWNUM in nested subqueries
--

-- Subquery with ROWNUM in WHERE clause
SELECT name FROM (
    SELECT id, name FROM rownum_test WHERE ROWNUM <= 7
) sub WHERE id > 3;

-- Multiple levels of ROWNUM
SELECT * FROM (
    SELECT * FROM (
        SELECT id, name FROM rownum_test WHERE ROWNUM <= 8
    ) WHERE ROWNUM <= 5
) WHERE ROWNUM <= 3;

--
-- ROWNUM with JOINs
--

CREATE TABLE dept (
    dept_id int,
    dept_name varchar(50)
);

INSERT INTO dept VALUES
    (1, 'Engineering'),
    (2, 'Sales'),
    (3, 'Marketing');

-- Update test data to include dept_id
ALTER TABLE rownum_test ADD COLUMN dept_id int;
UPDATE rownum_test SET dept_id = (id % 3) + 1;

-- ROWNUM with JOIN
SELECT e.id, e.name, d.dept_name
FROM (SELECT * FROM rownum_test WHERE ROWNUM <= 5) e
JOIN dept d ON e.dept_id = d.dept_id
ORDER BY e.id;

-- JOIN with ORDER BY and ROWNUM
SELECT * FROM (
    SELECT e.id, e.name, e.value, d.dept_name
    FROM rownum_test e
    JOIN dept d ON e.dept_id = d.dept_id
    ORDER BY e.value DESC
) WHERE ROWNUM <= 4;

--
-- Edge cases and non-optimizable patterns
--

-- ROWNUM > N (not optimizable to LIMIT, returns empty)
SELECT id, name FROM rownum_test WHERE ROWNUM > 5;

-- ROWNUM >= 2 (not optimizable, returns empty)
SELECT id, name FROM rownum_test WHERE ROWNUM >= 2;

-- ROWNUM = 0 (always false)
SELECT id, name FROM rownum_test WHERE ROWNUM = 0;

-- ROWNUM with negative number
SELECT id, name FROM rownum_test WHERE ROWNUM <= -1;

-- ROWNUM in complex WHERE clause (AND)
SELECT id, name FROM rownum_test WHERE ROWNUM <= 5 AND id > 2;

-- ROWNUM in complex WHERE clause (OR - not optimizable)
SELECT id, name FROM rownum_test WHERE ROWNUM <= 3 OR id = 10;

--
-- ROWNUM with DISTINCT
--

SELECT DISTINCT dept_id FROM rownum_test WHERE ROWNUM <= 6;

--
-- ROWNUM with aggregate functions
--

-- ROWNUM with GROUP BY (applied before grouping)
SELECT dept_id, COUNT(*)
FROM (SELECT * FROM rownum_test WHERE ROWNUM <= 7)
GROUP BY dept_id
ORDER BY dept_id;

--
-- Verify optimizer transformation with EXPLAIN
--

-- Should show Limit node for ROWNUM <= N
EXPLAIN (COSTS OFF) SELECT id, name FROM rownum_test WHERE ROWNUM <= 5;

-- Should show Limit node for ROWNUM = 1
EXPLAIN (COSTS OFF) SELECT id, name FROM rownum_test WHERE ROWNUM = 1;

-- Should show Limit node for ROWNUM < N
EXPLAIN (COSTS OFF) SELECT id, name FROM rownum_test WHERE ROWNUM < 4;

-- Subquery pattern should show Limit node
EXPLAIN (COSTS OFF)
SELECT * FROM (
    SELECT id, name, value
    FROM rownum_test
    ORDER BY value DESC
) WHERE ROWNUM <= 3;

-- Non-optimizable pattern (no Limit)
EXPLAIN (COSTS OFF) SELECT id, name FROM rownum_test WHERE ROWNUM > 5;

--
-- ROWNUM with other clauses
--

-- ROWNUM with OFFSET (not standard Oracle, but test interaction)
SELECT id, name FROM rownum_test WHERE ROWNUM <= 5 OFFSET 2;

-- ROWNUM with FETCH FIRST (should work together)
SELECT id, name FROM rownum_test WHERE ROWNUM <= 8 FETCH FIRST 3 ROWS ONLY;

--
-- Cleanup
--

DROP TABLE rownum_test CASCADE;
DROP TABLE dept CASCADE;
