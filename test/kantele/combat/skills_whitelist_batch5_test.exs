defmodule Kantele.Combat.SkillsWhitelistBatch5Test do
  @moduledoc """
  白名单补全 batch5：4 个攻击类特技的招式表迁移（动态值 + 双表分派）。

  对应 LPC 源：

    - `qingyun-bian.c`  —— 10 式，`force = max_neili/4`、`damage = shen/1500`（动态）
    - `qixian-wuxingjian.c` —— `action_unarmed`(7) + `action_sword`(7)，按是否持械分表；
      空手表用 `level >= lvl`、持械表用 `level > lvl`（源内不对称）
    - `tanzhi-shentong.c` —— 6 式静态 + 「极意」；选招是**均匀随机且不过滤等级**
    - `yiyang-zhi.c` —— `action_finger`(12 + 极意) + `action_staff`(5)，同样 `>=` / `>` 不对称

  本测试锁定：

  1. 注册 + `valid_enable` 用法集合；
  2. 招式表长度与 `lvl` 阶梯；
  3. `query_action/3` 的持械分派与 `>=` / `>` 差异；
  4. 动态值注入（含 `Fighter.shen` 新增字段）；
  5. `valid_learn/2` 逐条门槛。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.{QingyunBian, QixianWuxingjian, TanzhiShentong, YiyangZhi}

  # rng 约定：返回 1..n。`rng_max` 取 lpc_random 的最大值，`rng_min` 取 0。
  defp rng_max, do: fn n -> n end
  defp rng_min, do: fn _n -> 1 end

  defp unarmed(extra \\ %{}),
    do: struct(Fighter, Map.merge(%{weapon_name: nil, skills: %{}}, extra))

  defp armed(name \\ "长剑", extra \\ %{}),
    do: struct(Fighter, Map.merge(%{weapon_name: name, skills: %{}}, extra))

  defp stats(skills, extra \\ %{}), do: Map.merge(%{skills: skills}, extra)
  defp char(max_neili), do: %{meta: %{vitals: %{max_neili: max_neili}}}

  describe "注册与用法集合" do
    test "4 个技能均已注册" do
      for id <- ~w(qingyun-bian qixian-wuxingjian tanzhi-shentong yiyang-zhi) do
        assert Skills.get(id) != nil, "#{id} 应已注册"
      end
    end

    test "valid_enable 用法集合与 LPC 一致" do
      assert QingyunBian.valid_enable("whip")
      assert QingyunBian.valid_enable("parry")
      refute QingyunBian.valid_enable("sword")

      for u <- ~w(unarmed sword parry tanqin-jifa), do: assert(QixianWuxingjian.valid_enable(u))
      refute QixianWuxingjian.valid_enable("blade")

      for u <- ~w(finger parry throwing), do: assert(TanzhiShentong.valid_enable(u))
      refute TanzhiShentong.valid_enable("sword")

      for u <- ~w(finger parry staff), do: assert(YiyangZhi.valid_enable(u))
      refute YiyangZhi.valid_enable("sword")
    end
  end

  describe "qingyun-bian 招式表（10 式，全 lvl 0）" do
    test "表长 10 且 lvl 全为 0（源无 lvl 字段）" do
      assert length(QingyunBian.actions()) == 10
      assert Enum.all?(QingyunBian.actions(), &(&1["lvl"] == 0))
    end

    test "招式名顺序与源一致" do
      names = Enum.map(QingyunBian.actions(), & &1["skill_name"])
      assert names == ~w(聚火 起光 招雨 动雷 移电 剪虹 止风 断云 遮月 掩日)
    end

    test "第 6 式「剪虹」源缺 damage_type（保真不补）" do
      action = Enum.at(QingyunBian.actions(), 5)
      assert action["skill_name"] == "剪虹"
      refute Map.has_key?(action, "damage_type")
    end

    test "query_action/3 注入 force = max_neili/4、damage = shen/1500" do
      attacker = unarmed(%{max_neili: 2000, shen: 30_000})
      action = QingyunBian.query_action(100, rng_max(), attacker)

      assert action["force"] == 500
      assert action["damage"] == 20
    end

    test "shen 为负时 damage 为负（C 整数除法向零截断）" do
      attacker = unarmed(%{max_neili: 400, shen: -3000})
      action = QingyunBian.query_action(100, rng_max(), attacker)

      assert action["force"] == 100
      assert action["damage"] == -2
    end

    test "高 rng 取最后一式「掩日」" do
      action = QingyunBian.query_action(100, rng_max(), unarmed(%{max_neili: 800}))
      assert action["skill_name"] == "掩日"
    end

    test "无出招者上下文时动态字段为 0（不崩）" do
      action = QingyunBian.query_action(100, rng_min())
      assert action["force"] == 0
      assert action["damage"] == 0
    end
  end

  describe "qingyun-bian valid_learn/2" do
    defp qy_stats(shaolin, lvl, force \\ 200),
      do: stats(%{"shaolin-xinfa" => shaolin, "qingyun-bian" => lvl, "force" => force})

    test "max_neili < 500 被拒" do
      assert QingyunBian.valid_learn(qy_stats(80, 0), char(499)) ==
               {:error, "你的内力不足，没有办法练青云鞭法, 多练些内力再来吧。\n"}
    end

    test "shaolin-xinfa < 80 被拒" do
      assert QingyunBian.valid_learn(qy_stats(79, 0), char(500)) ==
               {:error, "你的少林心法火候太浅。\n"}
    end

    test "lvl <= 10 不查正气" do
      assert QingyunBian.valid_learn(qy_stats(80, 10), char(500)) == :ok
    end

    test "10 < lvl <= 150 且 shen < 20 被拒" do
      character = %{meta: %{vitals: %{max_neili: 500}, stats: %{shen: 19}}}

      assert QingyunBian.valid_learn(qy_stats(80, 11), character) ==
               {:error, "你的正气太低了。\n"}
    end

    test "10 < lvl <= 150 且 shen >= 20 放行" do
      character = %{meta: %{vitals: %{max_neili: 500}, stats: %{shen: 20}}}
      assert QingyunBian.valid_learn(qy_stats(80, 11), character) == :ok
    end

    test "lvl > 150 改用 11100 + (lvl - 100) * 1000 阈值" do
      # lvl 151 -> 需要 shen >= 11100 + 51 * 1000 = 62100
      low = %{meta: %{vitals: %{max_neili: 500}, stats: %{shen: 62_099}}}

      assert QingyunBian.valid_learn(qy_stats(80, 151), low) ==
               {:error, "你的正气太低了。\n"}

      ok = %{meta: %{vitals: %{max_neili: 500}, stats: %{shen: 62_100}}}
      assert QingyunBian.valid_learn(qy_stats(80, 151), ok) == :ok
    end
  end

  describe "qixian-wuxingjian 招式表（双表各 7 式）" do
    test "表长 7 + 7，lvl 阶梯一致" do
      assert length(QixianWuxingjian.actions()) == 7
      assert length(QixianWuxingjian.sword_actions()) == 7

      lvls = [0, 40, 80, 120, 160, 200, 240]
      assert Enum.map(QixianWuxingjian.actions(), & &1["lvl"]) == lvls
      assert Enum.map(QixianWuxingjian.sword_actions(), & &1["lvl"]) == lvls
    end

    test "持械表源无 skill_name（保真不补）" do
      refute Enum.any?(QixianWuxingjian.sword_actions(), &Map.has_key?(&1, "skill_name"))
    end

    test "空手走空手表、持械走持械表（用 force 区分：350 vs 140）" do
      assert QixianWuxingjian.query_action(0, rng_min(), unarmed())["force"] == 350
      assert QixianWuxingjian.query_action(0, rng_min(), armed())["force"] == 140
    end

    test "空手表用 `level >= lvl`：80 级可抽到 lvl 80 的「天河紫气」" do
      # count = 3（lvl 0/40/80），rng_max -> 索引 2
      action = QixianWuxingjian.query_action(80, rng_max(), unarmed())
      assert action["skill_name"] == "天河紫气"
      assert action["lvl"] == 80
    end

    test "持械表用 `level > lvl`：80 级抽不到 lvl 80 的招式（count 只有 2，取首式）" do
      # `>` 语义下 80 > 80 不成立 -> count = 2（lvl 0/40），NewRandom(2) 恒取索引 0
      action = QixianWuxingjian.query_action(80, rng_max(), armed())
      assert action["lvl"] == 0
    end

    test "0 级持械时持械表无可用招式，回落首式（LPC 返回 0 无招，引擎需具体招式以免崩）" do
      action = QixianWuxingjian.query_action(0, rng_min(), armed())
      assert action["lvl"] == 0
      assert action["force"] == 140
    end
  end

  describe "qixian-wuxingjian valid_learn/2" do
    defp qx_stats(force, unarmed, sword, tanqin, lvl),
      do: stats(%{"force" => force, "unarmed" => unarmed, "sword" => sword, "tanqin-jifa" => tanqin, "qixian-wuxingjian" => lvl})

    test "force < 270 被拒" do
      assert QixianWuxingjian.valid_learn(qx_stats(269, 200, 200, 200, 0), char(3000)) ==
               {:error, "你的内功火候不够，无法修炼七弦无形剑。\n"}
    end

    test "max_neili < 3000 被拒" do
      assert QixianWuxingjian.valid_learn(qx_stats(270, 200, 200, 200, 0), char(2999)) ==
               {:error, "你的内力太弱，无法修炼七弦无形剑。\n"}
    end

    test "unarmed < 180 被拒" do
      assert QixianWuxingjian.valid_learn(qx_stats(270, 179, 200, 200, 0), char(3000)) ==
               {:error, "你的基本拳脚火候不够，无法修炼七弦无形剑。\n"}
    end

    test "sword < 180 被拒" do
      assert QixianWuxingjian.valid_learn(qx_stats(270, 200, 179, 200, 0), char(3000)) ==
               {:error, "你的基本剑法火候不够，无法修炼七弦无形剑。\n"}
    end

    test "tanqin-jifa < 100 被拒" do
      assert QixianWuxingjian.valid_learn(qx_stats(270, 200, 200, 99, 0), char(3000)) ==
               {:error, "弹琴技法水平有限，无法修炼七弦无形剑。\n"}
    end

    test "本门等级不得高于 force / unarmed / sword" do
      assert QixianWuxingjian.valid_learn(qx_stats(270, 200, 200, 200, 271), char(3000)) ==
               {:error, "你的内功修为有限，无法领会更高深的七弦无形剑。\n"}

      assert QixianWuxingjian.valid_learn(qx_stats(300, 200, 300, 200, 201), char(3000)) ==
               {:error, "你的基本拳脚水平有限，无法领会更高深的七弦无形剑。\n"}

      assert QixianWuxingjian.valid_learn(qx_stats(300, 300, 200, 200, 201), char(3000)) ==
               {:error, "你的基本剑法水平有限，无法领会更高深的七弦无形剑。\n"}
    end

    test "tanqin-jifa 只需 >= 本门/3" do
      # 本门 350 -> div(350,3) = 116，故 tanqin-jifa 116 恰好放行、115 被拒
      # （两者都已过前面的 tanqin-jifa >= 100 硬门槛）
      assert QixianWuxingjian.valid_learn(qx_stats(400, 400, 400, 115, 350), char(3000)) ==
               {:error, "你对琴学的了解不够深入，无法领会更高深的七弦无形剑。\n"}

      assert QixianWuxingjian.valid_learn(qx_stats(400, 400, 400, 116, 350), char(3000)) == :ok
    end
  end

  describe "tanzhi-shentong 招式表（6 式 + 极意）" do
    test "静态 6 式 + 极意（lvl 200）" do
      assert length(TanzhiShentong.actions()) == 6
      assert TanzhiShentong.ultimate()["lvl"] == 200
      assert TanzhiShentong.ultimate()["skill_name"] == "极意"
    end

    test "选招均匀随机、不过滤等级：0 级也能抽到「极意」" do
      action = TanzhiShentong.query_action(0, rng_max(), unarmed())
      assert action["skill_name"] == "极意"
    end

    test "极意动态五项按出招者技能生成" do
      attacker = unarmed(%{skills: %{"force" => 200, "finger" => 200, "dodge" => 60, "parry" => 60}})
      action = TanzhiShentong.query_action(0, rng_max(), attacker)

      # rng_max 使每个 lpc_random 取上界
      assert action["force"] == div(200, 2) + 199
      assert action["attack"] == div(200, 4) + (div(200, 2) - 1)
      assert action["dodge"] == div(60, 6) + (div(200, 3) - 1)
      assert action["parry"] == div(60, 6) + (div(60, 3) - 1)
      assert action["damage"] == div(200, 4) + (div(200, 2) - 1)
    end
  end

  describe "tanzhi-shentong valid_learn/2" do
    defp tz_stats(dex, force, finger, lvl),
      do: stats(%{"force" => force, "finger" => finger, "tanzhi-shentong" => lvl}, %{dex: dex})

    test "dex < 34 被拒（源 query(\"dex\") 裸属性）" do
      assert TanzhiShentong.valid_learn(tz_stats(33, 200, 200, 0), char(2000)) ==
               {:error, "你的先天身法不足，无法修炼弹指神通。\n"}
    end

    test "force < 150 被拒" do
      assert TanzhiShentong.valid_learn(tz_stats(34, 149, 200, 0), char(2000)) ==
               {:error, "你的内功火候不够，无法修炼弹指神通。\n"}
    end

    test "max_neili < 2000 被拒" do
      assert TanzhiShentong.valid_learn(tz_stats(34, 150, 200, 0), char(1999)) ==
               {:error, "你的内力修为太弱，无法修炼弹指神通。\n"}
    end

    test "finger < 150 被拒" do
      assert TanzhiShentong.valid_learn(tz_stats(34, 150, 149, 0), char(2000)) ==
               {:error, "你的基本指法火候不够，无法学弹指神通。\n"}
    end

    test "finger < 本门被拒" do
      assert TanzhiShentong.valid_learn(tz_stats(34, 150, 150, 151), char(2000)) ==
               {:error, "你的基本指法水平有限，无法领会更高深的弹指神通。\n"}
    end

    test "全满足放行" do
      assert TanzhiShentong.valid_learn(tz_stats(34, 150, 150, 150), char(2000)) == :ok
    end
  end

  describe "yiyang-zhi 招式表（12 + 极意 + 5 杖法）" do
    test "指法表 12 式 + 极意 lvl 300；杖法表 5 式" do
      assert length(YiyangZhi.actions()) == 12
      assert YiyangZhi.ultimate()["lvl"] == 300
      assert length(YiyangZhi.staff_actions()) == 5

      assert Enum.map(YiyangZhi.actions(), & &1["lvl"]) ==
               [0, 20, 40, 60, 80, 100, 120, 140, 160, 180, 200, 220]

      assert Enum.map(YiyangZhi.staff_actions(), & &1["lvl"]) == [0, 20, 40, 60, 80]
    end

    test "杖法表源无 skill_name / attack / parry（保真不补）" do
      refute Enum.any?(YiyangZhi.staff_actions(), &Map.has_key?(&1, "skill_name"))
      refute Enum.any?(YiyangZhi.staff_actions(), &Map.has_key?(&1, "attack"))
    end

    test "空手走指法表、持械走杖法表（force 区分：350 vs 100）" do
      assert YiyangZhi.query_action(0, rng_min(), unarmed())["force"] == 350
      assert YiyangZhi.query_action(0, rng_min(), armed())["force"] == 100
    end

    test "指法表用 `level >= lvl`：40 级可抽到 lvl 40 的「阳春暖融」" do
      action = YiyangZhi.query_action(40, rng_max(), unarmed())
      assert action["skill_name"] == "阳春暖融"
      assert action["lvl"] == 40
    end

    test "杖法表用 `level > lvl`：40 级抽不到 lvl 40 的招式（count 只有 2，取首式）" do
      # `>` 语义下 40 > 40 不成立 -> count = 2（lvl 0/20），NewRandom(2) 恒取索引 0
      action = YiyangZhi.query_action(40, rng_max(), armed())
      assert action["lvl"] == 0
    end

    test "0 级持械时杖法表无可用招式，回落首式（LPC 返回 0 无招，引擎需具体招式以免崩）" do
      action = YiyangZhi.query_action(0, rng_min(), armed())
      assert action["lvl"] == 0
      assert action["force"] == 100
    end

    test "指法表 300 级可抽到极意" do
      attacker = unarmed(%{skills: %{"force" => 300, "finger" => 300, "dodge" => 300, "parry" => 300}})
      action = YiyangZhi.query_action(300, rng_max(), attacker)
      assert action["skill_name"] == "极意"
      assert action["lvl"] == 300
    end
  end

  describe "yiyang-zhi valid_learn/2" do
    # 性别在 character.meta.env.gender（源 me->query("gender")）
    defp yy_stats(con, int, force, finger, lvl) do
      stats(%{"force" => force, "finger" => finger, "yiyang-zhi" => lvl}, %{con: con, int: int})
    end

    defp yy_char(gender, max_neili \\ 2000),
      do: %{meta: %{vitals: %{max_neili: max_neili}, env: %{gender: gender}}}

    defp male, do: yy_char("男性")

    test "非男性被拒" do
      assert YiyangZhi.valid_learn(yy_stats(40, 40, 300, 300, 0), yy_char("女性")) ==
               {:error, "一阳指乃是纯阳玄功，你如何可以修习？\n"}
    end

    test "con < 34 被拒（源 query(\"con\") 裸属性）" do
      assert YiyangZhi.valid_learn(yy_stats(33, 40, 300, 300, 0), male()) ==
               {:error, "你的先天根骨欠佳，无法修炼一阳指。\n"}
    end

    test "int < 32 被拒（源 query(\"int\") 裸属性）" do
      assert YiyangZhi.valid_learn(yy_stats(34, 31, 300, 300, 0), male()) ==
               {:error, "你的先天悟性不足，无法领会一阳指。\n"}
    end

    test "force < 240 被拒" do
      assert YiyangZhi.valid_learn(yy_stats(34, 32, 239, 300, 0), male()) ==
               {:error, "你的内功火候不够，无法学一阳指。\n"}
    end

    test "max_neili < 2000 被拒" do
      assert YiyangZhi.valid_learn(yy_stats(34, 32, 240, 300, 0), yy_char("男性", 1999)) ==
               {:error, "你的内力太弱，无法练一阳指。\n"}
    end

    test "finger < 150 被拒" do
      assert YiyangZhi.valid_learn(yy_stats(34, 32, 240, 149, 0), male()) ==
               {:error, "你的基本指法火候不够，无法学一阳指。\n"}
    end

    test "finger < 本门被拒" do
      assert YiyangZhi.valid_learn(yy_stats(34, 32, 240, 150, 151), male()) ==
               {:error, "你的基本指法水平有限，无法领会更高深的一阳指。\n"}
    end

    test "全满足放行" do
      assert YiyangZhi.valid_learn(yy_stats(34, 32, 240, 150, 150), male()) == :ok
    end
  end

  describe "Fighter.shen 快照字段" do
    test "defstruct 含 :shen，默认 0" do
      assert Fighter.new().shen == 0
    end
  end
end
