defmodule Kantele.Character.ClosedCommandTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest
  import Kalevala.Character.Conn

  alias Kalevala.Character
  alias Kalevala.Event
  alias Kantele.Character.Closed
  alias Kantele.Character.ClosedCommand
  alias Kantele.Character.ClosedStepEvent
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(opts) do
    vitals = %Vitals{
      jing: Keyword.get(opts, :jing, 5000),
      jingli: Keyword.get(opts, :jingli, 2000),
      neili: Keyword.get(opts, :neili, 9000),
      max_neili: Keyword.get(opts, :max_neili, 10000),
      max_jing: Keyword.get(opts, :max_jing, 5000),
      max_jingli: Keyword.get(opts, :max_jingli, 2000),
      qi: Keyword.get(opts, :qi, 5000),
      max_qi: Keyword.get(opts, :max_qi, 5000)
    }

    stats = %Stats{
      str: Keyword.get(opts, :str, 20),
      dex: Keyword.get(opts, :dex, 20),
      con: Keyword.get(opts, :con, 20),
      int: Keyword.get(opts, :int, 20),
      skills: Keyword.get(opts, :skills, %{}),
      combat_exp: Keyword.get(opts, :combat_exp, 0),
      score: Keyword.get(opts, :score, 0),
      potential: Keyword.get(opts, :potential, 0),
      learned_points: Keyword.get(opts, :learned_points, 0),
      weiwang: Keyword.get(opts, :weiwang, 0)
    }

    %Character{
      id: Keyword.get(opts, :id, "player-1"),
      name: Keyword.get(opts, :name, "张三"),
      pid: self(),
      room_id: "test:room",
      inventory: [],
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Keyword.get(opts, :combat, Combat.new()),
        family: Keyword.get(opts, :family, nil)
      }
    }
  end

  defp busy_combat, do: %{Combat.new() | busy: 5}
  defp fighting_combat, do: %{Combat.new() | enemies: ["someone"]}

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp with_room_flags(conn, flags),
    do: Map.put(conn, :private, Map.put(conn.private, :closed_room_flags, flags))

  defp set_private(conn, key, value),
    do: Map.put(conn, :private, Map.put(conn.private, key, value))

  # ---------------------------------------------------------------------------
  # 门槛（Closed.gate）
  # ---------------------------------------------------------------------------

  describe "门槛（Closed.gate）" do
    test "忙碌时拒绝" do
      p = player(combat: busy_combat(), family: %{name: "武当派"}, potential: 20000)
      assert Closed.gate(p, ["no_fight"]) == {:error, "你现在正忙着呢。\n"}
    end

    test "战斗时拒绝" do
      p = player(combat: fighting_combat(), family: %{name: "武当派"}, potential: 20000)
      assert Closed.gate(p, ["no_fight"]) == {:error, "战斗中不能闭关。\n"}
    end

    test "无门派拒绝" do
      p = player(potential: 20000)
      assert Closed.gate(p, ["no_fight"]) == {:error, "你还没有拜师，无法闭关修行。\n"}
    end

    test "潜能不足拒绝" do
      p = player(family: %{name: "武当派"}, potential: 5000)
      assert {:error, msg} = Closed.gate(p, ["no_fight"])
      assert msg =~ "潜能不够"
    end

    test "气不足拒绝" do
      p = player(family: %{name: "武当派"}, potential: 20000, qi: 1000, max_qi: 5000)
      assert {:error, msg} = Closed.gate(p, ["no_fight"])
      assert msg =~ "气太少"
    end

    test "精不足拒绝" do
      p = player(family: %{name: "武当派"}, potential: 20000, jing: 1000, max_jing: 5000)
      assert {:error, msg} = Closed.gate(p, ["no_fight"])
      assert msg =~ "精太少"
    end

    test "非 no_fight 房间拒绝" do
      p = player(family: %{name: "武当派"}, potential: 20000)
      assert {:error, msg} = Closed.gate(p, [])
      assert msg =~ "不太安全"
    end

    test "全部满足通过" do
      p = player(family: %{name: "武当派"}, potential: 20000)
      assert Closed.gate(p, ["no_fight"]) == {:ok, p}
    end
  end

  # ---------------------------------------------------------------------------
  # 每拍转化（Closed.tick）
  # ---------------------------------------------------------------------------

  describe "每拍转化（Closed.tick）" do
    test "潜能耗尽返回 done" do
      p = player(family: %{name: "武当派"}, potential: 0, learned_points: 0)
      assert {:done, _char, msgs} = Closed.tick(p, fn _ -> 0 end)
      assert Enum.any?(msgs, &String.contains?(&1, "潜能耗尽"))
    end

    test "正常转化消耗潜能并增长 combat_exp 与技能" do
      p =
        player(
          family: %{name: "武当派"},
          potential: 20000,
          learned_points: 0,
          combat_exp: 100,
          skills: %{"sword" => 60, "force" => 20}
        )

      {:ok, new_char, _msgs} = Closed.tick(p, fn _ -> 0 end)

      new_stats = new_char.meta.stats
      assert Stats.available_potential(new_stats) < 20000
      assert new_stats.combat_exp > 100
      # 仅一项武学技能 +5（rng=0 选中迭代顺序中的第一个候选）
      assert new_stats.skills["sword"] + new_stats.skills["force"] == 85
    end
  end

  # ---------------------------------------------------------------------------
  # closed 命令
  # ---------------------------------------------------------------------------

  describe "closed 命令" do
    test "无师门时提示" do
      p = player(family: nil)
      conn = ClosedCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "没有拜师"
    end

    test "潜能不足时提示" do
      p = player(family: %{name: "武当派"}, potential: 5000)
      conn = ClosedCommand.run(build_conn(p), %{})
      assert output_text(conn) =~ "潜能不够"
    end

    test "路由解析" do
      {:ok, parsed} = Kantele.Character.Commands.parse("closed")
      assert parsed.module == ClosedCommand
    end

    test "条件满足时开始闭关并排程心跳" do
      p = player(family: %{name: "武当派"}, potential: 20000)
      conn = build_conn(p) |> with_room_flags(["no_fight"]) |> set_private(:closed_tick, 0)
      out = ClosedCommand.run(conn, %{})

      assert output_text(out) =~ "开始冥神运功"
      assert get_session(out, :closed) != nil
      assert_receive %Event{topic: "character/closed_step"}, 200
    end

    test "中途 stop 出关并返还一半已耗潜能" do
      p =
        player(
          family: %{name: "武当派"},
          potential: 10000,
          learned_points: 12000
        )

      conn = build_conn(p) |> put_session(:closed, %{started_at: 0})
      out = ClosedCommand.run(conn, %{"rest" => "stop"})

      assert output_text(out) =~ "你中止了闭关"
      assert get_session(out, :closed) == nil
      # refund = div(12000 - 10000, 2) = 1000 → potential 10000 + 1000
      assert out.private.update_character.meta.stats.potential == 11000
    end

    test "未闭关时 stop 提示" do
      p = player(family: %{name: "武当派"}, potential: 20000)
      conn = build_conn(p)
      out = ClosedCommand.run(conn, %{"rest" => "stop"})
      assert output_text(out) =~ "没有在闭关"
    end
  end

  # ---------------------------------------------------------------------------
  # ClosedStepEvent 心跳
  # ---------------------------------------------------------------------------

  describe "ClosedStepEvent 心跳" do
    test "潜能耗尽收尾出关" do
      p = player(family: %{name: "武当派"}, potential: 0, learned_points: 0)
      conn = build_conn(p) |> put_session(:closed, %{started_at: 0}) |> set_private(:closed_no_save, true)

      out = ClosedStepEvent.step(conn, %Event{topic: "character/closed_step", data: %{}})

      assert get_session(out, :closed) == nil
      assert output_text(out) =~ "潜能耗尽"
    end

    test "正常续拍增长并保留运行态" do
      p =
        player(
          family: %{name: "武当派"},
          potential: 20000,
          learned_points: 0,
          combat_exp: 100,
          skills: %{"sword" => 60, "force" => 20}
        )

      conn = build_conn(p) |> put_session(:closed, %{started_at: 0}) |> set_private(:closed_no_save, true)

      out = ClosedStepEvent.step(conn, %Event{topic: "character/closed_step", data: %{}})

      assert get_session(out, :closed) != nil
      new_stats = out.private.update_character.meta.stats
      assert new_stats.combat_exp > 100
    end

    test "角色濒死被打断出关" do
      p = player(family: %{name: "武当派"}, potential: 20000, qi: 0)
      conn = build_conn(p) |> put_session(:closed, %{started_at: 0}) |> set_private(:closed_no_save, true)

      out = ClosedStepEvent.step(conn, %Event{topic: "character/closed_step", data: %{}})

      assert get_session(out, :closed) == nil
      assert output_text(out) =~ "打断"
    end
  end
end
