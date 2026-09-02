defmodule Kantele.Character.SleepCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SleepCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player() do
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
      skills: %{},
      mapped: %{},
      performs: MapSet.new(),
      combat_exp: 1000,
      score: 0,
      potential: 100,
      weiwang: 0
    }

    combat = Kantele.Character.Combat.new()

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [
        %{
          id: "inst-1",
          item_id: "liuxi:peiyuan_dan",
          item: %{id: "liuxi:peiyuan_dan", name: "培元丹"}
        }
      ],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp build_conn_with_room(p, room) do
    build_conn(p)
    |> Map.put(:private, %{build_conn(p).private | room: room})
  end

  setup do
    peptide_item = %Kalevala.World.Item{
      id: "liuxi:peiyuan_dan",
      name: "培元丹",
      description: "补充气血的丹药",
      meta: %Kantele.World.Item.Meta{
        flag: 1,
        unit: "颗",
        value: 100,
        weight: 10,
        medicine: %{qi: 50, stats: %{str: 1}}
      }
    }

    Kantele.World.Items.put("liuxi:peiyuan_dan", peptide_item)
    :ok
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "sleep 命令" do
    test "非睡眠场所提示" do
      p = player()
      conn = SleepCommand.run(build_conn_with_room(p, %{attrs: %{}}), %{})
      text = output_text(conn)

      assert text =~ "这里不是你能睡的地方"
    end

    test "客栈未付钱提示" do
      p = player()

      conn =
        SleepCommand.run(build_conn_with_room(p, %{attrs: %{"sleep_room" => true, "hotel" => true}}), %{})

      text = output_text(conn)

      assert text =~ "先到一楼付钱后再来睡"
    end

    test "sleep 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("sleep")
      assert parsed.module == SleepCommand
    end

    test "睡觉 路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("睡觉")
      assert parsed.module == SleepCommand
    end
  end
end