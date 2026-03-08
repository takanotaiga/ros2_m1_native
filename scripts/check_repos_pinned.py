#!/usr/bin/env python3

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

import yaml

PINNED_SHA1_RE = re.compile(r"^[0-9a-f]{40}$")


def validate_manifest(manifest_path: Path) -> list[str]:
    errors: list[str] = []
    data = yaml.safe_load(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(data, dict) or "repositories" not in data:
        return [f"{manifest_path}: missing top-level 'repositories' mapping"]

    repositories = data["repositories"]
    if not isinstance(repositories, dict):
        return [f"{manifest_path}: 'repositories' must be a mapping"]

    for repo_name, spec in repositories.items():
        if not isinstance(spec, dict):
            errors.append(f"{manifest_path}: {repo_name}: entry must be a mapping")
            continue

        repo_type = spec.get("type")
        repo_url = spec.get("url")
        repo_version = spec.get("version")

        if repo_type != "git":
            errors.append(f"{manifest_path}: {repo_name}: type must be 'git'")
        if not isinstance(repo_url, str) or not repo_url.startswith("https://"):
            errors.append(f"{manifest_path}: {repo_name}: url must be an https git URL")
        if not isinstance(repo_version, str) or not PINNED_SHA1_RE.fullmatch(repo_version):
            errors.append(
                f"{manifest_path}: {repo_name}: version must be a 40-char lowercase commit hash"
            )

    return errors


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate that all repos in manifests are pinned to full git commit hashes."
    )
    parser.add_argument("manifests", nargs="+", type=Path, help="Path(s) to .repos manifest files")
    args = parser.parse_args()

    all_errors: list[str] = []
    for manifest in args.manifests:
        if not manifest.exists():
            all_errors.append(f"{manifest}: file not found")
            continue
        all_errors.extend(validate_manifest(manifest))

    if all_errors:
        for err in all_errors:
            print(f"ERROR: {err}", file=sys.stderr)
        return 1

    print("All manifests are hash-pinned.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
