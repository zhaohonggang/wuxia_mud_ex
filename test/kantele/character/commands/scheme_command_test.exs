defmodule Kantele.Character.SchemeCommandTest do
  @moduledoc """
  `scheme` 命令测试：聚焦 `start` 的各拒绝分支与 `stop` 收尾。
  成功分支会走到 `Records.save`（需 DB），交由 CI/Docker 套件覆盖；本文件只测
  不落库即可判定的分支，从而在本地纯函数 harness 也能跑。
  """
  use ExUnit.Case, async: true
  import Kalevala.ConnTest

  alias Kalevala.Character
  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Scheme
  alias Kantele.Character.SchemeCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  defp player(attrs \\ []) do
    stats =
      Stats.new()
      |> Map.put(:combat_exp, Keyword.get(attrs, :combat_exp, 100_000))

    %Character{
      id: "scheme-test-player",
      name: "scheme-test-player",
      pid: self(),
      room_id: Keyword.get(attrs, :room_id, "city:kedian"),
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Keyword.get(attrs, :combat, Combat.new()),
        coins: 100,
        setup_done: true,
        schedule: Keyword.get(attrs, :schedule, nil),
        env: %{}
      }
    }
  end

  defp run(conn, arg), do: SchemeCommand.run(conn, %{"arg" => arg})

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp with_scheme(conn) do
    %{conn | private: Map.put(conn.private, :scheme, Scheme.init_state(["lianxi"]))}
  end

  test "start 无计划被拒" do
    conn = build_conn(player())
    assert output_text(run(conn, "start")) =~ "你目前还没有制订计划。"
  end

  test "start 正在执行计划被拒" do
    conn = build_conn(player(schedule: "lianxi"))
    conn = with_scheme(conn)
    assert output_text(run(conn, "start")) =~ "你现在正在执行计划，不能开展新计划。"
  end

  test "start 忙时被拒" do
    busy = %{Combat.new() | busy: 5}
    conn = build_conn(player(schedule: "lianxi", combat: busy))
    assert output_text(run(conn, "start")) =~ "你现在正忙着呢。"
  end

  test "start 战斗中被拒" do
    fighting = %{Combat.new() | enemies: ["someone"]}
    conn = build_conn(player(schedule: "lianxi", combat: fighting))
    assert output_text(run(conn, "start")) =~ "战斗中不能执行计划。"
  end

  test "start 无房间被拒" do
    conn = build_conn(player(schedule: "lianxi", room_id: nil))
    assert output_text(run(conn, "start")) =~ "你现在什么都做不了。"
  end

  test "start 房间标志不满足被拒（room_flags 取不到 → 视为非休息室）" do
    # 本地 harness 无 ZoneCache，room_flags 返回 [] → 落入 sleep_room 闸门
    conn = build_conn(player(schedule: "lianxi"))
    assert output_text(run(conn, "start")) =~ "你必须在能够休息的地方才能执行计划。"
  end

  test "stop 未在执行时提示" do
    conn = build_conn(player())
    assert output_text(run(conn, "stop")) =~ "你现在没有在执行任何计划。"
  end

  test "stop 执行中则清除运行态" do
    conn = build_conn(player(schedule: "lianxi"))
    conn = with_scheme(conn)
    out = run(conn, "stop")
    assert output_text(out) =~ "你停止了当前计划。"
    assert Map.get(out.private, :scheme) == nil
  end

  test "clear 执行中禁止清除" do
    conn = build_conn(player(schedule: "lianxi"))
    conn = with_scheme(conn)
    assert output_text(run(conn, "clear")) =~ "请先停下来再清除它。"
  end
end
