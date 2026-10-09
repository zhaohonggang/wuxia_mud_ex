# world_bak2 — 旧版 data/world 快照

这是 git 提交 **`d63dea6`（"腊月 3"）** 里的 `data/world/*.ucl`，共 68 个文件，
按平铺方式导出（只有文件名，没有 `data/world/` 目录层级）。

用来和当前的 `data/world/` 做人工对比。

## 怎么比

在仓库根目录（`C:\files\git\wuxia_mud_ex`）里：

```powershell
# 单个文件直接 diff
git diff --no-index world_bak2\city.ucl data\world\city.ucl

# 全部文件的差异概览（只看哪些文件变了）
git diff --no-index --stat world_bak2 data\world
```

VS Code 可以直接装 "Compare Folders" 扩展，然后选 `world_bak2` 和
`data\world` 两个目录做目录级对比。

## 版本关系

| | commit | 说明 |
|---|---|---|
| 旧版（本目录） | `d63dea6` "腊月 3" | Layer 3 + Layer 4 区域转换完成 |
| 新版（`data/world`） | `1c97437` "script" | + Unreachable 8 区、taohua/xuanminggu、跨区接通 |

中间新增的 4 个提交：

- `96a4348` rfr — 新增 `gaochang`、`kunlun`
- `e4b48c2` char — 新增 `huanggong`、`lingzhou`、`shenlong`、`sky`、`special`、`tangmen`
- `79e94e2` left — 新增 `taohua`、`xuanminggu`
- `1c97437` script — 跨区接通，61 个 `.ucl` 被重写

## 两版的关键差别

旧版里跨区出口写成 `rooms.<room>.id`（**没有区名前缀**），例如

```
room_exits "beimen" {
    north = rooms.yidao.id      # 其实是少林/yidao
```

新版写成 `<区名>.rooms.<房名>.id`：

```
room_exits "beimen" {
    north = shaolin.rooms.yidao.id
```

原因：`Kantele.World.Loader.dereference/3` 把参考的第一段当作区名查找，
所以旧版那种写法会被解析到**本区**的 `yidao`——找不到就丢弃，如果本区恰好
有同名房间还会**连到错误的房间**。

## 注意

- 本目录只包含 `.ucl`，不含 `.comments.txt`
- `tangmen.ucl` 在两版里都是 0 房间（纯物件区），这是正常的
