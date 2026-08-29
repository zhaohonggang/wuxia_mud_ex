defmodule Kantele.Combat.SkillsPenaltyTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills

  describe "skill_death_penalty (skill.c)" do
    test "无 learned：每技能 -1，跌破 1 删除" do
      {sk, ln} = Skills.skill_death_penalty(%{"sword" => 5, "dodge" => 1, "force" => 2})
      assert sk == %{"sword" => 4, "force" => 1}
      assert ln == %{}
    end

    test "有 learned：过高领悟删 learned，否则技能 -1" do
      # sword=2 → (2+1)^2/2 = 4；learned=5 > 4 → 删 learned[sword]
      # force=2 → 4；learned=2 → 不删，force-- → 1
      {sk, ln} =
        Skills.skill_death_penalty(%{"sword" => 2, "force" => 2}, %{"sword" => 5, "force" => 2})

      assert sk == %{"sword" => 2, "force" => 1}
      assert ln == %{"force" => 2}
    end

    test "跌破 0 删除技能" do
      {sk, _} = Skills.skill_death_penalty(%{"dodge" => 0})
      assert sk == %{}
    end
  end

  describe "skill_expell_penalty (skill.c)" do
    @meta %{
      "dugu-jiujian" => %{type: "martial", guards: ["parry"]},
      "taiji-quan" => %{type: "martial", guards: ["parry", "dodge"]},
      "force" => %{type: "martial", guards: ["force"]},
      "sword" => %{type: "martial", guards: []},
      "literate" => %{type: "knowledge", guards: []},
      "no-such" => %{missing: true}
    }

    test "可 enable parry/dodge/throwing/force 删除；martial-cognize/知识保留" do
      res =
        Skills.skill_expell_penalty(
          %{"dugu-jiujian" => 50, "force" => 80, "literate" => 90, "taiji-quan" => 30},
          @meta
        )

      # dugu-jiujian/taiji-quan/force 被删，literate 保留
      assert res == %{"literate" => 90}
    end

    test "普通 martial 技能压回 100" do
      res = Skills.skill_expell_penalty(%{"sword" => 150}, @meta)
      assert res == %{"sword" => 100}
    end

    test "missing 技能删除" do
      res = Skills.skill_expell_penalty(%{"no-such" => 40}, @meta)
      assert res == %{}
    end

    test "guards_special? 谓词" do
      assert Skills.guards_special?(%{guards: ["parry"]})
      assert Skills.guards_special?(%{guards: ["dodge"]})
      refute Skills.guards_special?(%{guards: ["strike"]})
    end
  end
end