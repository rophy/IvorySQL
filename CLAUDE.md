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
