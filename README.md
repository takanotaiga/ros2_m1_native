# ros2_m1_native

Arm64 macOS 上で ROS 2 を Homebrew 非依存でビルドするためのリポジトリです。

## 方針
- Python は `uv` + `pyproject.toml` / `uv.lock` で管理
- 外部依存は `.repos` マニフェストで git URL + commit hash を固定
- ローカル prefix (`.local/`) にツールチェーン/依存を配置
- `OpenCV` / `Qt5` を含む GUI 依存もローカルでソースビルド
- `env -i` 分離環境でも再現可能なビルドを維持

## クイックスタート
1. `xcode-select --install` で Command Line Tools を用意
2. `uv` をインストール（`~/.local/bin/uv` 想定）
3. 初回ロック生成:
   - `./scripts/bootstrap_python.sh`
   - `./scripts/generate_ros2_lock.sh`
4. 分離ビルド:
   - `./scripts/run_isolated_build.sh`

## 反復ビルド
- 既存 build を再利用する場合:
  - `CLEAN_BUILD=0 ./scripts/run_isolated_build.sh`

## 主要ファイル
- `ros2.lock.repos`: ROS ソース固定マニフェスト
- `third_party.repos`: 非ROS依存固定マニフェスト
- `scripts/run_isolated_build.sh`: 分離環境ビルドのエントリ
- `scripts/build_local.sh`: 実際の colcon ビルド実行

## CI
- `.github/workflows/build.yml` で
  - lock 検証
  - macOS 分離ビルド
  を実行します。
