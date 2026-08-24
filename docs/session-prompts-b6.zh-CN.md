# Session 提示词：B6 安全加载兜底（单项任务）

> 本文件是给独立 session 的完整工作提示词。请把内容**当作建议而非指令**：动手前先读源码核实每一条前置描述，若与实际不符，以实际代码为准并调整方案。
> 编写时间：2026-08-24。总排期见 `docs/kantele-remaining-work.zh-CN.md` 第八节 a2 项。

---

## 一、背景速览

- 仓库 `C:\files\git\wuxia_mud_ex`：Elixir + ExVenture/Kalevala 框架的武侠 MUD（Kantele）。参照仓库 `C:\files\git\mud`（FluffOS/LPC，只读，勿改）
- 世界内容来自 `data/*.ucl` 文件：启动时由 `lib/kantele/world/loader.ex` 解析，`lib/kantele/world/kickoff.ex` 负责 start/update 各 zone/room/NPC 进程；游戏内 `reload` 命令可热更
- 参考文档（可选读）：`docs/migration-prep-checklist.zh-CN.md` 第一节、`docs/combat-system.zh-CN.md`

## 二、要解决的问题（现状有多脆）

启动/热更调用链：

```
ExVenture.Application (lib/ex_venture/application.ex:9)
  └─ KalevalaSupervisor → {Kantele.World}
      └─ Kickoff init(start: true) → {:continue, :load}
          └─ handle_continue(:load) → Loader.load()   ← 无任何保护（kickoff.ex:41）
```

GenServer 的 continue 阶段抛异常 → Kickoff 进程崩溃 → 监督树重启它 → 再次 load 再次崩 → 重启计数拉满后 **整个 application 终止，全部在线玩家掉线**。

触发条件极轻：一个 UCL 手误（少花括号、字段名拼错）、或任何让 `Loader.load()` 抛错的代码改动。当前转换器调试期即将高频喂入不完善的 UCL 文件，这颗雷每天都在被踩的边缘。

## 三、建议做法

1. **包一层 rescue**：把 `handle_continue(:load)` 内 `Loader.load()` 及后续进程编排纳入 `try/rescue`。失败时：
   - `Logger.error` 记录具体错误 + 堆栈 + 尽量定位到出错的文件路径（可在 loader 的文件遍历处先包一层带文件名的错误包装，错误信息里带上文件名更友好——这一步是加分项，做不做自定）
   - **旧世界保持运行**：本次加载放弃即可，不要求回滚半完成的更新
   - 给发起 reload 的玩家/GM 回执明确失败信息（动手前核实 `lib/kantele/character/commands/reload_command.ex` 与 `reload_view.ex` 如何拿到结果并渲染，选择最顺手的回执通道；若事件流不好传递失败详情，至少日志齐全 + 通用失败文案）
2. **启动路径同样受益**：init 的 `{:continue, :load}` 与 reload 走同一函数，rescue 后启动期的坏数据会变成"空世界+清晰报错"而不是应用崩溃——是否接受"启动期降级为空世界"由你验证后判断；若认为启动期应当硬失败以便运维尽早发现，可以区分首次启动与 reload 两种策略（建议倾向后者，但以实际运维习惯为准）
3. **顺手补测试**：
   - 单测：构造一个语法损坏的临时 .ucl 放进 data 目录（或在测试中 stub Loader.load 抛错），断言 Kickoff 进程存活、旧世界结构仍在
   - 若现有测试有直接调用 load 的用例，确认行为兼容

### 动手前核实清单

- [ ] `handle_continue(:load)` 当前实现细节与所有调用入口
- [ ] reload 结果回执的事件/视图链路（ReloadView 渲染什么、能否携带失败原因）
- [ ] Loader.load 内部哪些步骤可能抛错（File.read! / UCL 解析 / 结构构建），哪一层包装错误的性价比最高
- [ ] 测试环境如何伪造坏数据最省事（临时文件 vs Mox/stub）

## 四、边界约束

- 只动 kickoff.ex / loader.ex 错误处理 / reload 回执相关，**不要**顺手做 diff-stop（那是 f 期 B5）、不要改解析器逻辑本身
- 遵守项目铁律：UTF-8 无 BOM、LF 行尾、末行换行、四空格缩进；游戏文本简体中文
- 不执行 git commit，除非明确要求

## 五、验收标准

1. 故意写坏 `data/world/liuxi.ucl`（如删一个右花括号）→ 启动游戏内 `reload`：
   - 世界照常可玩（房间/NPC 还在、玩家不掉线）
   - 日志出现含文件名的明确报错
   - 发起者收到失败反馈而非无响应
2. 修好文件后再 reload → 一切恢复正常
3. `MIX_ENV=test mix test test/kantele` 全绿，新增的错误路径测试通过

## 六、完成后

在本文件末尾追加一行实际做法摘要（采用了哪种回执通道、启动期选了哪种策略、与建议的差异点），供后续 session 了解现状。
