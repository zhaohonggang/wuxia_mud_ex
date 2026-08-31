defmodule Kantele.Batch6Test do
  use ExUnit.Case, async: true

  alias Kantele.Character.Conditions
  alias Kantele.Character.Encumbrance
  alias Kantele.Object.CleanUp
  alias Kantele.Util.Shadow

  describe "Encumbrance (move.c 负重)" do
    test "weight() = weight + encumb" do
      s = %Encumbrance{weight: 10, encumb: 5}
      assert Encumbrance.weight(s) == 15
      assert Encumbrance.query_encumbrance(s) == 5
      assert Encumbrance.query_max_encumbrance(s) == 0
    end

    test "over_encumbranced?" do
      s = %Encumbrance{encumb: 11, max_encumb: 10}
      assert Encumbrance.over_encumbranced?(s)
      s2 = %Encumbrance{encumb: 10, max_encumb: 10}
      refute Encumbrance.over_encumbranced?(s2)
    end

    test "add_encumbrance 触发 on_over 回调" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      s = %Encumbrance{encumb: 8, max_encumb: 10}
      s2 = Encumbrance.add_encumbrance(s, 5, on_over: fn -> Agent.update(agent, &(&1 + 1)) end)
      assert Encumbrance.query_encumbrance(s2) == 13
      assert Agent.get(agent, & &1) == 1
    end

    test "add_encumbrance 不重复触发" do
      {:ok, agent} = Agent.start_link(fn -> 0 end)

      s =
        Encumbrance.add_encumbrance(%Encumbrance{encumb: 8, max_encumb: 10}, 5,
          on_over: fn -> Agent.update(agent, &(&1 + 1)) end
        )

      s = Encumbrance.add_encumbrance(s, 1, on_over: fn -> Agent.update(agent, &(&1 + 1)) end)
      assert Agent.get(agent, & &1) == 1
    end

    test "set_weight 返回差额联动" do
      s = %Encumbrance{weight: 10}
      {s2, delt} = Encumbrance.set_weight(s, 15)
      assert delt == 5
      assert s2.weight == 15
      {_s3, delt0} = Encumbrance.set_weight(s, 10)
      assert delt0 == 0
    end

    test "move_in/out weight" do
      s = %Encumbrance{weight: 10, encumb: 5}
      assert Encumbrance.move_out_weight(s) == -15
      assert Encumbrance.move_in_weight(s) == 15
    end
  end

  describe "Conditions (condition.c 通用化)" do
    defmodule DemoCond do
      def update_condition(%{hits: h} = info) do
        if h <= 0, do: {:expire}, else: {:continue, %{info | hits: h - 1}}
      end

      def do_effect(state, _cnd, _para), do: {:effect, Map.get(state, :hp, 0)}
    end

    test "apply/query/clear" do
      s = Conditions.apply_condition(%{}, "poison", %{hits: 3})
      assert Conditions.query_condition(s, "poison") == %{hits: 3}
      assert map_size(Conditions.query_condition(s)) == 1
      s2 = Conditions.clear_condition(s, "poison")
      assert Conditions.query_condition(s2, "poison") == nil
    end

    test "clear nil 清空全部" do
      s = Conditions.apply_condition(%{}, "a", 1) |> Conditions.apply_condition("b", 2)
      s = Conditions.apply_condition(s, "b", 2)
      assert map_size(Conditions.query_condition(s)) == 2
      assert Conditions.clear_condition(s, nil) == %{}
    end

    test "update_condition 迭代/到期/失败移除" do
      s = Conditions.apply_condition(%{}, "poison", %{hits: 1})

      daemon = fn
        "poison" -> {:ok, DemoCond}
        _ -> :error
      end

      {s2, live} = Conditions.update_condition(s, daemon)
      assert live
      assert Conditions.query_condition(s2, "poison") == %{hits: 0}

      {s3, live2} = Conditions.update_condition(s2, daemon)
      refute live2
      assert Conditions.query_condition(s3, "poison") == nil
    end

    test "update_condition 无法解析 -> 移除" do
      s = %{conditions: %{"gone" => 1}}
      {s2, live} = Conditions.update_condition(s, fn _ -> :error end)
      refute live
      assert s2.conditions == nil
    end

    test "affect_by 调用 do_effect + piyi 免疫" do
      s = Conditions.apply_condition(%{hp: 50}, "poison", %{hits: 1})

      assert Conditions.affect_by(
               s,
               fn
                 "poison" -> {:ok, DemoCond}
                 _ -> :error
               end,
               "poison",
               nil
             ) == {:ok, {:effect, 50}}

      immune = %{special_skill: %{piyi: true}}

      assert Conditions.affect_by(
               immune,
               fn
                 "poison" -> {:ok, DemoCond}
                 _ -> :error
               end,
               "poison",
               nil
             ) == {:immune}
    end
  end

  describe "CleanUp (clean_up.c)" do
    test "决定保留项" do
      assert CleanUp.decide(%{
               is_clone?: true,
               no_clean_up: 0,
               interactive?: true,
               quest_ob?: false,
               environment: nil,
               occupants: []
             }) == :again

      assert CleanUp.decide(%{
               is_clone?: false,
               no_clean_up: 1,
               interactive?: true,
               quest_ob?: false,
               environment: nil,
               occupants: []
             }) == :again

      assert CleanUp.decide(%{
               is_clone?: true,
               no_clean_up: 0,
               interactive?: false,
               quest_ob?: true,
               environment: nil,
               occupants: []
             }) == :again

      assert CleanUp.decide(%{
               is_clone?: true,
               no_clean_up: 0,
               interactive?: false,
               quest_ob?: false,
               environment: %{id: "r"},
               occupants: []
             }) == :again
    end

    test "环境有玩家/stay_in_room -> 保留" do
      assert CleanUp.decide(%{
               is_clone?: true,
               no_clean_up: 0,
               interactive?: false,
               quest_ob?: false,
               environment: nil,
               occupants: [%{interactive: true}]
             }) == :again

      assert CleanUp.decide(%{
               is_clone?: true,
               no_clean_up: 0,
               interactive?: false,
               quest_ob?: false,
               environment: nil,
               occupants: [%{stay_in_room: true}]
             }) == :again
    end

    test "无保留因素 -> never_again（清场）" do
      assert CleanUp.decide(%{
               is_clone?: true,
               no_clean_up: 0,
               interactive?: false,
               quest_ob?: false,
               environment: nil,
               occupants: []
             }) == :never_again
    end
  end

  describe "Shadow (shadow.c)" do
    test "do_shadow/query_shadow_now" do
      {s, _} = Shadow.do_shadow(%{}, :target)
      assert Shadow.query_shadow_now(s) == :target
    end

    test "remove_shadow 同目标清空/异目标保留" do
      {s, _} = Shadow.do_shadow(%{}, :target)
      {s2, r} = Shadow.remove_shadow(s, :target)
      assert r == :removed
      assert Shadow.query_shadow_now(s2) == nil

      {s, _} = Shadow.do_shadow(%{}, :target)
      {_s3, r2} = Shadow.remove_shadow(s, :other)
      assert r2 == :keep
    end
  end
end
