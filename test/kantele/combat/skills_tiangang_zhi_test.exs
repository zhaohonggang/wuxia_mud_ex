defmodule Kantele.Combat.SkillsTiangangZhiTest do
  @moduledoc """
  天罡指穴法学习门槛迁移（C 相位，tiangang-zhi 真缺口补齐）。

  对照 `kungfu/skill/tiangang-zhi.c`：
  - valid_learn: force>=100 / max_neili>=500 / finger>=tiangang-zhi（LPC 另查须空手，由 practice 流程把关）；
  - practice_skill 扣 qi 55 / neili 51。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.TiangangZhi

  defp stats(force, finger, self_lvl),
    do: %{skills: %{"force" => force, "finger" => finger, "tiangang-zhi" => self_lvl}}

  defp char_with_max_neili(mn), do: %{meta: %{vitals: %{max_neili: mn}}}

  describe "valid_learn/2 学习门槛（LPC force>=100 / max_neili>=500 / finger>=self）" do
    test "force < 100 被拒（内功火候不够）" do
      assert TiangangZhi.valid_learn(stats(50, 200, 50), char_with_max_neili(2000)) ==
               {:error, "你的内功火候不够，无法学天罡指穴法。\n"}
    end

    test "max_neili < 500 被拒（内力太弱）" do
      assert TiangangZhi.valid_learn(stats(200, 200, 50), char_with_max_neili(300)) ==
               {:error, "你的内力太弱，无法练天罡指穴法。\n"}
    end

    test "finger < tiangang-zhi 被拒（基本指法太差）" do
      assert TiangangZhi.valid_learn(stats(200, 200, 250), char_with_max_neili(2000)) ==
               {:error, "你的基本指法太差，无法领会更高深的天罡指穴法。\n"}
    end

    test "三项全满足则放行" do
      assert TiangangZhi.valid_learn(stats(200, 200, 50), char_with_max_neili(2000)) == :ok
    end

    test "character 为 nil 时跳过 max_neili 检查" do
      assert TiangangZhi.valid_learn(stats(200, 200, 50), nil) == :ok
    end
  end

  describe "practice_cost（LPC practice_skill 扣 qi 55 / neili 51）" do
    test "返回 LPC 一致的消耗" do
      assert TiangangZhi.practice_cost() == %{qi: 55, neili: 51}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("tiangang-zhi") == TiangangZhi
    end
  end
end
