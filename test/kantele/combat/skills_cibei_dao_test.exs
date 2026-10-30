defmodule Kantele.Combat.SkillsCibeiDaoTest do
  @moduledoc """
  慈悲刀法招式表迁移（C 相位，cibei-dao 真缺口补齐）。

  LPC `kungfu/skill/cibei-dao.c` 有 8 式静态招式（lvl 0/10/30/50/80/100/120/150），
  `translate_skill.exs` 只认 `mapping *action`，本应机械产出；实际 Elixir 侧
  `query_action` 返回 `%{}`，出招无描述无伤害。本测试锁定：

  1. 表长 8 式，每式 `lvl` 与 LPC 一致；
  2. `query_action/2` 按 `level > lvl` 过滤（LPC `for (i = sizeof(action); i > 0; i--)`）；
  3. `query_action/3` 与 /2 行为一致（慈悲刀法无动态表，忽略 attacker）；
  4. 极低等级回落到第一式（LPC count 0 → `List.first`）；
  5. `valid_enable`：blade/parry 可，其余不可；
  6. `query_skill_name` 遍历整表（LPC `level >= lvl`）；
  7. 已进 `Skills` 注册表，`Engine.select_action` 端到端可出招。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Fighter
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.CibeiDao
  alias Kantele.Combat.Engine

  defp rng, do: fn _ -> 1 end  # NewRandom 取最靠前可用招式（索引 0）

  @expected_lvls [0, 10, 30, 50, 80, 100, 120, 150]
  @expected_names [
    "停车问路", "童子挂画", "推窗望月", "开门见山",
    "临溪观鱼", "张弓望的", "风送轻舟", "停车问路"
  ]
  @expected_damage_types ["割伤", "割伤", "割伤", "割伤", "割伤", "割伤", "割伤", "割伤"]

  describe "招式表长度与 LPC 对照（8 式）" do
    test "表长 8 式" do
      assert length(CibeiDao.actions()) == 8
    end

    test "每式 lvl 与 LPC 一致" do
      assert Enum.map(CibeiDao.actions(), & &1["lvl"]) == @expected_lvls
    end

    test "每式 skill_name 与 LPC 一致" do
      assert Enum.map(CibeiDao.actions(), & &1["skill_name"]) == @expected_names
    end

    test "每式 damage_type 与 LPC 一致" do
      assert Enum.map(CibeiDao.actions(), & &1["damage_type"]) == @expected_damage_types
    end
  end

  describe "query_action/2 按等级加权选招（LPC `level > lvl` 严格过滤）" do
    test "level 0 无可选招式，回落第一式（LPC count 0 → List.first）" do
      for _ <- 1..20 do
        assert CibeiDao.query_action(0, rng())["skill_name"] == "停车问路"
      end
    end

    test "level 10 仅 lvl 0 可选（strict >：level 10 不大于 lvl 10）" do
      assert CibeiDao.query_action(10, rng())["skill_name"] == "停车问路"
    end

    test "level 11 lvl 10 已入表但 NewRandom(2) 恒取索引 0（与 LPC `random(1)` 一致）" do
      # 仅 2 式可用时 NewRandom(2, _)：sum = 1，random(1) 恒 0 → 恒返回索引 0，
      # 即第一式「停车问路」。第 2 式「童子挂画」的可用性已由
      # query_skill_name/11 == "童子挂画" 覆盖，此处不再断言选中它。
      assert CibeiDao.query_action(11, rng())["skill_name"] == "停车问路"
    end

    test "返回动作的 lvl 始终严格小于 level（LPC 边界；level 0 回落除外）" do
      Enum.each([11, 50, 51, 150, 151, 300], fn level ->
        action = CibeiDao.query_action(level, rng())
        assert Map.get(action, "lvl", 0) < level
      end)
    end

    test "高等级可到达表尾招式（rng 取最大，NewRandom 取最后一可用式）" do
      max_rng = fn n -> n end
      # level 121：lvl 0~120 可选（7 式，lvl 150 不可），最大可选「风送轻舟」
      assert CibeiDao.query_action(121, max_rng)["skill_name"] == "风送轻舟"
      # level 151 / 300：全部 8 式可选，最大可选「停车问路」（lvl 150）
      assert CibeiDao.query_action(151, max_rng)["skill_name"] == "停车问路"
      assert CibeiDao.query_action(300, max_rng)["skill_name"] == "停车问路"
    end

    test "返回的动作字段非空（出招有描述）" do
      action = CibeiDao.query_action(300, rng())
      assert is_binary(action["action"]) and action["action"] != ""
    end
  end

  describe "query_action/3 与 /2 行为一致（忽略 attacker）" do
    test "带角色快照时不改变选招结果" do
      attacker = %Fighter{skills: %{"cibei-dao" => 300}, weapon_name: nil}

      for _ <- 1..20 do
        assert CibeiDao.query_action(300, rng(), attacker) ==
               CibeiDao.query_action(300, rng())
      end
    end

    test "attacker 为 nil 也不崩溃（宏回落路径）" do
      assert is_map(CibeiDao.query_action(300, rng(), nil))
    end
  end

  describe "极低等级回落（LPC count 0 → List.first）" do
    test "level 0 时取第一式，不崩溃" do
      assert CibeiDao.query_action(0, rng())["skill_name"] == "停车问路"
    end
  end

  describe "valid_enable（blade / parry 可，其余不可）" do
    test "blade / parry 为 true" do
      assert CibeiDao.valid_enable("blade")
      assert CibeiDao.valid_enable("parry")
    end

    test "其余 usage 为 false" do
      refute CibeiDao.valid_enable("sword")
      refute CibeiDao.valid_enable("force")
      refute CibeiDao.valid_enable("dodge")
    end
  end

  describe "query_skill_name 遍历整表（LPC `level >= lvl`）" do
    test "lvl 边界" do
      assert CibeiDao.query_skill_name(0) == "停车问路"
      assert CibeiDao.query_skill_name(9) == "停车问路"
      assert CibeiDao.query_skill_name(10) == "童子挂画"
      assert CibeiDao.query_skill_name(29) == "童子挂画"
      assert CibeiDao.query_skill_name(30) == "推窗望月"
      assert CibeiDao.query_skill_name(49) == "推窗望月"
      assert CibeiDao.query_skill_name(50) == "开门见山"
      assert CibeiDao.query_skill_name(79) == "开门见山"
      assert CibeiDao.query_skill_name(80) == "临溪观鱼"
      assert CibeiDao.query_skill_name(99) == "临溪观鱼"
      assert CibeiDao.query_skill_name(100) == "张弓望的"
      assert CibeiDao.query_skill_name(119) == "张弓望的"
      assert CibeiDao.query_skill_name(120) == "风送轻舟"
      assert CibeiDao.query_skill_name(149) == "风送轻舟"
      assert CibeiDao.query_skill_name(150) == "停车问路"
      assert CibeiDao.query_skill_name(300) == "停车问路"
      assert CibeiDao.query_skill_name(-1) == nil
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("cibei-dao") == CibeiDao
    end
  end

  describe "Engine.select_action/1 端到端" do
    test "能选出慈悲刀法招式" do
      fighter = %Fighter{
        attack_skill: "blade",
        mapped: %{"blade" => "cibei-dao"},
        skills: %{"cibei-dao" => 300},
        weapon_name: nil
      }

      for _ <- 1..30 do
        action = Engine.select_action(fighter)
        assert action["skill_name"] in @expected_names
      end
    end
  end
end
