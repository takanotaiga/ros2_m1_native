# ros2_m1_native

This is the shortest path to build Homebrew-independent ROS 2 on Arm64 macOS and run:
- `ros2 run demo_nodes_cpp talker`
- `ros2 run demo_nodes_py listener`

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
