# Oracle ROWNUM Compatibility Comparison

This document details the comparison between IvorySQL ROWNUM implementation and Oracle Database 23.26 Free.

## Test Environment

- **IvorySQL:** PostgreSQL 18beta1 (IvorySQL 5beta1)
- **Oracle:** Oracle Database 23.26 Free (container: container-registry.oracle.com/database/free:23.26.0.0-lite)

## Test Data Setup

Both databases use identical test data:

```sql
CREATE TABLE rownum_test (id NUMBER, name VARCHAR2(50), value NUMBER);
INSERT INTO rownum_test VALUES (1, 'Alice', 100);
INSERT INTO rownum_test VALUES (2, 'Bob', 200);
INSERT INTO rownum_test VALUES (3, 'Charlie', 150);
INSERT INTO rownum_test VALUES (4, 'David', 300);
INSERT INTO rownum_test VALUES (5, 'Eve', 250);
INSERT INTO rownum_test VALUES (6, 'Frank', 175);
INSERT INTO rownum_test VALUES (7, 'Grace', 225);
INSERT INTO rownum_test VALUES (8, 'Henry', 125);
INSERT INTO rownum_test VALUES (9, 'Iris', 275);
INSERT INTO rownum_test VALUES (10, 'Jack', 190);
```

## Detailed Test Comparisons

### Test 1: Basic ROWNUM <= N

**Query:**
```sql
SELECT id, name FROM rownum_test WHERE ROWNUM <= 5;
```

**Oracle Result:**
```
ID  NAME
--  -----
1   Alice
2   Bob
3   Charlie
4   David
5   Eve
```

**IvorySQL Result:**
```
id |  name
---+---------
 1 | Alice
 2 | Bob
 3 | Charlie
 4 | David
 5 | Eve
```

**Status:** MATCH

---

### Test 2: ROWNUM = 1

**Query:**
```sql
SELECT id, name FROM rownum_test WHERE ROWNUM = 1;
```

**Oracle Result:**
```
ID  NAME
--  -----
1   Alice
```

**IvorySQL Result:**
```
id | name
---+-------
 1 | Alice
```

**Status:** MATCH

---

### Test 3: ROWNUM < N

**Query:**
```sql
SELECT id, name FROM rownum_test WHERE ROWNUM < 4;
```

**Oracle Result:**
```
ID  NAME
--  -------
1   Alice
2   Bob
3   Charlie
```

**IvorySQL Result:**
```
id |  name
---+---------
 1 | Alice
 2 | Bob
 3 | Charlie
```

**Status:** MATCH

---

### Test 4: ROWNUM in SELECT List

**Query:**
```sql
SELECT ROWNUM, id, name FROM rownum_test WHERE ROWNUM <= 3;
```

**Oracle Result:**
```
ROWNUM  ID  NAME
------  --  -------
1       1   Alice
2       2   Bob
3       3   Charlie
```

**IvorySQL Result:**
```
rownum | id |  name
-------+----+---------
     1 |  1 | Alice
     2 |  2 | Bob
     3 |  3 | Charlie
```

**Status:** MATCH

---

### Test 5: Top-N with ORDER BY (Subquery Pattern)

**Query:**
```sql
SELECT * FROM (
    SELECT id, name, value FROM rownum_test ORDER BY value DESC
) WHERE ROWNUM <= 3;
```

**Oracle Result:**
```
ID  NAME   VALUE
--  -----  -----
4   David  300
9   Iris   275
5   Eve    250
```

**IvorySQL Result:**
```
id | name  | value
---+-------+-------
 4 | David |   300
 9 | Iris  |   275
 5 | Eve   |   250
```

**Status:** MATCH

---

### Test 6: Multiple Levels of ROWNUM

**Query:**
```sql
SELECT * FROM (
    SELECT * FROM (
        SELECT id, name FROM rownum_test WHERE ROWNUM <= 8
    ) WHERE ROWNUM <= 5
) WHERE ROWNUM <= 3;
```

**Oracle Result:**
```
ID  NAME
--  -------
1   Alice
2   Bob
3   Charlie
```

**IvorySQL Result:**
```
id |  name
---+---------
 1 | Alice
 2 | Bob
 3 | Charlie
```

**Status:** MATCH

---

### Test 7: ROWNUM > 0 (Tautology)

**Query:**
```sql
SELECT COUNT(*) FROM rownum_test WHERE ROWNUM > 0;
```

**Oracle Result:**
```
COUNT(*)
--------
10
```

**IvorySQL Result:**
```
count
-------
   10
```

**Status:** MATCH

---

### Test 8: ROWNUM > N (Always False)

**Query:**
```sql
SELECT id, name FROM rownum_test WHERE ROWNUM > 5;
```

**Oracle Result:**
```
no rows selected
```

**IvorySQL Result:**
```
id | name
---+------
(0 rows)
```

**Status:** MATCH

---

### Test 9: ROWNUM = 2 (Always False)

**Query:**
```sql
SELECT id, name FROM rownum_test WHERE ROWNUM = 2;
```

**Oracle Result:**
```
no rows selected
```

**IvorySQL Result:**
```
id | name
---+------
(0 rows)
```

**Status:** MATCH

---

### Test 10: COUNT with ROWNUM <= 5

