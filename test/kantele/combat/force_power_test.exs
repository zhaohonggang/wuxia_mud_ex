defmodule Kantele.Combat.ForcePowerTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.Combat
  alias Kantele.Character.ExertCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Skills
  alias Kantele.Combat.Skills.Performs.Force.Power

  defp player(opts) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 0,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000,
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: 10000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: Keyword.get(opts, :skills, %{"force" => 250, "martial-cognize" => 130}),
      mapped: Keyword.get(opts, :mapped, %{}),
      performs: MapSet.new(),
      combat_exp: 1_000_000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
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

  describe "force 技能注册" do
    test "Skills 注册表含 force，exert_list 挂 Power" do
      assert Skills.known?("force")
      assert Map.get(Skills.get("force").exert_list(), "power") == Power
    end
  end

  describe "Power.run 门槛" do
    test "内力 <100" do
      p = player(neili: 50)
      conn = Power.run(build_conn(p))
      assert output_text(conn) =~ "你的内力不够"
      assert conn.character.meta.vitals.neili == 50
    end

    test "基本内功 <200" do
      p = player(skills: %{"force" => 150, "martial-cognize" => 130})
      conn = Power.run(build_conn(p))
      assert output_text(conn) =~ "内功修为不够"
    end

    test "武学修养 <120" do
      p = player(skills: %{"force" => 250, "martial-cognize" => 100})
      conn = Power.run(build_conn(p))
      assert output_text(conn) =~ "武学修养不够"
    end
  end

  describe "Power.run 生效" do
    test "成功：内力量清零 + 攻防加成 + Buff 记状态（非战斗不 busy）" do
      p =
        player(
          mapped: %{"sword" => "huashan-jian"},
          skills: %{"force" => 250, "martial-cognize" => 130, "huashan-jian" => 300}
        )

      conn = Power.run(build_conn(p))
      char = conn.private.update_character

      assert char.meta.vitals.neili == 0
      assert char.meta.combat.temp.attack == div(130, 5)
      assert char.meta.combat.temp.defense == div(130, 5)
      assert Combat.buff_active?(char.meta.combat, "force-power")
      assert char.meta.combat.busy == 0
    end

    test "战斗中运功：busy +3" do
      p = player(combat: combat_fight())
      conn = Power.run(build_conn(p))
      assert conn.private.update_character.meta.combat.busy == 3
    end

    test "已在运功中则拒绝" do
      combat = %{Combat.new() | buffs: [%Combat.Buff{key: "force-power", applies: []}]}
      p = player(combat: combat)
      conn = Power.run(build_conn(p))
      assert output_text(conn) =~ "你已经在运功中了"
      assert conn.character.meta.vitals.neili == 9000
    end
  end

  describe "ExertCommand 公共运功 fallback" do
    test "无内功映射时经 force 共用运功也能 exert power" do
      p = player(mapped: %{})
      conn = ExertCommand.run(build_conn(p), %{"function" => "power"})
      assert conn.private.update_character.meta.vitals.neili == 0
    end

    test "公共运功表里没有该功能仍报错" do
      p = player(mapped: %{})
      conn = ExertCommand.run(build_conn(p), %{"function" => "powerup"})
      assert output_text(conn) =~ "你不会这种运功方法"
    end
  end
end