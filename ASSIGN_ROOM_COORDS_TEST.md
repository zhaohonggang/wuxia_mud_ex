# assign_room_coords.exs 使用与测试文档

## 概述

`scripts/assign_room_coords.exs` 用于为 UCL 区域文件中的房间自动分配 3D 坐标。脚本会：
- 保留已有非零坐标的房间作为锚点
- 从起始房间 (0,0,0) 沿出口图遍历，根据方向推导坐标
- 孤立子图堆叠在 z 轴上
- 支持 22 种移动方向（含斜向、3D、enter/out/in/climb 等特殊出口）

## 标准测试流程

### 1. 准备测试源文件（清空坐标）

```bash
# 进入容器
docker exec -w /app wuxia_mud_dev-app-1 sh -c "
  sed -i -E 's/^[[:space:]]*x[[:space:]]*=[[:space:]]*-?[0-9]+/  x = 0/' data/world/test_zero.ucl
  sed -i -E 's/^[[:space:]]*y[[:space:]]*=[[:space:]]*-?[0-9]+/  y = 0/' data/world/test_zero.ucl
  sed -i -E 's/^[[:space:]]*z[[:space:]]*=[[:space:]]*-?[0-9]+/  z = 0/' data/world/test_zero.ucl
"
```

验证：
```bash
docker exec -w /app wuxia_mud_dev-app-1 sh -c "
  grep -E '^[[:space:]]*[xyz][[:space:]]*=' data/world/test_zero.ucl | sort | uniq -c
"
# 应输出：34 个 x=0, 34 个 y=0, 34 个 z=0
```

### 2. 运行坐标分配（输出到宿主机可访问路径）

```bash
docker exec -w /app wuxia_mud_dev-app-1 sh -c '
  MIX_ENV=dev mix run --no-start scripts/assign_room_coords.exs \
    data/world/test_zero.ucl damen \
    --output /app/data/world/test_assigned.ucl
'
```

参数说明：
- `data/world/test_zero.ucl` — 输入文件（已清空坐标）
- `damen` — 起始房间 ID，将被固定为 (0,0,0)
- `--output /app/data/world/test_assigned.ucl` — 输出文件（挂载卷，宿主机可见）

### 3. 验证结果

```bash
# 查看输出文件坐标分布
docker exec -w /app wuxia_mud_dev-app-1 sh -c "
  grep -E '^[[:space:]]*[xyz][[:space:]]*=' /app/data/world/test_assigned.ucl | sort | uniq -c
"

# 确认源文件未被修改
docker exec -w /app wuxia_mud_dev-app-1 sh -c "
  grep -E '^[[:space:]]*[xyz][[:space:]]*=' data/world/test_zero.ucl | sort | uniq -c
"
```

预期输出：
- 源文件：`34 x=0, 34 y=0, 34 z=0`
- 输出文件：33 个房间获得新坐标，包含负坐标、多层 z 轴分布

## 命令行选项

| 选项 | 说明 |
|------|------|
| `<zone.ucl>` | 输入 UCL 文件路径 |
| `<start_room_id>` | 起始房间 ID（坐标归一化为 0,0,0） |
| `--dry-run` | 仅打印结果到 stdout，不写文件 |
| `--output <file>` / `-o <file>` | 写入指定输出文件，原文件不变 |

示例：
```bash
# 预览模式
docker exec -w /app wuxia_mud_dev-app-1 sh -c '
  MIX_ENV=dev mix run --no-start scripts/assign_room_coords.exs \
    data/world/test_zero.ucl damen --dry-run
'

# 指定输出文件
docker exec -w /app wuxia_mud_dev-app-1 sh -c '
  MIX_ENV=dev mix run --no-start scripts/assign_room_coords.exs \
    data/world/test_zero.ucl damen --output /app/data/world/test_assigned.ucl
'
```

## 宿主机访问输出文件

输出路径 `/app/data/world/...` 对应宿主机：
```
C:\files\git\wuxia_mud_ex\data\world\test_assigned.ucl
```

可直接用编辑器或 `git diff` 对比：
```bash
git diff data/world/test_zero.ucl data/world/test_assigned.ucl
```

## 方向系统支持

脚本 `@dirs` 映射表包含 22 个方向：

| 类别 | 方向 | 坐标增量 |
|------|------|----------|
| 基本四向 | north/south/east/west | (0,±1,0)/(±1,0,0) |
| 上下 | up/down | (0,0,±1) |
| 2D 斜向 | northeast/northwest/southeast/southwest | (±1,±1,0) |
| 3D 上斜向 | northup/southup/eastup/westup | (0/±1, ±1/0, 1) |
| 3D 下斜向 | northdown/southdown/eastdown/westdown | (0/±1, ±1/0, -1) |
| 传送门类 | enter/out/in/go_in | (0,0,0) — 与连接房间共用坐标 |
| 攀爬 | climb | (0,0,1) — 同 up |

## 自动化测试建议

在 CI/CD 或本地开发循环中：

```bash
#!/bin/bash
# test_assign_coords.sh

set -e

# 1. 清空坐标
docker exec -w /app wuxia_mud_dev-app-1 sh -c "
  sed -i -E 's/^[[:space:]]*x[[:space:]]*=[[:space:]]*-?[0-9]+/  x = 0/' data/world/test_zero.ucl
  sed -i -E 's/^[[:space:]]*y[[:space:]]*=[[:space:]]*-?[0-9]+/  y = 0/' data/world/test_zero.ucl
  sed -i -E 's/^[[:space:]]*z[[:space:]]*=[[:space:]]*-?[0-9]+/  z = 0/' data/world/test_zero.ucl
"

# 2. 运行分配
docker exec -w /app wuxia_mud_dev-app-1 sh -c '
  MIX_ENV=dev mix run --no-start scripts/assign_room_coords.exs \
    data/world/test_zero.ucl damen \
    --output /app/data/world/test_assigned.ucl
'

# 3. 基本断言
docker exec -w /app wuxia_mud_dev-app-1 sh -c "
  # 起始房间必须是 (0,0,0)
  grep -A 5 'rooms \"damen\"' /app/data/world/test_assigned.ucl | grep -E 'x = 0|y = 0|z = 0' | wc -l
  # 应该有 3 行匹配

  # 至少有一些房间获得了非零坐标
  grep -E 'x = -?[1-9]|y = -?[1-9]|z = -?[1-9]' /app/data/world/test_assigned.ucl | wc -l
  # 应该 > 0
"

# 4. 跑全量测试套件
docker exec -w /app wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test'
```

## 常见问题

**Q: 起始房间 ID 找不到？**
A: 确认 UCL 中 `rooms "xxx"` 的 ID 与参数一致（不含 `rooms.` 前缀）。

**Q: 输出文件没变化？**
A: 检查源文件是否已有非零锚点；`anchor rooms (kept non-zero)` 数量会在日志显示。

**Q: 想测试其他区域？**
A: 复制 zone.ucl 到 `test_zero.ucl`，清空坐标，换起始房间 ID 跑即可。

## 相关文件

- `scripts/assign_room_coords.exs` — 主脚本
- `data/world/test_zero.ucl` — 测试源文件（全零坐标）
- `data/world/test_assigned.ucl` — 测试输出文件（gitignore 建议忽略）
- `lib/kantele/world/lpc_converter.ex` — UCL 生成器（重新生成会丢失坐标）