# Install Guide (Arm64 macOS, isolated)

## Prerequisites
- Arm64 macOS
- Xcode Command Line Tools (`xcode-select --install`)
- `uv` available in `PATH` (default: `~/.local/bin/uv`)

## 1. Clone
```bash
git clone https://github.com/TakanoTaiga/ros2_m1_native.git
cd ros2_m1_native
```

## 2. Python environment (uv)
```bash
./scripts/bootstrap_python.sh
```

## 3. Generate ROS lock manifest (first time only)
```bash
./scripts/generate_ros2_lock.sh
```

## 4. Run isolated build
```bash
./scripts/run_isolated_build.sh
```

## 5. Faster iterative build (optional)
```bash
CLEAN_BUILD=0 ./scripts/run_isolated_build.sh
```

## Notes
- Homebrew is not used by these scripts.
- External sources are locked by commit hash in `ros2.lock.repos` and `third_party.repos`.
