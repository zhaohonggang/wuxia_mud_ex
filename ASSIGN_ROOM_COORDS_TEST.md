# assign_room_coords.py 使用与测试文档

## 概述

`scripts/assign_room_coords.py` 用于为 UCL 区域文件中的房间自动分配 3D 坐标。**在宿主机直接用 Python 运行**（容器 `wuxia_mud_dev-app-1` 内没有 Python，`python3: not found`）。脚本会：
- 保留已有非零坐标的房间作为锚点
- 从起始房间 (0,0,0) 沿出口图遍历，根据方向推导坐标
- 孤立子图堆叠在 z 轴上
- 支持 23 种移动方向（含斜向、3D、enter/out/in/go_in/climb 等特殊出口）

> Python 版是 Elixir 版 `scripts/assign_room_coords.exs` 的**逐字节对齐移植**；Elixir 版保留为**遗留参考**，不再作为主流程。

## 标准测试流程

### 1. 准备测试源文件（清空坐标）

在**宿主机**仓库根目录执行：

```powershell
# 测试用中间文件放 data\world_backup\，不要放 data\world\
# （data\world\*.ucl 是生成产物，且同一 zone 只能有一个 .ucl，同名会互相覆盖）
# 不要用 PowerShell 的 `>` 重定向生成 .ucl —— 它会写成 UTF-16/带 BOM
python -c "import re; p=r'data\world_backup\test_zero.ucl'; s=open(p,encoding='utf-8',newline='').read(); s=re.sub(r'(?m)^([ \t]*)([xyz])[ \t]*=[ \t]*-?\d+', r'\1\2 = 0', s); open(p,'w',encoding='utf-8',newline='').write(s)"
```

验证：
```powershell
Select-String -Path data\world_backup\test_zero.ucl -Pattern '^\s*[xyz]\s*=' |
  Group-Object { $_.Line -replace '^\s*','' } | Select-Object Count,Name
# 应输出：34 个 x = 0, 34 个 y = 0, 34 个 z = 0
```

### 2. 运行坐标分配（输出到仓库 `data\world_backup\`）

```powershell
python scripts\assign_room_coords.py data\world_backup\test_zero.ucl damen `
    --output data\world_backup\test_assigned.ucl
```

参数说明：
- `data\world_backup\test_zero.ucl` — 输入文件（已清空坐标）
- `damen` — 起始房间 ID，将被固定为 (0,0,0)
- `--output data\world_backup\test_assigned.ucl` — 输出文件，**输入文件保持不变**

> ⚠️ **省略 `--output` 会就地覆盖输入文件**。Python 版只接受 2 个位置参数（`<zone.ucl>`、`<start_room_id>`），
> **没有** Elixir 版曾有的第 3 个位置参数 `zone_name`，也**没有** `-o` 短选项。

预期 stdout：
```
zone: test_zero.ucl  rooms: 34
anchor rooms (kept non-zero): 0
rooms assigned new coords:    33
start room: damen -> (0,0,0)
Written to data\world_backup\test_assigned.ucl
```

### 3. 验证结果

```powershell
# 查看输出文件坐标分布（应含负坐标、多层 z 轴）
Select-String -Path data\world_backup\test_assigned.ucl -Pattern '^\s*[xyz]\s*=' |
  Group-Object { $_.Line -replace '^\s*','' } | Sort-Object Name | Select-Object Count,Name

# 确认源文件未被修改（无输出 = 仍是 34/34/34 全零）
git diff --stat data/world_backup/test_zero.ucl

# 结构 / 完整性校验（5 项检查全跑不短路，退出码 0 表示全过）
python scripts\validate_ucl.py data\world_backup\test_assigned.ucl
# 预期：✅ All checks passed: data\world_backup\test_assigned.ucl
```

预期输出：
- 源文件：`34 x = 0, 34 y = 0, 34 z = 0`
- 输出文件：33 个房间获得新坐标，包含负坐标、多层 z 轴分布
- `validate_ucl.py`：`✅ All checks passed: ...`，退出码 0

## 命令行选项

| 选项 | 说明 |
|------|------|
| `<zone.ucl>` | 输入 UCL 文件路径（位置参数 1） |
| `<start_room_id>` | 起始房间 ID（坐标归一化为 0,0,0）（位置参数 2） |
| `--dry-run` | 仅把新内容打印到 stdout，**不写任何文件** |
| `--output <file>` | 写入指定输出文件，输入文件保持不变 |
| `--output=<file>` | 同上，等号写法 |

> 只认 `--` 前缀的长选项。**`-o <file>` 短选项不存在**（`-o` 会被当成普通位置参数而**静默忽略**，
> 结果是输入文件被就地覆盖）。

示例：
```powershell
# 预览模式
python scripts\assign_room_coords.py data\world_backup\test_zero.ucl damen --dry-run

