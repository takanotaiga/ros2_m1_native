#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path

import yaml

PINNED_SHA1_RE = re.compile(r"^[0-9a-f]{40}$")


def run(cmd: list[str], cwd: Path | None = None, capture: bool = False) -> str:
    proc = subprocess.run(
        cmd,
        cwd=cwd,
        check=False,
        text=True,
        capture_output=capture,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.strip() if proc.stderr else ""
        stdout = proc.stdout.strip() if proc.stdout else ""
        message = stderr or stdout or f"command failed with exit code {proc.returncode}"
        raise RuntimeError(f"{' '.join(cmd)}: {message}")
    return proc.stdout if capture else ""


def load_repositories(manifest_path: Path, *, required: bool) -> dict[str, dict[str, str]]:
    if not manifest_path.exists():
        if required:
            raise RuntimeError(f"{manifest_path}: file not found")
        return {}

    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    if data is None:
        return {}
    if not isinstance(data, dict):
        raise RuntimeError(f"{manifest_path}: top-level must be a mapping")

    repositories = data.get("repositories", {})
    if not isinstance(repositories, dict):
        raise RuntimeError(f"{manifest_path}: 'repositories' must be a mapping")

    normalized: dict[str, dict[str, str]] = {}
    for name, spec in repositories.items():
        if not isinstance(spec, dict):
            raise RuntimeError(f"{manifest_path}: {name}: entry must be a mapping")
        normalized[name] = spec
    return normalized


def resolve_locked_spec(
    src_root: Path, repo_name: str, source_spec: dict[str, str]
) -> dict[str, str]:
    repo_type = source_spec.get("type")
    repo_url = source_spec.get("url")
    if repo_type != "git":
        raise RuntimeError(f"{repo_name}: type must be 'git' in source manifest")
    if not isinstance(repo_url, str):
        raise RuntimeError(f"{repo_name}: missing url in source manifest")

    repo_path = src_root / repo_name
    if not repo_path.exists():
        raise RuntimeError(f"{repo_name}: expected repository at {repo_path} was not found")

    commit = run(["git", "rev-parse", "HEAD"], cwd=repo_path, capture=True).strip()
    if not PINNED_SHA1_RE.fullmatch(commit):
        raise RuntimeError(f"{repo_name}: resolved commit is not a pinned SHA-1 ({commit})")

    return {
        "type": "git",
        "url": repo_url,
        "version": commit,
    }


def sync_repositories(sync_script: Path, manifest: Path, src_root: Path, repo_names: list[str]) -> None:
    if not repo_names:
        return

    cmd = [
        sys.executable,
        str(sync_script),
        "--manifest",
        str(manifest),
        "--root",
        str(src_root),
        "--allow-non-pinned",
    ]
    for name in repo_names:
        cmd.extend(["--repo", name])

    run(cmd)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate ros2.lock.repos from ros2.repos. Default mode adds only missing repositories."
    )
    parser.add_argument("--manifest", required=True, type=Path, help="Path to ros2.repos")
    parser.add_argument("--lock-manifest", required=True, type=Path, help="Path to ros2.lock.repos")
    parser.add_argument("--src-root", required=True, type=Path, help="Path to local source root (src)")
    parser.add_argument(
        "--all",
        action="store_true",
        help="Update all repositories in ros2.repos (not only missing entries).",
    )
    args = parser.parse_args()

    sync_script = Path(__file__).resolve().with_name("sync_git_repos.py")
    source_repositories = load_repositories(args.manifest, required=True)
    lock_repositories = load_repositories(args.lock_manifest, required=False)

    if args.all:
        target_names = sorted(source_repositories.keys())
        print(f"[lock] full update mode: {len(target_names)} repositories")
    else:
        target_names = sorted(set(source_repositories.keys()) - set(lock_repositories.keys()))
        print(f"[lock] diff mode: {len(target_names)} missing repositories")

    sync_repositories(sync_script, args.manifest, args.src_root, target_names)

    resolved_entries = {
        name: resolve_locked_spec(args.src_root, name, source_repositories[name]) for name in target_names
    }

    if args.all:
        merged_repositories = {
            name: resolved_entries[name] for name in sorted(source_repositories.keys())
        }
    else:
        merged_repositories = dict(lock_repositories)
        merged_repositories.update(resolved_entries)
        merged_repositories = {
            name: merged_repositories[name] for name in sorted(merged_repositories.keys())
        }

    output = {"repositories": merged_repositories}
    rendered = yaml.safe_dump(output, sort_keys=False)
    existing = args.lock_manifest.read_text(encoding="utf-8") if args.lock_manifest.exists() else None

    if existing != rendered:
        args.lock_manifest.write_text(rendered, encoding="utf-8")
        if args.all:
            print(f"[lock] wrote full lock manifest: {args.lock_manifest} ({len(merged_repositories)} entries)")
        else:
            print(
                f"[lock] wrote lock manifest: {args.lock_manifest} "
                f"(added {len(resolved_entries)} entries, total {len(merged_repositories)})"
            )
    else:
        print(f"[lock] lock manifest is already up to date: {args.lock_manifest}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
