defmodule Kantele.Combat.SkillsAdjustTest do
  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills

  test "skill_adjust: 把超过 combat_exp^3/10 的 martial 技能压回上限" do
    # combat_exp=100 -> lmt = 100^3/10 = 100000
    skills = %{"sword" => 500_000, "dodge" => 100_000, "force" => 50_000}

    assert Skills.skill_adjust(skills, 100) == %{
             "sword" => 100_000,
             "dodge" => 100_000,
             "force" => 50_000
           }
  end

  test "skill_adjust: 低于上限的不动" do
    skills = %{"sword" => 10}
    assert Skills.skill_adjust(skills, 100) == %{"sword" => 10}
  end

  test "skill_adjust: 指定 martial 键集合时只看这些键" do
    skills = %{"sword" => 500_000, "literate" => 500_000}
    # lmt = 100^3/10 = 100000；只压 "sword"，literate 不动
    assert Skills.skill_adjust(skills, 100, ["sword"]) == %{
             "sword" => 100_000,
             "literate" => 500_000
           }
  end
end
