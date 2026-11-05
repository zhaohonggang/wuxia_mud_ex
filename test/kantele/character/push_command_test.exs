defmodule Kantele.Character.PushCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.PushCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kalevala.Event

  @source_room "test:room"
  @target_room "test:target"

  defp player(opts \\ []) do
    force = Keyword.get(opts, :force, 120)
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 2000),
      jingli: 2000,
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: 10000,
      max_jingli: 2000,
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: 5000
    }
    stats = %Stats{
      str: 20,
      dex: 20,
      con: 20,
      int: 20,
      skills: %{"force" => force},
      combat_exp: Keyword.get(opts, :combat_exp, 100),
      score: 0,
      weiwang: 0
    }
    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: @source_room,
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  # 命令按 pid 排除自己，fixture 必须与 self() 不同的 pid；推人目标 pid 取 self()
  # 以便断言 character/teleport 事件投递到测试进程邮箱。
  defp other_pid, do: spawn(fn -> :ok end)

  defp target(opts \\ []) do
    force = Keyword.get(opts, :force, 20)
    %Kalevala.Character{
      id: "target-1",
      name: Keyword.get(opts, :name, "李四"),
      pid: Keyword.get(opts, :pid, other_pid()),
      room_id: @target_room,
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %PlayerMeta{
        vitals: %Vitals{jing: 2000, neili: 9000, qi: 5000, max_qi: 5000},
        stats: %Stats{
          str: 20,
          dex: 20,
          con: 20,
          int: 20,
          skills: %{"force" => force},
          combat_exp: 0
        },
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp source_room(exits \\ %{"north" => @target_room}) do
    %{attrs: %{"exits" => exits}, private: %{characters: []}}
  end

  defp target_room(characters) do
    %{attrs: %{"exits" => %{}}, private: %{characters: characters}}
  end

  defp build(p, opts \\ []) do
    conn = build_conn(p)

    private =
      conn.private
      |> Map.put(:room, Keyword.get(opts, :room, source_room()))
      |> Map.put(:rooms, %{@target_room => Keyword.get(opts, :target_room, target_room([]))})
      |> Map.put(:room_flags, Keyword.get(opts, :room_flags, []))
      |> Map.put(:exit_vetoes, Keyword.get(opts, :exit_vetoes, %{}))

    %{conn | private: private}
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "parse/1 与方向表（LPC sscanf / default_where / default_dirs / default_undirs）" do
    test "标准格式" do
      assert {:ok, "张三", "north"} = PushCommand.parse("张三 to north")
      assert {:ok, "张三", "north"} = PushCommand.parse("  张三   to   NORTH  ")
    end

    test "缺 to / 缺方向 / 多余都报格式错" do
      assert {:error, :format} = PushCommand.parse("张三")
      assert {:error, :format} = PushCommand.parse("张三 to")
      assert {:error, :format} = PushCommand.parse("张三 to north extra")
      assert {:error, :format} = PushCommand.parse(nil)
    end

    test "短别名归一" do
      assert PushCommand.normalize_direction("n") == "north"
      assert PushCommand.normalize_direction("nu") == "northup"
      assert PushCommand.normalize_direction("sw") == "southwest"
      assert PushCommand.normalize_direction("d") == "down"
      assert PushCommand.normalize_direction("enter") == "enter"
    end

    test "去向 / 来向中文" do
      assert PushCommand.direction_name("north") == "北边"
      assert PushCommand.direction_name("up") == "上面"
      assert PushCommand.opposite_name("north") == "南边"
      assert PushCommand.opposite_name("down") == "上面"
    end
  end

  describe "push 命令门控" do
    test "无参数显示指令格式" do
      assert output_text(PushCommand.run(build(player()), %{})) =~ "指令格式"
    end

    test "格式不对显示指令格式" do
      assert output_text(PushCommand.run(build(player()), %{"rest" => "张三"})) =~
               "指令格式"
    end

    test "没有这个方向" do
      conn = build(player(), room: source_room(%{}))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "没有这个方向。"
    end

    test "短别名 n 能解析到 north 出口（无人目标则报没有此人）" do
      conn = build(player(), target_room: target_room([]))
      assert output_text(PushCommand.run(conn, %{"rest" => "张三 to n"})) =~
               "你要推开谁？"
    end

    test "目标房间 no_fight 时禁止推人" do
      conn = build(player(), room_flags: ["no_fight"], target_room: target_room([target()]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "这里不是你嚣张的地方。"
    end

    test "valid_leave 的 notify_fail 原样回显" do
      conn =
        build(player(),
          target_room: target_room([target()]),
          exit_vetoes: %{"north" => "你被一股真气挡住了。\n"}
        )

      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "你被一股真气挡住了。"
    end

    test "目标房间没有此人" do
      conn = build(player(), target_room: target_room([]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "你要推开谁？"
    end

    test "目标正在战斗时拒绝" do
      t = %{target() | meta: %{target().meta | combat: %Kantele.Character.Combat{enemies: [%{pid: other_pid()}]}}}
      conn = build(player(), target_room: target_room([t]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "正在打架呢"
    end

    test "目标是尸体时拒绝" do
      corpse = target(attributes: %{"not_living" => true})
      conn = build(player(), target_room: target_room([corpse]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "没有知觉"
    end

    test "目标非玩家（NPC）时拒绝" do
      npc = %{target() | meta: %{guarder: true}}
      conn = build(player(), target_room: target_room([npc]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "没敢动"
    end

    test "推者 qi < 150 无法推人" do
      conn = build(player(qi: 100), target_room: target_room([target()]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "气力不佳"
    end

    test "推者 neili < 100 无法推人" do
      conn = build(player(neili: 50), target_room: target_room([target()]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "内力不济"
    end

    test "推者 force < 100 无法推人" do
      conn = build(player(force: 50), target_room: target_room([target()]))
      assert output_text(PushCommand.run(conn, %{"rest" => "李四 to north"})) =~
               "内功修为有限"
    end
  end

  describe "push 执行（LPC main 后半段）" do
    test "完整推人：文案 + 推者 qi-100/neili-50/busy(1) + 目标 busy(5) + 瞬移 + 目标房间文案" do
      me = %{player() | pid: other_pid()}
      t = %{target() | pid: self()}
      conn = build(me, target_room: target_room([t]))
      conn = PushCommand.run(conn, %{"rest" => "李四 to north"})

      text = output_text(conn)
      refute text =~ "暂未开放"

      updated = conn.private.update_character
      assert updated.meta.combat.busy == 1
      assert updated.meta.vitals.qi == 4900
      assert updated.meta.vitals.neili == 8950

      # 目标被推入目标房间（character/teleport 事件发给目标 pid = self()）
      assert_received(%Event{topic: "character/teleport", data: %{room_id: @target_room}})
    end

    test "目标 force >= 150 推不动：撞墙文案，推者 busy(1) 与扣费，不瞬移" do
      me = %{player() | pid: other_pid()}
      base = target()
      t = %{base | pid: self(), meta: %{base.meta | stats: %Stats{
        str: 20,
        dex: 20,
        con: 20,
        int: 20,
        skills: %{"force" => 150},
        combat_exp: 0
      }}}
      conn = build(me, target_room: target_room([t]))
      conn = PushCommand.run(conn, %{"rest" => "李四 to north"})

      text = output_text(conn)
      assert text =~ "撞到了一堵墙"
      refute text =~ "暂未开放"

      updated = conn.private.update_character
      assert updated.meta.combat.busy == 1
      assert updated.meta.vitals.qi == 4900

      # 未瞬移：未向目标 pid 投递 character/teleport
      refute_received(%Event{topic: "character/teleport"})
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("push 张三")
      assert parsed.module == PushCommand
    end
  end
end
