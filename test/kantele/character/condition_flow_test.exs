defmodule Kantele.Character.ConditionFlowTest do
  use ExUnit.Case, async: true

  import Kalevala.ConnTest

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.Conditions
  alias Kantele.Character.Events
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @tick_interval 1000

  describe "poison/apply 自毒接线（经 Events 路由）" do
    test "daub 自毒落到宿主：写 conditions 会话 + 触发 condition/tick 心跳" do
      applied = fire(build_conn(poisoned_player()), poison_event())

      assert Conn.get_session(applied, "conditions")["poison"]["level"] == 50
      assert output_text(applied) =~ "腥臭"

      assert_receive %Event{topic: "condition/tick"}, @tick_interval + 300
    end

    test "再中同种毒走混毒（等级叠加），不覆盖" do
      applied = fire(apply_poison(poisoned_player()), poison_event(%{"level" => 100}))

      # mixed_poison: max(100,50) + div(min(100,50),4) = 100 + 12
      assert Conn.get_session(applied, "conditions")["poison"]["level"] == 112
    end

    test "非 self 目标不落地（英雄不吃毒）" do
      event = %Event{topic: "poison/apply", data: %{target: "other", poison: poison()}}
      conn = fire(build_conn(poisoned_player()), event)

      assert Conn.get_session(conn, "conditions") == nil
      assert output_text(conn) == ""
    end
  end

  describe "condition/tick 心跳（经 Events 路由）" do
    test "中毒每跳扣 jing/qi，remain 归零到期自动清除" do
      character = poisoned_player(vitals: [jing: 2000, qi: 5000, max_jing: 2000, max_qi: 5000])

      tick1 = tick(apply_poison(character))

      char1 = current_character(tick1)
      assert char1.meta.vitals.jing < 2000
      assert char1.meta.vitals.qi < 5000
      assert Conn.get_session(tick1, "conditions")["poison"]["remain"] == 1

      tick2 = tick(tick1)

      char2 = current_character(tick2)
      # 第二跳 remain 1→0 到期清除，不再有 do_effect 扣血
      assert char2.meta.vitals.jing == char1.meta.vitals.jing
      assert char2.meta.vitals.qi == char1.meta.vitals.qi
      assert Conn.get_session(tick2, "conditions") == nil

      # conditions 已清空：tick 不再产出任何输出
      assert output_text(tick(tick2)) == ""
    end

    test "piyi 免疫：attributes special_skills 含 piyi 时中毒不掉血" do
      character =
        poisoned_player(
          vitals: [jing: 2000, qi: 5000, max_jing: 2000, max_qi: 5000],
          attributes: %{"special_skills" => %{"piyi" => true}}
        )

      conn = tick(apply_poison(character))

      char = current_character(conn)
      assert char.meta.vitals.jing == 2000
      assert char.meta.vitals.qi == 5000
      assert Conn.get_session(conn, "conditions")["poison"]["level"] == 50
    end

    test "conditions 清空后不再续投心跳（省资源）" do
      _conn = tick(tick(apply_poison(poisoned_player())))
      refute_receive %Event{topic: "condition/tick"}, 100
    end
  end

  # ---- helpers ----

  # 经真正的 Events 路由派发，锁定 "poison/apply"/"condition/tick" 已注册 + data 键约定
  defp fire(conn, event), do: Events.call(conn, event)

  defp poison(overrides \\ %{}) do
    Map.merge(
      %{"level" => 50, "duration" => 2, "remain" => 2, "id" => "daubtest:poison", "name" => "砒霜"},
      overrides
    )
  end

  defp poison_event(overrides \\ %{}) do
    %Event{topic: "poison/apply", data: %{target: "self", poison: poison(overrides)}}
  end

  defp apply_poison(character), do: fire(build_conn(character), poison_event())

  # 每次 tick 都重建 conn（传入更新后的 character 与 conditions 会话），
  # 与 production 下持续同一连接不同——ConnTest 里 put_character 只写
  # private.update_character，不覆盖 conn.character
  defp tick(conn) do
    session = %{
      "conditions" => Conn.get_session(conn, "conditions"),
      "cond_applyer" => Conn.get_session(conn, "cond_applyer")
    }

    fire(
      build_conn(current_character(conn), session),
      %Event{topic: "condition/tick", data: %{}}
    )
  end

  defp current_character(conn), do: conn.private.update_character || conn.character

  defp poisoned_player(opts \\ []) do
    vitals = struct(Vitals.new(), Keyword.get(opts, :vitals, []))

    %Kalevala.Character{
      id: "player-1",
      name: "张三",
      pid: self(),
      room_id: "test:room",
      attributes: Keyword.get(opts, :attributes, %{}),
      meta: %PlayerMeta{
        vitals: vitals,
        stats: Stats.new(),
        combat: Combat.new(),
        temp: Keyword.get(opts, :temp, %{})
      }
    }
  end

  defp output_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "Conditions.dispel/3（排除异常逐条驱散）" do
    # 故意不导出 dispel_condition/2（LPC 里没实现 dispel() 的 condition）
    defmodule NoDispel do
      def marker, do: :ok
    end

    defmodule Rejecting do
      def dispel_condition(_info, _ctx), do: {:fail, "驱不掉\n"}
    end

    defmodule Skipping do
      def dispel_condition(_info, _ctx), do: :skip
    end

    test "未导出 dispel_condition/2 的 daemon 默认驱散（与 LPC 相反，见 moduledoc）" do
      daemon = fn
        "plain" -> {:ok, NoDispel}
        _ -> :error
      end

      assert {nil, [{"plain", :ok}]} = Conditions.dispel(%{"plain" => %{}}, %{force: 1}, daemon)
    end

    test "{:fail, msg} 保留该条件" do
      daemon = fn
        "hard" -> {:ok, Rejecting}
        _ -> :error
      end

      assert {%{"hard" => %{}}, [{"hard", {:fail, "驱不掉\n"}}]} =
               Conditions.dispel(%{"hard" => %{}}, %{force: 1}, daemon)
    end

    test ":skip 保留条件但不算失败" do
      daemon = fn
        "skip" -> {:ok, Skipping}
        _ -> :error
      end

      assert {%{"skip" => %{}}, [{"skip", :skip}]} =
               Conditions.dispel(%{"skip" => %{}}, %{force: 1}, daemon)
    end

    test "daemon 解析不到的条件不擅自删" do
      daemon = fn _ -> :error end
      assert {%{"x" => %{}}, [{"x", :skip}]} = Conditions.dispel(%{"x" => %{}}, %{force: 1}, daemon)
    end

    test "部分成功：剩余只留失败的（结果按 key 序，与 map 迭代一致）" do
      daemon = fn
        "plain" -> {:ok, NoDispel}
        "hard" -> {:ok, Rejecting}
        _ -> :error
      end

      assert {%{"hard" => %{}}, results} =
               Conditions.dispel(%{"plain" => %{}, "hard" => %{}}, %{force: 1}, daemon)

      assert Enum.sort(results) == [{"hard", {:fail, "驱不掉\n"}}, {"plain", :ok}]
    end

    test "全部驱散时剩余返回 nil（不是空 map）" do
      daemon = fn _ -> {:ok, NoDispel} end
      assert {nil, _} = Conditions.dispel(%{"a" => %{}, "b" => %{}}, %{force: 1}, daemon)
    end

    test "非 map 输入安全返回空结果" do
      assert {nil, []} = Conditions.dispel(nil, %{force: 1}, fn _ -> :error end)
      assert {nil, []} = Conditions.dispel([], %{force: 1}, fn _ -> :error end)
    end
  end
end
