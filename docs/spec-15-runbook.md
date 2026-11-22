# Spec #15 运行手册（Flutter 前端 + Go 边车）

本手册覆盖首个端到端纵切片的开发、验收与手工演示路径。所有命令都从仓库根目录执行；
Python/Flet 旧应用不在此工程的构建链内，也没有任何目标会读写它的数据目录。

## 1. 前置工具链

版本固定如下（与本机实测一致，也与 `.github/workflows/new-stack.yml`、
`backend/go.mod`、`frontend/pubspec.yaml`、`tools/codegen.sh` 对齐）：

| 工具 | 版本 | 检查命令 |
| --- | --- | --- |
| Go | 1.27.x | `go version` |
| Flutter / Dart | 3.50.0 / 3.14.0 | `flutter --version` |
| protoc | 36.1 | `protoc --version` |
| protoc-gen-go | 1.36.12 | `$(go env GOPATH)/bin/protoc-gen-go --version` |
| protoc-gen-go-grpc | 1.6.2 | `$(go env GOPATH)/bin/protoc-gen-go-grpc --version` |
| protoc_plugin（Dart） | 25.1.0 | `dart pub global list \| grep protoc_plugin` |

Linux 桌面构建还需要 GTK 3 / clang / cmake / ninja / pkg-config（Flutter Linux
工具链的常规依赖）。Go 构建一律使用 `CGO_ENABLED=0`，Makefile 已导出该变量。

## 2. Make 目标

| 目标 | 行为 |
| --- | --- |
| `make codegen` | 从 `proto/` 重新生成 Go 与 Dart 代码 |
| `make codegen-check` | 重新生成后若工作树有差异则失败；不要与依赖生成代码的目标并行执行 |
| `make backend-test` | `go test ./...`，不启用 `integration` 构建标签 |
| `make backend-integration` | `go test -tags=integration -count=1 ./...`，构建真实 `dlssd` 并驱动真实 UDS |
| `make frontend-test` | `flutter pub get`、`dart format --set-exit-if-changed`、`flutter analyze`、`flutter test` |
| `make frontend-integration` | 需显式设置 `DLSS_FIXTURE_STEAM_ROOT`；运行需要图形会话的 Flutter 集成测试 |
| `make build` | 产出 `backend/bin/dlssd`（静态）与 `frontend/build/linux/x64/release/bundle/` |
| `make run-dev` | 清空并重建 `build/dev-data`、`build/dev-runtime`，再以 `flutter run -d linux` 启动应用 |

`backend/bin/`、`build/` 均被 `.gitignore` 忽略，属于本机产物。

## 3. 数据目录隔离规则

- 边车只接受三个显式路径：`--data-dir`、`--socket`、`--dll-source-dir`；它不推断、
  不读取任何用户默认目录。
- 开发运行固定使用仓库内 `build/dev-data` 与 `build/dev-runtime`；`make run-dev`
  每次启动前删除并重建二者，因此不会继承上一次的选择或数据库。
- **禁止**把 `--data-dir` 指向 `~/.config/DLSS-Updater`、`~/.local/share/DLSS-Updater`
  或旧应用的任何数据库/备份；也禁止把扫描根指向真实 Steam 库做演示。
- 测试只使用 `testing.T.TempDir()` 与短期临时 socket 目录，`TestMain`/`t.Cleanup`
  负责删除；运行结束后临时根之外不得出现 socket、lock、日志或临时文件。
- 手工演示把仓库内的夹具复制到 `/tmp`，不要在原地修改 `fixtures/demo`。

## 4. 夹具库

`fixtures/demo/` 是可搬运的最小 Steam 库与本地 DLL 源：

```
fixtures/demo/
  nvngx_dlss-2.4.2.0.dll              # 合成 PE，安装版本
  nvngx_dlss-3.7.10.0.dll             # 合成 PE，更新版本
  steam/steamapps/appmanifest_900001.acf
  steam/steamapps/common/Fixture Game/bin/nvngx_dlss.dll
  dll-source/nvngx_dlss.dll           # 3.7.10.0
```

`libraryfolders.vdf` 故意缺席：扫描在这种情况下回退到 `<root>/steamapps/common`，
因此这份夹具可以任意复制。合成 PE 由 `backend/internal/testfixtures` 同款生成器
产出，不含受版权保护的二进制。

## 5. 手工演示：扫描 → 更新 → 备份 → 恢复 → 删除

1. 准备一份一次性夹具库：

   ```bash
   rm -rf /tmp/dlss-fixture-steam
   cp -r fixtures/demo/steam /tmp/dlss-fixture-steam
   ```

2. 启动开发模式：

   ```bash
   make run-dev
   ```

   该目标只构建并启动 Flutter 应用；边车由前端按既有架构作为子进程拉起，
   Makefile **不会**再启动第二个 daemon 去争用同一个 socket。

3. 在应用窗口中选择 Steam 根目录：Games → **Choose folder** → 选择
   `/tmp/dlss-fixture-steam`（原生选择器里可用 `Ctrl+L` 直接输入路径）。

4. 点击 **Scan**。列表出现 `Fixture Game`，`nvngx_dlss.dll` 的当前版本为
   `2.4.2.0`。

5. 应用运行期间把新版本放进本次开发数据目录的 DLL 源（默认即
   `--dll-source-dir`，由前端传入 `build/dev-data/dll-source`）：

   ```bash
   mkdir -p build/dev-data/dll-source
   cp fixtures/demo/dll-source/nvngx_dlss.dll build/dev-data/dll-source/
   ```

6. 在游戏详情中选中该 DLL 并执行更新。完成后磁盘上应同时存在：

   - `.../Fixture Game/bin/nvngx_dlss.dll`，版本 `3.7.10.0`，权限与原文件一致；
   - `.../Fixture Game/bin/nvngx_dlss.dlsss`，内容为原 `2.4.2.0` 文件，权限 `0600`。

