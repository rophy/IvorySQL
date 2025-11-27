/*-------------------------------------------------------------------------
 *
 * pl_autonomous.c
 *	  Autonomous transaction support for PL/iSQL
 *
 *-------------------------------------------------------------------------
 */

#include "postgres.h"

#include "access/xact.h"
#include "catalog/namespace.h"
#include "catalog/pg_extension.h"
#include "catalog/pg_proc.h"
#include "catalog/pg_type.h"
#include "commands/extension.h"
#include "executor/spi.h"
#include "fmgr.h"
#include "libpq/libpq-be.h"
#include "miscadmin.h"
#include "nodes/makefuncs.h"
#include "parser/parse_func.h"
#include "parser/parse_type.h"
#include "utils/builtins.h"
#include "utils/guc.h"
#include "utils/inval.h"
#include "utils/lsyscache.h"
#include "utils/syscache.h"

#include "plisql.h"
#include "pl_autonomous.h"

static Oid	dblink_exec_oid = InvalidOid;

/*
 * Invalidation callback to reset cached dblink_exec OID.
 * Called when pg_proc catalog changes (e.g., extension drop/recreate).
 */
static void
dblink_oid_invalidation_callback(Datum arg, int cacheid, uint32 hashvalue)
{
	/* Reset the cached OID so it will be looked up again next time */
	dblink_exec_oid = InvalidOid;
}

/*
 * Initialize autonomous transaction support.
 * Register syscache invalidation callback for dblink_exec OID.
 */
void
plisql_autonomous_init(void)
{
	/* Register callback to invalidate cached dblink_exec OID on pg_proc changes */
	CacheRegisterSyscacheCallback(PROCOID, dblink_oid_invalidation_callback, (Datum) 0);
}

/* Helper: Get current database name safely without SPI */
static char *
get_current_database(void)
{
	/*
	 * Get database name from MyProcPort structure.
	 * This is safe - no catalog access needed, just reading from
	 * the connection's Port structure.
	 *
	 * MyProcPort is set during backend startup and should always be
	 * available in a normal client backend. If it's NULL, we're in
	 * an unexpected context (e.g., background worker, standalone mode).
	 */
	if (MyProcPort == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_INTERNAL_ERROR),
				 errmsg("autonomous transactions cannot run in background processes"),
				 errdetail("MyProcPort is NULL - not a client backend")));

	if (MyProcPort->database_name == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_INTERNAL_ERROR),
				 errmsg("database name not available in connection info"),
				 errdetail("MyProcPort->database_name is NULL")));

	return pstrdup(MyProcPort->database_name);
}

