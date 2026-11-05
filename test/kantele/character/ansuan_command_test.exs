defmodule Kantele.Character.AnsuanCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kantele.Character.AnsuanCommand
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @source_room "test:room"
  @target_room "test:target"

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
      skills: %{},
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

  # 命令按 pid 排除自己， fixture 必须用与 self() 不同的 pid。
  defp other_pid, do: spawn(fn -> :ok end)

  defp target(opts \\ []) do
    %Kalevala.Character{
      id: "target-1",
      name: Keyword.get(opts, :name, "李四"),
      pid: Keyword.get(opts, :pid, other_pid()),
      room_id: @target_room,
      attributes: Keyword.get(opts, :attributes, %{}),
      inventory: [],
      meta: %PlayerMeta{
        vitals: %Vitals{jing: 2000, neili: 9000, qi: 5000, max_qi: 5000},
        stats: %Stats{str: 20, dex: 20, con: 20, int: 20, skills: %{}, combat_exp: 0},
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
      assert {:ok, "李四", "north"} = AnsuanCommand.parse("李四 at north")
      assert {:ok, "李四", "n"} = AnsuanCommand.parse("  李四   at   N  ")
    end

    test "缺 at / 缺方向 / 多词都报格式错" do
      assert {:error, :format} = AnsuanCommand.parse("李四")
      assert {:error, :format} = AnsuanCommand.parse("李四 at")
      assert {:error, :format} = AnsuanCommand.parse("李四 at north east")
      assert {:error, :format} = AnsuanCommand.parse(nil)
    end

    test "短别名归一" do
      assert AnsuanCommand.normalize_direction("n") == "north"
      assert AnsuanCommand.normalize_direction("nu") == "northup"
      assert AnsuanCommand.normalize_direction("sw") == "southwest"
      assert AnsuanCommand.normalize_direction("d") == "down"
      assert AnsuanCommand.normalize_direction("enter") == "enter"
    end

    test "去向 / 来向中文" do
      assert AnsuanCommand.direction_name("north") == "北边"
      assert AnsuanCommand.direction_name("up") == "上面"
      assert AnsuanCommand.opposite_name("north") == "南边"
      assert AnsuanCommand.opposite_name("down") == "上面"
    end
  end

  describe "ansuan 命令门控" do
    test "无参数显示指令格式" do
      assert output_text(AnsuanCommand.run(build(player()), %{})) =~ "指令格式"
    end

    test "格式不对显示指令格式" do
      assert output_text(AnsuanCommand.run(build(player()), %{"rest" => "李四"})) =~
               "指令格式"
    end

    test "没有这个方向" do
      conn = build(player(), room: source_room(%{}))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~
               "没有这个方向。"
    end

    test "短别名 n 能解析到 north 出口" do
      conn = build(player(), target_room: target_room([]))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at n"})) =~
               "这个方向没有此人。"
    end

    test "目标房间 no_fight 时禁止暗算" do
      conn = build(player(), room_flags: ["no_fight"], target_room: target_room([target()]))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~
               "那里禁止战斗。"
    end

    test "valid_leave 的 notify_fail 原样回显" do
      conn =
        build(player(),
          target_room: target_room([target()]),
          exit_vetoes: %{"north" => "你被一股真气挡住了。\n"}
        )

      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~
               "你被一股真气挡住了。"
    end

    test "jing 不足 100 无法集中精力" do
      conn = build(player(jing: 50), target_room: target_room([target()]))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~
               "无法集中精力"
    end

    test "目标房间没有这个人" do
      conn = build(player(), target_room: target_room([]))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~
               "这个方向没有此人。"
    end

    test "目标是尸体时拒绝" do
      corpse = target(attributes: %{"not_living" => true})
      conn = build(player(), target_room: target_room([corpse]))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~
               "都已经这样了"
    end
  end

  describe "ansuan 执行（LPC main 后半段）" do
    test "完整暗算：文案 + 收尾 start_busy(3) 与 jing -50" do
      conn = build(player(), target_room: target_room([target()]))
      conn = AnsuanCommand.run(conn, %{"rest" => "李四 at north"})
      text = output_text(conn)

      assert text =~ "你摒息静气"
      assert text =~ "向#{AnsuanCommand.direction_name("north")}的李四扑去"
      assert text =~ "一条人影"
      refute text =~ "暂未开放"

      updated = conn.private.update_character
      assert updated.meta.combat.busy == 3
      assert updated.meta.vitals.jing == 1950
    end

    test "女性暗算者使用「倩影」" do
      p = player()
      meta = Map.put(p.meta, :env, %{"gender" => "女性"})
      p = %{p | meta: meta}

      conn = build(p, target_room: target_room([target()]))
      assert output_text(AnsuanCommand.run(conn, %{"rest" => "李四 at north"})) =~ "一条倩影"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("ansuan 李四")
      assert parsed.module == AnsuanCommand
    end
  end
end
