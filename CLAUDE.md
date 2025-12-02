# Background

This project is a work of [IvorySQL](https://github.com/IvorySQL/IvorySQL). Changes can be reviewed by comparing HEAD with upstream/master.


# Build Instructions

## Git Commit Policy (MANDATORY)

**Commit message format:**
```
<type>: <short description>

[optional body explaining why/what changed]
```

**RULES:**
- NO "Generated with Claude Code" footer
- NO "Co-Authored-By: Claude" line
- NO mention of "Claude" or "Happy" anywhere
- Keep messages short (1-5 lines preferred)
- Types: feat, fix, refactor, chore, docs, build, test

## Git Branch Convention (IMPORTANT)

- `master` should be based on upstream/master and match origin
- `test/dev-container` is upstream/master plus docker-compose for dev-containers and CLAUDE.md
- `test/*` should be based on `test/dev-container` plus commits for a single feature
- `feat/*` should be based on upstream/master, plus commits cherry-picked from `test/*` for submitting pull requests to upstream

When you want to test something and noticed you don't see containers, verify the active branch you're on.

## Quick Start

1. **Start the development container**
   ```bash
   docker compose up -d
   ```

2. **Configure the build**
   ```bash
   docker compose exec dev ./configure --prefix=/home/ivorysql/ivorysql --enable-debug --enable-cassert --with-uuid=e2fs --with-libxml
   ```

3. **Build the project**
   ```bash
   docker compose exec dev make -j4
   ```

4. **Install the build**
   ```bash
   docker compose exec dev make install
   ```

## Dual Build Systems (IMPORTANT)

IvorySQL supports two build systems that **must be kept in sync**:

| Build System | Configuration File | Build Command |
|--------------|-------------------|---------------|
| Autoconf/Make (traditional) | `Makefile` | `./configure && make` |
| Meson/Ninja (modern) | `meson.build` | `meson setup build && ninja -C build` |

### Adding New Source Files

When adding a new `.c` file, update BOTH:
- `Makefile` - add to `OBJS` list (as `.o`)
- `meson.build` - add to sources `files()` list (as `.c`)

### Adding New Tests

When adding a new test, update BOTH:
- `Makefile` - add to `REGRESS` list
- `meson.build` - add to `tests` sql list

**Failure to update both will cause build failures for users of the other build system.**

## Build Verification (CRITICAL)

**ALWAYS verify that installed files are newer than source files after `make install`.**

The build system may not rebuild files if timestamps are stale. After `make install`, verify:

```bash
# Check if binary is newer than source
docker compose exec dev stat -c "%Y %n" /home/ivorysql/ivorysql/bin/<binary> /home/ivorysql/IvorySQL/src/<path>/<source>.c

# Check if installed extension SQL is updated
docker compose exec dev grep "<expected_content>" /home/ivorysql/ivorysql/share/postgresql/extension/<file>.sql
```

**If installed files are older than source:**
1. Use `touch` on source files to update timestamps
2. Or run `make clean` in the specific subdirectory before rebuilding
3. Then run `make && make install` again

**Example - rebuilding initdb:**
```bash
docker compose exec dev bash -c "cd /home/ivorysql/IvorySQL/src/bin/initdb && make clean && make && make install"
```

**Example - reinstalling an extension SQL file:**
```bash
docker compose exec dev bash -c "cd /home/ivorysql/IvorySQL/src/pl/plisql/src && rm -f /home/ivorysql/ivorysql/share/postgresql/extension/plisql--1.0.sql && make install"
```

## Debugging with GDB

The dev container includes gdb with ptrace enabled.

**Debug initdb:**
```bash
docker compose exec dev bash -c "
export PATH=/home/ivorysql/IvorySQL/tmp_install/home/ivorysql/ivorysql/bin:\$PATH
export LD_LIBRARY_PATH=/home/ivorysql/IvorySQL/tmp_install/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
rm -rf /tmp/testdb
gdb -ex 'break main' -ex 'run -D /tmp/testdb' initdb
"
```

**Debug postgres backend:**
```bash
# Start server, then attach to a backend process
docker compose exec dev bash -c "
export PATH=/home/ivorysql/ivorysql/bin:\$PATH
gdb -p <backend_pid>
"
```

## Test Framework Overview

IvorySQL uses **pg_regress** (PostgreSQL's regression test framework) with multiple test suites:

### Test Suites

1. **PostgreSQL Compatibility Tests** (`src/test/regress/`)
   - **Runner**: `pg_regress`
   - Tests standard PostgreSQL features

2. **Oracle Compatibility Tests** (`src/oracle_test/regress/`)
   - **Runner**: `ora_pg_regress`
   - **Key tests**:
     - `ora_plisql.sql` - PL/iSQL language tests
     - `ora_package.sql` - Oracle package tests

3. **PL/iSQL Language Tests** (`src/pl/plisql/src/`)
   - Tests PL/iSQL procedural language internals
   - **Examples**: `plisql_array`, `plisql_control`, `plisql_dbms_output`, etc.
   - Command: `cd src/pl/plisql/src && make oracle-check`

4. **Oracle Extension Tests** (`contrib/ivorysql_ora/`)
   - Tests Oracle compatibility packages (DBMS_UTILITY, datatypes, functions)
   - Test files: `sql/*.sql` and expected outputs in `expected/*.out`
   - Tests defined in `ORA_REGRESS` variable in Makefile
   - Command: `cd contrib/ivorysql_ora && make installcheck`

### Test Pattern

All tests follow the same pattern:
1. SQL input files in `sql/` directory
2. Expected outputs in `expected/` directory (`.out` files)
3. Runner executes SQL and compares actual vs expected output

### Running Tests

```bash
# PostgreSQL tests
docker compose exec dev make check

# Oracle compatibility tests
docker compose exec dev make oracle-check

# Both test suites
docker compose exec dev make all-check

# Specific contrib module (e.g., ivorysql_ora)
docker compose exec dev bash -c "cd contrib/ivorysql_ora && make installcheck"

# PL/iSQL language tests
docker compose exec dev bash -c "cd src/pl/plisql/src && make oracle-check"
```

### Adding New Tests

**For Oracle packages (like DBMS_UTILITY):**
1. Create `contrib/ivorysql_ora/sql/<testname>.sql`
2. Create `contrib/ivorysql_ora/expected/<testname>.out`
3. Add `<testname>` to `ORA_REGRESS` in `contrib/ivorysql_ora/Makefile`
4. Run `make installcheck` to verify

## Manual Testing with Oracle Compatibility

When you need to test SQL manually (e.g., testing PL/iSQL packages):

1. **Initialize a test database in Oracle mode**
   ```bash
   docker compose exec dev bash -c "
   export PATH=/home/ivorysql/ivorysql/bin:\$PATH
   export LD_LIBRARY_PATH=/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
   cd /home/ivorysql
   rm -rf test_oracle
   initdb -D test_oracle --auth=trust -m oracle
   "
   ```

2. **Start the database server**
   ```bash
   docker compose exec dev bash -c "
   export PATH=/home/ivorysql/ivorysql/bin:\$PATH
   export LD_LIBRARY_PATH=/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
   pg_ctl -D /home/ivorysql/test_oracle -l /home/ivorysql/test_oracle/logfile start
   "
   ```

   **Note:** Oracle mode servers listen on **both ports**:
   - Port 5432 (PostgreSQL default)
   - Port 1521 (Oracle default)

3. **Create a test database**
   ```bash
   docker compose exec dev bash -c "
   export PATH=/home/ivorysql/ivorysql/bin:\$PATH
   export LD_LIBRARY_PATH=/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
   createdb testdb
   "
   ```

4. **Connect and test (use Oracle port 1521)**
   ```bash
   # Interactive connection
   docker compose exec dev bash -c "
   export PATH=/home/ivorysql/ivorysql/bin:\$PATH
   export LD_LIBRARY_PATH=/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
   psql -h localhost -p 1521 -d testdb
   "

   # Run a SQL file
   docker compose exec dev bash -c "
   export PATH=/home/ivorysql/ivorysql/bin:\$PATH
   export LD_LIBRARY_PATH=/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
   psql -h localhost -p 1521 -d testdb -f /path/to/your/file.sql
   "
   ```

5. **Stop the test server when done**
   ```bash
   docker compose exec dev bash -c "
   export PATH=/home/ivorysql/ivorysql/bin:\$PATH
   export LD_LIBRARY_PATH=/home/ivorysql/ivorysql/lib:\$LD_LIBRARY_PATH
   pg_ctl -D /home/ivorysql/test_oracle stop -m fast
   "
   ```

**Important:** Always use port **1521** when testing Oracle PL/SQL compatibility features (packages, PL/iSQL procedures, etc.)

## Testing Against Real Oracle Database

A real Oracle Database Free container is available for validating Oracle compatibility.

### Container Information

- **Container name:** `ivorysql-oracle-1`
- **Image:** `container-registry.oracle.com/database/free:23.26.0.0-lite`
- **Version:** Oracle 23.26 Free
- **Status:** Optional; requires `--profile ora` flag to start
- **Memory:** Requires minimum 3GB RAM

**IMPORTANT - Check before starting:**
The Oracle container requires 3GB+ RAM. Multiple git worktrees can share one instance.
**ALWAYS** check for existing Oracle containers before starting a new one:
```bash
docker ps --filter "ancestor=container-registry.oracle.com/database/free:23.26.0.0-lite"
```
If an Oracle container is already running, use `docker exec` to connect to it directly. Do NOT start another instance.

**Starting the Oracle container (only if none exists):**
```bash
docker compose --profile ora up -d
```

### Connecting to Oracle

**Interactive SQL*Plus session:**
```bash
docker exec -it ivorysql-oracle-1 sqlplus / as sysdba
```

**Run SQL from command line:**
```bash
docker exec ivorysql-oracle-1 bash -c "echo 'SELECT * FROM dual;' | sqlplus -s / as sysdba"
```

**Run inline SQL script:**
```bash
docker exec ivorysql-oracle-1 bash -c "cat << 'EOF' | sqlplus -s / as sysdba
SET SERVEROUTPUT ON;
DECLARE
  result NUMBER;
BEGIN
  SELECT (100 - 50) * 0.01 INTO result FROM dual;
  DBMS_OUTPUT.PUT_LINE('Result: ' || result);
END;
/
EXIT;
EOF
"
```

