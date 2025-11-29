/***************************************************************
 *
 * DBMS_UTILITY package - Oracle compatibility package
 *
 * This package provides utility functions compatible with Oracle's
 * DBMS_UTILITY package, including error handling and formatting functions.
 *
 ***************************************************************/

-- Create DBMS_UTILITY package specification
CREATE OR REPLACE PACKAGE dbms_utility IS
  /*
   * FORMAT_ERROR_BACKTRACE - Returns formatted error backtrace
   *
   * This Oracle-compatible function automatically retrieves the exception
   * context when called from within an exception handler. Returns empty
   * string if called outside an exception handler.
   *
   * Usage:
   *   BEGIN
   *     some_procedure();
   *   EXCEPTION
   *     WHEN OTHERS THEN
   *       DBMS_OUTPUT.PUT_LINE(DBMS_UTILITY.FORMAT_ERROR_BACKTRACE);
   *   END;
   */
  FUNCTION FORMAT_ERROR_BACKTRACE RETURN VARCHAR2;

  -- Future functions:
  -- FUNCTION FORMAT_ERROR_STACK RETURN VARCHAR2;
  -- FUNCTION FORMAT_CALL_STACK RETURN VARCHAR2;
END dbms_utility;

-- Create DBMS_UTILITY package body
CREATE OR REPLACE PACKAGE BODY dbms_utility IS

  FUNCTION FORMAT_ERROR_BACKTRACE RETURN VARCHAR2 IS
  BEGIN
    /*
     * Call the C function that retrieves the current exception context
     * from PL/iSQL's session-level storage and formats it.
     */
    RETURN sys.ora_format_error_backtrace();
  END FORMAT_ERROR_BACKTRACE;

END dbms_utility;
