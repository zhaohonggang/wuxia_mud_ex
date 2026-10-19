defmodule Kantele.World.NpcActions.KneelTest do
  # `async: false`：陈家洛用例经 `:global.register_name` 注册假房间，避免全局名串扰。
  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.Kneel

  @room_id "hangzhou:liuhe9"
  @kicked_room_id "hangzhou:liuheta"

  # ---- 假房间（供陈家洛在场判定：`Room.npc_characters_by_id/1` 读全局房间进程）----

  defmodule FakeRoom do
    use GenServer

    def start_link(state), do: GenServer.start_link(__MODULE__, state)

    @impl true
    def init(state), do: {:ok, state}
  end

  defp register_room(room_id, characters) do
    state = %{private: %{characters: characters, item_instances: []}}
    {:ok, pid} = FakeRoom.start_link(state)
    :global.register_name({Kalevala.World.Room, room_id}, pid, fn _n, _p, _r -> :yes end)

    on_exit(fn -> :global.unregister_name({Kalevala.World.Room, room_id}) end)
    pid
  end

  defp npc_char(id, name, aliases) do
    %Kalevala.Character{
      id: id,
      name: name,
      room_id: @room_id,
      meta: %Kantele.Character.NonPlayerMeta{aliases: aliases},
      pid: self()
    }
  end

  defp player_char(id) do
    %Kalevala.Character{id: id, name: "玩家", room_id: @room_id, pid: self()}
  end

  # `conn/1`：`vitals` 缺省为 nil（对应「未建模」），弱分支用例显式传 `Vitals.new()`
  # —— `Damage.receive_wound/3` 需要 `%Vitals{}` 才能扣 max_qi。
  defp conn(stats, opts \\ []) do
    meta = %PlayerMeta{
      stats: stats,
      vitals: Keyword.get(opts, :vitals),
      marks: Keyword.get(opts, :marks, %{})
    }

    %Conn{
      character: %Kalevala.Character{
        id: Keyword.get(opts, :id),
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

  defp params(room_id \\ @room_id) do
    %{verb: "kneel", trailing: "", room_id: room_id, npc: %Kalevala.Character{name: "乾隆皇帝"}}
  end

  # 分派后真正的角色状态写在 `private.update_character`（`put_character/2` 的语义）
  defp character(conn), do: conn.private.update_character || conn.character

  defp out_text(conn), do: conn.output |> Enum.map(& &1.data) |> Enum.join()

  defp vision_texts(conn) do
    conn.private.channel_changes
    |> Enum.filter(fn
      {:publish, _, event, _, _} when is_map(event) -> event.data.type == "vision"
      _ -> false
    end)
    |> Enum.map(fn {:publish, _, event, _, _} -> event.data.text end)
  end

  defp vision_contains?(conn, needle),
    do: Enum.any?(vision_texts(conn), &String.contains?(&1, needle))

  describe "run/2（分派）" do
    test "room_id 为 nil → :not_handled（不崩溃）" do
      assert :not_handled = Kneel.run(conn(nil), params(nil))
    end

    test "其他房间 → :not_handled" do
      assert :not_handled = Kneel.run(conn(nil), params("city:kedian"))
    end
  end

  describe "弱玩家（combat_exp < 150000）→ 被踢下六和塔" do
    setup do
      conn2 =
        Kneel.run(
          conn(%Stats{combat_exp: 100_000}, vitals: Vitals.new()),
          params()
        )

      {:ok, conn: conn2}
    end

    test "落点改为六和塔底 liuheta", %{conn: conn2} do
      assert character(conn2).room_id == @kicked_room_id
    end

    test "combat_exp 扣 1%（100000 → 99000）", %{conn: conn2} do
      assert character(conn2).meta.stats.combat_exp == 99_000
    end

    test "qi 受创（max_qi 150 → 130）", %{conn: conn2} do
      assert character(conn2).meta.vitals.max_qi == 130
    end

    test "广播「被踢下六和塔」+ 私聊受伤文案", %{conn: conn2} do
      assert vision_contains?(conn2, "被乾隆皇帝一脚踢下了六和塔！")
      assert out_text(conn2) =~ "你从塔顶被一脚踢了下来，好疼！还受了伤。"
    end

    test "不发封赏 say（不走 reward 分支）", %{conn: conn2} do
      refute vision_contains?(conn2, "免了！看在你救驾有功")
    end
  end

  describe "已封赏过（marks/qianlong 已置）→ 乾隆不理" do
    setup do
      conn2 =
        Kneel.run(
          conn(%Stats{combat_exp: 200_000}, marks: %{"qianlong" => 1}),
          params()
        )

      {:ok, conn: conn2}
    end

    test "不重复加经验", %{conn: conn2} do
      assert character(conn2).meta.stats.combat_exp == 200_000
    end

    test "广播「被一脚踢开」+ 私聊「哼了一声」", %{conn: conn2} do
      assert vision_contains?(conn2, "却被乾隆皇帝一脚踢开")
      assert out_text(conn2) =~ "乾隆皇帝看着你，哼了一声，没理你。"
    end

    test "不发封赏 say", %{conn: conn2} do
      refute vision_contains?(conn2, "免了！看在你救驾有功")
    end
  end

  describe "首次跪拜（combat_exp ≥ 150000 且未封赏）→ 封赏" do
    setup do
      conn2 =
        Kneel.run(
          conn(%Stats{combat_exp: 200_000}),
          params()
        )

      {:ok, conn: conn2}
    end

    test "置 marks/qianlong = 1", %{conn: conn2} do
      assert PlayerMeta.mark(character(conn2).meta, "qianlong") == 1
    end

    test "combat_exp + 10000", %{conn: conn2} do
      assert character(conn2).meta.stats.combat_exp == 210_000
    end

    test "广播跪拜 + 私聊请安 + 乾隆封赏 say", %{conn: conn2} do
      assert vision_contains?(conn2, "奴才救驾来迟，皇上恕奴才死罪！")
      assert out_text(conn2) =~ "你恭恭敬敬地跪了下来，磕头请安。"
      assert vision_contains?(conn2, "乾隆皇帝说道：免了！看在你救驾有功，免你死罪，朕自有封赏。")
    end
  end

  describe "陈家洛在场 → 拦住 + kill_ob（LPC 分支 1）" do
    setup do
      chen = npc_char("npc-chen", "陈家洛", ["chen jialuo", "chen", "jialuo"])
      player = player_char("player-1")
      register_room(@room_id, [chen, player])
      :ok
    end

    test "广播「被陈家洛一把拦住」" do
      conn2 = Kneel.run(conn(%Stats{combat_exp: 200_000}, id: "player-1"), params())
      assert vision_contains?(conn2, "却被陈家洛一把拦住")
    end

    test "给玩家发 combat/start（type: kill）" do
      Kneel.run(conn(%Stats{combat_exp: 200_000}, id: "player-1"), params())
      assert_receive %Kalevala.Event{topic: "combat/start", data: %{type: "kill"}}, 200
    end

    test "不阻断封赏链（仍 +10000 经验）" do
      conn2 = Kneel.run(conn(%Stats{combat_exp: 200_000}, id: "player-1"), params())
      assert character(conn2).meta.stats.combat_exp == 210_000
    end
  end
end
