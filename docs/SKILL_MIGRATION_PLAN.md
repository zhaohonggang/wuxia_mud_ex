# 武学技能真实迁移执行计划（T2/T3 深度迁移）

## 核心原则
- **批次提交**：以门派/体系为单位提交，每批 10-20 个 skill
- **对照源码**：每步必读对应 `.c`，禁止凭记忆
- **复用 perform**：优先迁移 perform 模块，skill 只做薄封装
- **自动化优先**：先跑通 perform 抽取器，减少手写

---

## Phase 0：工具链就绪（预计 1-2 天）

### 目标
- 修复 `translate_perform.exs` 跑通
- 生成 `tmp/perf_out/*.ex` (~430 个 perform 骨架)
- 补全缺失 perform 到 `lib/kantele/combat/skills/performs/`
- 增强 `diff_skill.exs` 支持字段级对比

### 任务清单
- [ ] 修复 `RUN_EXTRACTOR` 逻辑，使 `scripts/translate_perform.exs` 可直接运行
- [ ] 执行抽取：`MIX_ENV=test RUN_EXTRACTOR=1 mix run scripts/translate_perform.exs`
- [ ] 验证产出：`ls /tmp/perf_out | wc -l` 应约等于 430
- [ ] 对比现有 performs：`diff <(ls /tmp/perf_out | sort) <(ls lib/kantele/combat/skills/performs | sort)`
- [ ] 批量创建缺失 perform 模板（复用 `batch_migrate` 逻辑）
- [ ] 编译通过：`mix compile`
- [ ] 基础测试通过：`mix test test/kantele/combat/`

### 产出物
- `/tmp/perf_out/` 完整 perform 骨架库
- `lib/kantele/combat/skills/performs/` 补全至 430+
- 可用的 `diff_skill.exs --fields query_action,valid_learn,damage,gates`

---

## Phase 1：核心内功/基础技能（第 1 周，~40 个）

### 批次 1A：Force 系列内功（11 个）— **单次提交**
| 技能 | 类型 | 关键 perform |
|------|------|--------------|
| force-power | 内功 | exert:powerup |
| force-heal | 内功 | exert:heal |
| force-dispel | 内功 | exert:dispel |
| force-recover | 内功 | exert:recover |
| force-regenerate | 内功 | exert:regenerate |
| force-inspire | 内功 | exert:inspire |
| force-lifeheal | 内功 | exert:lifeheal |
| force-roar | 内功 | exert:roar |
| force-shot | 内功 | exert:shot |
| force-tianmo | 内功 | exert:tianmo |
| force-xun | 内功 | exert:xun |

**共同特征**：纯 `exert` 无招式，核心是内力消耗/恢复公式、buff 数值、冷却。

### 批次 1B：八大门派核心内功（8 个）— **单次提交**
| 技能 | 门派 | 关键 perform |
|------|------|--------------|
| taiji-shengong | 武当/全真 | powerup, shield, heal |
| xiaowuxiang | 逍遥 | powerup, shield |
| hunyuan-yiqi | 少林/全真 | powerup, shield |
| zixia-shengong | 华山 | powerup, ziqi |
| bibo-shengong | 桃花岛 | powerup, shield |
| bahuang-gong | 逍遥/星宿 | powerup |
| changsheng-jue | 全真 | powerup, shield |
| xuanming-shengong | 星宿/雪山 | powerup, shield |

### 批次 1C：Extra 列表补全（2 个）— **单次提交**
| 技能 | 备注 |
|------|------|
| liuxi-neigong | 已在 Extra，优先补全 |
| liuxin-jian | 已在 Extra，剑法+内功混合 |

### 批次 1D：基础武器/拳脚类（15 个）— **单次提交**
| 分类 | 技能列表 |
|------|----------|
| 兵器基础 | sword, blade, staff, whip, axe, dagger, hammer, club |
| 拳脚基础 | finger, cuff, strike, hand, claw, unarmed |
| 暗器基础 | throwing |

**共同特征**：`query_action` 映射通用 perform，`valid_learn` 基础判定（等级/臂力/身法）。

---

## Phase 2：主流门派招式技能（第 2-3 周，~160 个）

### 批次 2A：华山派（7 个）— **单次提交**
huashan-jian, huashan-quan, huashan-zhang, huashan-shenfa, huashan-xinfa, huashan-zhangfa, huashan-sword

