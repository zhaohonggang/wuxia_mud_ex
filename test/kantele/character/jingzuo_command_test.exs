defmodule Kantele.Character.JingzuoCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.JingzuoCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts \\ []) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
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
      skills: Keyword.get(opts, :skills, %{"force" => 50}),
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    family = Keyword.get(opts, :family, %{name: "峨嵋派", master_id: "wang_chongjiu", master_name: "王重九"})

    meta = %PlayerMeta{
      vitals: vitals,
      stats: stats,
      combat: combat,
      family: family
    }

    meta = if opts[:jingzuo_time] do
      Map.put(meta, :jingzuo_time, opts[:jingzuo_time])
    else
      meta
    end

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: meta
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

  describe "jingzuo 命令" do
    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("jingzuo")
      assert parsed.module == JingzuoCommand
    end

    test "战斗中拒绝静坐" do
      p = player_in_combat()
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "战斗中"
    end

    test "忙乱中拒绝静坐" do
      p = player_busy()
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "正忙着"
    end

    test "非峨嵋派弟子拒绝静坐" do
      p = player(family: %{name: "少林派", master_id: "master1", master_name: "大师"})
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "峨嵋派弟子"
    end

    test "无门派拒绝静坐" do
      p = player(family: nil)
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "峨嵋派弟子"
    end

    test "精力不足拒绝静坐" do
      p = player(jing: 30)
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "无法定心"
    end

    test "冷却中拒绝静坐" do
      p = player(jingzuo_time: System.system_time(:second) - 30)
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "头脑一片空白"
    end

    test "内功不足拒绝静坐" do
      p = player(skills: %{"force" => 30})
      conn = JingzuoCommand.run(build_conn(p), %{})
      text = output_text(conn)
      assert text =~ "内功修为还不够"
    end
  end
end
