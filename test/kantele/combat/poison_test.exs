defmodule Kantele.Combat.Skills.PoisonTest do
  @moduledoc """
  poison.c valid_learn 人格门单测（LPC 保真）：

  LPC：
    int valid_learn(object me) {
      if (me->query("character") == "光明磊落")
        return notify_fail("你心中暗想：我行事光明磊落，学什么毒技！\n");
      return 1;
    }

  无 practice_skill 覆盖 → practice_cost 沿用基类默认 %{qi: 50, neili: 30}。
  无 valid_enable → 保真返回 false。
  """

  use ExUnit.Case, async: true

  alias Kantele.Combat.Skills

  defp char(personality), do: %{meta: %{character: personality}}

  defp stats(attrs \\ %{}) do
    base = %{
      str: 50,
      int: 50,
      dex: 50,
      con: 50,
      skills: %{"force" => 300, "poison" => 300}
    }

    %{
      base
      | str: Map.get(attrs, :str, base.str),
        int: Map.get(attrs, :int, base.int),
        dex: Map.get(attrs, :dex, base.dex),
        con: Map.get(attrs, :con, base.con),
        skills: Map.merge(base.skills, Map.get(attrs, :skills, %{}))
    }
  end

  test "模块已注册并可加载" do
    module = Skills.get("poison")

    assert is_atom(module) and Code.ensure_loaded(module) == {:module, module},
           "Skills.get(\"poison\") 应返回已加载的武学模块"
  end

  test "valid_enable 拒绝所有用途（源未定义，保真 false）" do
    m = Skills.get("poison")

    refute m.valid_enable("force")
    refute m.valid_enable("unarmed")
    refute m.valid_enable("poison")
  end

  test "practice_cost 沿用基类默认 qi/neili" do
    assert Skills.get("poison").practice_cost() == %{qi: 50, neili: 30}
  end

  describe "valid_learn/2 人格门（LPC 保真）" do
    test "光明磊落被拒绝" do
      m = Skills.get("poison")

      assert m.valid_learn(stats(), char("光明磊落")) ==
             {:error, "你心中暗想：我行事光明磊落，学什么毒技！\n"}
    end

    test "非光明磊落人格放行（含 nil 人格）" do
      m = Skills.get("poison")

      assert m.valid_learn(stats(), char(nil)) == :ok
      assert m.valid_learn(stats(), char("阴狠毒辣")) == :ok
      assert m.valid_learn(stats(), char("心狠手辣")) == :ok
    end
  end
end
