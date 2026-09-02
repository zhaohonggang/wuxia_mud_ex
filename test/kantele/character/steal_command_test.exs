defmodule Kantele.Character.StealCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.StealCommand
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
      inventory: [],
      attributes: %{"jing" => 200},
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: combat
      }
    }
  end

  defp player_in_combat() do
    p = player()
    combat = %{p.meta.combat | enemies: [%{id: "npc-1", name: "山贼", room_id: "test:room"}]}
    %{p | meta: %{p.meta | combat: combat}}
  end

  defp player_already_stealing() do
    p = player()
    temp = Map.put(p.meta.temp || %{}, "stealing", true)
    %{p | meta: %{p.meta | temp: temp}}
  end

  defp player_low_jing() do
    p = player()
    %{p | attributes: %{"jing" => 50}}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "steal 命令" do
    test "缺少参数提示格式" do
      p = player()
      conn = StealCommand.run(build_conn(p), %{})
      text = output_text(conn)

      assert text =~ "指令格式：steal"
    end

    test "精神不足不可偷窃" do
      p = player_low_jing()
      conn = StealCommand.run(build_conn(p), %{"item" => "剑", "target" => "张三"})
      text = output_text(conn)

      assert text =~ "难以集中精神"
    end

    test "战斗中不可偷窃" do
      p = player_in_combat()
      conn = StealCommand.run(build_conn(p), %{"item" => "剑", "target" => "山贼"})
      text = output_text(conn)

      assert text =~ "好好打你的架"
    end

    test "正在偷窃时不可再次下手" do
      p = player_already_stealing()
      conn = StealCommand.run(build_conn(p), %{"item" => "剑", "target" => "张三"})
      text = output_text(conn)

      assert text =~ "已经在找机会下手"
    end

    test "偷窃成功发送 steal/attempt 事件" do
      p = player()
      conn = StealCommand.run(build_conn(p), %{"item" => "剑", "target" => "张三"})
      events = Enum.filter(conn.events, fn e -> e.topic == "steal/attempt" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.item == "剑"
      assert event.data.target == "张三"
    end
  end
end