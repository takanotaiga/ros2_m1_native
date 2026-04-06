# ros2_m1_native

This is the shortest path to build Homebrew-independent ROS 2 on Arm64 macOS and run:
- `ros2 run demo_nodes_cpp talker`
- `ros2 run demo_nodes_py listener`
- `/Applications/ROS2Native.app`
- `/Applications/RViz 2.app`
- `/Applications/rqt.app`

## Prerequisites
- Apple Silicon macOS (arm64)
- `git`
- Xcode Command Line Tools
- `uv` (installed under `~/.local/bin/uv`)

## 1. Install required tools
```bash
xcode-select --install
curl -LsSf https://astral.sh/uv/install.sh | sh
```

Open a new shell, or add `uv` to `PATH`:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## 2. Clone this repository
```bash
git clone <YOUR_REPO_URL> ros2_m1_native
cd ros2_m1_native
```

## 3. Build ROS 2 (isolated environment)
```bash
./scripts/run_isolated_build.sh
```

For incremental rebuilds (no clean build):

```bash
CLEAN_BUILD=0 ./scripts/run_isolated_build.sh
```

## 4. Load runtime environment
```bash
source scripts/activate_env.sh
source install/setup.bash
```

`scripts/activate_env.sh` also sets Python-related `colcon` defaults (when unset), so downstream workspaces inherit the same CMake Python settings used to build this ROS 2 install.

## 5. Run demo nodes
Terminal A:

```bash
source scripts/activate_env.sh
source install/setup.bash
ros2 run demo_nodes_py listener
```

Terminal B:

```bash
source scripts/activate_env.sh
source install/setup.bash
ros2 run demo_nodes_cpp talker
```

Success condition: Terminal A prints `I heard: [Hello World: N]`.

## 6. Build a custom workspace
```bash
source /path/to/ros2_m1_native/scripts/activate_env.sh
source /path/to/ros2_m1_native/install/setup.bash
cd /path/to/your_workspace
uv run colcon build
```

## 7. Build a macOS app bundle release
This builds a self-contained runtime directly into:

- `/Applications/ROS2Native.app`
- `/Applications/RViz 2.app`
- `/Applications/rqt.app`

```bash
./scripts/build_release.sh
```

The release build verifies:

- a clean, Homebrew-free environment
- a packaged Python runtime under `ROS2Native.app`
- `demo_nodes_cpp` / `demo_nodes_py` talker-listener communication

## 8. Load the packaged runtime manually
```bash
source /Applications/ROS2Native.app/Contents/Resources/runtime/share/ros2native/activate.sh
source /Applications/ROS2Native.app/Contents/Resources/runtime/setup.bash
```

## 9. Create a macOS installer package
After `./scripts/build_release.sh` succeeds:

```bash
./scripts/package_macos_app.sh
```

This creates:

- `.release/pkg/ros2native.pkg`

The installer adds these managed CLI entry points:

- `/usr/local/bin/ros2`
- `/usr/local/bin/ros2native`
- `/usr/local/bin/rviz2`
- `/usr/local/bin/ros2native-rviz2`
- `/usr/local/bin/colcon`
- `/usr/local/bin/ros2native-colcon`
- `/usr/local/bin/ros2native-uninstall`

On a normal macOS shell where `/usr/local/bin` is already on `PATH`, `ros2` is usable immediately after installation with no manual `source`.

Optional signing:

```bash
PKG_SIGN_IDENTITY="Developer ID Installer: Example Org" \
PRODUCT_SIGN_IDENTITY="Developer ID Installer: Example Org" \
./scripts/package_macos_app.sh
```

## 10. Verify installer behavior
The install verification script mounts a temporary APFS volume, installs the pkg into that volume, confirms `ros2` works immediately, then runs the packaged uninstaller:

```bash
./scripts/verify_pkg_install.sh
```

## 11. CI and release
- Pull requests targeting `master` run package verification on `macos-26`.
- That PR workflow only checks that the packaged runtime and `.pkg` can be built.
- Pushes to `master` run the release workflow on `macos-26`.
- The release workflow reads `project.version` from `pyproject.toml` and publishes `v<version>` as a GitHub Release when that release does not already exist.
- To publish a new release after merge, bump `project.version` in the PR before it lands on `master`.
