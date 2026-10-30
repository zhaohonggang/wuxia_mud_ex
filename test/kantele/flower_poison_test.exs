defmodule Kantele.FlowerPoisonTest do
  @moduledoc """
  `Kantele.FlowerPoison`（断肠花毒，`kungfu/condition/flower_poison.c`）。

  daemon 是纯函数：`update_condition/1` 只碰 info，`do_effect/3` 收 state 出 state。
  """

  use ExUnit.Case, async: true

  alias Kantele.Character.ConditionRegistry
  alias Kantele.FlowerPoison

  @cnd "flower_poison"

  defp state(opts) do
    %{
      conditions: %{@cnd => %{"duration" => Keyword.get(opts, :duration, 5)}},
      attributes: %{
        jing: Keyword.get(opts, :jing, 300),
        qi: Keyword.get(opts, :qi, 500),
        max_jing: Keyword.get(opts, :max_jing, 300),
        max_qi: Keyword.get(opts, :max_qi, 500),
        force: Keyword.get(opts, :force, 100)
      },
      temp: Keyword.get(opts, :temp, %{})
    }
  end

  defp messages(state) do
    Map.get(state, :condition_messages) || []
  end

  defp duration_of(state) do
    get_in(state, [:conditions, @cnd, "duration"])
  end

  test "注册表能解析 flower_poison" do
    assert {:ok, Kantele.FlowerPoison} = ConditionRegistry.daemon("flower_poison")
  end

  test "daemon/1 只认 flower_poison" do
    assert {:ok, FlowerPoison} = FlowerPoison.daemon("flower_poison")
    assert :error = FlowerPoison.daemon("poison")
  end

  describe "update_condition/1（生命周期）" do
    test "每跳减一，减到 0 仍保留（末跳要结算伤害）" do
      assert {:continue, %{"duration" => 0}} = FlowerPoison.update_condition(%{"duration" => 1})
    end

    test "减到负数才到期" do
      assert {:expire} = FlowerPoison.update_condition(%{"duration" => 0})
    end

    test "正常递减" do
      assert {:continue, %{"duration" => 4}} = FlowerPoison.update_condition(%{"duration" => 5})
    end
  end

  describe "do_effect/3（每跳结算）" do
    test "房间广播（排除本人）+ 本人提示 + 精/气双扣" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 5), @cnd, nil)

      assert {:vision_excl, vision} = List.first(messages(out))
      assert vision =~ "{npc}一阵摇晃，立足不定。"
      assert {:tell, "你中的断肠花毒发作了！\n"} in messages(out)

      # jing 扣 2×[25,49]，qi 扣 2×[50,99]
      assert out.attributes.jing <= 300 - 50
      assert out.attributes.jing >= 300 - 98
      assert out.attributes.qi <= 500 - 100
      assert out.attributes.qi >= 500 - 198
    end

    test "receive_wound 削减上限：max_jing / max_qi 一起降" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 5), @cnd, nil)

      assert out.attributes.max_jing < 300
      assert out.attributes.max_qi < 500
      # 当前值不会超过被削后的上限
      assert out.attributes.jing <= out.attributes.max_jing
      assert out.attributes.qi <= out.attributes.max_qi
    end

    test "temp nopoison 时毒性归零且不扣血" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 5, temp: %{"nopoison" => 1}), @cnd, nil)

      assert duration_of(out) == 0
      assert out.attributes.jing == 300
      assert out.attributes.qi == 500
      assert messages(out) == []
    end

    test "duration 0（末跳）补「心口一阵剧痛」并把毒性归零" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 0), @cnd, nil)

      assert {:tell, text} = List.last(messages(out))
      assert text =~ "你心口一阵剧痛"
      assert duration_of(out) == 0
    end

    test "force >= 300 额外多减一跳" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 5, force: 300), @cnd, nil)
      assert duration_of(out) == 4
    end

    test "force < 300 不多减" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 5, force: 299), @cnd, nil)
      assert duration_of(out) == 5
    end

    test "气/精不足 25 时记死因并归零（玩家侧不直接处决），且不结算伤害" do
      {:ok, out} =
        FlowerPoison.do_effect(state(duration: 5, jing: 0, qi: 10, max_jing: 0, max_qi: 10), @cnd, nil)

      assert out.condition_die_reason == "断肠花毒发作，不治身亡了"
      assert duration_of(out) == 0
      assert out.attributes.qi == 10
      assert messages(out) == []
    end

    test "扣血不会把气/精打成负数" do
      {:ok, out} = FlowerPoison.do_effect(state(duration: 5, jing: 10, qi: 20), @cnd, nil)
      assert out.attributes.jing == 0
      assert out.attributes.qi == 0
    end
  end
end
