defmodule Kantele.Character.RespirateCommandTest do
  use ExUnit.Case, async: true

  alias Kantele.Character.Vitals
  alias Kantele.Character.Stats

  describe "respirate 参数校验" do
    test "jingli 字段存在于 Vitals" do
      vitals = Vitals.new()
      assert Map.has_key?(vitals, :jingli)
      assert Map.has_key?(vitals, :max_jingli)
      assert vitals.jingli == 0
      assert vitals.max_jingli == 0
    end
  end

  describe "respirate_event jingli 转化" do
    test "jingli 增加同时 jing 减少" do
      vitals = %Vitals{
        qi: 150,
        max_qi: 150,
        base_qi: 150,
        jing: 100,
        max_jing: 120,
        base_jing: 120,
        jingli: 0,
        max_jingli: 0,
        neili: 200,
        max_neili: 200,
        base_neili: 200
      }

      # 模拟消耗 30 精，获得 30 jingli
      vitals = %{vitals | jing: vitals.jing - 30, jingli: vitals.jingli + 30}

      assert vitals.jing == 70
      assert vitals.jingli == 30
    end

    test "jing 伤害正常工作" do
      vitals = Vitals.new() |> Map.put(:jing, 100)
      vitals = Vitals.damage(vitals, :jing, 30)
      assert vitals.jing == 70
    end

    test "jingli 伤害正常工作" do
      vitals = Vitals.new() |> Map.put(:jingli, 100)
      vitals = Vitals.damage(vitals, :jingli, 30)
      assert vitals.jingli == 70
    end
  end
end