/* Helper: Get procedure/function name from OID */
static char *
get_procedure_name(Oid funcoid)
{
	HeapTuple proctup;
	Form_pg_proc procstruct;
	char *procname;
	char *nspname;
	char *result;

	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(funcoid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", funcoid);

	procstruct = (Form_pg_proc) GETSTRUCT(proctup);
	procname = NameStr(procstruct->proname);

	/* Get schema name for fully qualified name */
	nspname = get_namespace_name(procstruct->pronamespace);

	/* Build schema-qualified name */
	result = psprintf("%s.%s", quote_identifier(nspname), quote_identifier(procname));

	ReleaseSysCache(proctup);
	return result;
}

void
plisql_mark_autonomous_transaction(PLiSQL_function *func, int location, void *yyscanner)
{
	if (func == NULL)
		ereport(ERROR,
				(errcode(ERRCODE_SYNTAX_ERROR),
				 errmsg("PRAGMA AUTONOMOUS_TRANSACTION must be inside a function or procedure"),
				 plisql_scanner_errposition(location, yyscanner)));

	if (func->fn_is_autonomous)
		ereport(ERROR,
				(errcode(ERRCODE_SYNTAX_ERROR),
				 errmsg("duplicate PRAGMA AUTONOMOUS_TRANSACTION"),
				 plisql_scanner_errposition(location, yyscanner)));

	/*
	 * Don't check for dblink availability at procedure creation time.
	 * Check it at execution time instead. This avoids crashes during
	 * CREATE PROCEDURE when dblink might not be accessible yet.
	 */

	func->fn_is_autonomous = true;
}

bool
plisql_check_dblink_available(void)
{
	return OidIsValid(get_extension_oid("dblink", true));
}

/* Build SQL to call procedure by name in autonomous session */
static char *
build_autonomous_call(PLiSQL_function *func, FunctionCallInfo fcinfo)
{
	StringInfoData sql;
	StringInfoData args;
	char *proc_name;
	HeapTuple proctup;
	Form_pg_proc procstruct;
	int i;

	initStringInfo(&sql);
	initStringInfo(&args);

	/* Get procedure/function name */
	proc_name = get_procedure_name(func->fn_oid);

	/* Get procedure info for argument types */
	proctup = SearchSysCache1(PROCOID, ObjectIdGetDatum(func->fn_oid));
	if (!HeapTupleIsValid(proctup))
		elog(ERROR, "cache lookup failed for function %u", func->fn_oid);
	procstruct = (Form_pg_proc) GETSTRUCT(proctup);

	/* Format arguments */
	for (i = 0; i < fcinfo->nargs; i++)
	{
		if (i > 0)
			appendStringInfoString(&args, ", ");

		if (fcinfo->args[i].isnull)
		{
			appendStringInfoString(&args, "NULL");
		}
		else
		{
			Oid argtype = procstruct->proargtypes.values[i];
			Oid typoutput;
			bool typIsVarlena;
			char *valstr;

			getTypeOutputInfo(argtype, &typoutput, &typIsVarlena);
			valstr = OidOutputFunctionCall(typoutput, fcinfo->args[i].value);

			/* Format based on type */
			switch (argtype)
			{
				case INT2OID:
				case INT4OID:
				case INT8OID:
				case FLOAT4OID:
				case FLOAT8OID:
				case NUMERICOID:
				case OIDOID:
					/* Numeric types don't need quoting */
					appendStringInfoString(&args, valstr);
					break;
				case BOOLOID:
					/* Convert 't'/'f' to 'true'/'false' for SQL */
					if (DatumGetBool(fcinfo->args[i].value))
						appendStringInfoString(&args, "true");
					else
						appendStringInfoString(&args, "false");
					break;
				default:
					/* Quote string literals and other types */
					appendStringInfoString(&args, quote_literal_cstr(valstr));
					break;
			}
			pfree(valstr);
		}
	}

	/* Build complete SQL - call procedure by name with recursion prevention */
	appendStringInfo(&sql,
		"SET ivorysql.compatible_mode = oracle; "
		"SET plisql.inside_autonomous_transaction = true; "
		"CALL %s(%s);",
		proc_name,
		args.data);

	ReleaseSysCache(proctup);
	pfree(proc_name);

	return sql.data;
}

Datum
plisql_exec_autonomous_function(PLiSQL_function *func, FunctionCallInfo fcinfo,
								EState *simple_eval_estate, ResourceOwner simple_eval_resowner)
{
	char *sql;
	char *connstr;
	StringInfoData connstr_buf;
	const char *port_str;
	char *dbname;
	Datum connstr_datum;
	Datum sql_datum;
	Datum result_datum;
	char *result_str;
	Oid dblink_exec_oid_local;

	/* Lookup dblink_exec function if not cached */
	if (!OidIsValid(dblink_exec_oid))
	{
		Oid argtypes[2] = {TEXTOID, TEXTOID};
		dblink_exec_oid_local = LookupFuncName(list_make1(makeString("dblink_exec")), 2, argtypes, true);
		if (!OidIsValid(dblink_exec_oid_local))
			ereport(ERROR,
					(errcode(ERRCODE_UNDEFINED_FUNCTION),
					 errmsg("dblink_exec function not found"),
					 errhint("Install dblink extension: CREATE EXTENSION dblink")));
		dblink_exec_oid = dblink_exec_oid_local;
	}

	/* Get current database name dynamically */
	dbname = get_current_database();

	/* Build SQL to call procedure by name */
	sql = build_autonomous_call(func, fcinfo);

	/* Build connection string */
	port_str = GetConfigOption("port", false, false);
	initStringInfo(&connstr_buf);
	appendStringInfo(&connstr_buf, "dbname=%s", dbname);
	if (port_str)
		appendStringInfo(&connstr_buf, " port=%s", port_str);

	connstr = connstr_buf.data;
	connstr_datum = CStringGetTextDatum(connstr);
	sql_datum = CStringGetTextDatum(sql);

	/* Execute via dblink with error handling */
	PG_TRY();
	{
		result_datum = OidFunctionCall2(dblink_exec_oid, connstr_datum, sql_datum);
		result_str = TextDatumGetCString(result_datum);

		/* Check for errors in result */
		if (strncmp(result_str, "ERROR", 5) == 0)
			ereport(ERROR,
					(errcode(ERRCODE_EXTERNAL_ROUTINE_EXCEPTION),
					 errmsg("autonomous transaction failed"),
					 errdetail("%s", result_str)));
		pfree(result_str);
	}
	PG_CATCH();
	{
		/* Clean up and re-throw */
		pfree(sql);
		pfree(dbname);
		PG_RE_THROW();
	}
	PG_END_TRY();

	/* Clean up */
	pfree(sql);
	pfree(dbname);

	/* For now, autonomous procedures return NULL */
	fcinfo->isnull = true;
	return (Datum) 0;
}
