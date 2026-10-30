defmodule Kantele.Combat.SkillsLuohanQuanTest do
  @moduledoc """
  罗汉拳招式表迁移（C 相位，luohan-quan 真缺口补齐）。

  LPC `kungfu/skill/luohan-quan.c` 有 8 式静态招式（lvl 0/8/15/24/33/42/50/58），
  `translate_skill.exs` 只认 `mapping *action`，本应机械产出；实际 Elixir 侧
  `query_action` 返回 `%{}`，出招无描述无伤害。本测试锁定：

  1. 表长 8 式，每式 `lvl` 与 LPC 一致；
  2. `query_action/2` 按 `level > lvl` 过滤（LPC `for (i = sizeof(action); i > 0; i--)`）；
  3. `query_action/3` 与 /2 行为一致（罗汉拳无动态表，忽略 attacker）；
  4. 极低等级回落到第一式（LPC count 0 → `List.first`）；
  5. `valid_enable`：cuff/parry 可，其余不可；
  6. `query_skill_name` 遍历整表；
  7. 已进 `Skills` 注册表，`Engine.select_action` 端到端可出招。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.LuohanQuan
  alias Kantele.Combat.Engine

  defp rng, do: fn _ -> 1 end  # NewRandom 取最靠后可用招式

  @expected_lvls [0, 8, 15, 24, 33, 42, 50, 58]
  @expected_names [
    "黄莺落架", "丹凤朝阳", "洛钟东应", "偏花七星",
    "苦海回头", "挟山超海", "慑服外道", "三入地狱"
  ]

  describe "招式表长度与 LPC 对照（8 式）" do
    test "表长 8 式" do
      assert length(LuohanQuan.actions()) == 8
    end

    test "每式 lvl 与 LPC 一致" do
      assert Enum.map(LuohanQuan.actions(), & &1["lvl"]) == @expected_lvls
    end

    test "每式 skill_name 与 LPC 一致" do
      assert Enum.map(LuohanQuan.actions(), & &1["skill_name"]) == @expected_names
    end

    test "每式 damage_type 皆 瘀伤" do
      for a <- LuohanQuan.actions() do
        assert a["damage_type"] == "瘀伤"
      end
    end
  end

  describe "query_action/2 按等级加权选招（LPC `level > lvl` 严格过滤）" do
    test "level 0 无可选招式，回落第一式（LPC count 0 → List.first）" do
      for _ <- 1..20 do
        assert LuohanQuan.query_action(0, rng())["skill_name"] == "黄莺落架"
      end
    end

    test "level 7 / 8 仅 lvl 0 可选（strict >：level 8 不大于 lvl 8）" do
      assert LuohanQuan.query_action(7, rng())["skill_name"] == "黄莺落架"
      assert LuohanQuan.query_action(8, rng())["skill_name"] == "黄莺落架"
    end

    test "level 9 lvl 8 已入表但 NewRandom(2) 恒取索引 0（与 LPC `random(1)` 一致）" do
      # 仅 2 式可用时 NewRandom(2, _)：sum = 1，random(1) 恒 0 → 恒返回索引 0，
      # 即第一式「黄莺落架」。第 2 式「丹凤朝阳」的可用性已由
      # query_skill_name/9 == "丹凤朝阳" 覆盖，此处不再断言选中它。
      assert LuohanQuan.query_action(9, rng())["skill_name"] == "黄莺落架"
    end

    test "返回动作的 lvl 始终严格小于 level（LPC 边界；level 0 回落除外）" do
      Enum.each([9, 30, 50, 57, 58, 59, 300], fn level ->
        action = LuohanQuan.query_action(level, rng())
        assert Map.get(action, "lvl", 0) < level
      end)
    end

    test "高等级可到达表尾招式（rng 取最大，NewRandom 取最后一可用式）" do
      max_rng = fn n -> n end
      assert LuohanQuan.query_action(57, max_rng)["skill_name"] == "慑服外道"
      assert LuohanQuan.query_action(59, max_rng)["skill_name"] == "三入地狱"
      assert LuohanQuan.query_action(300, max_rng)["skill_name"] == "三入地狱"
    end

    test "返回的动作字段非空（出招有描述）" do
      action = LuohanQuan.query_action(300, rng())
      assert is_binary(action["action"]) and action["action"] != ""
    end
  end

  describe "query_action/3 与 /2 行为一致（忽略 attacker）" do
    test "带角色快照时不改变选招结果" do
      attacker = %Fighter{skills: %{"luohan-quan" => 300}, weapon_name: nil}

      for _ <- 1..20 do
        assert LuohanQuan.query_action(300, rng(), attacker) ==
               LuohanQuan.query_action(300, rng())
      end
    end

    test "attacker 为 nil 也不崩溃（宏回落路径）" do
      assert is_map(LuohanQuan.query_action(300, rng(), nil))
    end
  end

  describe "极低等级回落（LPC count 0 → List.first）" do
    test "level 0 时取第一式，不崩溃" do
      assert LuohanQuan.query_action(0, rng())["skill_name"] == "黄莺落架"
    end
  end

  describe "valid_enable（cuff / parry 可，其余不可）" do
    test "cuff / parry 为 true" do
      assert LuohanQuan.valid_enable("cuff")
      assert LuohanQuan.valid_enable("parry")
    end

    test "其余 usage 为 false" do
      refute LuohanQuan.valid_enable("sword")
      refute LuohanQuan.valid_enable("force")
      refute LuohanQuan.valid_enable("dodge")
    end
  end

  describe "query_skill_name 遍历整表" do
    test "lvl 边界" do
      assert LuohanQuan.query_skill_name(0) == "黄莺落架"
      assert LuohanQuan.query_skill_name(7) == "黄莺落架"
      assert LuohanQuan.query_skill_name(8) == "丹凤朝阳"
      assert LuohanQuan.query_skill_name(57) == "慑服外道"
      assert LuohanQuan.query_skill_name(58) == "三入地狱"
      assert LuohanQuan.query_skill_name(300) == "三入地狱"
      assert LuohanQuan.query_skill_name(-1) == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("luohan-quan") == LuohanQuan
    end
  end

  describe "Engine.select_action/1 端到端" do
    test "能选出罗汉拳招式" do
      fighter = %Fighter{
        attack_skill: "cuff",
        mapped: %{"cuff" => "luohan-quan"},
        skills: %{"luohan-quan" => 300},
        weapon_name: nil
      }

      for _ <- 1..30 do
        action = Engine.select_action(fighter)
        assert action["skill_name"] in @expected_names
      end
    end
  end

  describe "valid_learn/2 学习门槛（LPC force>=20 / max_neili>=50 / cuff>=luohan-quan）" do
    defp stats(force, cuff, luohan) do
      %{skills: %{"force" => force, "cuff" => cuff, "luohan-quan" => luohan}}
    end

    defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

    test "force < 20 被拒（内功火候不够）" do
      assert LuohanQuan.valid_learn(stats(10, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学罗汉拳。\n"}
    end

    test "max_neili < 50 被拒（内力太弱）" do
      assert LuohanQuan.valid_learn(stats(100, 200, 50), char_with_max_neili(20)) ==
               {:error, "你的内力太弱，无法练罗汉拳。\n"}
    end

    test "cuff < luohan-quan 被拒（基本拳法水平有限）" do
      assert LuohanQuan.valid_learn(stats(100, 100, 150), char_with_max_neili(2000)) ==
               {:error, "你的基本拳法水平有限，无法领会更高深的罗汉拳。\n"}
    end

    test "三项全满足则放行" do
      assert LuohanQuan.valid_learn(stats(100, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert LuohanQuan.valid_learn(stats(100, 200, 50), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert LuohanQuan.valid_learn(stats(100, 200, 50), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 25 / neili 6）" do
    test "返回 LPC 一致的消耗" do
      assert LuohanQuan.practice_cost() == %{qi: 25, neili: 6}
    end
  end
end
