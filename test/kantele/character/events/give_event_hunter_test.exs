defmodule Kantele.Character.GiveEvent.HunterTest do
  @moduledoc """
  衡阳猎人收捕兽夹的两端（对应 LPC `d/hengyang/npc/hunter.c` accept_object）。

  - `HunterAccept.handle/5`（猎人进程侧）：玩家给「捕兽夹」(`bushou jia`) →
    收下并发 `hunter/give-trap` 事件给玩家，由玩家进程置位 marks/hunter。
  - `GiveEvent.receive`（accept_object 规则分发）：命中 `kind:"hunter"` 规则时
    走 HunterAccept（发 `hunter/give-trap`），而非通用 `give/result`。
  - `GiveEvent.hunter_give_trap/2`（玩家进程侧）：移除捕兽夹实例、置位
    marks/hunter（LPC set_temp("marks/hunter", 1)），放行捕猎教学。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kalevala.World.Item
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.GiveEvent
  alias Kantele.Character.NonPlayerEvents
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.World.HunterAccept
  alias Kantele.World.Items
  alias Kantele.World.Loader

  @trap_id "bushou jia"

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    added =
      case Items.get(@trap_id) do
        {:ok, _} -> []
        _ -> [Items.put(@trap_id, %Item{id: @trap_id, name: "捕兽夹", verbs: [], callback_module: Kantele.World.Item, meta: %Kantele.World.Item.Meta{}})]
      end

    on_exit(fn ->
      for id <- added, do: Items.delete(id)
    end)

    :ok
  end

  # ---- HunterAccept.handle（猎人进程侧收捕兽夹） ----

  defp npc_conn do
    %Conn{
      character: %Kalevala.Character{
        id: "hengyang:hunter",
        name: "猎人",
        room_id: "hengyang:hunter_room",
        inventory: [],
        meta: %PlayerMeta{
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Kantele.Character.Combat.new()
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp instance(item_id \\ @trap_id) do
    %Instance{
      id: "trap-inst-#{:erlang.unique_integer([:monotonic])}",
      item_id: item_id,
      created_at: DateTime.utc_now()
    }
  end

  defp out_text(conn) do
    conn.output
    |> Enum.flat_map(fn
      %Kalevala.Character.Conn.Text{data: data} -> [IO.iodata_to_binary(data)]
      _ -> []
    end)
    |> Enum.join("")
  end

  describe "HunterAccept.handle（猎人收捕兽夹）" do
    test "给捕兽夹 → 收下并通知玩家进程置位 marks/hunter" do
      conn0 = npc_conn()
      data = %{reply_to: self(), from_id: "player:test"}
      inst = instance()

      conn1 = HunterAccept.handle(conn0, conn0.character, inst, data, "玩家")

      assert_receive %Event{topic: "hunter/give-trap", data: ev}, 1000
      assert ev.from_id == "player:test"
      assert ev.item_id == @trap_id
      assert out_text(conn1) =~ "猎人点点头收下了捕兽夹"
    end
  end

  # ---- GiveEvent.receive 命中 hunter 规则分发 ----

  defp hunter_npc_conn do
    %Conn{
      character: %Kalevala.Character{
        id: "hengyang:hunter",
        name: "猎人",
        room_id: "hengyang:hunter_room",
        inventory: [],
        meta: %NonPlayerMeta{
          zone_id: "hengyang",
          accept: [%{kind: "hunter", name: "捕兽夹"}],
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Kantele.Character.Combat.new()
        }
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  describe "GiveEvent.receive（hunter 规则分发）" do
    test "给捕兽夹 → 走 HunterAccept，发 hunter/give-trap（非 give/result）" do
      _conn =
        GiveEvent.receive(hunter_npc_conn(), %Event{
          topic: "characters/give",
          data: %{
            item_instance: instance(),
            item_name: "捕兽夹",
            from_name: "玩家",
            from_id: "player:test",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "hunter/give-trap"}, 1000
      refute_receive %Event{topic: "give/result"}, 500
    end

    test "给错物品 → 不命中 hunter 规则，发 give/result(ok:false)" do
      _conn =
        GiveEvent.receive(hunter_npc_conn(), %Event{
          topic: "characters/give",
          data: %{
            item_instance: instance("test:wrong-item"),
            item_name: "包子",
            from_name: "玩家",
            from_id: "player:test",
            reply_to: self()
          }
        })

      assert_receive %Event{topic: "give/result", data: %{ok: false}}, 1000
      refute_receive %Event{topic: "hunter/give-trap"}, 500
    end
  end

  # ---- 回归：NPC 事件路由必须挂 characters/give ----
  # 之前 Kantele.Character.NonPlayerEvents 没有 characters/give，房间转发的赠送
  # 事件被静默丢弃，赠与者因 assign(:prompt, false) 收不到回执 → 体感「give 没反应」。
  # 直接对 GiveEvent.receive 的单测无法发现这个问题，必须走 NonPlayerEvents.call。

  describe "NonPlayerEvents 路由（NPC 真实事件路由）" do
    test "猎人经 NonPlayerEvents 收到 characters/give → 走 HunterAccept 发 hunter/give-trap" do
      conn0 = hunter_npc_conn()

      event = %Event{
        from_pid: self(),
        topic: "characters/give",
        data: %{
          item_instance: instance(),
          item_name: "捕兽夹",
          from_name: "玩家",
          from_id: "player:test",
          reply_to: self()
        }
      }

      conn1 = NonPlayerEvents.call(conn0, event)

      assert_receive %Event{topic: "hunter/give-trap", data: %{from_id: "player:test"}}, 1000
      refute_receive %Event{topic: "give/result"}, 500
      assert out_text(conn1) =~ "猎人点点头收下了捕兽夹"
    end

    test "NPC 无 accept 规则时仍能收到事件（不再静默丢弃）走 handle_normal_give" do
      conn0 =
        %Conn{
          character: %Kalevala.Character{
            id: "hengyang:hunter",
            name: "猎人",
            room_id: "hengyang:hunter_room",
            inventory: [],
            meta: %NonPlayerMeta{
              zone_id: "hengyang",
              vitals: Vitals.new(),
              stats: Stats.new(),
              combat: Kantele.Character.Combat.new()
            }
          },
          private: %Conn.Private{channel_changes: []},
          output: []
        }

      event = %Event{
        from_pid: self(),
        topic: "characters/give",
        data: %{
          item_instance: instance(),
          item_name: "包子",
          from_name: "玩家",
          from_id: "player:test",
          reply_to: self()
        }
      }

      _conn = NonPlayerEvents.call(conn0, event)

      # 无 accept 规则：落入通用收受，给玩家回执 give/result(ok:true)
      assert_receive %Event{topic: "give/result", data: %{ok: true}}, 1000
    end
  end

  # ---- GiveEvent.hunter_give_trap（玩家进程侧置位 marks/hunter） ----

  defp player_conn(opts) do
    inventory = Keyword.get(opts, :inventory, [])

    meta = %PlayerMeta{
      vitals: Vitals.new(),
      stats: Stats.new(),
      combat: Kantele.Character.Combat.new()
    }

    %Conn{
      character: %Kalevala.Character{
        id: "player:test",
        name: "玩家",
        room_id: "hengyang:hunter_room",
        inventory: inventory,
        meta: meta
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp character(conn), do: conn.private.update_character || conn.character

  describe "GiveEvent.hunter_give_trap（置位 marks/hunter）" do
    test "收到回执 → 移除捕兽夹并置位 marks/hunter" do
      conn0 = player_conn(inventory: [instance()])

      conn1 =
        GiveEvent.hunter_give_trap(conn0, %{
          data: %{item_id: @trap_id, instance_id: List.first(conn0.character.inventory).id, from_id: "player:test"}
        })

      char = character(conn1)
      assert PlayerMeta.mark(char.meta, "hunter") == 1
      assert PlayerMeta.get_temp(char.meta, "marks/hunter") == 1
      assert char.inventory == []
      assert out_text(conn1) =~ "你把捕兽夹交给了猎人"
    end

    test "不是自己的回执 → 不动状态" do
      conn0 = player_conn(inventory: [instance()])

      conn1 =
        GiveEvent.hunter_give_trap(conn0, %{
          data: %{item_id: @trap_id, instance_id: List.first(conn0.character.inventory).id, from_id: "someone-else"}
        })

      assert conn1.private.update_character == nil
    end
  end

  # ---- 加载器（UCL accept → NonPlayerMeta.accept）----
  # 之前 parse_accept_rules 白名单只收 money/item_id/item_name/any，会丢弃
  # forge/wuxiuwen/reborn/suoyangdan/hunter 等专门派发类规则，导致 meta.accept
  # 变 nil，give 静默落到 handle_normal_give（猎人只收物品不置 marks/hunter）。
  # 直接用 parse_character 走真实加载路径来验证。

  defp load_character_with_accept(rules) do
    zone = %{id: "hengyang"}

    character_data = %{
      name: "猎人",
      description: "",
      accept: rules
    }

    {_key, character} = Loader.parse_character(zone, "hunter", character_data, %{})
    character
  end

  describe "Loader.parse_character 解析特殊 accept 规则" do
    test "kind:hunter 不被白名单丢弃" do
      character = load_character_with_accept([%{kind: "hunter", id: @trap_id}])

      assert [%{kind: "hunter", id: @trap_id}] = character.meta.accept
    end

    test "reborn/forge/wuxiuwen/suoyangdan 同样保留" do
      character =
        load_character_with_accept([
          %{kind: "reborn"},
          %{kind: "forge"},
          %{kind: "wuxiuwen"},
          %{kind: "suoyangdan", id: "longdan"}
        ])

      kinds = Enum.map(character.meta.accept, & &1.kind)
      assert "reborn" in kinds
      assert "forge" in kinds
      assert "wuxiuwen" in kinds
      assert "suoyangdan" in kinds
    end

    test "未知 kind 仍被丢弃" do
      character = load_character_with_accept([%{kind: "totally_unknown"}])

      assert character.meta.accept == nil
    end
  end
end
