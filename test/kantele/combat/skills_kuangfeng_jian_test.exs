defmodule Kantele.Combat.SkillsKuangfengJianTest do
  @moduledoc """
  狂风快剑招式表迁移（C 相位，kuangfeng-jian 真缺口补齐）。

  LPC `kungfu/skill/kuangfeng-jian.c` 有 4 式静态招式（lvl 0/30/60/90），
  `translate_skill.exs` 只认 `mapping *action`，本应机械产出；实际 Elixir 侧
  `query_action` 返回 `%{}`，出招无描述无伤害。本测试锁定：

  1. 表长 4 式，每式 `lvl` 与 LPC 一致；
  2. `query_action/2` 按 `level > lvl` 过滤（LPC `for (i = sizeof(action); i > 0; i--)`）；
  3. `query_action/3` 与 /2 行为一致（狂风快剑无动态表，忽略 attacker）；
  4. 极低等级回落到第一式（LPC count 0 → `List.first`）；
  5. `valid_enable`：sword/parry 可，其余不可；
  6. `query_skill_name` 遍历整表（LPC `level >= lvl`）；
  7. 已进 `Skills` 注册表，`Engine.select_action` 端到端可出招。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.KuangfengJian
  alias Kantele.Combat.Engine

  defp rng, do: fn _ -> 1 end

  @expected_lvls [0, 30, 60, 90]
  @expected_names ["风平浪静", "风起云涌", "风卷残云", "风流云散"]
  @expected_damage_types ["刺伤", "刺伤", "刺伤", "割伤"]

  describe "招式表长度与 LPC 对照（4 式）" do
    test "表长 4 式" do
      assert length(KuangfengJian.actions()) == 4
    end

    test "每式 lvl 与 LPC 一致" do
      assert Enum.map(KuangfengJian.actions(), & &1["lvl"]) == @expected_lvls
    end

    test "每式 skill_name 与 LPC 一致" do
      assert Enum.map(KuangfengJian.actions(), & &1["skill_name"]) == @expected_names
    end

    test "每式 damage_type 与 LPC 一致" do
      assert Enum.map(KuangfengJian.actions(), & &1["damage_type"]) == @expected_damage_types
    end
  end

  describe "query_action/2 按等级加权选招" do
    test "level 0 只能选第 1 式（lvl 0，LPC count 0 → List.first）" do
      for _ <- 1..20 do
        assert KuangfengJian.query_action(0, rng())["skill_name"] == "风平浪静"
      end
    end

    test "level 29 / 30 仍只能选第 1 式（30 > 30 不成立，第 2 式不可选）" do
      assert KuangfengJian.query_action(29, rng())["skill_name"] == "风平浪静"
      assert KuangfengJian.query_action(30, rng())["skill_name"] == "风平浪静"
    end

    test "level 31 lvl 30 已入表但 NewRandom(2) 恒取索引 0（与 LPC `random(1)` 一致）" do
      # 仅 2 式可用时 NewRandom(2, _) 恒返回索引 0，即第一式「风平浪静」。
      # 第 2 式「风起云涌」的可用性已由 query_skill_name/31 == "风起云涌" 覆盖。
      assert KuangfengJian.query_action(31, rng())["skill_name"] == "风平浪静"
    end

    test "返回动作的 lvl 始终严格小于 level（LPC 边界；level 0 回落除外）" do
      Enum.each([31, 60, 61, 90, 91, 300], fn level ->
        action = KuangfengJian.query_action(level, rng())
        assert Map.get(action, "lvl", 0) < level
      end)
    end

    test "高等级可到达表尾招式（rng 取最大，NewRandom 取最后一可用式）" do
      max_rng = fn n -> n end
      # level 61：3 式可用（lvl 0/30/60），最大可选「风卷残云」
      assert KuangfengJian.query_action(61, max_rng)["skill_name"] == "风卷残云"
      # level 91 / 300：4 式可用，最大可选「风流云散」
      assert KuangfengJian.query_action(91, max_rng)["skill_name"] == "风流云散"
      assert KuangfengJian.query_action(300, max_rng)["skill_name"] == "风流云散"
    end

    test "返回的动作字段非空（出招有描述）" do
      action = KuangfengJian.query_action(300, rng())
      assert is_binary(action["action"]) and action["action"] != ""
    end
  end

  describe "query_action/3 与 /2 行为一致（忽略 attacker）" do
    test "带角色快照时不改变选招结果" do
      attacker = %Fighter{skills: %{"kuangfeng-jian" => 300}, weapon_name: nil}

      for _ <- 1..20 do
        assert KuangfengJian.query_action(300, rng(), attacker) ==
               KuangfengJian.query_action(300, rng())
      end
    end

    test "attacker 为 nil 也不崩溃（宏回落路径）" do
      assert is_map(KuangfengJian.query_action(300, rng(), nil))
    end
  end

  describe "极低等级回落（LPC count 0 → List.first）" do
    test "level 0 时取第一式，不崩溃" do
      assert KuangfengJian.query_action(0, rng())["skill_name"] == "风平浪静"
    end
  end

  describe "valid_enable（sword / parry 可，其余不可）" do
    test "sword / parry 为 true" do
      assert KuangfengJian.valid_enable("sword")
      assert KuangfengJian.valid_enable("parry")
    end

    test "其余 usage 为 false" do
      refute KuangfengJian.valid_enable("staff")
      refute KuangfengJian.valid_enable("force")
      refute KuangfengJian.valid_enable("dodge")
    end
  end

  describe "query_skill_name 遍历整表（LPC `level >= lvl`）" do
    test "lvl 边界" do
      assert KuangfengJian.query_skill_name(0) == "风平浪静"
      assert KuangfengJian.query_skill_name(29) == "风平浪静"
      assert KuangfengJian.query_skill_name(30) == "风起云涌"
      assert KuangfengJian.query_skill_name(59) == "风起云涌"
      assert KuangfengJian.query_skill_name(60) == "风卷残云"
      assert KuangfengJian.query_skill_name(89) == "风卷残云"
      assert KuangfengJian.query_skill_name(90) == "风流云散"
      assert KuangfengJian.query_skill_name(300) == "风流云散"
      assert KuangfengJian.query_skill_name(-1) == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("kuangfeng-jian") == KuangfengJian
    end
  end

  describe "Engine.select_action/1 端到端" do
    test "能选出狂风快剑招式" do
      fighter = %Fighter{
        attack_skill: "sword",
        mapped: %{"sword" => "kuangfeng-jian"},
        skills: %{"kuangfeng-jian" => 300},
        weapon_name: nil
      }

      for _ <- 1..30 do
        action = Engine.select_action(fighter)
        assert action["skill_name"] in @expected_names
      end
    end
  end
end
