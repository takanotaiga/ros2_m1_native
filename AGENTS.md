# AGENTS.md

## Purpose
This repository aims to build ROS 2 (Humble lineage) natively on Arm64 macOS with high reproducibility.

## Current Snapshot
- Existing flow is Homebrew-centered (`install_guide.md`, `setup.sh`, `.github/workflows/build.yml`).
- ROS sources are imported via `ros2.repos` (many entries are branch/tag based, not commit-pinned).
- Local compatibility patches exist under `patches/`.

## Fresh-Start Goal (This Branch)
On branch `chore/arm64-macos-fresh-start`, migrate to a fully self-contained local build flow:
- Python environment managed only by `uv` and `pyproject.toml`.
- Compilers and all non-system dependencies fetched from git repositories with pinned commit hashes.
- No dependency on Homebrew paths or packages during configure/build/test.
- CI continuously checks that reproducibility assumptions hold.

## Non-Negotiable Rules
1. Do not add Homebrew-based install/build instructions.
2. Do not reference `$(brew --prefix)` in scripts, CMake flags, or CI.
3. Every external source must have:
   - canonical git URL
   - exact commit hash
   - deterministic build/install procedure
4. Python dependencies must be declared in `pyproject.toml` and installed via `uv`.
5. Build must pass in a shell that does not inherit Homebrew-related environment variables.

## Repository Map
- `ros2.repos`: ROS 2 source manifest (to be converted to commit-pinned form).
- `patches/`: local patches required for macOS Arm64 compatibility.
- `setup.sh`: legacy bootstrap script (brew-based; target for replacement).
- `install_guide.md`: legacy guide (brew-based; target for rewrite).
- `.github/workflows/build.yml`: current CI workflow (brew-based; target for rewrite).

## Working Conventions
1. Prefer adding new scripts under `scripts/` and keep them idempotent.
2. Keep lock/manifests in VCS (no floating branches in production manifests).
3. Separate concerns:
   - source fetching
   - toolchain/dependency build
   - ROS workspace build
   - validation checks
4. Document every new environment variable in a single env file and in README.
5. When changing dependency versions/hashes, update manifests and CI in the same PR.

## Definition of Done (Migration)
1. Fresh clone on Arm64 macOS can build ROS 2 in a local prefix without Homebrew.
2. Python setup is reproducible with `uv sync --frozen`.
3. CI verifies source pinning, environment isolation, and ROS build success.
4. Legacy brew-dependent docs/scripts are either removed or clearly marked deprecated.
