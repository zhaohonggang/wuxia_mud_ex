defmodule Kantele.Character.SleepConditionGateTest do
  @moduledoc """
  `sleep` 的 condition 门控（LPC `cmds/std/sleep.c`）。

  覆盖 2026-10-26 修的缺陷：门控原先读 `character.meta.conditions` —— 那个字段
  **全库无人写入**（condition 框架存 `session["conditions"]`），所以这道门控
  永远放行。现在改读 session，门槛判定走 `Conditions.blocked_by_vitals/3`。

  LPC 里只有 `kungfu/condition/ill_*` 五族实现了 `min_qi_needed` /
  `min_jing_needed`，故这里用 `ConditionRegistry.register/2` 的热增路径
  注册一个假 daemon 来驱动（`async: false`，`:persistent_term` 是全局的）。
  """

  use ExUnit.Case, async: false

  import Kalevala.ConnTest

  alias Kantele.Character.ConditionRegistry
  alias Kantele.Character.Conditions
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.SleepCommand
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  # 假 condition：门槛 100 气 / 60 精（对应 LPC `ill_*` 的 `min_qi_needed`）
  defmodule FakeIll do
    def min_qi_needed(_attributes), do: 100
    def min_jing_needed(_attributes), do: 60
  end

  # 只拦精的假 condition，用来验「气够但精不够」
  defmodule FakeJingOnly do
    def min_jing_needed(_attributes), do: 60
  end

  @sleep_room %{attrs: %{"sleep_room" => true}}

  defp player(attributes) do
    vitals = %Vitals{
      jing: 2000,
      jingli: 2000,
      neili: 9000,
      max_neili: 10_000,
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

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      inventory: [],
      attributes: attributes,
      meta: %PlayerMeta{
        vitals: vitals,
        stats: stats,
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  defp conn_with(attributes, session_conditions) do
    conn = build_conn(player(attributes))
    conn = Map.put(conn, :private, %{conn.private | room: @sleep_room})

    if session_conditions do
      Kalevala.Character.Conn.put_session(conn, "conditions", session_conditions)
    else
      conn
    end
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  defp published_text(conn) do
    conn.private.channel_changes
    |> Enum.flat_map(fn
      {:publish, _channel, %Kalevala.Event{topic: Kalevala.Event.Message, data: data}, _, _} ->
        [data.text]

      _ ->
        []
    end)
    |> Enum.join("")
  end

  defp slept?(conn) do
    Kalevala.Character.Conn.character(conn).meta.temp["sleeped"] == true
  end

  setup do
    ConditionRegistry.register("ill_shanghan", FakeIll)
    ConditionRegistry.register("ill_jing_only", FakeJingOnly)

    on_exit(fn ->
      ConditionRegistry.unregister("ill_shanghan")
      ConditionRegistry.unregister("ill_jing_only")
    end)

    :ok
  end

  describe "Conditions.blocked_by_vitals/3" do
    defp blocked(conditions, attributes) do
      Conditions.blocked_by_vitals(conditions, attributes, &ConditionRegistry.daemon/1)
    end

    test "无 condition 时返回 nil" do
      assert blocked(%{}, %{"qi" => 10, "jing" => 10}) == nil
      assert blocked(nil, %{"qi" => 10, "jing" => 10}) == nil
    end

    test "气低于 min_qi_needed 即拦" do
      conds = %{"ill_shanghan" => %{"duration" => 5}}
      assert blocked(conds, %{"qi" => 99, "jing" => 999}) == "ill_shanghan"
    end

    test "气够但精低于 min_jing_needed 也拦" do
      conds = %{"ill_shanghan" => %{"duration" => 5}}
      assert blocked(conds, %{"qi" => 100, "jing" => 59}) == "ill_shanghan"
    end

    test "两者都达标则放行" do
      conds = %{"ill_shanghan" => %{"duration" => 5}}
      assert blocked(conds, %{"qi" => 100, "jing" => 60}) == nil
    end

    test "未导出 min_* 的 daemon 门槛按 0（不拦）" do
      # drunk 是已注册但没实现 min_qi_needed 的 daemon
      conds = %{"drunk" => %{"duration" => 9999}}
      assert blocked(conds, %{"qi" => 0, "jing" => 0}) == nil
    end

    test "未注册的 condition 名不拦（daemon 返回 :error）" do
      conds = %{"nonexistent_cnd" => %{"duration" => 5}}
      assert blocked(conds, %{"qi" => 0, "jing" => 0}) == nil
    end

    test "返回第一个拦的条件（LPC 命中即 return 1）" do
      conds = %{"ill_jing_only" => %{"duration" => 5}, "ill_shanghan" => %{"duration" => 5}}
      # ill_jing_only 的 min_qi=0、min_jing=60；jing=50 → 拦
      result = blocked(conds, %{"qi" => 500, "jing" => 50})
      assert result in ["ill_jing_only", "ill_shanghan"]
      assert result != nil
    end

    test "attributes 缺失 qi/jing 时按 0 处理" do
      conds = %{"ill_shanghan" => %{"duration" => 5}}
      assert blocked(conds, %{}) == "ill_shanghan"
    end

    test "原子键 attributes（ConditionEvent 的形状）也认" do
      conds = %{"ill_shanghan" => %{"duration" => 5}}
      assert blocked(conds, %{qi: 50, jing: 500}) == "ill_shanghan"
      assert blocked(conds, %{qi: 500, jing: 500}) == nil
    end
  end

  describe "ConditionRegistry.chinese_name/1" do
    test "已收录的 ill_* 给中文名（LPC 的 dict 缺这些条目，属本地补白）" do
      assert ConditionRegistry.chinese_name("ill_shanghan") == "伤寒"
      assert ConditionRegistry.chinese_name("ill_dongshang") == "冻伤"
      assert ConditionRegistry.chinese_name("drunk") == "醉意"
    end

    test "未收录回落 id 原样（与 force/dispel.ex 的 to_chinese/1 同约定）" do
      assert ConditionRegistry.chinese_name("some_future_cnd") == "some_future_cnd"
      assert ConditionRegistry.chinese_name(nil) == nil
    end
  end

  describe "sleep 命令的 condition 门控" do
    test "有拦路 condition：拒绝入睡 + 点名症状 + 房间 vision" do
      conn =
        SleepCommand.run(
          conn_with(%{"qi" => 50, "jing" => 50}, %{"ill_shanghan" => %{"duration" => 30}}),
          %{}
        )

      refute slept?(conn)
      # LPC: "你想合上眼睛好好睡上一觉，可是" + to_chinese(kc[i]) + "不断折磨着你…"
      assert output_text(conn) =~ "伤寒不断折磨着你，让你辗转难眠"
      # LPC: message("vision", me->name() + "看样子是想睡觉，可是辗转反侧，就是睡不着。")
      assert published_text(conn) =~ "看样子是想睡觉，可是辗转反侧，就是睡不着"
      # 没排唤醒
      refute Enum.any?(conn.events, &match?(%Kalevala.Event.Delayed{topic: "sleep/wakeup"}, &1))
    end

    test "门槛达标则照常入睡" do
      conn =
        SleepCommand.run(
          conn_with(%{"qi" => 500, "jing" => 500}, %{"ill_shanghan" => %{"duration" => 30}}),
          %{}
        )

      assert slept?(conn)
      assert output_text(conn) =~ "梦乡"
    end

    test "无 condition 照常入睡（回归：修复前也放行，但原因不同）" do
      conn = SleepCommand.run(conn_with(%{"qi" => 1, "jing" => 1}, nil), %{})
      assert slept?(conn)
    end

    test "drunk 不拦睡觉（LPC drunk.c 未实现 min_qi_needed）" do
      conn =
        SleepCommand.run(
          conn_with(%{"qi" => 1, "jing" => 1}, %{"drunk" => %{"duration" => 9999}}),
          %{}
        )

      assert slept?(conn)
    end

    test "condition 存在但只在 meta.conditions：不拦（修复前会误判的字段）" do
      conn = build_conn(player(%{"qi" => 1, "jing" => 1}))
      conn = Map.put(conn, :private, %{conn.private | room: @sleep_room})
      character = conn.character
      conn =
        Kalevala.Character.Conn.put_character(
          conn,
          %{character | meta: Map.put(character.meta, :conditions, %{poison: 5})}
        )

      conn = SleepCommand.run(conn, %{})

      # 门控不再读 meta.conditions，故放行
      assert slept?(conn)
    end
  end
end
