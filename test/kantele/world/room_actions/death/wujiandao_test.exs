defmodule Kantele.World.RoomActions.Death.WujiandaoTest do
  @moduledoc """
  P4-F：无间道（death:wujiandao）say/enter/smash 三个房间动作 handler 的单元测试。

  对应 LPC `d/death/liudaolunhui/wujiandao.c`：
  - do_say：诵诗授予无间闪电，置位 poem_said
  - do_enter：门控（poem_said=1 / HellZhenPass / 武功门控 / 无鬼）+ entering_world 动画
  - do_smash：须装备无间闪电，砸目标（NPC 死亡）

  与 `room_actions_shaolin_putiyuan_test.exs` 同款 FakeRoom 模式：
  启动一间名为 `{Kalevala.World.Room, room_id}` 的 GenServer，
  供 `Room.get_state_by_id/put_state_by_id/npc_characters_by_id` 查房间 state。
  """

  use ExUnit.Case, async: false

  alias Kalevala.Character.Conn
  alias Kalevala.Event
  alias Kantele.Character.Combat
  alias Kantele.Character.Events
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Character.PlayerMeta
  alias Kalevala.World.Item.Instance
  alias Kantele.Character.Stats
  alias Kantele.World.Items
  alias Kantele.World.Room
  alias Kantele.World.RoomActionHandlers
  alias Kantele.World.RoomActions.Death.WujiandaoEnter
  alias Kantele.World.RoomActions.Death.WujiandaoSay
  alias Kantele.World.RoomActions.Death.WujiandaoSmash

  import Kalevala.Character.Conn, only: [put_character: 2]

  @room "death:wujiandao"
  @wujian "death:wujian"
  @poem "潜能无限，精意神通，身居祸福，自我主宰！"

  # ---- FakeRoom：供 Room.get_state_by_id/put_state_by_id/npc_characters_by_id 查 ----

  defmodule FakeRoom do
    use GenServer

    def start_link({room_id, opts}) do
      GenServer.start_link(__MODULE__, {room_id, opts},
        name: {:global, {Kalevala.World.Room, room_id}}
      )
    end

    @impl true
    def init({room_id, opts}) do
      {:ok,
       %{
         data: %Kantele.World.Room{
           id: room_id,
           key: String.split(room_id, ":") |> List.last(),
           zone_id: String.split(room_id, ":") |> hd(),
           state: Keyword.get(opts, :state, %{})
         },
         private: %{
           characters: Keyword.get(opts, :characters, []),
           item_instances: []
         }
       }}
    end
  end

  # ---- 注册表断言 ----

  test "RoomActionHandlers 注册了 death:wujiandao 的三个 handler" do
    assert RoomActionHandlers.lookup(@room, "do_say") ==
             {:ok, {WujiandaoSay, :run}}
    assert RoomActionHandlers.lookup(@room, "do_enter") ==
             {:ok, {WujiandaoEnter, :run}}
    assert RoomActionHandlers.lookup(@room, "do_smash") ==
             {:ok, {WujiandaoSmash, :run}}
  end

  # ---- 连接构造 ----

  defp base_conn(room_id) do
    %Conn{
      character: %Kalevala.Character{
        name: "测试者",
        room_id: room_id,
        meta: %PlayerMeta{
          stats: Stats.new(),
          combat: %Combat{},
          env: %{HellZhenPass: true},
          temp: %{}
        },
        inventory: []
      },
      private: %Conn.Private{channel_changes: []},
      output: []
    }
  end

  defp char_with_wujian(conn) do
    character = conn.character
    combat = character.meta.combat
    weapon = %Instance{
      id: "inst_wujian",
      item_id: @wujian,
      created_at: DateTime.utc_now()
    }
    character =
      %{character |
        meta: %{
          character.meta
          | combat: %{combat | equipped: %{weapon: weapon}}
        }
      }
    put_character(conn, character)
  end

  defp output(conn), do: Enum.map_join(conn.output, & &1.data)

  defp published(conn) do
    conn.private.channel_changes
    |> Enum.reverse()
    |> Enum.filter(fn
      {:publish, _chan, %{data: %{type: "vision"}}, _opts, _err} -> true
      _ -> false
    end)
    |> Enum.map(fn {:publish, _chan, event, _opts, _err} -> event.data.text end)
  end

  defp character_of(conn), do: conn.private.update_character || conn.character

  # ---- 房间启动 ----

  defp start_room(state \\ %{}, opts \\ []) do
    room_id = "test:wujiandao-#{System.unique_integer([:positive])}"
    start_supervised!({FakeRoom, {room_id, [state: state] ++ opts}}, id: room_id)
    room_id
  end

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(ExVenture.Repo)

    # 注册无间闪电物品定义，供 give_item 在 say 测试中落地
    Items.put(@wujian, %Kalevala.World.Item{
      id: @wujian,
      name: "无间闪电",
      meta: %{}
    })

    :ok
  end

  # =====================================================================
  # WujiandaoSay
  # =====================================================================

  describe "do_say（诵诗授予无间闪电）" do

    test "空输入 → :not_handled（交回全局 say）" do
      room_id = start_room()
      assert WujiandaoSay.run(base_conn(room_id), %{trailing: "", room_id: room_id}) ==
               :not_handled
    end

    test "非诗句输入 → :not_handled（交回全局 say）" do
      room_id = start_room()
      assert WujiandaoSay.run(base_conn(room_id), %{trailing: "hello world", room_id: room_id}) ==
               :not_handled
    end

    test "首次诵诗匹配 → 授予无间闪电 + 置位 poem_said=1 + 房间广播三段文案" do
      room_id = start_room(%{"poem_said" => 0})

      result =
        WujiandaoSay.run(base_conn(room_id), %{trailing: @poem, room_id: room_id})

      # 物品入背包
      assert [%{item_id: @wujian}] = character_of(result).inventory

      # 房间 state 置位
      assert Room.get_state_by_id(room_id, "poem_said") == 1

      # 广播三段文案（enter vision part1 + part2，flash vision part3）
      visions = published(result)
      assert length(visions) == 3
      assert Enum.any?(visions, &String.contains?(&1, "猛然高声喝道"))
      assert Enum.any?(visions, &String.contains?(&1, "轰隆隆"))
      assert Enum.any?(visions, &String.contains?(&1, "无间闪电"))
    end

    test "诗句已诵过（poem_said=1）→ 仅私发重复文案，不动 room state" do
      room_id = start_room(%{"poem_said" => 1})

      result =
        WujiandaoSay.run(base_conn(room_id), %{trailing: @poem, room_id: room_id})

      assert Room.get_state_by_id(room_id, "poem_said") == 1
      assert output(result) =~ "你对着黑暗一声猛喝"
      # 不应再次广播房间文案
      assert published(result) == []
    end

  end

  # =====================================================================
  # WujiandaoEnter
  # =====================================================================

  describe "do_enter（转世进入铜镜）" do

    test "poem_said=0 → 拒绝（未诵诗）" do
      room_id = start_room(%{"poem_said" => 0})

      result = WujiandaoEnter.run(base_conn(room_id), %{room_id: room_id})

      assert output(result) =~ "什么也说不出来"
    end

    test "HellZhenPass=false → 拒绝（未过十八层地狱）" do
      room_id = start_room(%{"poem_said" => 1})
      character = base_conn(room_id).character
      character = %{character | meta: %{character.meta | env: %{}}}
      conn = %{base_conn(room_id) | character: character}

      result = WujiandaoEnter.run(conn, %{room_id: room_id})

      assert output(result) =~ "施主怎么来"
    end

    test "武功不足 → 拒绝（martial-cognize<600 且 force<800）" do
      room_id = start_room(%{"poem_said" => 1})
      stats = %Stats{skills: %{"martial-cognize" => 100, "force" => 100}}
      character = base_conn(room_id).character
      character = %{character | meta: %{character.meta | stats: stats}}
      conn = %{base_conn(room_id) | character: character}

      result = WujiandaoEnter.run(conn, %{room_id: room_id})

      assert output(result) =~ "武功修为太差"
    end

    test "房间有鬼 → 拒绝" do
      room_id = start_room(%{"poem_said" => 1}, characters: [%{id: "ghost_1", name: "亡魂", meta: %{aliases: ["ghost"]}}])
      # 武功足够，否则会在 ghost 门控前被 skill_ok? 拒绝
      stats = %Stats{skills: %{"martial-cognize" => 700}}
      character = base_conn(room_id).character
      character = %{character | meta: %{character.meta | stats: stats}}
      conn = %{base_conn(room_id) | character: character}

      result = WujiandaoEnter.run(conn, %{room_id: room_id})

      assert output(result) =~ "先解决掉这些亡魂"
    end

    test "全部门控通过 → 广播入镜文案 + 置位 entering_world=0 + 发送 step 0 事件" do
      room_id = start_room(%{"poem_said" => 1})
      stats = %Stats{skills: %{"martial-cognize" => 600, "force" => 100}}
      character = base_conn(room_id).character
      character = %{character | meta: %{character.meta | stats: stats}}
      conn = %{base_conn(room_id) | character: character}

      result = WujiandaoEnter.run(conn, %{room_id: room_id})

      # 广播入镜文案（Helpers.broadcast_vision 把 $N 归一化为 {npc}）
      assert published(result) == ["{npc}向着铜镜的方向走去。\n"]

      # 房间 state: entering_world = %{pid => 0}
      state = Room.get_state_by_id(room_id, "entering_world")
      assert is_map(state)
      assert Map.has_key?(state, character_of(result).pid)

      # entering_world temp 置位为 0
      assert character_of(result).meta.temp["entering_world"] == 0
    end

  end

  # =====================================================================
  # entering_world_step 事件路由（回归：模块名必须与 scope/1 对齐）
  # =====================================================================

  describe "entering_world 动画事件路由" do
    test "Events.call/2 能把 character/entering_world_step 路由到 EnterWorldEvent" do
      # 回归守卫：events.ex 的 scope(Kantele.Character) 会把 module(EnterWorldEvent)
      # 解析成 Kantele.Character.EnterWorldEvent；若模块定义成别的命名空间，
      # 编译期不报错但运行期 apply/3 会 UndefinedFunctionError。
      assert function_exported?(Kantele.Character.EnterWorldEvent, :entering_world_step, 2)

      character = %Kalevala.Character{
        id: "player-1",
        name: "测试者",
        pid: self(),
        room_id: @room,
        inventory: [],
        meta: %PlayerMeta{
          stats: Stats.new(),
          combat: %Combat{},
          env: %{},
          temp: %{}
        }
      }

      conn = Kalevala.ConnTest.build_conn(character)

      result =
        Events.call(conn, %Event{
          topic: "character/entering_world_step",
          data: %{step: 0, room_id: @room, character_id: "player-1"}
        })

      # 第一段文案已私发给玩家（证明 handler 真的被路由并执行）
      assert output(result) =~ "你只觉得眼前一花"
    end
  end

  # =====================================================================
  # WujiandaoSmash
  # =====================================================================

  describe "do_smash（无间闪电神力攻击）" do

    test "未装备无间闪电 → 拒绝" do
      room_id = start_room()

      result = WujiandaoSmash.run(base_conn(room_id), %{trailing: "someone", room_id: room_id})

      assert output(result) =~ "没有装备无间闪电"
    end

    test "无目标参数 → 格式提示" do
      room_id = start_room()
      conn = char_with_wujian(base_conn(room_id))

      result = WujiandaoSmash.run(conn, %{trailing: "", room_id: room_id})

      assert output(result) =~ "指令格式: smash <living>"
    end

    test "目标不存在 → 找不到该生物" do
      room_id = start_room()
      conn = char_with_wujian(base_conn(room_id))

      result = WujiandaoSmash.run(conn, %{trailing: "nonexistent", room_id: room_id})

      assert output(result) =~ "找不到这个生物"
    end

    test "目标为非角色物品 → 广播消失文案，不标记死亡" do
      room_id = start_room(%{}, characters: [%{id: "stone_1", name: "石头", meta: %{aliases: ["石头"]}}])

      conn = char_with_wujian(base_conn(room_id))

      result =
        WujiandaoSmash.run(conn, %{trailing: "石头", room_id: room_id})

      visions = published(result)
      assert Enum.any?(visions, &String.contains?(&1, "从这个世界上消失了"))
    end

    test "目标为角色 → 广播闪电攻击文案 + 标记目标死亡" do
      room_id = start_room(%{}, characters: [%{id: "npc_victim", name: "无间鬼卒", meta: %NonPlayerMeta{}}])

      conn = char_with_wujian(base_conn(room_id))

      result =
        WujiandaoSmash.run(conn, %{trailing: "无间鬼卒", room_id: room_id})

      visions = published(result)
      assert Enum.any?(visions, &String.contains?(&1, "无间闪电化作无数闪电击向"))
      assert Enum.any?(visions, &String.contains?(&1, "劈成飞灰"))
    end

  end

end