# 指定输出文件
python scripts\assign_room_coords.py data\world_backup\test_zero.ucl damen --output data\world_backup\test_assigned.ucl

# 等号写法
python scripts\assign_room_coords.py data\world_backup\test_zero.ucl damen --output=data\world_backup\test_assigned.ucl
```

## 宿主机与容器共享输出文件

脚本在**宿主机**运行，输出直接落在仓库 `data\world_backup\` 下。容器 `/app` 就是仓库
`C:\files\git\wuxia_mud_ex` 的 bind mount，因此：

```
宿主机  C:\files\git\wuxia_mud_ex\data\world_backup\test_assigned.ucl
   ≡
容器   /app/data/world_backup/test_assigned.ucl
```

**无需 `docker cp`**。可直接用编辑器或 `git diff` 对比：
```powershell
git diff data/world_backup/test_zero.ucl data/world_backup/test_assigned.ucl
```

## 方向系统支持

脚本 `DIRS` 映射表包含 23 个方向：

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

在 CI/CD 或本地开发循环中（**PowerShell** 版；Git Bash 下需自行替换换行符与反斜杠路径）：

```powershell
# test_assign_coords.ps1
Set-Location C:\files\git\wuxia_mud_ex
$ErrorActionPreference = 'Stop'

# 1. 清空坐标（不要用 `>` 重定向：PowerShell 会写成 UTF-16）
python -c "import re; p=r'data\world_backup\test_zero.ucl'; s=open(p,encoding='utf-8',newline='').read(); s=re.sub(r'(?m)^([ \t]*)([xyz])[ \t]*=[ \t]*-?\d+', r'\1\2 = 0', s); open(p,'w',encoding='utf-8',newline='').write(s)"

# 2. 运行分配（显式 --output，避免就地覆盖输入）
python scripts\assign_room_coords.py data\world_backup\test_zero.ucl damen --output data\world_backup\test_assigned.ucl

# 3. 基本断言
#    3.1 起始房间 damen 的 x/y/z 必须是 0 —— 应匹配 3 行
$start = Select-String -Path data\world_backup\test_assigned.ucl -Pattern '^\s*rooms\s+"damen"' -Context 0,6 |
  ForEach-Object { $_.Context.PostContext } | Select-String -Pattern '^\s*[xyz]\s*=\s*0\s*$'
if ($start.Count -ne 3) { throw "start room damen is not (0,0,0): matched $($start.Count) lines" }

#    3.2 至少有一些房间获得了非零坐标 —— 应 > 0
$nonzero = (Select-String -Path data\world_backup\test_assigned.ucl -Pattern '^\s*[xyz]\s*=\s*-?[1-9]').Count
if ($nonzero -le 0) { throw "no room received a non-zero coordinate" }

#    3.3 UCL 校验必须全过
python scripts\validate_ucl.py data\world_backup\test_assigned.ucl
if ($LASTEXITCODE -ne 0) { throw "validate_ucl.py failed with exit code $LASTEXITCODE" }

# 4. 跑全量测试套件（Elixir 测试套件仍在容器内）
docker exec wuxia_mud_dev-app-1 sh -c 'MIX_ENV=test mix test'
```

## 常见问题

**Q: 起始房间 ID 找不到？**
A: 确认 UCL 中 `rooms "xxx"` 的 ID 与参数一致（不含 `rooms.` 前缀）。脚本会打印
`ERROR: start room 'xxx' not found in <path>` 并以退出码 1 结束。

**Q: 输出文件没变化？**
A: 检查源文件是否已有非零锚点；`anchor rooms (kept non-zero)` 数量会在日志显示。

**Q: 误跑了 `-o`，源文件被改了？**
A: `-o` 会被静默忽略，脚本**就地覆盖**了输入。用
`git checkout -- data/world_backup/test_zero.ucl` 还原，然后重跑上面的清零命令。

**Q: 想测试其他区域？**
A: 复制 `<zone>.ucl` 到 `data\world_backup\test_zero.ucl`，清空坐标，换起始房间 ID 跑即可。

## 相关文件

- `scripts/assign_room_coords.py` — 主脚本（Python，宿主机运行）
- `scripts/validate_ucl.py` — UCL 校验脚本（Python，宿主机运行）
- `data/world_backup/test_zero.ucl` — 测试源文件（全零坐标）
- `data/world_backup/test_assigned.ucl` — 测试输出文件（gitignore 建议忽略）
- `scripts/lpc_converter.py` — UCL 生成器（重新生成会丢失坐标）
- `scripts/assign_room_coords.exs` — 遗留 Elixir 版，仅作参考
