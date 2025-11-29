/***************************************************************
 *
 * DBMS_OUTPUT package - Full Oracle-compatible implementation
 *
 * This provides native buffering for PUT_LINE, PUT, NEW_LINE,
 * GET_LINE, and GET_LINES with full Oracle compatibility.
 *
 * Tested against Oracle Database Free 23.26.0.0
 * See design/dbms_output/ORACLE_BEHAVIOR.md for validation details
 *
 ***************************************************************/

-- Register C functions
CREATE FUNCTION sys.ora_dbms_output_enable(buffer_size INTEGER DEFAULT 20000)
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_output_enable'
LANGUAGE C VOLATILE;

CREATE FUNCTION sys.ora_dbms_output_disable()
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_output_disable'
LANGUAGE C VOLATILE;

CREATE FUNCTION sys.ora_dbms_output_put_line(a VARCHAR2)
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_output_put_line'
LANGUAGE C VOLATILE;

CREATE FUNCTION sys.ora_dbms_output_put(a VARCHAR2)
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_output_put'
LANGUAGE C VOLATILE;

CREATE FUNCTION sys.ora_dbms_output_new_line()
RETURNS VOID
AS 'MODULE_PATHNAME', 'ora_dbms_output_new_line'
LANGUAGE C VOLATILE;

-- Create composite types for GET_LINE and GET_LINES return values
CREATE TYPE sys.dbms_output_line AS (
    line VARCHAR2,
    status INTEGER
);

CREATE TYPE sys.dbms_output_lines AS (
    lines VARCHAR2[],
    numlines INTEGER
);

CREATE FUNCTION sys.ora_dbms_output_get_line()
RETURNS sys.dbms_output_line
AS 'MODULE_PATHNAME', 'ora_dbms_output_get_line'
LANGUAGE C VOLATILE;

CREATE FUNCTION sys.ora_dbms_output_get_lines(numlines INTEGER)
RETURNS sys.dbms_output_lines
AS 'MODULE_PATHNAME', 'ora_dbms_output_get_lines'
LANGUAGE C VOLATILE;

-- Create DBMS_OUTPUT package
CREATE OR REPLACE PACKAGE sys.dbms_output IS
    PROCEDURE enable(buffer_size INTEGER DEFAULT 20000);
    PROCEDURE disable;
    PROCEDURE put_line(a VARCHAR2);
    PROCEDURE put(a VARCHAR2);
    PROCEDURE new_line;
    PROCEDURE get_line(line OUT VARCHAR2, status OUT INTEGER);
    PROCEDURE get_lines(lines OUT VARCHAR2[], numlines IN OUT INTEGER);
END dbms_output;

CREATE OR REPLACE PACKAGE BODY sys.dbms_output IS

    PROCEDURE enable(buffer_size INTEGER DEFAULT NULL) IS
    BEGIN
        PERFORM sys.ora_dbms_output_enable(buffer_size);
    END;

    PROCEDURE disable IS
    BEGIN
        PERFORM sys.ora_dbms_output_disable();
    END;

    PROCEDURE put_line(a VARCHAR2) IS
    BEGIN
        PERFORM sys.ora_dbms_output_put_line(a);
    END;

    PROCEDURE put(a VARCHAR2) IS
    BEGIN
        PERFORM sys.ora_dbms_output_put(a);
    END;

    PROCEDURE new_line IS
    BEGIN
        PERFORM sys.ora_dbms_output_new_line();
    END;

    PROCEDURE get_line(line OUT VARCHAR2, status OUT INTEGER) IS
        result sys.dbms_output_line;
    BEGIN
        SELECT * INTO result FROM sys.ora_dbms_output_get_line();
        line := result.line;
        status := result.status;
    END;

    PROCEDURE get_lines(lines OUT VARCHAR2[], numlines IN OUT INTEGER) IS
        result sys.dbms_output_lines;
    BEGIN
        SELECT * INTO result FROM sys.ora_dbms_output_get_lines(numlines);
        lines := result.lines;
        numlines := result.numlines;
    END;

END dbms_output;
