defmodule Kantele.Combat.SimpleTest.BuffExert do
  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "test/buff",
      gates: [
        {:neili_min, 100, "你的内力不够！\n"},
        {:skill_min, "force", 50, "你的内功修为不够。\n"},
        {:no_buff, "test-buff", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "test-buff", %{attack: 20, defense: 10}},
        {:temp, %{dodge: 5}}
      ],
      busy: {:if_fighting, 3},
      message: "$N运起测试功。\n"
    }
end

defmodule Kantele.Combat.SimpleTest.SetNeiliExert do
  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "test/set-neili",
      effects: [{:set, :neili, 0}, {:message, "$N散去内力。\n"}]
    }
end

defmodule Kantele.Combat.SimpleTest.CustomGateExert do
  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "test/custom",
      gates: [{:custom, fn ctx -> ctx.vitals.neili >= 5000 end, "内力不足五千。\n"}],
      effects: [{:add, :neili, -1}],
      message: "散功。\n"
    }
end

defmodule Kantele.Combat.SimpleTest.ScaledExert do
  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "test/scaled",
      costs: %{neili: 100},
      effects: [
        {:buff, "scaled", %{
          attack: {:div, {:skill, "force"}, 2},
          defense: {:div, {:mul, {:skill, "force"}, 2}, 5}
        }},
        {:add, :neili, {:random, -5, -1}}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: 1,
      expire_message: "运功完毕。\n",
      message: "$N运功。\n"
    }
end

defmodule Kantele.Combat.SimpleTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs.Simple
  alias Kantele.Combat.Performs.Spec
  alias Kantele.Combat.SimpleTest.BuffExert
  alias Kantele.Combat.SimpleTest.CustomGateExert
  alias Kantele.Combat.SimpleTest.ScaledExert
  alias Kantele.Combat.SimpleTest.SetNeiliExert

  defp player(opts) do
    skills = Keyword.get(opts, :skills, %{"force" => 250})
    mapped = Keyword.get(opts, :mapped, %{})

    stats =
      struct(Kantele.Character.Stats.new(), %{
        skills: skills,
        mapped: mapped,
        performs: MapSet.new()
      })

    vitals = %{Vitals.new() | neili: Keyword.get(opts, :neili, 9000), max_neili: 10000}

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %Kantele.Character.PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new())
      }
    }
  end

  defp combat_fight do
    %{Combat.new() | enemies: [%{id: "e1", pid: self(), name: "敌", room_id: "test:room"}]}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn change ->
      match?({:publish, _, %Kalevala.Event{topic: Kalevala.Event.Message}, _, _}, change)
    end)
    |> Enum.map(fn {:publish, _channel, event, _opts, _error} -> event.data.text end)
    |> Enum.join("")
  end

  describe "Spec" do
    test "new/1 默认值 + 未知键报错" do
      spec = Spec.new(id: "x")
      assert spec.kind == :exert
      assert spec.costs == %{}
      assert spec.busy == 0

      assert_raise KeyError, fn -> Spec.new(bogus: 1) end
    end

    test "__using__ 注入 spec/0 与 run/1" do
      assert BuffExert.spec().id == "test/buff"
      assert function_exported?(BuffExert, :run, 1)
    end
  end

  describe "生效" do
    test "扣消耗 + buff/temp 加成 + 文案" do
      conn = BuffExert.run(build_conn(player(neili: 9000)))
      char = conn.private.update_character

      assert char.meta.vitals.neili == 8900
      assert char.meta.combat.temp.attack == 20
      assert char.meta.combat.temp.defense == 10
      assert char.meta.combat.temp.dodge == 5
      assert Combat.buff_active?(char.meta.combat, "test-buff")

      buff = Enum.find(char.meta.combat.buffs, &(&1.key == "test-buff"))
      assert buff.applies == %{attack: -20, defense: -10}

      assert published_text(conn) =~ "运起测试功"
      assert conn.assigns[:prompt] == false
    end

    test "非战斗 busy 不生效；战斗中 busy +3" do
      assert BuffExert.run(build_conn(player(neili: 9000))).private.update_character.meta.combat.busy == 0

      conn = BuffExert.run(build_conn(player(neili: 9000, combat: combat_fight())))
      assert conn.private.update_character.meta.combat.busy == 3
    end

    test "{:set, :neili, 0} 清空内力量" do
      conn = SetNeiliExert.run(build_conn(player(neili: 7777)))
      assert conn.private.update_character.meta.vitals.neili == 0
      assert published_text(conn) =~ "散去内力"
    end

    test "值表达式按状态求值（skill/div/mul/random）" do
      conn = Simple.run(build_conn(player(neili: 9000)), ScaledExert.spec(), fn _n -> 1 end)
      char = conn.private.update_character

      # 扣 100 → 8900，再 {:add, :neili, {:random, -5, -1}}；rng=1 → -5
      assert char.meta.vitals.neili == 8895
      assert char.meta.combat.temp.attack == 125
      assert char.meta.combat.temp.defense == 100

      buff = Enum.find(char.meta.combat.buffs, &(&1.key == "scaled"))
      assert buff.applies == %{attack: -125, defense: -100}
    end

    test "random busy 由 rng 决定；非战斗不计" do
      conn = Simple.run(build_conn(player(neili: 9000, combat: combat_fight())), ScaledExert.spec(), fn _n -> 3 end)
      assert conn.private.update_character.meta.combat.busy == 3

      conn = Simple.run(build_conn(player(neili: 9000)), ScaledExert.spec(), fn _n -> 3 end)
      assert conn.private.update_character.meta.combat.busy == 0
    end

    test "duration 到期投递 combat/buff-expire" do
      Simple.run(build_conn(player(neili: 9000)), ScaledExert.spec(), fn _n -> 1 end)

      assert_receive %Kalevala.Event{topic: "combat/buff-expire", data: %{key: "scaled"}}, 1500
    end
  end

  describe "门槛" do
    test "neili_min 不足：渲染文案、不落库" do
      conn = BuffExert.run(build_conn(player(neili: 50)))

      assert output_text(conn) =~ "你的内力不够"
      assert is_nil(conn.private.update_character)
      assert conn.assigns[:prompt] == false
    end

    test "skill_min 不足" do
      conn = BuffExert.run(build_conn(player(skills: %{"force" => 10})))
      assert output_text(conn) =~ "你的内功修为不够"
    end

    test "no_buff 已在运功中拒绝" do
      combat = %{Combat.new() | buffs: [%Combat.Buff{key: "test-buff", applies: []}]}
      conn = BuffExert.run(build_conn(player(combat: combat)))
      assert output_text(conn) =~ "你已经在运功中了"
    end

    test "custom 门槛拿到 ctx" do
      pass = CustomGateExert.run(build_conn(player(neili: 9000)))
      assert pass.private.update_character.meta.vitals.neili == 8999

      fail = CustomGateExert.run(build_conn(player(neili: 100)))
      assert output_text(fail) =~ "内力不足五千"
      assert is_nil(fail.private.update_character)
    end
  end
end
