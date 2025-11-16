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
   docker compose exec dev make -j\$(nproc)
   ```

## Running Tests

```bash
# PostgreSQL tests (228 tests)
docker compose exec dev make check

# Oracle compatibility tests (234 tests)
docker compose exec dev make oracle-check

# Both test suites
docker compose exec dev make all-check
```

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
