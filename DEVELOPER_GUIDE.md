# Developer Guide

This document defines hash pinning rules and update procedures for source dependencies.

## 1. Hash pinning rules
- Managed manifests:
  - `ros2.lock.repos` (locked ROS 2 sources)
  - `third_party.repos` (non-ROS dependencies)
- `version` must always be a **40-character lowercase commit hash** (SHA-1).
- `type` must be `git`, and `url` must be an `https://` git URL.
- Do not leave branch names or tags in production manifests.

## 2. Which files to edit
- Update source references in `ros2.repos`.
- Build-time ROS input must be `ros2.lock.repos`.
- Update non-ROS dependencies directly in `third_party.repos` (always hash-pinned).

## 3. ROS 2 hash update flow
1. Edit target repositories in `ros2.repos`.
2. Regenerate the lock file (default: add only repos that are missing from `ros2.lock.repos`):

```bash
./scripts/generate_ros2_lock.sh
```

To refresh all lock entries from `ros2.repos`:

```bash
./scripts/generate_ros2_lock.sh --all
```

3. Validate pinning:

```bash
uv run python scripts/check_repos_pinned.py ros2.lock.repos third_party.repos
```

4. Re-sync and verify build:

```bash
./scripts/sync_ros2_sources.sh
CLEAN_BUILD=0 ./scripts/run_isolated_build.sh
```

## 4. third_party hash update flow
1. Update the target entry hash in `third_party.repos`.
2. Validate pinning:

```bash
uv run python scripts/check_repos_pinned.py third_party.repos
```

3. Rebuild to verify:

```bash
./scripts/run_isolated_build.sh
```

## 5. Validation mechanics
- `scripts/check_repos_pinned.py`
  - Validates 40-character lowercase commit hashes.
  - Validates `type/url/version` shape.
- `scripts/sync_git_repos.py`
  - Rejects unexpected `origin` URL changes.
  - With `--force-clean`, resets local changes via `git reset --hard` and `git clean -fd`.
  - Verifies checked out `HEAD` against expected hash.

## 6. CI enforcement
- `.github/workflows/build.yml` runs `validate-locks` on:
  - `ros2.lock.repos`
  - `third_party.repos`
- Any pinning violation fails CI.

## 7. Minimum PR requirements
- Include manifest updates and build verification in the same PR.
- Explain why hashes changed in the PR description.
- At minimum, verify `talker/listener` communication after updates.
