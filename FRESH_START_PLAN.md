# Arm64 macOS ROS 2 Fresh-Start Plan

## Objective
Build ROS 2 on Arm64 macOS in a fully local, reproducible environment that does not rely on Homebrew at build time.

## Priority Order
1. Local standalone build success (no brew reference)
2. Reproducible dependency and Python environment locking
3. Continuous verification in CI

## Constraints
- Python environment must be managed only by `uv`.
- Python dependencies must be declared in `pyproject.toml`.
- Compilers and all non-system dependencies must be obtained from `git clone` with fixed commit hashes.
- Build scripts must not depend on Homebrew binaries, include paths, or libraries.

## Phase 0: Baseline and Branching
- [x] Create dedicated migration branch (`chore/arm64-macos-fresh-start`).
- [ ] Record current build inputs and known failing points from existing setup.
- [ ] Define supported host baseline (macOS version + Xcode/Command Line Tools minimum).

Exit Criteria:
- Branch and baseline assumptions are documented.

## Phase 1: Source Pinning and Manifest Strategy
- [ ] Replace floating refs in `ros2.repos` with exact commit hashes.
- [ ] Add a separate lock manifest for non-ROS dependencies and toolchain sources:
  - compiler toolchain
  - CMake/Ninja and other build tools
  - third-party C/C++ libs currently coming from brew
- [ ] Add a verification script that fails if any source entry is not hash-pinned.

Exit Criteria:
- All cloned sources (ROS + non-ROS) are hash-pinned and machine-checkable.

## Phase 2: Python via uv
- [ ] Add `pyproject.toml` and define all Python dependencies and versions.
- [ ] Add `uv.lock` and enforce frozen sync in automation.
- [ ] Replace direct `pip` usage with `uv sync` and `uv run`.
- [ ] Ensure `colcon`, `vcstool`, lint/test tooling, and ROS Python deps are available via uv environment.

Exit Criteria:
- `uv sync --frozen` reproduces the Python environment from a clean state.

## Phase 3: Local Toolchain and Dependency Bootstrap
- [ ] Introduce deterministic bootstrap scripts (for example under `scripts/`):
  - clone by hash
  - build/install into repository-local prefix (for example `.local/`)
- [ ] Export environment through a single activation script (PATH, CMAKE_PREFIX_PATH, PKG_CONFIG_PATH, etc.).
- [ ] Ensure scripts are idempotent and resumable.

Exit Criteria:
- A fresh machine can build required native deps without Homebrew packages.

## Phase 4: ROS 2 Build in Isolated Shell
- [ ] Build ROS 2 workspace using only:
  - system-provided base tools (macOS/Xcode CLT)
  - repository-local toolchain/dependency prefix
  - uv-managed Python
- [ ] Apply local patches deterministically during bootstrap/build.
- [ ] Add a strict isolation check command (minimal env shell) to prove no brew path leakage.

Exit Criteria:
- `colcon build` succeeds from a clean checkout in isolated mode.

## Phase 5: CI Hardening
- [ ] Rewrite GitHub Actions workflow to use new bootstrap and uv flow.
- [ ] Add mandatory checks:
  - source pinning validation
  - Python lock reproducibility
  - isolated ROS build smoke test
- [ ] Publish logs/artifacts needed for quick failure triage.

Exit Criteria:
- CI fails immediately on unpinned dependencies, environment drift, or build regressions.

## Phase 6: Documentation and Legacy Cleanup
- [ ] Rewrite `README.md` and `install_guide.md` for fresh-start flow.
- [ ] Deprecate or remove legacy brew-based `setup.sh`.
- [ ] Document patch policy and update procedure for pinned hashes.

Exit Criteria:
- New contributors can follow one canonical path and reproduce build results.

## First Implementation Slice (Recommended)
1. Add manifests for hash-pinned sources (ROS + non-ROS).
2. Add `pyproject.toml` + `uv.lock`.
3. Add bootstrap/env scripts for local prefix.
4. Run isolated local build and capture missing deps.
5. Iterate until local build passes, then move CI to same commands.

## Risks and Mitigations
- Long native build time:
  - mitigate with incremental bootstrap + cache directories.
- Hidden transitive dependency leakage from host:
  - mitigate with isolated-shell checks and explicit path assertions.
- Upstream hash churn / mirror outage:
  - mitigate with lock manifest governance and optional source mirrors.
