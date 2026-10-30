defmodule Kantele.Combat.SkillsBanruoZhangTest do
  @moduledoc """
  般若掌招式表迁移（C 相位，banruo-zhang 真缺口补齐）。

  LPC `kungfu/skill/banruo-zhang.c` 有 10 式静态招式（lvl 0/10/20/40/70/90/110/130/140/150），
  `translate_skill.exs` 只认 `mapping *action`，本应机械产出；实际 Elixir 侧
  `query_action` 返回 `%{}`，出招无描述无伤害。本测试锁定：

  1. 表长 10 式，每式 `lvl` 与 LPC 一致；
  2. `query_action/2` 按 `level > lvl` 过滤（LPC `for (i = sizeof(action); i > 0; i--)`）；
  3. `query_action/3` 与 /2 行为一致（般若掌无动态表，忽略 attacker）；
  4. 极低等级回落到第一式（LPC count 0 → `List.first`）；
  5. `valid_enable`：strike/parry 可，其余不可；
  6. `query_skill_name` 遍历整表（LPC `level >= lvl`）；
  7. 已进 `Skills` 注册表，`Engine.select_action` 端到端可出招。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.BanruoZhang
  alias Kantele.Combat.Engine

  defp rng, do: fn _ -> 1 end  # NewRandom 取最靠前可用招式（索引 0）

  @expected_lvls [0, 10, 20, 40, 70, 90, 110, 130, 140, 150]
  @expected_names [
    "横空出世", "长虹贯日", "云断秦岭", "铁索拦江", "狂风卷地",
    "怀中抱月", "高山流水", "摘星换斗", "翻江搅海", "金刚伏魔"
  ]
  @expected_damage_types [
    "瘀伤", "瘀伤", "劈伤", "瘀伤", "瘀伤",
    "瘀伤", "瘀伤", "劈伤", "瘀伤", "瘀伤"
  ]

  describe "招式表长度与 LPC 对照（10 式）" do
    test "表长 10 式" do
      assert length(BanruoZhang.actions()) == 10
    end

    test "每式 lvl 与 LPC 一致" do
      assert Enum.map(BanruoZhang.actions(), & &1["lvl"]) == @expected_lvls
    end

    test "每式 skill_name 与 LPC 一致" do
      assert Enum.map(BanruoZhang.actions(), & &1["skill_name"]) == @expected_names
    end

    test "每式 damage_type 与 LPC 一致" do
      assert Enum.map(BanruoZhang.actions(), & &1["damage_type"]) == @expected_damage_types
    end
  end

  describe "query_action/2 按等级加权选招（LPC `level > lvl` 严格过滤）" do
    test "level 0 无可选招式，回落第一式（LPC count 0 → List.first）" do
      for _ <- 1..20 do
        assert BanruoZhang.query_action(0, rng())["skill_name"] == "横空出世"
      end
    end

    test "level 10 仅 lvl 0 可选（strict >：level 10 不大于 lvl 10）" do
      assert BanruoZhang.query_action(10, rng())["skill_name"] == "横空出世"
    end

    test "level 11 lvl 10 已入表但 NewRandom(2) 恒取索引 0（与 LPC `random(1)` 一致）" do
      # 仅 2 式可用时 NewRandom(2, _)：sum = 1，random(1) 恒 0 → 恒返回索引 0，
      # 即第一式「横空出世」。第 2 式「长虹贯日」的可用性已由
      # query_skill_name/11 == "长虹贯日" 覆盖，此处不再断言选中它。
      assert BanruoZhang.query_action(11, rng())["skill_name"] == "横空出世"
    end

    test "返回动作的 lvl 始终严格小于 level（LPC 边界；level 0 回落除外）" do
      Enum.each([11, 70, 71, 150, 151, 300], fn level ->
        action = BanruoZhang.query_action(level, rng())
        assert Map.get(action, "lvl", 0) < level
      end)
    end

    test "高等级可到达表尾招式（rng 取最大，NewRandom 取最后一可用式）" do
      max_rng = fn n -> n end
      # level 141：lvl 0~140 可选（9 式，lvl 150 不可），最大可选「翻江搅海」
      assert BanruoZhang.query_action(141, max_rng)["skill_name"] == "翻江搅海"
      # level 151 / 300：全部 10 式可选，最大可选「金刚伏魔」
      assert BanruoZhang.query_action(151, max_rng)["skill_name"] == "金刚伏魔"
      assert BanruoZhang.query_action(300, max_rng)["skill_name"] == "金刚伏魔"
    end

    test "返回的动作字段非空（出招有描述）" do
      action = BanruoZhang.query_action(300, rng())
      assert is_binary(action["action"]) and action["action"] != ""
    end
  end

  describe "query_action/3 与 /2 行为一致（忽略 attacker）" do
    test "带角色快照时不改变选招结果" do
      attacker = %Fighter{skills: %{"banruo-zhang" => 300}, weapon_name: nil}

      for _ <- 1..20 do
        assert BanruoZhang.query_action(300, rng(), attacker) ==
               BanruoZhang.query_action(300, rng())
      end
    end

    test "attacker 为 nil 也不崩溃（宏回落路径）" do
      assert is_map(BanruoZhang.query_action(300, rng(), nil))
    end
  end

  describe "极低等级回落（LPC count 0 → List.first）" do
    test "level 0 时取第一式，不崩溃" do
      assert BanruoZhang.query_action(0, rng())["skill_name"] == "横空出世"
    end
  end

  describe "valid_enable（strike / parry 可，其余不可）" do
    test "strike / parry 为 true" do
      assert BanruoZhang.valid_enable("strike")
      assert BanruoZhang.valid_enable("parry")
    end

    test "其余 usage 为 false" do
      refute BanruoZhang.valid_enable("sword")
      refute BanruoZhang.valid_enable("force")
      refute BanruoZhang.valid_enable("dodge")
    end
  end

  describe "query_skill_name 遍历整表（LPC `level >= lvl`）" do
    test "lvl 边界" do
      assert BanruoZhang.query_skill_name(0) == "横空出世"
      assert BanruoZhang.query_skill_name(9) == "横空出世"
      assert BanruoZhang.query_skill_name(10) == "长虹贯日"
      assert BanruoZhang.query_skill_name(19) == "长虹贯日"
      assert BanruoZhang.query_skill_name(20) == "云断秦岭"
      assert BanruoZhang.query_skill_name(39) == "云断秦岭"
      assert BanruoZhang.query_skill_name(40) == "铁索拦江"
      assert BanruoZhang.query_skill_name(69) == "铁索拦江"
      assert BanruoZhang.query_skill_name(70) == "狂风卷地"
      assert BanruoZhang.query_skill_name(89) == "狂风卷地"
      assert BanruoZhang.query_skill_name(90) == "怀中抱月"
      assert BanruoZhang.query_skill_name(109) == "怀中抱月"
      assert BanruoZhang.query_skill_name(110) == "高山流水"
      assert BanruoZhang.query_skill_name(129) == "高山流水"
      assert BanruoZhang.query_skill_name(130) == "摘星换斗"
      assert BanruoZhang.query_skill_name(139) == "摘星换斗"
      assert BanruoZhang.query_skill_name(140) == "翻江搅海"
      assert BanruoZhang.query_skill_name(149) == "翻江搅海"
      assert BanruoZhang.query_skill_name(150) == "金刚伏魔"
      assert BanruoZhang.query_skill_name(300) == "金刚伏魔"
      assert BanruoZhang.query_skill_name(-1) == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("banruo-zhang") == BanruoZhang
    end
  end

  describe "Engine.select_action/1 端到端" do
    test "能选出般若掌招式" do
      fighter = %Fighter{
        attack_skill: "strike",
        mapped: %{"strike" => "banruo-zhang"},
        skills: %{"banruo-zhang" => 300},
        weapon_name: nil
      }

      for _ <- 1..30 do
        action = Engine.select_action(fighter)
        assert action["skill_name"] in @expected_names
      end
    end
  end
end
