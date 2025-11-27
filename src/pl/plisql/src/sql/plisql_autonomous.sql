--
-- Test PRAGMA AUTONOMOUS_TRANSACTION
--
-- This test verifies autonomous transaction functionality using dblink
--

-- Setup: Enable Oracle mode and install dblink
CREATE EXTENSION IF NOT EXISTS dblink;

-- Create test table
CREATE TABLE autonomous_test (
    id INT,
    msg TEXT,
    tx_state TEXT DEFAULT 'unknown'
);

--
-- Test 1: Basic autonomous transaction (no parameters)
--
CREATE OR REPLACE PROCEDURE test_basic AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (1, 'basic test', 'committed');
END;
$$ LANGUAGE plisql;
/

-- Must commit procedure before calling it
COMMIT;

CALL test_basic();
SELECT id, msg, tx_state FROM autonomous_test WHERE id = 1;

--
-- Test 2: Autonomous transaction with parameters
--
CREATE OR REPLACE PROCEDURE test_with_params(p_id INT, p_msg TEXT) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (p_id, p_msg, 'committed');
END;
$$ LANGUAGE plisql;
/

COMMIT;

CALL test_with_params(2, 'with params');
SELECT id, msg, tx_state FROM autonomous_test WHERE id = 2;

--
-- Test 3: Transaction isolation - autonomous commit survives outer rollback
--
CREATE OR REPLACE PROCEDURE test_isolation(p_id INT) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (p_id, 'autonomous', 'committed');
END;
$$ LANGUAGE plisql;
/

COMMIT;

-- Start a transaction and rollback
BEGIN;
    INSERT INTO autonomous_test VALUES (100, 'before autonomous', 'rolled back');
    CALL test_isolation(200);
    INSERT INTO autonomous_test VALUES (300, 'after autonomous', 'rolled back');
ROLLBACK;

-- Verify: Only id=200 should exist (100 and 300 rolled back)
SELECT id, msg, tx_state FROM autonomous_test WHERE id >= 100 ORDER BY id;

--
-- Test 4: Multiple parameters with different types
--
CREATE OR REPLACE PROCEDURE test_multi_types(
    p_int INT,
    p_text TEXT,
    p_bool BOOLEAN
) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (
        p_int,
        p_text || ' (bool=' || p_bool::TEXT || ')',
        'committed'
    );
END;
$$ LANGUAGE plisql;
/

COMMIT;

CALL test_multi_types(4, 'multi-type', true);
SELECT id, msg FROM autonomous_test WHERE id = 4;

--
-- Test 5: NULL parameter handling
--
CREATE OR REPLACE PROCEDURE test_nulls(p_id INT, p_msg TEXT) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (p_id, COALESCE(p_msg, 'NULL msg'), 'committed');
END;
$$ LANGUAGE plisql;
/

COMMIT;

CALL test_nulls(5, NULL);
SELECT id, msg FROM autonomous_test WHERE id = 5;

--
-- Test 6: Multiple sequential autonomous calls
--
CREATE OR REPLACE PROCEDURE test_sequential(p_id INT) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (p_id, 'sequential', 'committed');
END;
$$ LANGUAGE plisql;
/

COMMIT;

CALL test_sequential(6);
CALL test_sequential(7);
CALL test_sequential(8);

SELECT id, msg FROM autonomous_test WHERE id IN (6, 7, 8) ORDER BY id;

--
-- Test 7: Error handling - missing dblink should give clear error
--
-- Note: We can't actually test this because dblink is already installed,
-- but the error message would be:
-- ERROR: dblink_exec function not found
-- HINT: Install dblink extension: CREATE EXTENSION dblink

--
-- Test 8: Verify transaction isolation - autonomous changes persist
--
TRUNCATE autonomous_test;

CREATE OR REPLACE PROCEDURE test_persist(p_id INT) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (p_id, 'should persist', 'committed');
END;
$$ LANGUAGE plisql;
/

COMMIT;

-- Outer transaction that will rollback
BEGIN;
    INSERT INTO autonomous_test VALUES (1000, 'will rollback', 'rolled back');
    CALL test_persist(2000);
    INSERT INTO autonomous_test VALUES (3000, 'will rollback', 'rolled back');

    -- Check within transaction - both should be visible
    SELECT COUNT(*) AS count_in_tx FROM autonomous_test;
ROLLBACK;

-- After rollback - only autonomous insert should remain
SELECT id, msg, tx_state FROM autonomous_test ORDER BY id;

--
-- Test 9: Extension drop/recreate - verify OID invalidation works
--
CREATE OR REPLACE PROCEDURE test_oid_invalidation(p_id INT) AS $$
PRAGMA AUTONOMOUS_TRANSACTION;
BEGIN
    INSERT INTO autonomous_test VALUES (p_id, 'oid test', 'committed');
END;
$$ LANGUAGE plisql;
/

COMMIT;

-- Call once to cache the OID
CALL test_oid_invalidation(9);

-- Drop and recreate dblink extension (OID will change)
DROP EXTENSION dblink CASCADE;
CREATE EXTENSION dblink;

-- Call again - should work with new OID (tests invalidation callback)
CALL test_oid_invalidation(10);

-- Verify both calls succeeded
SELECT id, msg FROM autonomous_test WHERE id IN (9, 10) ORDER BY id;

--
-- Summary: Show all test results
--
SELECT 'All autonomous transaction tests completed' AS status;

-- Cleanup
DROP PROCEDURE test_basic();
DROP PROCEDURE test_with_params(INT, TEXT);
DROP PROCEDURE test_isolation(INT);
DROP PROCEDURE test_multi_types(INT, TEXT, BOOLEAN);
DROP PROCEDURE test_nulls(INT, TEXT);
DROP PROCEDURE test_sequential(INT);
DROP PROCEDURE test_persist(INT);
DROP PROCEDURE test_oid_invalidation(INT);
DROP TABLE autonomous_test;