### 批次 2B：武当派 + 太极系（10 个）— **单次提交**
wudang-jian, wudang-zhang, wudang-quan, wudang-jiuyang, wudang-xinfa, taiji-jian, taiji-quan, taiji-dao, taiji-shengong, wudang-yaoli

### 批次 2C：少林派（12 个）— **单次提交**
shaolin-quan, shaolin-zhang, shaolin-tantui, shaolin-xinfa, shaolin-yishu, shaolin-shenfa, yijinjing, jingang-zhi, banruo-zhang, luohan-quan, weituo-chu, dazhi-zhi

### 批次 2D：逍遥派（6 个）— **单次提交**
xiaoyao-jian, xiaoyao-quan, xiaoyao-xinfa, xiaoyao-qixue, beidou-xianzong, lingbo-weibu

### 批次 2E：峨眉派（5 个）— **单次提交**
emei-jian, emei-zhang, emei-quan, emei-xinfa, jinding-zhang

### 批次 2F：丐帮（5 个）— **单次提交**
xianglong-zhang, dabi-zhang, dacidabei-shou, suohou-gong, bangjue

### 批次 2G：星宿派（5 个）— **单次提交**
xingxiu-qishu, chousui-zhang, huagong-dafa, xixing-dafa, tianbu-zhenfa

### 批次 2H：古墓派（4 个）— **单次提交**
yunu-jian, yunu-xinfa, yunv-xinjing, yunv-shenfa

### 批次 2I：全真派（5 个）— **单次提交**
quanzhen-jian, quanzhen-quan, quanzhen-xinfa, dugu-jiujian, tiangang-zhi

### 批次 2J：五岳剑派其它（8 个）— **单次提交**
songshan-jian, hengshan-jian, hengshan-quan, taishan-sword, taishan-xinfa, hengshan-sword, hengshan-xinfa, songshan-xinfa

---

## Phase 3：特殊机制技能（第 4 周，~80 个）

### 批次 3A：吸功/化功系（6 个）
xixing-dafa, huagong-dafa, beiming-shengong, xixing-xiaofa, sangong, tianmo-jue

### 批次 3B：毒系（6 个）
tangmen-poison, wudu-qishu, wudu-shenzhang, xingxiu-qishu, xueshan-dao, qishang-quan

### 批次 3C：暗器/投掷（6 个）
tangmen-throwing, xiaoli-feidao, feidao, throwing, tougu-zhen, bijia

### 批次 3D：轻功/身法（8 个）
lingbo-weibu, taxue-wuhen, yunlong-shenfa, tiyunzong, zhuifeng-steps, shenghuo-bu, yueying-wubu, yunv-shenfa

### 批次 3E：阵法/协作（4 个）
wai-bagua, zhenfa, liangyi-jian, liangyi-zhen

### 批次 3F：医疗/炼药/生活（10 个）
yaowang-miaoshu, yaowang-shenxin, tangmen-medical, bencao-shuli, bencao-changshi, yaogu-xinfa, zhenjiu-shu, liandan-shu, suqin-beijian, liuyue-jian

### 批次 3G：琴棋书画/特殊（6 个）
tanqin-jifa, guzheng-jifa, qixian-wuxingjian, suxing-jian, zither, chess

### 批次 3H：其它门派/杂项（~30 个）
baituo-michuan, baituo-xinfa, bixue-danxin, canglang-zhi, dalun-zhang, dali-quan, dimai-shou, guanri-jian, guanyuan-zhang, huagu-mianzhang, huashan-quanfa, hujia-quan, huoyan-dao, jiaohua-bangfa, jiaohua-neigong, jinshe-youshenbu, jinshe-zhang, kuihua-mogong, kuihua-xinfa, luohan-jian, mizong-zhang, muyu-zhang, pangu-qishi, qiankun-danuoyi, qishang-quan, riyue-xinfa, rouyun-jian, rulai-zhang, shenzhang-bada, shenlong-bashi, tianshan-zhang

---

## Phase 4：剩余长尾（第 5 周，~200 个）

按字母序分 10 批，每批 20 个，**每批单次提交**。

许多是变体/别名/极少用（如 `array`, `checking`, `chess`, `cooking`, `literate`, `idle-force`, `japanese`, `korean`, `magic`, `never-defeated`, `persuading`, `russian` 等），可只保留最小可用骨架（`query_action` 返回空、`valid_learn` 返回 false）。

