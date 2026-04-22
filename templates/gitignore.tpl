# .gitignore

# Environment / secrets
.env
.env.local
.env.*.local
!.env.example

# Graphify
.venv-graphify/
graphify-out/

# Python
__pycache__/
*.pyc
*.pyo
*.pyd
*.egg-info/
.venv/
venv/
env/
.mypy_cache/
.ruff_cache/
.pytest_cache/
.coverage
htmlcov/

# Node / JS
node_modules/
.svelte-kit/
dist/
build/
out/
.next/

# AI-generated assets (regenerable; store URLs in DB + keep on CDN)
assets/generated/

# NeuralTree temp (backups etc)
.neuraltree/.tmp/

# IDE
.vscode/
.idea/
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Test artifacts
playwright-report/
test-results/
playwright/.cache/

# OS
*.swp
*~