**Query:**
```sql
SELECT COUNT(*) FROM rownum_test WHERE ROWNUM <= 5;
```

**Oracle Result:**
```
COUNT(*)
--------
5
```

**IvorySQL Result:**
```
count
-------
    5
```

**Status:** MATCH

---

### Test 11: ORDER BY with ROWNUM (Pick First, Then Sort)

**Query:**
```sql
SELECT id, name, value FROM rownum_test WHERE ROWNUM <= 5 ORDER BY value;
```

**Oracle Result:**
```
ID  NAME     VALUE
--  -------  -----
1   Alice    100
3   Charlie  150
2   Bob      200
5   Eve      250
4   David    300
```

**IvorySQL Result:**
```
id |  name   | value
---+---------+-------
 1 | Alice   |   100
 3 | Charlie |   150
 2 | Bob     |   200
 5 | Eve     |   250
 4 | David   |   300
```

**Status:** MATCH

---

### Test 12: Correlated Subquery with ROWNUM

**Query:**
```sql
SELECT
    id,
    name,
    (SELECT ROWNUM FROM (
        SELECT * FROM rownum_test t2
        WHERE t2.id = t1.id
        ORDER BY value DESC
    ) sub) as correlated_rn
FROM rownum_test t1
WHERE ROWNUM <= 5
ORDER BY id;
```

**Oracle Result:**
```
ID  NAME     CORRELATED_RN
--  -------  -------------
1   Alice    1
2   Bob      1
3   Charlie  1
4   David    1
5   Eve      1
```

**IvorySQL Result:**
```
id |  name   | correlated_rn
---+---------+---------------
 1 | Alice   |             1
 2 | Bob     |             1
 3 | Charlie |             1
 4 | David   |             1
 5 | Eve     |             1
```

**Status:** MATCH

---

### Test 13: MAX ROWNUM in Correlated Subquery

**Query:**
```sql
SELECT
    id,
    (SELECT MAX(ROWNUM) FROM rownum_test t2 WHERE t2.id = t1.id) as max_rn
FROM rownum_test t1
WHERE id <= 5
GROUP BY id
ORDER BY id;
```

**Oracle Result:**
```
ID  MAX_RN
--  ------
1   1
2   1
3   1
4   1
5   1
```

**IvorySQL Result:**
```
id | max_rn
---+--------
 1 |      1
 2 |      1
 3 |      1
 4 |      1
 5 |      1
```

**Status:** MATCH

---

### Test 14: ROWNUM with Filter (Non-ROWNUM Condition)

**Query:**
```sql
SELECT ROWNUM, id FROM rownum_test WHERE id >= 5;
```

**Oracle Result:**
```
ROWNUM  ID
------  --
1       5
2       6
3       7
4       8
5       9
6       10
```

**IvorySQL Result:**
```
rownum | id
-------+----
     1 |  5
     2 |  6
     3 |  7
     4 |  8
     5 |  9
     6 | 10
```

**Status:** MATCH

---

### Test 15: Combined ROWNUM and Filter Condition

**Query:**
```sql
SELECT ROWNUM, id FROM rownum_test WHERE ROWNUM <= 3 AND id >= 5;
```

**Oracle Result:**
```
ROWNUM  ID
------  --
1       5
2       6
3       7
```

**IvorySQL Result:**
```
rownum | id
-------+----
     1 |  5
     2 |  6
     3 |  7
```

**Status:** MATCH

---

### Test 16: UNION with ROWNUM (Known Difference)

**Query:**
```sql
SELECT ROWNUM as rn, id FROM rownum_test WHERE id <= 3
UNION
SELECT ROWNUM as rn, id FROM rownum_test WHERE id > 7
ORDER BY rn, id;
```

**Oracle Result:**
```
RN  ID
--  --
1   1
1   8
2   2
2   9
3   3
3   10
```

**IvorySQL Result:**
```
rn | id
---+----
 1 |  1
 2 |  2
 3 |  3
 4 |  8
 5 |  9
 6 | 10
```

**Status:** MISMATCH

**Explanation:** Oracle treats each UNION branch as an independent query block, so each branch has its own ROWNUM counter starting at 1. IvorySQL uses a shared counter across all branches.

---

## Summary

| Test | Description | Status |
|------|-------------|--------|
| 1 | ROWNUM <= N | MATCH |
| 2 | ROWNUM = 1 | MATCH |
| 3 | ROWNUM < N | MATCH |
| 4 | ROWNUM in SELECT | MATCH |
| 5 | Top-N with ORDER BY | MATCH |
| 6 | Multiple ROWNUM levels | MATCH |
| 7 | ROWNUM > 0 (tautology) | MATCH |
| 8 | ROWNUM > N (always false) | MATCH |
| 9 | ROWNUM = N where N>1 | MATCH |
| 10 | COUNT with ROWNUM | MATCH |
| 11 | ORDER BY with ROWNUM | MATCH |
| 12 | Correlated subquery | MATCH |
| 13 | MAX ROWNUM correlated | MATCH |
| 14 | ROWNUM with filter | MATCH |
| 15 | Combined conditions | MATCH |
| 16 | UNION with ROWNUM | **MISMATCH** |

**Overall:** 15 of 16 test categories match Oracle behavior. The only known difference is UNION handling, where Oracle provides independent ROWNUM counters per branch.