批量跑 `validate_skill.exs` 扫描遗漏字段。

---

## Phase 5：全量回归 & 性能（第 6 周）

| 动作 | 目标 |
|------|------|
| `mix test --trace` 全量跑 | 0 failures，无 timeout |
| 加载测试：100 并发角色释放技能 | 无死锁、内存稳定 |
| 抽样对比 LPC 伤害输出 | 核心技能误差 < 5% |
| 生成迁移报告 | 统计：已迁移/遗漏/待优化 |

---

## 每批次执行模板

```bash
# 1. 设定批次技能列表
SKILLS=("huashan-jian" "huashan-quan" "huashan-zhang" "huashan-shenfa" "huashan-xinfa" "huashan-zhangfa" "huashan-sword")

# 2. 批量读源码对照
for s in "${SKILLS[@]}"; do
  echo "=== $s ==="
  cat /app/kungfu_source/kungfu/skill/${s}.c
  ls /app/kungfu_source/kungfu/skill/${s}/ 2>/dev/null
  cat /app/tmp/skill_out/${s//-/_}.ex
  ls /app/tmp/perf_out/${s//-/_}_*.ex 2>/dev/null
done

# 3. 批量编辑实装（建议用多窗口/IDE 并行）
# 填入：query_action, valid_learn, valid_enable, valid_prepare, perform_action_file, prepared gates

# 4. 批量编译+测试
cd /app && MIX_ENV=test mix compile
MIX_ENV=test mix test test/kantele/combat/ --max-failures 1

# 5. 批量提交
git add lib/kantele/combat/skills/{huashan_jian,huashan_quan,...}.ex
git commit -m "feat(skill): implement huashan sect skills (7 skills, real logic from .c)"
```

---

## 关键依赖：先跑通 perform 抽取器（立即执行）

```bash
cd /app

# 方案 A：环境变量触发
MIX_ENV=test RUN_EXTRACTOR=1 elixir scripts/translate_perform.exs

# 方案 B：手动调用（若方案 A 失败）
elixir -e "
  KUNGFU_SRC = '/app/kungfu_source/kungfu/skill'
  KUNGFU_OUT = '/tmp/perf_out'
  Code.require_file('scripts/translate_perform.exs')
  Scripts.TranslatePerform.run(KUNGFU_SRC, KUNGFU_OUT)
"

# 验收
ls /tmp/perf_out | wc -l  # 期望 ~430
head -100 /tmp/perf_out/xianglong_zhang_fei.ex  # 抽样检查结构
```

---

## 里程碑检查点

| 周末 | 必达指标 | 提交数预估 |
|------|----------|------------|
| Week 1 | Phase 0+1 全绿，force*/taiji*/liuxi*/基础武器 真实可战斗 | 4 |
| Week 2 | 华山/武当/少林/逍遥/峨眉/丐帮/星宿/古墓/全真/五岳 完成 | 10 |
| Week 3 | 吸功/毒/暗器/轻功/医疗/琴棋/杂项 特殊机制跑通 | 8 |
| Week 4 | 长尾 200 个分批完成 | 10 |
| Week 5 | `list_pending() == 0` 且全量测试 0 failure | 1 |
| Week 6 | 性能基线、伤害对齐报告出具 | - |

---

## 风险缓解

| 风险 | 对策 |
|------|------|
| perform 抽取器跑不通 | 先手写高频 perform（powerup, shield, heal, suck, sangong, roar, shot, dispel），再补长尾 |
| 伤害公式难对齐 | 建立 `DamageCalculator` 共享模块，统一公式参数化，便于回归测试 |
| 门槛判定不一致 | 提取 `SkillGate` 行为模式（level_gate, neili_gate, mapped_gate, prepared_gate），统一 DSL |
| 测试覆盖不足 | 每批次同步在 `test/kantele/combat/<sect>_test.exs` 加 2-3 个集成测试 |
| 并行冲突 | 门派间 perform 命名空间隔离（如 `Huashan.Jian.Fei` vs `Wudang.Jian.Fei`） |

---

## 起手式（现在开始）

1. **修复并运行 perform 抽取器** → 产出 `/tmp/perf_out/`
2. **补全缺失 perform 到 `lib/kantele/combat/skills/performs/`**
3. **Phase 1A：Force 系列 11 个** → 验证流程跑通
4. **Phase 1B-D：按批次推进**