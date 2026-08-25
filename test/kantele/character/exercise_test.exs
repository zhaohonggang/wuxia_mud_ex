defmodule Kantele.Character.ExerciseTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.ExerciseCommand
  alias Kantele.Character.ExerciseEvent
  alias Kantele.Character.NeiliLimit
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @recv_timeout 3000

  describe "NeiliLimit.current/1（LPC query_current_neili_limit）" do
    test "无映射时只有基本线：force/2 × 10" do
      stats = Stats.new()

      assert NeiliLimit.current(stats) == 100
    end

    test "有映射时基本线 + 特殊内功等级 × 10" do
      stats = %Stats{
        Stats.new()
        | skills: %{"force" => 30, "liuxi-neigong" => 30},
          mapped: %{"force" => "liuxi-neigong"}
      }

      assert NeiliLimit.current(stats) == div(30, 2) * 10 + 30 * 10
    end

    test "学了特殊内功但未 enable 时不算进天花板" do
      stats = %Stats{Stats.new() | skills: %{"force" => 30, "liuxi-neigong" => 30}}

      assert NeiliLimit.current(stats) == div(30, 2) * 10
    end
  end

  describe "exercise 命令前置校验" do
    test "战斗中拒绝打坐" do
      character = meditator()
      {combat, _} = Combat.add_enemy(Combat.new(), enemy_ref())
      character = put_combat(character, combat)

      conn = run_command(character, "30")

      assert output_text(conn) =~ "战斗中不能练内功"
    end

    test "未 enable 内功拒绝" do
      character = meditator(stats: [mapped: %{}])

      conn = run_command(character, "30")

      assert output_text(conn) =~ "enable"
    end

    test "参数不足 10 拒绝" do
      conn = run_command(meditator(), "5")

      assert output_text(conn) =~ "至少耗费"
    end

    test "气不够拒绝" do
      character = meditator(vitals: [qi: 20])

      conn = run_command(character, "50")

      assert output_text(conn) =~ "气太少"
    end

    test "精力低于七成拒绝" do
      character = meditator(vitals: [jing: 80, max_jing: 120])

      conn = run_command(character, "30")

      assert output_text(conn) =~ "精不够"
    end

    test "合法参数启动打坐并调度心跳" do
      conn = run_command(meditator(), "30")

      assert Conn.get_session(conn, "exercise") == %{remaining: 30}
      assert output_text(conn) =~ "盘膝坐下"

      # 首跳经 foreman 自投递到测试进程（角色 pid = self()）
      assert_receive %Event{topic: "exercise/tick"}, @recv_timeout
    end
  end

  describe "打坐循环" do
    test "耗气攒内力，结束后推高 max_neili 并同步 base_neili" do
      character =
        meditator(
          vitals: [qi: 500, neili: 400, max_neili: 200, base_neili: 200],
          stats: [
            skills: %{
              "unarmed" => 60,
              "sword" => 60,
              "dodge" => 60,
              "parry" => 60,
              "force" => 20,
              "liuxi-neigong" => 20
            },
            mapped: %{"force" => "liuxi-neigong"}
          ]
        )

      limit = NeiliLimit.current(character.meta.stats)
      assert limit == 100 + 200

      final = drive_to_finish(character, remaining: 10)

      vitals = current_character(final).meta.vitals
      assert vitals.max_neili == 201
      assert vitals.base_neili == 201
      assert vitals.neili == 201
      assert vitals.qi < 500
      assert output_text(final) =~ "内力增加"
    end

    test "达到瓶颈时不再增长并把内力压回上限" do
      # max_neili 500 已超过天花板 300：force 30/2×10=150 + 特殊 15×10=150
      character =
        meditator(
          vitals: [qi: 500, neili: 1000, max_neili: 500, base_neili: 500],
          stats: [
            skills: %{"force" => 30, "liuxi-neigong" => 15},
            mapped: %{"force" => "liuxi-neigong"}
          ]
        )

      final = drive_to_finish(character, remaining: 5)

      vitals = current_character(final).meta.vitals
      assert vitals.max_neili == 500
      assert vitals.neili == 500
      assert output_text(final) =~ "瓶颈"
    end

    test "战斗中被打断：内力钳回 2×上限并清除状态" do
      character = meditator(vitals: [qi: 500, neili: 450, max_neili: 200, base_neili: 200])
      {combat, _} = Combat.add_enemy(Combat.new(), enemy_ref())
      character = put_combat(character, combat)

      conn =
        build_conn(character, %{"exercise" => %{remaining: 100}})
        |> ExerciseEvent.tick(%Event{topic: "exercise/tick", data: %{}})

      character = current_character(conn)
      vitals = character.meta.vitals

      assert Conn.get_session(conn, "exercise") == nil
      assert vitals.neili == 400
      assert output_text(conn) =~ "真气压回丹田"
    end

    test "自然回复不会削减超过上限的内力" do
      vitals = %Vitals{Vitals.new() | qi: 100, max_qi: 150, neili: 380, max_neili: 200}

      regenerated = Vitals.regenerate(vitals, Stats.new(), false)

      # 内力超上限（打坐蓄力）时回复只补气血，不把内力拉回 200
      assert regenerated.neili >= 380
      assert regenerated.qi > 100
    end
  end

  # ---- helpers ----

  defp meditator(opts \\ []) do
    stats =
      Stats.new()
      |> struct(
        Keyword.merge([mapped: %{"force" => "liuxi-neigong"}], Keyword.get(opts, :stats, []))
      )

    vitals = struct(Vitals.new(), Keyword.get(opts, :vitals, []))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      meta: %PlayerMeta{vitals: vitals, stats: stats, combat: Combat.new()}
    }
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp enemy_ref(),
    do: %{id: "npc-1", pid: self(), name: "野猪", room_id: "test:room"}

  defp run_command(character, arg) do
    ExerciseCommand.run(build_conn(character), %{"arg" => arg})
  end

  # 同步驱动 tick 直到结束（session 清空）；期间产生的定时器消息留在收件箱无害
  defp drive_to_finish(character, opts \\ [], ticks \\ 60)

  defp drive_to_finish(_character, _opts, 0), do: flunk("打坐未在限定跳数内结束")

  defp drive_to_finish(character, opts, ticks) do
    remaining = Keyword.fetch!(opts, :remaining)
    event = %Event{topic: "exercise/tick", data: %{}}
    conn = build_conn(character, %{"exercise" => %{remaining: remaining}})
    ticked = ExerciseEvent.tick(conn, event)

    case Conn.get_session(ticked, "exercise") do
      nil ->
        ticked

      %{remaining: left} when left > 0 and left < remaining ->
        drive_to_finish(current_character(ticked), [remaining: left], ticks - 1)

      _ ->
        flunk("打坐循环卡住：剩余 #{inspect(remaining)}")
    end
  end

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end
end
