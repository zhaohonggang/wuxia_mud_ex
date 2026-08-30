defmodule Kantele.Item.FoodTest do
  use ExUnit.Case, async: false

  alias Kantele.Item.Food
  alias Kantele.Item.Effect

  setup do
    :ok
  end

  describe "Food 纯逻辑" do
    test "is_food? 总是 true" do
      assert Food.is_food?(%{})
    end
  end

  describe "Effect 消耗食物" do
    test "食物提供气血恢复" do
      vitals = %Kantele.Character.Vitals{
        qi: 100,
        max_qi: 150,
        jing: 80,
        max_jing: 100,
        neili: 60,
        max_neili: 100
      }

      stats = %Kantele.Character.Stats{}
      meta = %{food: 30}

      {:ok, result} = Effect.consume(vitals, stats, meta)

      assert result.food? == true
      assert result.medicine? == false
      assert result.vitals.qi == 130
      assert result.vitals.max_qi == 150
      assert result.vitals.jing == 80
      assert result.vitals.neili == 60
      assert result.parts == ["气血+30"]
    end

    test "食物饱食度超过上限时钳制" do
      vitals = %Kantele.Character.Vitals{
        qi: 140,
        max_qi: 150,
        jing: 80,
        max_jing: 100,
        neili: 60,
        max_neili: 100
      }

      stats = %Kantele.Character.Stats{}
      meta = %{food: 100}

      {:ok, result} = Effect.consume(vitals, stats, meta)

      assert result.vitals.qi == 150
      assert result.parts == ["气血+10"]
    end

    test "无食物属性时不提供食物效果" do
      vitals = %Kantele.Character.Vitals{qi: 100, max_qi: 150}
      stats = %Kantele.Character.Stats{}
      meta = %{}

      {:ok, result} = Effect.consume(vitals, stats, meta)

      assert result.food? == false
      assert result.vitals.qi == 100
      assert result.parts == []
    end
  end
end
