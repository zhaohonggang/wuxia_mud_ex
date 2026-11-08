defmodule Kantele.Combat.SkillsQiankunDanuoyiTest do
  @moduledoc """
  乾坤大挪移学习门槛迁移（E1 收尾：query_condition 接入 valid_learn）。

  对照 `kungfu/skill/qiankun-danuoyi.c`：
  - 性别/悟性/内力/内功/招架 门槛已逐条保真；
  - `query_condition("qiankun-except")` 经 E1 传入的 `character.conditions` 读取
    （session 态 conditions 在 learn_command/skills_event 调用前并入角色快照）。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.Conditions
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.QiankunDanuoyi

  # 满足除 condition 门外所有门槛：悟性 100 / 内力上限 5000 / 内功 450 / 招架 0 / 等级 0
  defp stats,
    do: %{
      skills: %{"qiankun-danuoyi" => 0, "force" => 450, "parry" => 0},
      int: 100
    }

  defp char(extra), do: %{meta: %{vitals: %{max_neili: 5000}}, conditions: extra}

  describe "valid_learn/2 学习门槛（LPC 逐条保真 + E1 condition 门）" do
    test "有 qiankun-except 条件被拒（体内若冰、四肢皆寒）" do
      conditions = %{"qiankun-except" => %{}}
      assert QiankunDanuoyi.valid_learn(stats(), char(conditions)) ==
               {:error, "你现在体内若冰、四肢皆寒、面赤如火，无法继续修炼神功。\n"}
    end

    test "Conditions.query_condition 返回非 nil 即触发（等价 LPC 行为）" do
      conditions = Conditions.query_condition(%{conditions: %{"qiankun-except" => %{from: "x"}}}, "qiankun-except")
      refute is_nil(conditions)
      assert QiankunDanuoyi.valid_learn(stats(), char(%{"qiankun-except" => %{from: "x"}})) ==
               {:error, "你现在体内若冰、四肢皆寒、面赤如火，无法继续修炼神功。\n"}
    end

    test "无 conditions 且其余门槛满足则放行" do
      assert QiankunDanuoyi.valid_learn(stats(), char(%{})) == :ok
    end

    test "无性且等级>=50 被拒（首门）" do
      char = %{
        meta: %{env: %{gender: "无性"}, vitals: %{max_neili: 5000}},
        conditions: %{}
      }

      stats = %{skills: %{"qiankun-danuoyi" => 60, "force" => 450, "parry" => 0}, int: 100}
      assert QiankunDanuoyi.valid_learn(stats, char) ==
               {:error, "你试图按照心法修炼大挪移，却觉得心中一阵迷茫，难以继续。\n"}
    end

    test "悟性不足被拒（深奥无比）" do
      stats = %{skills: %{"qiankun-danuoyi" => 0, "force" => 450, "parry" => 0}, int: 10}
      assert QiankunDanuoyi.valid_learn(stats, char(%{})) ==
               {:error, "你觉得乾坤大挪移实在是深奥无比，全然无法理解。\n"}
    end

    test "内力修为太差被拒（max_neili < 5000）" do
      char = %{meta: %{vitals: %{max_neili: 1000}}, conditions: %{}}
      assert QiankunDanuoyi.valid_learn(stats(), char) ==
               {:error, "你的内力修为太差，无法修炼乾坤大挪移。\n"}
    end
  end

  describe "已进 Skills 注册表" do
    test "Skills.get 可解析" do
      assert Skills.get("qiankun-danuoyi") == QiankunDanuoyi
    end
  end
end
