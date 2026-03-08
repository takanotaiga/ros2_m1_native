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


def is_clean_git_repo(repo_path: Path) -> bool:
    status = run(["git", "status", "--porcelain"], cwd=repo_path, capture=True)
    return status.strip() == ""


def sync_repo(
    repo_root: Path,
    repo_name: str,
    repo_spec: dict[str, str],
    allow_non_pinned: bool,
    update_submodules: bool,
    force_clean: bool,
) -> None:
    repo_type = repo_spec.get("type")
    repo_url = repo_spec.get("url")
    repo_version = repo_spec.get("version")

    if repo_type != "git":
        raise RuntimeError(f"{repo_name}: only git repositories are supported")
    if not isinstance(repo_url, str):
        raise RuntimeError(f"{repo_name}: missing url")
    if not isinstance(repo_version, str):
        raise RuntimeError(f"{repo_name}: missing version")
    if not allow_non_pinned and not PINNED_SHA1_RE.fullmatch(repo_version):
        raise RuntimeError(
            f"{repo_name}: version must be a 40-char lowercase commit hash (got: {repo_version})"
        )

    repo_path = repo_root / repo_name
    repo_path.parent.mkdir(parents=True, exist_ok=True)

    if not repo_path.exists():
        print(f"[clone] {repo_name}")
        run(
            [
                "git",
                "clone",
                "--origin",
                "origin",
                "--no-checkout",
                "--filter=blob:none",
                repo_url,
                str(repo_path),
            ]
        )
    else:
        current_url = run(
            ["git", "config", "--get", "remote.origin.url"], cwd=repo_path, capture=True
        ).strip()
        if current_url != repo_url:
            raise RuntimeError(
                f"{repo_name}: remote origin URL mismatch\nexpected: {repo_url}\nactual:   {current_url}"
            )
        if not is_clean_git_repo(repo_path):
            if force_clean:
                print(f"[clean] {repo_name}")
                run(["git", "reset", "--hard"], cwd=repo_path)
                run(["git", "clean", "-fd"], cwd=repo_path)
            else:
                raise RuntimeError(
                    f"{repo_name}: repository is dirty; commit or stash local changes first"
                )

    print(f"[fetch] {repo_name}")
    fetched_by_ref = False
    try:
        run(["git", "fetch", "--no-tags", "--force", "origin", repo_version], cwd=repo_path)
        fetched_by_ref = True
    except RuntimeError:
        # Fallback for remotes that don't allow direct SHA/ref fetches.
        run(["git", "fetch", "--no-tags", "--force", "origin"], cwd=repo_path)

    print(f"[checkout] {repo_name} -> {repo_version}")
    try:
        if fetched_by_ref:
            run(["git", "checkout", "--force", "FETCH_HEAD"], cwd=repo_path)
        else:
            run(["git", "checkout", "--force", repo_version], cwd=repo_path)
    except RuntimeError:
        if not allow_non_pinned:
            raise
        run(["git", "checkout", "--force", f"origin/{repo_version}"], cwd=repo_path)

    if update_submodules:
        run(["git", "submodule", "update", "--init", "--recursive"], cwd=repo_path)

    if PINNED_SHA1_RE.fullmatch(repo_version):
        actual = run(["git", "rev-parse", "HEAD"], cwd=repo_path, capture=True).strip()
        if actual != repo_version:
            raise RuntimeError(
                f"{repo_name}: checkout mismatch (expected {repo_version}, got {actual})"
            )


def main() -> int:
    parser = argparse.ArgumentParser(description="Clone/fetch and checkout repositories from a .repos file.")
    parser.add_argument("--manifest", required=True, type=Path, help="Path to .repos manifest")
    parser.add_argument("--root", required=True, type=Path, help="Destination root directory")
    parser.add_argument(
        "--allow-non-pinned",
        action="store_true",
        help="Allow branch/tag versions (used only for bootstrapping lock generation).",
    )
    parser.add_argument(
        "--update-submodules",
        action="store_true",
        help="Run git submodule update --init --recursive for each repo.",
    )
    parser.add_argument(
        "--force-clean",
        action="store_true",
        help="If repo has local changes, discard them (git reset --hard && git clean -fd).",
    )
    args = parser.parse_args()

    data = yaml.safe_load(args.manifest.read_text(encoding="utf-8"))
    repositories = data.get("repositories", {}) if isinstance(data, dict) else {}
    if not isinstance(repositories, dict):
        raise RuntimeError("manifest is invalid: 'repositories' must be a mapping")

    args.root.mkdir(parents=True, exist_ok=True)

    for name in sorted(repositories.keys()):
        spec = repositories[name]
        if not isinstance(spec, dict):
            raise RuntimeError(f"{name}: manifest entry must be a mapping")
        sync_repo(
            repo_root=args.root,
            repo_name=name,
            repo_spec=spec,
            allow_non_pinned=args.allow_non_pinned,
            update_submodules=args.update_submodules,
            force_clean=args.force_clean,
        )

    print("Repository sync completed.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
