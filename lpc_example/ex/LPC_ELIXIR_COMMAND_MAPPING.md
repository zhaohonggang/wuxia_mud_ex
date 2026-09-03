# LPC vs Elixir 命令详细对照表

> 生成时间: 2026-09-02
> LPC源: `C:\files\git\mud\cmds\`
> Elixir源: `C:\files\git\wuxia_mud_ex\lib\kantele\character\commands\`

---

## 统计总览

| 类别 | LPC | Elixir | 状态 |
|------|-----|--------|------|
| std/ | 85 | ~70 | 大部分已实现 |
| usr/ | 67 | ~55 | 大部分已实现 |
| wiz/ | 40 | 6 (goto/where/who1/clone/dest/update) | 部分实现 |
| arch/ | 49 | 14 (stubs) | stubs占位 |
| skill/ | 59 | ~30 | 大部分已实现 |
| adm/ | 28 | 0 | 不适用 |
| chat/ | 11 | 0 | 不适用 |
| imm/ | 6 | 0 | 不适用 |
| **总计** | **347** | **~176** | |

---

## std/ 目录 (85个)

| LPC命令 | Elixir实现 | 状态 | 说明 |
|---------|-----------|------|------|
| accept | AcceptCommand | ✅ | 已实现 |
| ansuan | AnsuanCommand | ✅ | 已实现 |
| answer | AnswerCommand | ✅ | 已实现 |
| apply | - | ❌ | 系统函数，非玩家命令 |
| ask | AskCommand | ✅ | 已实现 |
| attack | FightCommand | ✅ | hit/kill统一到fight |
| beg | BegCommand | ✅ | 已实现 |
| check | CheckCommand | ✅ | 已实现（丐帮打探） |
| close | CloseCommand | ✅ | 已实现 |
| come | ComeCommand | ✅ | 已实现(stub) |
| cook | CookCommand | ✅ | 已实现 |
| cut | CutCommand | ✅ | 已实现 |
| daub | DaubCommand | ✅ | 已实现 |
| drink | DrinkCommand | ✅ | 已实现 |
| drive | DriveCommand | ✅ | 已实现 |
| drop | ItemCommand | ✅ | 统一到item命令 |
| drug | DrugCommand | ✅ | 已实现 |
| eat | EatCommand | ✅ | 已实现 |
| emote | EmoteCommand | ✅ | 已实现 |
| femote | FemoteCommand | ✅ | 已实现 |
| fight | FightCommand | ✅ | 已实现 |
| fill | FillCommand | ✅ | 已实现 |
| follow | FollowCommand | ✅ | 已实现 |
| get | ItemCommand | ✅ | 统一到item命令 |
| give | GiveCommand | ✅ | 已实现 |
| go | MoveCommand | ✅ | 通过方向移动 |
| guard | GuardCommand | ✅ | 已实现 |
| halt | HaltCommand | ✅ | 已实现 |
| hand | HandCommand | ✅ | 已实现(stub) |
| hit | FightCommand | ✅ | 统一到fight |
| invasion | - | ❌ | 入侵事件，未实现 |
| kill | FightCommand | ✅ | 统一到fight |
| liuxi | LiuxiCommand | ✅ | 已实现(stub) |
| look | LookCommand | ✅ | 已实现 |
| look2 | - | ❌ | 次级look，未实现 |
| make | MakeCommand | ✅ | 已实现 |
| makelove | - | ❌ | 社交命令，未实现 |
| map | MapCommand | ✅ | 已实现 |
| open | OpenCommand | ✅ | 已实现 |
| pour | PourCommand | ✅ | 已实现 |
| purchase | PurchaseCommand | ✅ | 已实现(stub) |
| push | PushCommand | ✅ | 已实现(stub) |
| put | ItemCommand | ✅ | 统一到item命令 |
| refuse | RefuseCommand | ✅ | 已实现 |
| release | ReleaseCommand | ✅ | 已实现(stub) |
| remove | RemoveCommand | ✅ | 已实现(stub) |
| reply | ReplyCommand | ✅ | 已实现 |
| ride | RideCommand | ✅ | 已实现 |
| right | RightCommand | ✅ | 已实现 |
| say | SayCommand | ✅ | 已实现 |
| search | SearchCommand | ✅ | 已实现 |
| secularize | SecularizeCommand | ✅ | 已实现(stub) |
| semote | SemoteCommand | ✅ | 已实现 |
| skill | - | ❌ | 技能系统，未实现 |
| sleep | SleepCommand | ✅ | 已实现 |
| special | SpecialCommand | ✅ | 已实现(stub) |
| stab | StabCommand | ✅ | 已实现(stub) |
| stay | StayCommand | ✅ | 已实现(stub) |
| steal | StealCommand | ✅ | 已实现 |
| stop | StopCommand | ✅ | 已实现(stub) |
| surrender | SurrenderCommand | ✅ | 已实现 |
| swear | SwearCommand | ✅ | 已实现 |
| talk | TalkCommand | ✅ | 已实现(stub) |
| team | TeamCommand | ✅ | 已实现 |
| tell | TellCommand | ✅ | 已实现 |
| to | ToCommand | ✅ | 已实现(stub) |
| touch | TouchCommand | ✅ | 已实现(stub) |
| touxi | TouxiCommand | ✅ | 已实现 |
| train | TrainCommand | ✅ | 已实现(stub) |
| tune | TuneCommand | ✅ | 已实现 |
| unride | UnrideCommand | ✅ | 已实现 |
| unwield | WieldCommand | ✅ | 统一到wield |
| vote | VoteCommand | ✅ | 已实现(stub) |
| wash | WashCommand | ✅ | 已实现 |
| watch | LookCommand | ✅ | alias到look |
| wear | WieldCommand | ✅ | 统一到wield |
| wenxuan | WenxuanCommand | ✅ | 已实现 |
| whisper | WhisperCommand | ✅ | 已实现 |
| wield | WieldCommand | ✅ | 已实现 |

---

## usr/ 目录 (67个)

| LPC命令 | Elixir实现 | 状态 | 说明 |
|---------|-----------|------|------|
| accede | AccedeCommand | ✅ | 已实现 |
| alias | AliasCommand | ✅ | 已实现 |
| area | - | ❌ | 区域信息，未实现 |
| assist | AssistCommand | ✅ | 已实现(stub) |
| auction | AuctionCommand | ✅ | 已实现 |
| baitan | BaitanCommand | ✅ | 已实现 |
| beep | BeepCommand | ✅ | 已实现(stub) |
| bjtime | BjtimeCommand | ✅ | 已实现(stub) |
| brothers | BrothersCommand | ✅ | 已实现 |
| buy | BuyCommand | ✅ | 已实现 |
| cls | ClsCommand | ✅ | 已实现(stub) |
| color | ColorCommand | ✅ | 已实现(stub) |
| describe | DescribeCommand | ✅ | 已实现(stub) |
| divorce | DivorceCommand | ✅ | 已实现 |
| engage | EngageCommand | ✅ | 已实现 |
| feed | FeedCommand | ✅ | 已实现 |
| findwp | - | ❌ | 路点查找，系统工具 |
| finger | FingerCommand | ✅ | 已实现 |
| hatred | HatredCommand | ✅ | 已实现 |
| help | HelpCommand | ✅ | 已实现(stub) |
| hide | HideCommand | ✅ | 已实现（隐藏兵器，非隐身） |
| hp | HpCommand | ✅ | 已实现(stub) |
| id | IdCommand | ✅ | 已实现(stub) |
| idle | - | ❌ | 空闲状态，系统工具 |
| inventory | InventoryCommand | ✅ | 已实现 |
| jifen | JifenCommand | ✅ | 已实现 |
| league | LeagueCommand | ✅ | 已实现 |
| list | ListCommand | ✅ | 已实现 |
| miss | MissCommand | ✅ | 已实现 |
| mobile | - | ❌ | 移动信息，未实现 |
| mudinfo | MudinfoCommand | ✅ | 已实现 |
| mudlist | - | ❌ | MUD列表，未实现 |
| mudlist2 | - | ❌ | MUD列表变体，未实现 |
| news | NewsCommand | ✅ | 已实现 |
| nick | NickCommand | ✅ | 已实现(stub) |
| option | OptionCommand | ✅ | 已实现(stub) |
| passwd | PasswdCommand | ✅ | 已实现(stub) |
| pkd | PkdCommand | ✅ | 已实现(stub) |
| qrcode | - | ❌ | 二维码生成，未实现 |
| quest | QuestCommand | ✅ | 已实现 |
| quest2 | Quest2Command | ✅ | 已实现 |
| quit | QuitCommand | ✅ | 已实现 |
| recall | RecallCommand | ✅ | 已实现 |
| record | - | ❌ | 录制系统，未实现 |
| rideto | RidetoCommand | ✅ | 已实现 |
| save | SaveCommand | ✅ | 已实现 |
| scheme | SchemeCommand | ✅ | 已实现 |
| score | ScoreCommand | ✅ | 已实现 |
| score2 | Score2Command | ✅ | 已实现(stub) |
| set | SetCommand | ✅ | 已实现(stub) |
| shop | ShopCommand | ✅ | 已实现 |
| skip | - | ❌ | 跳过，未实现 |
| snoop | - | ❌ | 监听，未实现 |
| suicide | SuicideCommand | ✅ | 已实现 |
| summon | SummonCommand | ✅ | 已实现（召唤已注册物品） |
| swear | SwearCommand | ✅ | 复用std/ |
| system | SystemCommand | ✅ | 已实现(stub) |
| tianshu | TianshuCommand | ✅ | 已实现 |
| time | TimeCommand | ✅ | 已实现 |
| title | TitleCommand | ✅ | 已实现(stub) |
| top | TopCommand | ✅ | 已实现(stub) |
| top2 | Top2Command | ✅ | 已实现(stub) |
| topp | ToppCommand | ✅ | 已实现(stub) |
| unset | UnsetCommand | ✅ | 已实现 |
| uptime | UptimeCommand | ✅ | 已实现 |
| whistle | WhistleCommand | ✅ | 已实现 |
| who | WhoCommand | ✅ | 已实现 |
| wimpy | WimpyCommand | ✅ | 已实现(stub) |
| wizlist | WizlistCommand | ✅ | 已实现 |

---

## wiz/ 目录 (40个)

| LPC命令 | Elixir实现 | 状态 | 说明 |
|---------|-----------|------|------|
| cat | - | ❌ | 查看文件，未实现 |
| cd | - | ❌ | 切换目录，未实现 |
| chblk | - | ❌ | 屏蔽频道，未实现 |
| clone | CloneCommand | ✅ | 已实现(stub) |
| color | - | ❌ | 颜色命令，未实现 |
| copyskill | - | ❌ | 复制技能，未实现 |
| cost | - | ❌ | 消耗计算，未实现 |
| cp | - | ❌ | 复制文件，未实现 |
| dest | DestCommand | ✅ | 已实现(stub) |
| edit | - | ❌ | 编辑器，未实现 |
| ff | - | ❌ | 查找文件，未实现 |
| goto | GotoCommand | ✅ | 已实现 |
| home | HomeCommand | ✅ | 已实现（回区域起始房间） |
| ilist | - | ❌ | 物品列表，未实现 |
| info | - | ❌ | 信息，未实现 |
| ip | - | ❌ | IP信息，未实现 |
| ipname | - | ❌ | IP名称，未实现 |
| localcmds | LocalcmdsCommand | ✅ | 已实现（列出房间出口指令） |
| ls | - | ❌ | 目录列表，未实现 |
| mem | MemCommand | ✅ | 已实现 |
| mkdir | - | ❌ | 创建目录，未实现 |
| more | - | ❌ | 分页查看，未实现 |
| mv | - | ❌ | 移动文件，未实现 |
| nodie | - | ❌ | 不死模式，未实现 |
| pwd | - | ❌ | 当前目录，未实现 |
| qload | - | ❌ | 查询加载，未实现 |
| rm | - | ❌ | 删除文件，未实现 |
| status | - | ❌ | 系统状态，未实现 |
| summon | - | ❌ | 召唤，未实现 |
| ulist | - | ❌ | 用户列表，未实现 |
| unchblk | - | ❌ | 解除屏蔽，未实现 |
| update | UpdateCommand | ✅ | 已实现(stub) |
| weight | - | ❌ | 重量信息，未实现 |
| where | WhereCommand | ✅ | 已实现 |
| who1 | Who1Command | ✅ | 已实现 |
| who2 | Who2Command | ✅ | 已实现 |
| who3 | Who3Command | ✅ | 已实现 |
| whoami | WhoamiCommand | ✅ | 已实现 |
| whohave | - | ❌ | 谁有物品，未实现 |
| whoride | - | ❌ | 谁在骑乘，未实现 |
| wizard | - | ❌ | 巫师模式，未实现 |

---

## arch/ 目录 (49个)

| LPC命令 | Elixir实现 | 状态 | 说明 |
|---------|-----------|------|------|
| ban | - | ❌ | 禁用用户，未实现 |
| blockade | - | ❌ | 封锁命令，未实现 |
| board | - | ❌ | 公告板，未实现 |
| build | BuildCommand | ✅ | 已实现(stub) |
| call | CallCommand | ✅ | 已实现(stub) |
| callouts | - | ❌ | 回调信息，未实现 |
| changename | - | ❌ | 改名，未实现 |
| child | - | ❌ | 子进程，未实现 |
| chinese | - | ❌ | 中文模式，未实现 |
| cleanup | - | ❌ | 清理，未实现 |
| cleartemp | - | ❌ | 清除临时，未实现 |
| cmd | - | ❌ | 自定义命令，未实现 |
| config | - | ❌ | 配置，未实现 |
| data | - | ❌ | 数据命令，未实现 |
| dual | - | ❌ | 双武器，未实现 |
| endlog | - | ❌ | 结束日志，未实现 |
| examine | - | ❌ | 检查对象，未实现 |
| find | - | ❌ | 查找，未实现 |
| findusr | - | ❌ | 查找用户，未实现 |
| free | - | ❌ | 空闲内存，未实现 |
| getid | - | ❌ | 获取ID，未实现 |
| kickout | - | ❌ | 踢出玩家，未实现 |
| log | - | ❌ | 日志，未实现 |
| mv | - | ❌ | 移动，未实现 |
| overview | - | ❌ | 概览，未实现 |
| p2 | - | ❌ | 协议p2，未实现 |
| possess | PossessCommand | ✅ | 已实现(stub) |
| promote | - | ❌ | 提升权限，未实现 |
| purge | PurgeCommand | ✅ | 已实现(stub) |
| qdel | - | ❌ | 查询删除，未实现 |
| qinfo | - | ❌ | 查询信息，未实现 |
| reboot | RebootCommand | ✅ | 已实现(stub) |
| recovemud | - | ❌ | 恢复MUD，未实现 |
| register | RegisterCommand | ✅ | 已实现(stub) |
| rehash | - | ❌ | 重载，未实现 |
| restore | RestoreCommand | ✅ | 已实现(stub) |
| sa | - | ❌ | 特殊动作，未实现 |
| sameip | - | ❌ | 同IP用户，未实现 |
| setsk | SetskCommand | ✅ | 已实现(stub) |
| smash | SmashCommand | ✅ | 已实现(stub) |
| spy | - | ❌ | 侦察，未实现 |
| status1 | - | ❌ | 状态1，未实现 |
| throw | ThrowCommand | ✅ | 已实现(stub) |
| var | VarCommand | ✅ | 已实现(stub) |
| version | - | ❌ | 版本，未实现 |
| which | - | ❌ | 查找命令，未实现 |
| wizlock | - | ❌ | 巫师锁，未实现 |

---

## skill/ 目录 (59个)

| LPC命令 | Elixir实现 | 状态 | 说明 |
|---------|-----------|------|------|
| abandon | AbandonCommand | ✅ | 已实现 |
| animaout | AnimaoutCommand | ✅ | 已实现 |
| apprentice | ApprenticeCommand | ✅ | 已实现 |
| berserk | BerserkCommand | ✅ | 已实现 |
| breakup | BreakupCommand | ✅ | 已实现 |
| burning | BurningCommand | ✅ | 已实现 |
| checkskill | CheckskillCommand | ✅ | 已实现 |
| closed | ClosedCommand | ✅ | 已实现 |
| combine | CombineCommand | ✅ | 已实现 |
| crattack | CrattackCommand | ✅ | 已实现 |
| death | - | ❌ | 死亡处理，未实现 |
| derive | DeriveCommand | ✅ | 已实现 |
| detach | DetachCommand | ✅ | 已实现 |
| enable | EnableCommand | ✅ | 已实现 |
| enchase | EnchaseCommand | ✅ | 已实现 |
| enforce | - | ❌ | 加力，未实现 |
| exercise | ExerciseCommand | ✅ | 已实现 |
| exert | ExertCommand | ✅ | 已实现 |
| expell | - | ❌ | 开除，未实现 |
| fuse | FuseCommand | ✅ | 已实现 |
| imbue | ImbueCommand | ✅ | 已实现 |
| jingxiu | JingxiuCommand | ✅ | 已实现 |
| jingzuo | JingzuoCommand | ✅ | 已实现 |
| learn | LearnCommand | ✅ | 已实现 |
| myskill | SkillsCommand | ✅ | alias到skills |
| perform | PerformCommand | ✅ | 已实现 |
| persuade | PersuadeCommand | ✅ | 已实现 |
| pique | PiqueCommand | ✅ | 已实现 |
| practice | PracticeCommand | ✅ | 已实现 |
| prepare | PrepareCommand | ✅ | 已实现(stub) |
| recruit | RecruitCommand | ✅ | 已实现 |
| research | ResearchCommand | ✅ | 已实现 |
| respirate | RespirateCommand | ✅ | 已实现 |
| san | SanCommand | ✅ | 已实现 |
| skills | SkillsCommand | ✅ | 已实现 |
| spattack | SpattackCommand | ✅ | 已实现 |
| study | StudyCommand | ✅ | 已实现 |
| syn | SynCommand | ✅ | 已实现 |
| yanlian | YanlianCommand | ✅ | 已实现 |

---

## adm/ 目录 (28个) - 系统管理，不适用Elixir迁移

| LPC命令 | 状态 | 说明 |
|---------|------|------|
| auth | N/A | 认证系统 |
| cache | N/A | 缓存管理 |
| checkuser | N/A | 检查用户 |
| chklog | N/A | 检查日志 |
| clear | N/A | 清屏 |
| dump | N/A | 转储 |
| eval | N/A | 代码执行 |
| f | N/A | 短格式eval |
| fcrypt | N/A | 文件加密 |
| giftall | N/A | 全员礼物 |
| giveall | N/A | 全员给予 |
| guilei | N/A | 归类 |
| linux | N/A | Linux命令 |
| loadall | N/A | 加载所有 |
| msg | N/A | 消息 |
| profile | N/A | 性能分析 |
| query | N/A | 查询 |
| reclaim | N/A | 回收内存 |
| rinemote | N/A | 远程命令 |
| shutdown | ShutdownCommand | ✅ | stub |
| sp | N/A | 特殊命令 |
| telnet | N/A | Telnet |
| tongji | N/A | 统计 |
| updateall | N/A | 更新所有 |
| updatei | N/A | 更新项目 |
| grant | GrantCommand | ✅ | stub |

---

## chat/ 目录 (11个) - 聊天系统

| LPC命令 | Elixir实现 | 状态 | 说明 |
|---------|-----------|------|------|
| command | - | ❌ | 通用命令 |
| enterworld | - | ❌ | 进入世界 |
| finger | FingerCommand | ✅ | 复用usr/ |
| getenv | - | ❌ | 获取环境 |
| go | MoveCommand | ✅ | 复用std/ |
| input | - | ❌ | 输入处理 |
| look | LookCommand | ✅ | 复用std/ |
| say | SayCommand | ✅ | 复用std/ |
| setenv | - | ❌ | 设置环境 |
| tell | TellCommand | ✅ | 复用std/ |
| who | WhoCommand | ✅ | 复用usr/ |

---

## imm/ 目录 (6个) - 特殊命令

| LPC命令 | 状态 | 说明 |
|---------|------|------|
| cpemote | ❌ | 复制表情 |
| edemote | ❌ | 编辑表情 |
| flyto | ❌ | 飞往 |
| recover | ❌ | 恢复 |
| rnemote | ❌ | 随机表情 |

---

## 问题汇总

### 1. 未注册的W3命令 (14个)
这些stub命令文件存在但没注册到commands.ex：
- BuildCommand, CallCommand, ChangeuserCommand, GrantCommand, PossessCommand, PurgeCommand, RebootCommand, RegisterCommand, RestoreCommand, SetskCommand, ShutdownCommand, SmashCommand, ThrowCommand, VarCommand

### 2. 高价值缺失命令
- ask (询问NPC) - 重要社交功能
- hide (隐身) - 重要技能
- summon (召唤) - 重要功能
- rideto (骑乘传送) - 重要功能
- list (商店列表) - 部分实现

### 3. LPC重复命令 (已处理)
- look (std/ + chat/) → LookCommand
- who (usr/ + chat/) → WhoCommand
- say (std/ + chat/) → SayCommand
- finger (usr/ + chat/) → FingerCommand
- tell (std/ + chat/) → TellCommand
- go (std/ + chat/) → MoveCommand

---

## 迁移建议

### 立即可行
1. 注册14个未注册的W3命令到commands.ex
2. 实现ask命令 (询问NPC)
3. 实现hide命令 (隐身)

### 中期计划
1. 实现summon命令 (召唤)
2. 实现rideto命令 (骑乘传送)
3. 完善list命令 (商店列表)

### 架构不适用 (adm/arch)
- adm/ 所有命令 - Elixir生态无等价物
- arch/ 大部分命令 - 需要对象系统支持
