defmodule Kantele.World.NpcActions.YitianTest do
  @moduledoc """
  倚天万安寺四关（`Kantele.World.NpcActions.Yitian`）测试。

  房间进程注入：`Room.npc_characters_by_id/1` 走
  `:global.whereis_name({Kalevala.World.Room, room_id})` + `:sys.get_state`，
  故测试用一个 GenServer 假房间挂上同一全局名，state 带
  `%{private: %{characters: [...], item_instances: [...]}}`。
  NPC/玩家的 `pid` 直接用测试进程，事件（`combat/start`、
  `yitian/begin`、`yitian/result`）用 `assert_receive` 收。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.YitianEvent
  alias Kantele.World.NpcActionHandlers
  alias Kantele.World.NpcActions.Yitian

  @was_lou4 "tulong:was_lou4"
  @jiulou "tulong:jiulou"

  # ---- 假房间 ----

  defmodule FakeRoom do
    use GenServer

    def start_link(state), do: GenServer.start_link(__MODULE__, state)

    @impl true
    def init(state), do: {:ok, state}
  end

  defp register_room(room_id, characters, items \\ []) do
    state = %{private: %{characters: characters, item_instances: items}}
    {:ok, pid} = FakeRoom.start_link(state)
    :global.register_name({Kalevala.World.Room, room_id}, pid, fn _n, _p, _r -> :yes end)

    on_exit(fn -> :global.unregister_name({Kalevala.World.Room, room_id}) end)
    pid
  end

  # ---- 角色构造 ----

  defp npc(id, name, aliases, opts) do
    %Kalevala.Character{
      id: id,
      name: name,
      room_id: @was_lou4,
      status: Keyword.get(opts, :status),
      meta: %Kantele.Character.NonPlayerMeta{
        aliases: aliases,
        vitals: %{neili: 0},
        stats: %{str: 1, dex: 1, con: 1, int: 1, combat_exp: 0, skills: %{}, mapped: %{}},
        combat: %Combat{
          dead: Keyword.get(opts, :dead, false),
          enemies: Keyword.get(opts, :enemies, [])
        }
      },
      pid: self()
    }
  end

  defp he(opts), do: npc("npc-he", "何太冲", ["he taichong", "he"], opts)
  defp asan(opts \\ []), do: npc("npc-asan", "阿三", ["a san", "san"], opts)
  defp aer(opts \\ []), do: npc("npc-aer", "阿二", ["a er", "er"], opts)
  defp ada(opts \\ []), do: npc("npc-ada", "阿大", ["a da", "da"], opts)

  defp player(opts \\ []) do
    temp = Keyword.get(opts, :temp, %{})
    weapon = Keyword.get(opts, :weapon)

    %Kalevala.Character{
      id: "player-1",
      name: "玩家",
      room_id: Keyword.get(opts, :room_id, @was_lou4),
      meta: %PlayerMeta{
        temp: temp,
        combat: %Combat{equipped: if(weapon, do: %{weapon: weapon}, else: %{})}
      },
      pid: self()
    }
  end

  defp sword_weapon, do: %{name: "竹剑", skill_type: "sword"}
  defp blade_weapon, do: %{name: "钢刀", skill_type: "blade"}

  defp conn(player) do
    %Conn{
      character: player,
      private: %Conn.Private{
        room: %Kantele.World.Room{id: player.room_id},
        channel_changes: []
      },
      output: []
    }
  end

  defp params(room_id, trailing \\ ""),
    do: %{verb: "bi", trailing: trailing, room_id: room_id, npc: %Kalevala.Character{name: "NPC"}}

  # was_lou4 全员（含玩家，供 kill_ob 找目标快照）
  defp full_cast(opts \\ []), do: [he(opts), asan(opts), aer(opts), ada(opts)]

  # 前 n 关已倒下的链条阵容（供阿三/阿二/阿大测试）
  defp cast_after(:he), do: [he(dead: true), asan(), aer(), ada()]
  defp cast_after(:asan), do: [he(dead: true), asan(dead: true), aer(), ada()]
  defp cast_after(:aer), do: [he(dead: true), asan(dead: true), aer(dead: true), ada()]

  defp room_with(cast), do: [player() | cast]

  defp with_room(room_id, cast, items \\ []) do
    register_room(room_id, room_with(cast), items)
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

  describe "run/2（分发）" do
    test "无房间进程 → :not_handled（放行全局）" do
      assert :not_handled = Yitian.run(conn(player()), params(@was_lou4))
    end

    test "非 bi 动词 → :not_handled" do
      with_room(@was_lou4, full_cast())
      assert :not_handled = Yitian.run(conn(player()), %{params(@was_lou4) | verb: "get"})
    end

    test "注册表：was_lou4 与 jiulou 的 bi 命中 Yitian" do
      assert {:ok, {Kantele.World.NpcActions.Yitian, :run}} = NpcActionHandlers.lookup(@was_lou4, "bi")
      assert {:ok, {Kantele.World.NpcActions.Yitian, :run}} = NpcActionHandlers.lookup(@jiulou, "bi")
      assert @was_lou4 in NpcActionHandlers.registered_rooms()
    end
  end

  describe "何太冲（第一关，无标记守卫，必须剑类兵器）" do
    test "无兵器：广播「只能和你比剑」+ 私聊拒绝" do
      with_room(@was_lou4, full_cast())
      conn2 = Yitian.run(conn(player()), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "何太冲说道：我内力全失，现在只能和你比剑！"))
      assert String.contains?(out_text(conn2), "看起来何太冲并不想跟你较量。")
    end

    test "非剑兵器（钢刀）同样拒绝" do
      with_room(@was_lou4, full_cast())
      p = player(weapon: blade_weapon())
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert String.contains?(out_text(conn2), "看起来何太冲并不想跟你较量。")
    end

    test "持剑：广播进招 + 两仪剑文案，互发 combat/start，NPC 收 yitian/begin" do
      with_room(@was_lou4, full_cast())
      p = player(weapon: sword_weapon())
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "何太冲说道：进招吧！"))
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "手中竹剑对准"))
      assert bi_temp(conn2) == 1

      assert_receive %Kalevala.Event{topic: "combat/start"}, 500
      assert_receive %Kalevala.Event{topic: "combat/start"}, 500
      assert_receive %Kalevala.Event{topic: "yitian/begin", data: data}, 500
      assert data.stage == :he
      assert data.strikes == 2
    end
  end

  # 取 conn 里的 bi 临时标记
  defp bi_temp(conn), do: Kantele.World.NpcActions.Helpers.temp(conn, "bi")

  describe "阿三 / 阿二 / 阿大（后续关：win_* 标记守卫）" do
    test "何太冲在场且无 win_he：链条落到何太冲（阿三的守卫不生效）" do
      with_room(@was_lou4, full_cast())
      conn2 = Yitian.run(conn(player()), params(@was_lou4))

      # say 走广播，notify_fail 走私聊
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "何太冲说道：我内力全失"))
      assert String.contains?(out_text(conn2), "看起来何太冲并不想跟你较量。")
    end

    test "阿三：有 win_he 但持兵器 → 拒绝（比空手）" do
      with_room(@was_lou4, cast_after(:he))
      p = player(temp: %{"win_he" => 1}, weapon: sword_weapon())
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿三说道：我和你比空手，请将竹剑放下。"))
      assert String.contains?(out_text(conn2), "看起来阿三并不想跟你较量。")
    end

    test "阿三：win_he + 空手 → 开打（好！+ 大力金刚指）" do
      with_room(@was_lou4, cast_after(:he))
      p = player(temp: %{"win_he" => 1})
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿三说道：好！"))
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "大力金刚指"))

      assert_receive %Kalevala.Event{topic: "yitian/begin", data: data}, 500
      assert data.stage == :asan
    end

    test "阿二：win_asan 缺失 → 拣便宜拒绝（何太冲/阿三已倒下）" do
      with_room(@was_lou4, cast_after(:asan))
      p = player(temp: %{"win_he" => 1})
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿二说道：阁下是谁？为何刚才不出战"))
      assert String.contains?(out_text(conn2), "看起来阿二并不想跟你较量。")
    end

    test "阿二：win_asan + 空手 → 开打（我出招了 + 般若掌）" do
      with_room(@was_lou4, cast_after(:asan))
      p = player(temp: %{"win_he" => 1, "win_asan" => 1})
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿二说道：我出招了。"))
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "双掌平推，掌劲如巨浪般汹涌而出"))

      assert_receive %Kalevala.Event{topic: "yitian/begin", data: data}, 500
      assert data.stage == :aer
    end

    test "阿大：win_aer 缺失 → 拒绝（阿三/阿二已倒下，如玩家真实击杀未落标记）" do
      with_room(@was_lou4, cast_after(:aer))
      p = player(temp: %{"win_he" => 1, "win_asan" => 1})
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿大说道：阁下是谁？为何刚才不出战"))
      assert String.contains?(out_text(conn2), "看起来阿大并不想跟你较量。")
    end

    test "阿大：win_aer + 无兵器 → 只比兵器功夫拒绝" do
      with_room(@was_lou4, cast_after(:aer))
      p = player(temp: %{"win_he" => 1, "win_asan" => 1, "win_aer" => 1})
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿大说道：我只和你比兵器功夫！"))
      assert String.contains?(out_text(conn2), "看起来阿大并不想跟你较量。")
    end

    test "阿大：win_aer + 兵器、屋内无倚天剑 → 静默开打（LPC 无剑分支）" do
      with_room(@was_lou4, cast_after(:aer))
      p = player(temp: %{"win_he" => 1, "win_asan" => 1, "win_aer" => 1}, weapon: sword_weapon())
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      # 无 say/广播，只有 bi 标记与开战事件
      assert vision_texts(conn2) == []
      assert out_text(conn2) == ""
      assert bi_temp(conn2) == 1

      assert_receive %Kalevala.Event{topic: "yitian/begin", data: data}, 500
      assert data.stage == :ada
      assert data.strikes == 3
    end
  end

  describe "阿大倚天剑分支（屋内有 tulong:yitianjian）" do
    test "地上有剑 → 完整倚天剑 sequence 广播" do
      with_room(@was_lou4, cast_after(:aer), [%Kalevala.World.Item.Instance{
        id: "inst-jian",
        item_id: "tulong:yitianjian",
        created_at: ~U[2026-10-18 00:00:00Z]
      }])

      p = player(temp: %{"win_he" => 1, "win_asan" => 1, "win_aer" => 1}, weapon: sword_weapon())
      conn2 = Yitian.run(conn(p), params(@was_lou4))

      texts = vision_texts(conn2)
      # broadcast_vision 把 $N 归一化为 {npc}（展示期再转「你」/玩家名）
      assert Enum.any?(texts, &String.contains?(&1, "赵敏喝道：“慢着！拿着倚天剑和{npc}斗！”"))
      assert Enum.any?(texts, &String.contains?(&1, "轻轻在红木剑架上一拍"))
      assert Enum.any?(texts, &String.contains?(&1, "嗖”的一声破空声响"))
      assert Enum.any?(texts, &String.contains?(&1, "阿大说道：进招了。"))
      assert Enum.any?(texts, &String.contains?(&1, "连续数剑，向{npc}各处要害连续刺去"))
    end
  end

  describe "tulong:jiulou 阿大单挑" do
    test "无 win_aer → 拒绝（何太冲/阿三/阿二不在场，链条落到阿大守卫）" do
      register_room(@jiulou, [player(room_id: @jiulou), ada()])
      p = player(room_id: @jiulou)
      conn2 = Yitian.run(conn(p), params(@jiulou))

      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "阿大说道：阁下是谁？为何刚才不出战"))
      assert String.contains?(out_text(conn2), "看起来阿大并不想跟你较量。")
    end

    test "win_aer + 兵器 → 开打" do
      register_room(@jiulou, [player(room_id: @jiulou), ada()])
      p = player(room_id: @jiulou, temp: %{"win_aer" => 1}, weapon: sword_weapon())
      conn2 = Yitian.run(conn(p), params(@jiulou))

      assert bi_temp(conn2) == 1
      assert_receive %Kalevala.Event{topic: "yitian/begin", data: data}, 500
      assert data.stage == :ada
    end
  end

  describe "脚本结算（on_begin / resolve）" do
    # ETS 死亡登记跨用例不失效（StatusTracker 活在整场测试），
    # 收了尾要清，否则污染本文件后续用例
    setup do
      on_exit(fn ->
        for id <- ["npc-he", "npc-asan", "npc-aer", "npc-ada"] do
          Kantele.Character.Combat.StatusTracker.mark_alive(id)
        end
      end)
    end

    test "玩家仍在敌人列表：resolve → yitian/result（win_he + 死亡文案）+ 落死" do
      he_npc = he(enemies: [%{id: "player-1", pid: self(), name: "玩家"}])
      register_room(@was_lou4, [player(), he_npc])

      begin_event = %Kalevala.Event{
        from_pid: self(),
        topic: "yitian/begin",
        data: %{stage: :he, player_id: "player-1", strikes: 2}
      }

      npc_conn = %Conn{
        character: he_npc,
        private: %Conn.Private{room: %Kantele.World.Room{id: @was_lou4}, channel_changes: []},
        output: []
      }

      Yitian.on_begin(npc_conn, begin_event)

      # assert strikes 已发出（combat/incoming ×2）
      assert_receive %Kalevala.Event{topic: "combat/incoming"}, 500
      assert_receive %Kalevala.Event{topic: "combat/incoming"}, 500

      # resolve：玩家还在敌人列表 → 放倒
      Yitian.resolve(npc_conn, "player-1")

      assert_receive %Kalevala.Event{topic: "yitian/result", data: data}, 500
      assert data.flag == "win_he"
      assert data.clear == []
      assert Enum.any?(data.lines, &String.contains?(&1, "废物"))

      # Down.mark_dead 落了 ETS 死亡登记
      assert Kantele.Character.Combat.StatusTracker.dead?("npc-he")
    end

    test "玩家已不在敌人列表（先死/逃了）：resolve 静默跳过" do
      he_npc = he(enemies: [])
      register_room(@was_lou4, [player(), he_npc])

      npc_conn = %Conn{
        character: he_npc,
        private: %Conn.Private{room: %Kantele.World.Room{id: @was_lou4}, channel_changes: []},
        output: []
      }

      Yitian.resolve(npc_conn, "player-1")

      refute_receive %Kalevala.Event{topic: "yitian/result"}, 200
      refute Kantele.Character.Combat.StatusTracker.dead?("npc-he")
    end

    test "阿大关 resolve：flag 为 nil，clear 三个前置标记" do
      ada_npc = ada(enemies: [%{id: "player-1", pid: self(), name: "玩家"}])
      register_room(@was_lou4, [player(), ada_npc])

      npc_conn = %Conn{
        character: ada_npc,
        private: %Conn.Private{room: %Kantele.World.Room{id: @was_lou4}, channel_changes: []},
        output: []
      }

      Yitian.resolve(npc_conn, "player-1")

      assert_receive %Kalevala.Event{topic: "yitian/result", data: data}, 500
      assert data.flag == nil
      assert data.clear == ["win_he", "win_asan", "win_aer"]
      assert Enum.any?(data.lines, &String.contains?(&1, "剑身已经贯胸而入"))
    end
  end

  describe "玩家侧 client_result" do
    test "落 win_he + 清 bi + 广播死亡文案" do
      event = %Kalevala.Event{
        from_pid: self(),
        topic: "yitian/result",
        data: %{
          stage: :he,
          flag: "win_he",
          clear: [],
          lines: ["\n赵敏皱了皱眉头，低声骂道：“废物！”\n"]
        }
      }

      p = player(temp: %{"bi" => 1})
      conn2 = YitianEvent.result(conn(p), event)

      assert Kantele.World.NpcActions.Helpers.temp(conn2, "win_he") == 1
      assert Kantele.World.NpcActions.Helpers.temp(conn2, "bi") in [nil, 0, false, ""]
      assert Enum.any?(vision_texts(conn2), &String.contains?(&1, "废物"))
    end

    test "阿大关：清 win_he/win_asan/win_aer + 清 bi" do
      event = %Kalevala.Event{
        from_pid: self(),
        topic: "yitian/result",
        data: %{
          stage: :ada,
          flag: nil,
          clear: ["win_he", "win_asan", "win_aer"],
          lines: []
        }
      }

      p = player(temp: %{"bi" => 1, "win_he" => 1, "win_asan" => 1, "win_aer" => 1})
      conn2 = YitianEvent.result(conn(p), event)

      for key <- ["win_he", "win_asan", "win_aer", "bi"] do
        assert Kantele.World.NpcActions.Helpers.temp(conn2, key) in [nil, 0, false, ""]
      end
    end
  end

  describe "事件桥接" do
    test "YitianEvent 导出 begin_event/2 与 result/2" do
      assert function_exported?(Kantele.Character.YitianEvent, :begin_event, 2)
      assert function_exported?(Kantele.Character.YitianEvent, :result, 2)
    end
  end
end