7. 打开 **Backups**，记录应显示游戏、DLL、原版本、大小与时间。执行
   **Restore** 并确认；目标文件恢复为 `2.4.2.0` 的原始字节，记录移出活动列表
   并带恢复时间，`.dlsss` 文件仍保留。随后可 **Delete** 该备份，`.dlsss`
   文件被删除。

8. 停止：在运行 `make run-dev` 的终端按 `Ctrl+C`，或正常关闭应用窗口。前端退出
   路径会先调用 `Daemon.Shutdown`，再以 SIGTERM/SIGKILL 兜底；边车自身也设置了
   `PR_SET_PDEATHSIG`，父进程消失时不会留下孤儿。可选核对：

   ```bash
   pgrep -a dlssd                       # 应无输出
   ls build/dev-runtime/dlss-updater    # 应无残留 socket
   ```

9. 下次运行仍从空数据目录开始；如需保留演示状态，直接在 `make run-dev`
   启动前备份 `build/dev-data`，或手工运行 `backend/bin/dlssd` 并自行指定
   `--data-dir`（不要与 `run-dev` 同时使用同一个 socket）。

### 只验证后端同一条链路

```bash
make backend-integration
```

`backend/integration/acceptance_test.go` 中的 `TestAcceptanceFullSlice` 就是第 5 节的
自动化版本：真实进程、真实 UDS、临时数据目录与临时夹具库，断言事件序列、
`.dlsss` 字节与权限、恢复后的原始字节、删除结果、Shutdown 后的 socket 清理，
以及临时夹具树在流程前后完全一致。

## 6. 可选的 Flutter 集成测试

测试文件为 `frontend/integration_test/app_flow_test.dart`。它默认**不运行**：
`flutter test` 只扫描 `frontend/test/`，且该测试自身还要求
`DLSS_INTEGRATION=1`。它会启动真实应用组件树、真实 `dlssd` 与真实 UDS，
扫描夹具库并显示游戏，同时在 Settings 中核对 `--dart-define=APP_VERSION`。

有图形会话时：

```bash
cp -r fixtures/demo/steam /tmp/dlss-fixture-steam   # 已存在可跳过
DLSS_FIXTURE_STEAM_ROOT=/tmp/dlss-fixture-steam make frontend-integration
```

等价的手工命令（Make 目标会构建 `backend/bin/dlssd` 并注入版本）：

```bash
cd frontend
DLSS_INTEGRATION=1 \
DLSSD_BIN=$PWD/../backend/bin/dlssd \
DLSS_FIXTURE_STEAM_ROOT=/tmp/dlss-fixture-steam \
DLSS_EXPECTED_APP_VERSION=$(cat ../VERSION) \
flutter test integration_test -d linux --dart-define=APP_VERSION=$(cat ../VERSION)
```

无头运行：本机**没有安装** `xvfb-run`/`Xvfb`（`command -v xvfb-run` 失败），因此
无法在本机无头执行；也不允许在共享桌面上无人值守地开窗。在安装了 Xvfb 的机器上
可以用：

```bash
xvfb-run -a -s "-screen 0 1920x1080x24" \
  env DLSS_FIXTURE_STEAM_ROOT=/tmp/dlss-fixture-steam make frontend-integration
```

CI 默认跳过该测试：GitHub 托管的 runner 没有 X 服务器/Xvfb，且 Flutter 桌面
集成测试需要构建并启动 Linux 窗口，属于手动/夜间任务。组件测试
（`make frontend-test`）在 CI 中照常运行。

## 7. 版本注入

- 根 `VERSION`（当前 `0.1.0-dev.0`）由 Makefile 的 `-ldflags -X …buildinfo.Version`
  注入 Go 二进制：`backend/bin/dlssd --version` 直接输出该值，且**不要求**三个
  必填路径。`Daemon.GetStatus` 的 `app_version` 使用同一个值。
- Flutter 侧通过 `--dart-define=APP_VERSION=$(VERSION)` 注入，Settings 页的
  App version 行显示该值；`frontend-integration` 还会用
  `DLSS_EXPECTED_APP_VERSION` 做精确比对。
- `frontend/pubspec.yaml` 的 `version:` 与根 `VERSION` 当前一致；它不是运行时
  展示来源，修改版本时两处需同步。

## 8. 已知缺口（不属于本切片）

- 旧 `config.toml`、`games.db` 与旧备份的迁移。
- DLL 远程下载、manifest 校验、缓存与重试；本切片只读本地 DLL 源目录。
- whitelist/忽略列表/更新范围、预设写入、Proton/FSR4 等后续行为。
- Flatpak/Flathub 打包与发布；CI 只跑后端、前端与代码生成三个作业。
- 带图形界面的 Flutter 集成测试未进入 CI（原因见第 6 节）。
- 大规模库性能、并行更新、备份清理策略。

## 9. 排障

- `dlssd: ...` 启动失败：确认三个路径均为绝对路径，socket 路径不超过 107 字节
  （`sun_path` 限制），DLL 源目录存在且可读。
- 第二个实例：同一数据目录的 `daemon.lock` 已被持有时会以 `ALREADY_RUNNING`
  退出；杀掉遗留进程或改用另一个 `--data-dir`。
- 残留 socket：边车只删除探测失败的 socket，绝不删除普通文件；若路径被普通
  文件占用，按错误提示手动处理。
- 日志在 `<data-dir>/logs/`，数据库为 `<data-dir>/db.sqlite3`；两者都属于边车。
  `ui.json` 属于前端（上次选择的 Steam 根与 DLL 源）。
