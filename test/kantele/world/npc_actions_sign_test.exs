defmodule Kantele.World.NpcActions.SignTest do
  # Pkd 用全局命名 ETS 表存赛事状态，PkdCommandTest 也会写它；
  # 两个模块都设 async: false，避免并发时读到对方留下的 :ready 状态。
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Pkd
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Sign

  @room_id "pk:entry"

  defp conn(stats) do
    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: %PlayerMeta{stats: stats}
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params, do: %{verb: "sign", trailing: "", room_id: @room_id, npc: %Kalevala.Character{name: "乌老大"}}

  # 经验守卫之后的分支直接读 PK_D 赛事状态。每条用例开头把状态钉成 :none，
  # 不依赖其它用例留下的全局 ETS 值。表由 ensure!/0 在本进程补建，
  # 随用例进程退出自动回收，故无需 on_exit 还原（还原反而会在表消失后崩）。
  setup do
    Pkd.ensure!()
    Pkd.set_state(:none)
    :ok
  end

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Sign.run(conn(nil), params() |> Map.put(:room_id, nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled = Sign.run(conn(nil), params() |> Map.put(:room_id, "city:kedian"))
    end
  end

  describe "run/2（经验守卫）" do
    test "stats 为 nil → exp 按 0 → 打招呼 + 拒绝「被屠大赛」" do
      conn2 = Sign.run(conn(nil), params())

      texts = vision_texts(conn2)
      assert Enum.any?(texts, &String.contains?(&1, "我也来签个到"))
      assert Enum.any?(texts, &String.contains?(&1, "就你这点本事？只好参加被屠大赛"))
    end

    test "exp = 9999（差 1）→ 拒绝" do
      conn2 = Sign.run(conn(%Stats{combat_exp: 9_999}), params())

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "被屠大赛"))
    end

    test "exp = 10000 → 过守卫，落「无赛事」say" do
      conn2 = Sign.run(conn(%Stats{combat_exp: 10_000}), params())

      refute Enum.any?(vision_texts(conn2), &String.contains?(&1, "被屠大赛"))
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "现在没要举行比赛啊？你跑来干什么？"))
    end

    test "打招呼无条件先行（高经验也看得到）" do
      conn2 = Sign.run(conn(%Stats{combat_exp: 500_000}), params())

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "我也来签个到"))
    end

    test "拒绝对私聊零输出（两条都是广播）" do
      conn2 = Sign.run(conn(%Stats{combat_exp: 100}), params())

      assert out_text(conn2) == ""
    end
  end
end
