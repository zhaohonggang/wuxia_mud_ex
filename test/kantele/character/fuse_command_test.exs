defmodule Kantele.Character.FuseCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.FuseCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.Combat

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      neili: Keyword.get(opts, :neili, 5000),
      max_neili: Keyword.get(opts, :max_neili, 6000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{"force" => 350})
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

  defp player_in_combat do
    p = player()
    combat = %{p.meta.combat | enemies: [%{id: "npc-1", name: "山贼", room_id: "test:room"}]}
    %{p | meta: %{p.meta | combat: combat}}
  end

  defp player_busy do
    p = player()
    combat = %{p.meta.combat | busy: 3}
    %{p | meta: %{p.meta | combat: combat}}
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
    test "fuse 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("fuse")
      assert parsed.module == FuseCommand
    end
  end

  describe "fuse 命令" do
    test "无物品时报错" do
      p = player()
      conn = FuseCommand.run(build_conn(p), %{"arg" => ""})
      text = output_text(conn)
      assert text =~ "你要熔炼什么物品"
    end

    test "战斗中拒绝" do
      p = player_in_combat()
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      text = output_text(conn)
      assert text =~ "正在打架"
    end

    test "忙乱中拒绝" do
      p = player_busy()
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      text = output_text(conn)
      assert text =~ "忙完了你的事情"
    end

    test "内功不足300时报错" do
      p = player(skills: %{"force" => 200})
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      text = output_text(conn)
      assert text =~ "内功修为不够"
    end

    test "max_neili不足5000时报错" do
      p = player(max_neili: 3000, neili: 3000)
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      text = output_text(conn)
      assert text =~ "内力修为不够"
    end

    test "neili不足3000时报错" do
      p = player(neili: 2000, max_neili: 6000)
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      text = output_text(conn)
      assert text =~ "内力不足"
    end

    test "条件满足但无物品时报需要提供物品" do
      p = player()
      conn = FuseCommand.run(build_conn(p), %{"arg" => "someitem"})
      text = output_text(conn)
      assert text =~ "需要提供可熔炼的物品"
    end
  end
end
