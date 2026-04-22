# .graphifyignore — what Graphify should NEVER index
# Format: one pattern per line, gitignore-style globs

# Virtual envs / dependency caches
.venv-graphify/
.venv/
venv/
env/
node_modules/
__pycache__/
*.pyc

# Graphify's own output
graphify-out/

# Generated assets (regenerable, not code)
assets/generated/

# Build / dist
dist/
build/
.svelte-kit/
.next/
out/

# Git internals
.git/

# Coverage / test artifacts
htmlcov/
.coverage
.pytest_cache/
.mypy_cache/
.ruff_cache/

# IDE
.vscode/
.idea/
.DS_Store

# Logs
*.log
logs/

# Secrets (should be in .env, not indexed)
.env
.env.local
.env.*.local
