defmodule Kantele.Combat.SkillsValidLearnBatch7Test do
  @moduledoc """
  F4 valid_learn 长尾补全——批次7：**personality（人格门）建模后的全量回填**。

  建模决策（本批前置）：LPC `me->query("character")` 的规范落点是
  `meta.character`（`Kantele.Character.PlayerMeta` moduledoc 第 12 行明示「人格/天性
  （LPC `query("character")`，如 "光明磊落"；poison.c valid_learn 门槛；运行态，不落盘）」，
  参考实现 `skills/poison.ex` 读 `character.meta.character`）。批前 30 个技能文件误读
  `Map.get(meta, :personality)`（键名不存在 → 恒 nil，性格门从未生效），本批一并修正。

  LPC 里 `character` 的赋值点只有两处：`d/register/npc/{hua,li,lu,wei}.c`（NPC 注册）与
  `adm/daemons/updated.c:515`（**转世**设「国士无双」）。故未设（nil）等价 LPC 的 0：
  对**排除门**（`== X` 则拒）不拦；对**包含门**（`!= X && != Y` 则拒）拦。

  本批覆盖 19 个技能：

  1. **14 个降龙十八掌子招**（`xianglong-zhang` 的 14 个 `main_skill()` 子技，源里
     `valid_learn` 完全同构，仅自身 id 不同）：
     `xianglong-zhang>0` / 性格「阴险奸诈」/ `query_str`<36 / `query_con`<32 /
     `query_skill("force")`<300 / `max_neili`<3000 / `query_skill("strike",1)`<180 /
     `strike < 自身等级`。
  2. **lonely-sword**：`int`<34 / 性格「心狠手辣」/「阴险奸诈」/「光明磊落」/ `sword < 自身`。
     首门「须持剑」按本仓约定由 practice 流程把关，不写入 `valid_learn`。
  3. **4 个 DOOR_MISMATCH**（性格门回填；其中 daojian-guizhen / sanwu-shou / xixing-dafa
     各自有专属测试文件，本文件只覆盖原先无测试的 wudoumi-shengong）：
     - daojian-guizhen：性格须「光明磊落」或「国士无双」（**首门**）→ `skills_daojian_guizhen_test.exs`
     - sanwu-shou     ：性格须「心狠手辣」或「国士无双」（**首门**）→ `skills_sanwu_shou_test.exs`
     - xixing-dafa    ：性格为「光明磊落」则拒（**首门**）→ `skills_xixing_dafa_test.exs`
     - wudoumi-shengong：性格须「心狠手辣」或「国士无双」+ 绝招 `gui` 习得后的
       `unarmed >= 自身等级` 门（本文件覆盖）

  **注意派生属性取值**：`Stats.query_str` = `str + max(拳脚类技能)/10`，
  `Stats.query_con` = `con + force/10`，`Stats.query_int` = `int + literate/10`。
  测 str 门时必须让拳脚技能为 0，测 con 门时必须让 force 为 0，否则门槛被技能加成顶过。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @xianglong_subs [
    "diyang-chufan",
    "feilong-zaitian",
    "huoyue-zaiyuan",
    "jianlong-zaitian",
    "kanglong-youhui",
    "lishe-dachuan",
    "longzhan-yuye",
    "lvshuang-bingzhi",
    "miyun-buyu",
    "shicheng-liulong",
    "shuanglong-qushui",
    "sunze-youfu",
    "turu-qilai",
    "yuyue-yuyuan"
  ]

  @all_ids @xianglong_subs ++ ["lonely-sword", "wudoumi-shengong"]

  # 派生属性（str/int/dex/con/per）走 struct 字段；其余一律当作技能等级放 :skills。
  # 未显式给出的派生属性默认给 100（足够通过门槛），仅「目标门槛测试」会显式给低值。
  @stat_keys ["str", "int", "dex", "con", "per"]
  @stat_default 100

  defp stats(map) do
    provided = MapSet.new(for({k, _} <- map, k in @stat_keys, do: k))

    base =
      Enum.reduce(map, Stats.new(), fn
        {k, v}, acc when k in @stat_keys -> Map.put(acc, String.to_atom(k), v)
        {_k, _v}, acc -> acc
      end)

    base =
      Enum.reduce(@stat_keys, base, fn k, acc ->
        if MapSet.member?(provided, k), do: acc, else: Map.put(acc, String.to_atom(k), @stat_default)
      end)

    skills = Map.new(for({k, v} <- map, not (k in @stat_keys), do: {k, v}))
    Map.put(base, :skills, skills)
  end

  defp char(opts \\ []) do
    %{
      meta: %{
        vitals: %{max_neili: Keyword.get(opts, :max_neili, 20000)},
        character: Keyword.get(opts, :character)
      },
      marks: Keyword.get(opts, :marks, %{})
    }
  end

  defp learn(id, stats, character), do: Skills.get(id).valid_learn(stats, character)

  defp assert_error(id, stats, character, fragment) do
    assert {:error, message} = learn(id, stats, character)
    assert message =~ fragment
  end

  # 14 个降龙子招「全达标」的一套 stats/char（自身等级 100）
  defp xianglong_ok(id) do
    {stats(%{"str" => 40, "con" => 40, "force" => 600, "strike" => 200, id => 100}),
     char(max_neili: 20000)}
  end

  # 五斗米神功「全达标」：con 30 / force 100 / unarmed 100 / max_neili 1000 / 自身 50
  defp wudoumi_ok,
    do: stats(%{"con" => 30, "force" => 100, "unarmed" => 100, "wudoumi-shengong" => 50})

  # ---- 注册健全性 ----
  test "本批 16 个技能均已在 Skills 注册且导出 valid_learn/2" do
    for id <- @all_ids do
      assert Skills.get(id) != nil, "未注册: #{id}"
      assert function_exported?(Skills.get(id), :valid_learn, 2), "缺 valid_learn/2: #{id}"
    end
  end

  # ==========================================================================
  # 1. 14 个降龙十八掌子招（同构门槛，逐条按场景遍历 14 个 id）
  # ==========================================================================

  describe "降龙十八掌 14 子招：全部门槛满足" do
    test "→ :ok" do
      for id <- @xianglong_subs do
        {stats, character} = xianglong_ok(id)
        assert :ok = learn(id, stats, character), "#{id} 应放行"
      end
    end
  end

  describe "降龙十八掌 14 子招：xianglong-zhang > 0（已学全十八掌）" do
    test "→ 拒「你已经学全十八掌了」" do
      for id <- @xianglong_subs do
        {stats, character} = xianglong_ok(id)
        stats = %{stats | skills: Map.put(stats.skills, "xianglong-zhang", 1)}
        assert_error(id, stats, character, "你已经学全十八掌了，不必再单独学习。")
      end
    end
  end

  describe "降龙十八掌 14 子招：性格「阴险奸诈」" do
    test "→ 拒「这武功难练得紧」" do
      for id <- @xianglong_subs do
        {stats, _} = xianglong_ok(id)
        assert_error(id, stats, char(character: "阴险奸诈"), "你心中暗想：这武功难练得紧，学它做甚？")
      end
    end
  end

  describe "降龙十八掌 14 子招：query_str < 36" do
    test "→ 拒「先天膂力孱弱」（拳脚技能为 0，避免 query_str 的 max(拳脚)/10 加成）" do
      for id <- @xianglong_subs do
        assert_error(
          id,
          stats(%{"str" => 20, "con" => 40, "force" => 600, "strike" => 0, id => 100}),
          char(),
          "你的先天膂力孱弱，难以修炼降龙十八掌。"
        )
      end
    end
  end

  describe "降龙十八掌 14 子招：query_con < 32" do
    test "→ 拒「先天根骨孱弱」（force 为 0，避免 query_con 的 force/10 加成）" do
      for id <- @xianglong_subs do
        assert_error(
          id,
          stats(%{"str" => 36, "con" => 20, "force" => 0, "strike" => 0, id => 100}),
          char(),
          "你的先天根骨孱弱，难以修炼降龙十八掌。"
        )
      end
    end
  end

  describe "降龙十八掌 14 子招：query_skill(\"force\") < 300" do
    test "→ 拒「内功火候不够」（有效等级 = force/2）" do
      for id <- @xianglong_subs do
        assert_error(
          id,
          stats(%{"str" => 36, "con" => 32, "force" => 0, "strike" => 0, id => 100}),
          char(),
          "你的内功火候不够，难以修炼降龙十八掌。"
        )
      end
    end
  end

  describe "降龙十八掌 14 子招：max_neili < 3000" do
    test "→ 拒「内力修为不足」" do
      for id <- @xianglong_subs do
        {stats, _} = xianglong_ok(id)
        assert_error(id, stats, char(max_neili: 2999), "你的内力修为不足，难以修炼降龙十八掌。")
      end
    end
  end

  describe "降龙十八掌 14 子招：query_skill(\"strike\", 1) < 180" do
    test "→ 拒「基本掌法火候不够」" do
      for id <- @xianglong_subs do
        assert_error(
          id,
          stats(%{"str" => 40, "con" => 40, "force" => 600, "strike" => 179, id => 100}),
          char(),
          "你的基本掌法火候不够，难以修炼降龙十八掌。"
        )
      end
    end
  end

  describe "降龙十八掌 14 子招：strike < 自身等级" do
    test "→ 拒「基本掌法水平有限」" do
      for id <- @xianglong_subs do
        assert_error(
          id,
          stats(%{"str" => 40, "con" => 40, "force" => 600, "strike" => 200, id => 250}),
          char(),
          "你的基本掌法水平有限，无法领会更高深的降龙十八掌。"
        )
      end
    end
  end

  describe "降龙十八掌 14 子招：门槛短路顺序" do
    test "性格门优先于属性门（性格阴险奸诈 + str 不足 → 报性格）" do
      for id <- @xianglong_subs do
        assert_error(
          id,
          stats(%{"str" => 10, "con" => 10, "force" => 0, "strike" => 0, id => 0}),
          char(character: "阴险奸诈"),
          "你心中暗想：这武功难练得紧，学它做甚？"
        )
      end
    end

    test "xianglong-zhang 门优先于性格门（已学全十八掌 + 性格阴险奸诈 → 报已学全）" do
      for id <- @xianglong_subs do
        {stats, _} = xianglong_ok(id)
        stats = %{stats | skills: Map.put(stats.skills, "xianglong-zhang", 10)}

        assert_error(
          id,
          stats,
          char(character: "阴险奸诈"),
          "你已经学全十八掌了，不必再单独学习。"
        )
      end
    end
  end

  # ==========================================================================
  # 2. lonely-sword
  # ==========================================================================

  describe "lonely-sword（独孤九剑）" do
    test "全部门槛满足 → :ok（须持剑门由 practice 流程把关，不在此）" do
      assert :ok =
               learn(
                 "lonely-sword",
                 stats(%{"int" => 40, "sword" => 200, "lonely-sword" => 100}),
                 char()
               )
    end

    test "int < 34 被拒（天资不足）" do
      assert_error(
        "lonely-sword",
        stats(%{"int" => 33, "sword" => 200, "lonely-sword" => 100}),
        char(),
        "你的天资不足，无法理解独孤九剑的剑意。"
      )
    end

    test "int 门优先于性格门（int 33 + 性格心狠手辣 → 报天资）" do
      assert_error(
        "lonely-sword",
        stats(%{"int" => 33, "sword" => 200, "lonely-sword" => 100}),
        char(character: "心狠手辣"),
        "你的天资不足，无法理解独孤九剑的剑意。"
      )
    end

    test "性格「心狠手辣」被拒" do
      assert_error(
        "lonely-sword",
        stats(%{"int" => 40, "sword" => 200, "lonely-sword" => 100}),
        char(character: "心狠手辣"),
        "你一心想杀尽敌人，没能理解独孤九剑的的真正含义。"
      )
    end

    test "性格「阴险奸诈」被拒" do
      assert_error(
        "lonely-sword",
        stats(%{"int" => 40, "sword" => 200, "lonely-sword" => 100}),
        char(character: "阴险奸诈"),
        "你一心想怎么学好剑法去害人，结果没能理解独孤九剑。"
      )
    end

    test "性格「光明磊落」被拒" do
      assert_error(
        "lonely-sword",
        stats(%{"int" => 40, "sword" => 200, "lonely-sword" => 100}),
        char(character: "光明磊落"),
        "你心中暗道：什么独孤九剑，乱七八糟的，没有半点气势。"
      )
    end

    test "性格「国士无双」/「狡黠多变」/ 未设 → 通过性格门" do
      for p <- ["国士无双", "狡黠多变", nil] do
        assert :ok =
                 learn(
                   "lonely-sword",
                   stats(%{"int" => 40, "sword" => 200, "lonely-sword" => 100}),
                   char(character: p)
                 ),
               "性格 #{inspect(p)} 应通过"
      end
    end

    test "sword < 自身等级被拒（基本剑法造诣有限）" do
      assert_error(
        "lonely-sword",
        stats(%{"int" => 40, "sword" => 100, "lonely-sword" => 200}),
        char(),
        "你的基本剑法造诣有限，无法理解更高深的独孤九剑。"
      )
    end
  end

  # ==========================================================================
  # 3. wudoumi-shengong（五斗米神功）—— DOOR_MISMATCH，性格门 + 绝招 gui 后的拳脚门
  # ==========================================================================

  describe "wudoumi-shengong（五斗米神功）" do
    test "全部门槛满足（性格心狠手辣）→ :ok" do
      assert :ok = learn("wudoumi-shengong", wudoumi_ok(), char(max_neili: 1000, character: "心狠手辣"))
    end

    test "性格「国士无双」（转世）→ :ok" do
      assert :ok = learn("wudoumi-shengong", wudoumi_ok(), char(max_neili: 1000, character: "国士无双"))
    end

    test "性格「光明磊落」被拒（损人不利己）" do
      assert_error(
        "wudoumi-shengong",
        wudoumi_ok(),
        char(max_neili: 1000, character: "光明磊落"),
        "你暗想这五斗米神功损人不利己，修来何用？"
      )
    end

    test "性格未设（nil）按 LPC「未设即 0」拒" do
      assert_error(
        "wudoumi-shengong",
        wudoumi_ok(),
        char(max_neili: 1000),
        "你暗想这五斗米神功损人不利己，修来何用？"
      )
    end

    test "性格门优先于 con 门（性格不合格 + con 不足 → 报性格）" do
      assert_error(
        "wudoumi-shengong",
        stats(%{"con" => 10, "force" => 100, "unarmed" => 100, "wudoumi-shengong" => 50}),
        char(max_neili: 1000, character: "阴险奸诈"),
        "你暗想这五斗米神功损人不利己，修来何用？"
      )
    end

    test "con < 24 被拒（丹田搅疼）" do
      assert_error(
        "wudoumi-shengong",
        stats(%{"con" => 23, "force" => 100, "unarmed" => 100, "wudoumi-shengong" => 50}),
        char(max_neili: 1000, character: "心狠手辣"),
        "你按照法门运转了下内息，忽然只觉丹田一阵搅疼。"
      )
    end

    test "force < 50 被拒（基本内功火候不足）" do
      assert_error(
        "wudoumi-shengong",
        stats(%{"con" => 30, "force" => 49, "unarmed" => 100, "wudoumi-shengong" => 50}),
        char(max_neili: 1000, character: "心狠手辣"),
        "你的基本内功火候不足，不能学五斗米神功。"
      )
    end

    test "unarmed < 50 被拒（基本拳脚火候不足）" do
      assert_error(
        "wudoumi-shengong",
        stats(%{"con" => 30, "force" => 100, "unarmed" => 49, "wudoumi-shengong" => 50}),
        char(max_neili: 1000, character: "心狠手辣"),
        "你的基本拳脚火候不足，不能学五斗米神功。"
      )
    end

    test "max_neili < 500 被拒（内力修为不足）" do
      assert_error(
        "wudoumi-shengong",
        wudoumi_ok(),
        char(max_neili: 499, character: "心狠手辣"),
        "你的内力修为不足，不能学五斗米神功。"
      )
    end

    test "force < 自身等级被拒（基本内功水平不够）" do
      assert_error(
        "wudoumi-shengong",
        stats(%{"con" => 30, "force" => 100, "unarmed" => 100, "wudoumi-shengong" => 150}),
        char(max_neili: 1000, character: "心狠手辣"),
        "你的基本内功水平不够，难以锻炼更深厚的五斗米神功。"
      )
    end

    test "绝招 gui 已习得时追加「unarmed >= 自身等级」门" do
      # unarmed 50 / 自身 60 / force 100：前一道 force>=lvl 已过，gui 门触发
      assert_error(
        "wudoumi-shengong",
        stats(%{"con" => 30, "force" => 100, "unarmed" => 50, "wudoumi-shengong" => 60}),
        char(
          max_neili: 1000,
          character: "心狠手辣",
          marks: %{"can_perform/wudoumi-shengong/gui" => 1}
        ),
        "你的基本拳脚水平不够，难以锻炼更深厚的五斗米神功。"
      )
    end

    test "未习得绝招 gui 时同一套属性放行（该门只在 mark 存在时生效）" do
      assert :ok =
               learn(
                 "wudoumi-shengong",
                 stats(%{"con" => 30, "force" => 100, "unarmed" => 50, "wudoumi-shengong" => 60}),
                 char(max_neili: 1000, character: "心狠手辣")
               )
    end
  end
end
