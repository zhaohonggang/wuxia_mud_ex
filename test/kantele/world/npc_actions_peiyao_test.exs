defmodule Kantele.World.NpcActions.PeiyaoTest do
  use ExUnit.Case, async: true

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.Peiyao

  @room_id "kaifeng:yaopu"

  defp conn(stats, opts \\ []) do
    meta = %PlayerMeta{
      stats: stats,
      vitals: Keyword.get(opts, :vitals, Vitals.new()),
      temp: Keyword.get(opts, :temp, %{}),
      marks: Keyword.get(opts, :marks, %{})
    }

    %Conn{
      character: %Kalevala.Character{
        name: "玩家",
        room_id: @room_id,
        meta: meta
      },
      private: %Conn.Private{
        room: %Kantele.World.Room{id: @room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params, do: %{verb: "peiyao", trailing: "", room_id: @room_id, npc: %Kalevala.Character{name: "平一指"}}

  defp character(conn), do: conn.private.update_character || conn.character

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Peiyao.run(conn(nil), params() |> Map.put(:room_id, nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled = Peiyao.run(conn(nil), params() |> Map.put(:room_id, "city:kedian"))
    end
  end

  describe "ask_job 守门（未领活）→ 首次 peiyao 视为领活" do
    setup do
      conn2 =
        Peiyao.run(
          conn(%Stats{combat_exp: 10_000}),
          params()
        )

      {:ok, conn: conn2}
    end

    test "combat_exp 5000 以下→ 拒绝「太弱」", %{conn: conn2} do
      # 重新用低经验角色走一次，命中第一个守门
      low = Peiyao.run(conn(%Stats{combat_exp: 1_000}), params())
      assert out_text(low) =~ "端不起来"
    end

    test "qi < 5 → 拒绝「先歇歇」", %{conn: conn2} do
      weak = Peiyao.run(conn(%Stats{combat_exp: 10_000}, vitals: %Vitals{qi: 3}), params())
      assert out_text(weak) =~ "先歇歇"
    end

    test "正常角色 → 设 temp job/peiyao，提示再次输入 peiyao", %{conn: conn2} do
      c = character(conn2)
      assert c.meta.temp["job/peiyao"] == 1
      assert out_text(conn2) =~ "帮我配药(peiyao)吧"
    end

    test "不消耗经验（领活不结算）", %{conn: conn2} do
      assert character(conn2).meta.stats.combat_exp == 10_000
    end
  end

  describe "mark/job_peiyao > 1000 且经验 > 20000 → 拒绝「太屈就」" do
    test "拒绝" do
      conn2 =
        Peiyao.run(
          conn(%Stats{combat_exp: 50_000}, marks: %{"job/peiyao" => 1001}),
          params()
        )

      assert out_text(conn2) =~ "太屈就"
    end
  end

  describe "已领活 → 执行配药并结算" do
    setup do
      conn2 =
        Peiyao.run(
          conn(%Stats{combat_exp: 10_000}, temp: %{"job/peiyao" => 1}),
          params()
        )

      {:ok, conn: conn2}
    end

    test "combat_exp + 潜能（30~49）", %{conn: conn2} do
      c = character(conn2)
      delta = c.meta.stats.combat_exp - 10_000
      assert delta in 30..49
      assert c.meta.stats.potential == delta
    end

    test "qi -1（150 → 149）", %{conn: conn2} do
      assert character(conn2).meta.vitals.qi == 149
    end

    test "mark/job_peiyao + 1 并清 temp job/peiyao", %{conn: conn2} do
      c = character(conn2)
      assert c.meta.marks["job/peiyao"] == 1
      assert c.meta.temp["job/peiyao"] == nil
    end

    test "渲染配药 + 报酬文案", %{conn: conn2} do
      assert out_text(conn2) =~ "不错，不错！这是给你的报酬！"
      assert out_text(conn2) =~ "铜钱"
    end

    test "不重复结算（temp 已清，再次 peiyao 回到领活）", %{conn: conn2} do
      conn3 =
        Peiyao.run(
          %{conn2 | character: conn2.private.update_character},
          params()
        )

      c = character(conn3)
      assert c.meta.temp["job/peiyao"] == 1
      assert out_text(conn3) =~ "帮我配药(peiyao)吧"
    end
  end
end
