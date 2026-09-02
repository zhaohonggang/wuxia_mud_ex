defmodule Kantele.Character.BurningCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BurningCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10000,
      max_jingli: 2000,
      qi: 5000,
      max_qi: 5000
    }

    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: Keyword.get(opts, :skills, %{"force" => 350}),
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
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
        combat: Kantele.Character.Combat.new(),
        damage: Keyword.get(opts, :damage, %{}),
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "路由解析" do
    test "burning 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("burning")
      assert parsed.module == BurningCommand
    end

    test "fenu 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("fenu")
      assert parsed.module == BurningCommand
    end
  end

  describe "burning 前置检查" do
    test "已经处于怒火中拒绝再燃" do
      p = player(damage: %{craze: 5000}, temp: %{"burning_up" => 70})
      conn = BurningCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "怒火中"
      assert output_text(conn) =~ "没有必要再发作"
    end

    test "愤怒值不足拒绝" do
      p = player(damage: %{craze: 500})
      conn = BurningCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "不够愤怒"
      assert output_text(conn) =~ "无法让自己怒火燃烧"
    end
  end

  describe "burning 成功" do
    test "消耗愤怒值并设置 burning_up 状态" do
      p = player(damage: %{craze: 5000}, skills: %{"force" => 350})
      conn = BurningCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "大吼"
      assert text =~ "精光四射"

      updated = conn.private.update_character || conn.character
      assert updated.meta.temp["burning_up"] != nil
      assert is_integer(updated.meta.temp["burning_up"])

      new_craze = (updated.meta.damage || %{})[:craze] || 0
      assert new_craze < 5000
      assert new_craze >= 5000 - 800
    end

    test "force 越高燃烧层数越多" do
      p1 = player(damage: %{craze: 5000}, skills: %{"force" => 50})
      c1 = BurningCommand.run(build_conn(p1), %{})
      u1 = c1.private.update_character || c1.character

      p2 = player(damage: %{craze: 5000}, skills: %{"force" => 350})
      c2 = BurningCommand.run(build_conn(p2), %{})
      u2 = c2.private.update_character || c2.character

      assert u2.meta.temp["burning_up"] > u1.meta.temp["burning_up"]
    end
  end
end