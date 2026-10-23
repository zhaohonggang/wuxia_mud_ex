defmodule Kantele.World.RoomActions.Jueqing.DuanchangTest do
  @moduledoc """
  P5-4aq-B：`d/jueqing/duanchang.c` 的 `do_jump`（tiao/jump）两步跳崖。

  - 第一次 `jump ya` → 确认提示 + 置 `marks/跳`
  - 第二次（已置标记）→ 跃崖文案 + `:timer.apply_after` 排程延时 `trap/effect`
    （落到 underya + 昏厥）。测试进程内定时器不触发，故标记保留、瞬移不发生。
  """
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kalevala.Character.Conn.Private
  alias Kalevala.Character.Conn.Text
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Jueqing.Duanchang

  @room "jueqing:duanchang"

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

  defp params(verb, arg), do: %{verb: verb, trailing: arg, room_id: @room}

  describe "do_jump（tiao/jump）" do
    test "参数非 ya/down → 私发提示，不置标记" do
      conn = conn_in()
      conn2 = Duanchang.run(conn, params("jump", "foo"))
      assert texts(conn2) == ["你要做什么？\n"]
      assert temp_of(conn2, "marks/跳") == nil
    end

    test "第一次 jump ya → 确认提示 + 置 marks/跳（未真正跳）" do
      conn = conn_in()
      conn2 = Duanchang.run(conn, params("jump", "ya"))
      assert Enum.any?(texts(conn2), &String.contains?(&1, "你真的要跳下断肠崖吗"))
      assert temp_of(conn2, "marks/跳") == 1
    end

    test "第二次（已置标记）jump ya → 跃崖文案 + 排程延时坠落（测试内定时器不触发）" do
      conn = conn_in()
      conn2 = Duanchang.run(conn, params("jump", "ya"))
      conn3 = Duanchang.run(conn2, params("jump", "ya"))
      assert Enum.any?(texts(conn3), &String.contains?(&1, "纵身一跃跳下断肠崖"))
      # 标记在 fire_effect 真正执行时才删，测试内定时器未触发，故仍保留
      assert temp_of(conn3, "marks/跳") == 1
    end

    test "别名 tiao ya 与 jump ya 同效" do
      conn = conn_in()
      conn2 = Duanchang.run(conn, params("tiao", "ya"))
      assert temp_of(conn2, "marks/跳") == 1
    end

    test "busy 守卫" do
      conn = conn_in(busy: 5)
      conn2 = Duanchang.run(conn, params("jump", "ya"))
      assert texts(conn2) == ["你现在正忙着呢！\n"]
      assert temp_of(conn2, "marks/跳") == nil
    end

    test "fighting 守卫" do
      conn = conn_in(enemies: ["x"])
      conn2 = Duanchang.run(conn, params("jump", "ya"))
      assert texts(conn2) == ["你还是先把你面前这个家伙解决了再说。\n"]
      assert temp_of(conn2, "marks/跳") == nil
    end
  end
end
