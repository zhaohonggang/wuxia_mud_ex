defmodule Kantele.World.RoomActions.Jueqing.UnderyaTest do
  @moduledoc """
  P5-4aq-B：`d/jueqing/underya.c` 的 `do_bao` / `do_climb` / `do_jump`。

  - do_bao "stone"：置 `marks/抱`（再抱提示已抱）
  - do_climb "teng"：瞬移 jueqing:jueqing
  - do_jump "tan"：未抱石 → 置 `tiao` + 排程延时出水（测试内不触发）；
    抱石 → 瞬移 underya2 + 清 `marks/抱`/`tiao`；已置 `tiao`（潜水途中）→ no-op（LPC return 1）
  """
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Jueqing.Underya

  @room "jueqing:underya"

  defp meta(overrides) do
    overrides = if is_list(overrides), do: Map.new(overrides), else: overrides

    vitals =
      Map.merge(
        %{qi: 200, jing: 200, neili: 100, max_neili: 100, max_qi: 200, max_jing: 200},
        Map.get(overrides, :vitals, %{})
      )

    combat =
      %{Combat.new() | busy: Map.get(overrides, :busy, 0), enemies: Map.get(overrides, :enemies, [])}

    %PlayerMeta{vitals: vitals, stats: Stats.new(), combat: combat, temp: %{}}
  end

  defp conn_in(overrides \\ %{}) do
    %Conn{
      character: %Kalevala.Character{
        id: "c1",
        name: "测试",
        description: "测试角色",
        room_id: @room,
        # 延时 fire_effect 按 pid 下发 trap/effect：给 self() 让守卫通过，
        # 消息落进测试进程邮箱无人读取（无害），避免 nil pid 触发 FunctionClauseError。
        pid: self(),
        meta: meta(overrides)
      },
      private: %Private{
        room: %Room{id: @room, key: "r", zone_id: "z", actions: %{}},
        channel_changes: []
      },
      output: [],
      events: []
    }
  end

  defp texts(conn) do
    Enum.flat_map(conn.output, fn
      %Text{data: data} -> [data]
      _ -> []
    end)
  end

  defp temp_of(conn, key) do
    char = conn.private.update_character || conn.character
    Map.get(char.meta.temp, key)
  end

  defp new_room(conn) do
    case conn.private.update_character do
      nil -> nil
      c -> c.room_id
    end
  end

  defp params(verb, arg), do: %{verb: verb, trailing: arg, room_id: @room}

  describe "do_bao（抱石）" do
    test "参数非 stone → 提示" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("bao", "paper"))
      assert texts(conn2) == ["你要抱什么？\n"]
      assert new_room(conn2) == nil
    end

    test "第一次 bao stone → 置 marks/抱" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("bao", "stone"))
      assert Enum.any?(texts(conn2), &String.contains?(&1, "你将大石抱起"))
      assert temp_of(conn2, "marks/抱") == 1
      assert new_room(conn2) == @room
    end

    test "已抱 → 提示已抱（无二次置位）" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("bao", "stone"))
      conn3 = Underya.run(conn2, params("bao", "stone"))
      # output 在同一 conn 上累积，取最后一条
      assert List.last(texts(conn3)) == "你已经抱了一块石头了。\n"
      assert new_room(conn3) == @room
    end
  end

  describe "do_climb（爬藤）" do
    test "参数非 teng → 提示" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("climb", "rock"))
      assert texts(conn2) == ["你要做什么？\n"]
      assert new_room(conn2) == nil
    end

    test "climb teng → 瞬移 jueqing:jueqing" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("climb", "teng"))
      assert Enum.any?(texts(conn2), &String.contains?(&1, "拉着树藤向上爬去"))
      assert new_room(conn2) == "jueqing:jueqing"
    end

    test "别名 pa teng 同效" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("pa", "teng"))
      assert new_room(conn2) == "jueqing:jueqing"
    end
  end

  describe "do_jump（潜水 tan）" do
    test "参数非 tan → 提示" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("jump", "rock"))
      assert texts(conn2) == ["你要往哪儿跳？\n"]
      assert new_room(conn2) == nil
    end

    test "未抱石 jump tan → 潜不下去 + 置 tiao（排程出水，测试内不触发）" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("jump", "tan"))
      assert Enum.any?(texts(conn2), &String.contains?(&1, "四周蓝森森的都是玄冰"))
      assert temp_of(conn2, "tiao") == 1
      assert new_room(conn2) == @room
    end

    test "已置 tiao（潜水途中）再次 jump tan → no-op（LPC return 1）" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("jump", "tan"))
      conn3 = Underya.run(conn2, params("jump", "tan"))
      assert new_room(conn3) == @room
      assert temp_of(conn3, "tiao") == 1
    end

    test "抱石 jump tan → 瞬移 underya2 + 清 marks/抱 与 tiao" do
      conn = conn_in()
      conn2 = Underya.run(conn, params("bao", "stone"))
      conn3 = Underya.run(conn2, params("jump", "tan"))
      assert Enum.any?(texts(conn3), &String.contains?(&1, "过不多时"))
      assert new_room(conn3) == "jueqing:underya2"
      assert temp_of(conn3, "marks/抱") == nil
      assert temp_of(conn3, "tiao") == nil
    end
  end
end
