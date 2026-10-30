defmodule Kantele.Combat.SkillsDaojianGuizhenTest do
  @moduledoc """
  刀剑归真学习门槛迁移（C 相位，daojian-guizhen 真缺口补齐）。

  对照 `kungfu/skill/daojian-guizhen.c`：
  - valid_learn: int>=35 / dex>=25 / martial-cognize>=250 / max_neili>=4500 /
    sword>=250 且 blade>=250 / 「刀剑均低于本技能」/「其一低于本技能」；
  - LPC 末门允许 `ultrap` 且刀剑均>=320 时只需其一达标，本仓无 ultrap 判定 → 按非大宗师处理；
  - practice_skill 扣 qi 85 / neili 85。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.DaojianGuizhen

  defp stats(int, dex, cognize, sword, blade, self_lvl) do
    %{
      int: int,
      dex: dex,
      skills: %{
        "martial-cognize" => cognize,
        "sword" => sword,
        "blade" => blade,
        "daojian-guizhen" => self_lvl
      }
    }
  end

  defp char(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  # 默认全达标：int 40 / dex 30 / cognize 300 / sword 300 / blade 300 / self 10
  defp ok_stats, do: stats(40, 30, 300, 300, 300, 10)

  describe "valid_learn/2 学习门槛" do
    test "int < 35 被拒（天资不足）" do
      assert DaojianGuizhen.valid_learn(stats(34, 30, 300, 300, 300, 10), char(5000)) ==
               {:error, "你研究了半天，却只感剑法和刀法毫无牵连，看来是自己天资不足。\n"}
    end

    test "dex < 25 被拒（身法灵动性不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 24, 300, 300, 300, 10), char(5000)) ==
               {:error, "你研究了半天，只觉依自己的身法灵动性，根本无法修习这门武功。\n"}
    end

    test "martial-cognize < 250 被拒（武学修养不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 249, 300, 300, 10), char(5000)) ==
               {:error, "你觉得苗家剑法和胡家刀法都极其深奥，依照自己武学修养难以理解。\n"}
    end

    test "max_neili < 4500 被拒（内力太弱）" do
      assert DaojianGuizhen.valid_learn(ok_stats(), char(4499)) ==
               {:error, "你的内力太弱，无法将苗家剑法和胡家刀法二者合一学习。\n"}
    end

    test "sword < 250 被拒（刀剑根基火候不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 249, 300, 10), char(5000)) ==
               {:error, "你的刀剑根基火候不足，难以修炼刀剑归真。\n"}
    end

    test "blade < 250 被拒（刀剑根基火候不足）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 300, 249, 10), char(5000)) ==
               {:error, "你的刀剑根基火候不足，难以修炼刀剑归真。\n"}
    end

    test "刀剑均低于本技能被拒（刀剑根基火候不足，无法领会）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 260, 260, 400), char(5000)) ==
               {:error, "你的刀剑根基火候不足，无法领会更高深的刀剑归真。\n"}
    end

    test "仅其一低于本技能被拒（刀法或剑法火候不足；ultrap 未建模按非大宗师处理）" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 400, 260, 400), char(5000)) ==
               {:error, "你的刀法或剑法火候不足，无法领会更高深的刀剑归真。\n"}
    end

    test "刀剑均不低于本技能则放行" do
      assert DaojianGuizhen.valid_learn(stats(40, 30, 300, 400, 400, 400), char(5000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查（其余门槛仍生效）" do
      assert DaojianGuizhen.valid_learn(ok_stats(), nil) == :ok
    end

    test "character 无 meta/vitals 时跳过 max_neili 检查" do
      assert DaojianGuizhen.valid_learn(ok_stats(), %{}) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 85 / neili 85）" do
    test "返回 LPC 一致的消耗" do
      assert DaojianGuizhen.practice_cost() == %{qi: 85, neili: 85}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("daojian-guizhen") == DaojianGuizhen
    end
  end
end
