defmodule Kantele.Character.BegCommandTest do
  @moduledoc """
  P5 乞讨命令（对应 LPC cmds/std/beg.c）命令层闸门测试。

  覆盖：门派（仅丐帮）、参数格式、硬通货关键字、战斗/忙乱拦截，
  以及合法乞讨向房间发 `beg/attempt` 事件。
  """
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.BegCommand
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp vitals() do
    %Vitals{
      qi: 500,
      max_qi: 500,
      jing: 200,
      max_jing: 200,
      neili: 100,
      max_neili: 100
    }
  end

  defp gaibang() do
    %Kalevala.Character{
      id: "player-1",
      name: "小乞丐",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: %{"jing" => 200},
      meta: %PlayerMeta{
        family: %{name: "丐帮"},
        stats: %Stats{skills: %{}},
        vitals: vitals(),
        combat: Combat.new()
      }
    }
  end

  defp non_gaibang() do
    %{gaibang() | meta: %{gaibang().meta | family: %{name: "武当"}}}
  end

  defp in_combat() do
    p = gaibang()
    combat = %{p.meta.combat | enemies: [%{id: "npc-1", name: "山贼", room_id: "test:room"}]}
    %{p | meta: %{p.meta | combat: combat}}
  end

  defp busy() do
    p = gaibang()
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

  describe "beg 命令" do
    test "非丐帮不可乞讨" do
      conn = BegCommand.run(build_conn(non_gaibang()), %{"coin" => "cash", "target" => "张三"})
      assert output_text(conn) =~ "只有乞丐才能乞讨。"
    end

    test "缺少参数提示格式" do
      conn = BegCommand.run(build_conn(gaibang()), %{})
      assert output_text(conn) =~ "指令格式：beg"
    end

    test "非法财物关键字" do
      conn = BegCommand.run(build_conn(gaibang()), %{"coin" => "apple", "target" => "张三"})
      assert output_text(conn) =~ "你只能乞讨硬通货。"
    end

    test "战斗中不可乞讨" do
      conn = BegCommand.run(build_conn(in_combat()), %{"coin" => "cash", "target" => "山贼"})
      assert output_text(conn) =~ "你还是先把你面前的家伙放倒再说吧。"
    end

    test "忙乱中不可乞讨" do
      conn = BegCommand.run(build_conn(busy()), %{"coin" => "cash", "target" => "张三"})
      assert output_text(conn) =~ "你现在正忙着呢。"
    end

    test "合法乞讨发送 beg/attempt 事件" do
      conn = BegCommand.run(build_conn(gaibang()), %{"coin" => "cash", "target" => "张三"})

      events = Enum.filter(conn.events, fn e -> e.topic == "beg/attempt" end)
      assert length(events) == 1
      event = hd(events)
      assert event.data.coin == "cash"
      assert event.data.target == "张三"
    end
  end
end
