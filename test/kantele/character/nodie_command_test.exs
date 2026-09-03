defmodule Kantele.Character.NodieCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.NodieCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(attrs \\ %{}) do
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      attributes: Map.get(attrs, :attributes, %{}),
      meta: %PlayerMeta{
        vitals: %{
          Vitals.new()
          | qi: 30,
            max_qi: 150,
            jing: 20,
            max_jing: 120,
            neili: 10,
            max_neili: 200
        },
        stats: Stats.new(),
        combat: Kantele.Character.Combat.new()
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

  test "普通玩家无权限" do
    conn = NodieCommand.run(build_conn(player()), %{})
    assert output_text(conn) =~ "没有巫师的权限"
  end

  test "巫师恢复满状态并挂起死亡保护" do
    p = player(%{attributes: %{"wiz_level" => 1}})
    conn = NodieCommand.run(build_conn(p), %{})
    p = conn.private.update_character || conn.character

    vitals = p.meta.vitals
    assert vitals.qi == 150
    assert vitals.jing == 120
    assert vitals.jingli == vitals.max_jingli
    assert vitals.neili == 200

    assert PlayerMeta.get_temp(p.meta, "guard_death") == 1
  end

  test "已处于死亡保护时不重复挂起" do
    p = player(%{attributes: %{"wiz_level" => 1}})
    p = %{p | meta: PlayerMeta.put_temp(p.meta, "guard_death", 1)}

    conn = NodieCommand.run(build_conn(p), %{})
    assert output_text(conn) =~ "已处于死亡保护状态"
  end
end