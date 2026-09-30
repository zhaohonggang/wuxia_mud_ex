defmodule Kantele.World.ChatRuntimeTest do
  use ExUnit.Case, async: false

  import Kalevala.ConnTest
  import Kalevala.Character.Conn, only: [get_session: 2, put_session: 3]

  alias Kalevala.Character.Foreman.Channel
  alias Kantele.Character.NonPlayerMeta
  alias Kantele.Communication

  @room_id "test:chat-room-#{System.unique_integer([:positive])}"

  setup_all do
    :ok = Communication.register("rooms:#{@room_id}", Kantele.RoomChannel, room_id: @room_id)
    :ok
  end

  setup do
    :ok =
      Communication.subscribe("rooms:#{@room_id}", [
        character: %Kalevala.Character{id: "chat-sub", room_id: @room_id}
      ])

    on_exit(fn ->
      Communication.unsubscribe("rooms:#{@room_id}", [
        character: %Kalevala.Character{id: "chat-sub", room_id: @room_id}
      ])
    end)

    :ok
  end

  defp npc do
    %Kalevala.Character{
      id: "test:jinhua",
      name: "金花",
      pid: self(),
      room_id: @room_id,
      inventory: [],
      meta: %NonPlayerMeta{
        zone_id: "test",
        vitals: Kantele.Character.Vitals.new(),
        stats: Kantele.Character.Stats.new(),
        combat: Kantele.Character.Combat.new()
      }
    }
  end

  @chat_lines [
    "金花哭泣着：我的命怎么这么苦哟。",
    "金花抹着眼泪：娘呀，我好想你呀！",
    "金花叹口气说道：不知今生今世能否再见到我娘。"
  ]

  describe "Kantele.Character.ChatAction" do
    test "从台词池随机挑一句以 speech 广播到房间频道" do
      conn =
        npc()
        |> build_conn()
        |> Kantele.Character.ChatAction.run(%{"lines" => @chat_lines})

      Channel.handle_channels(conn, %{communication_module: Communication})

      assert_receive %Kalevala.Event{
        topic: Kalevala.Event.Message,
        data: %Kalevala.Event.Message{type: "speech", text: text}
      }

      assert text in @chat_lines
    end

    test "空台词池不发消息" do
      conn = npc() |> build_conn() |> Kantele.Character.ChatAction.run(%{"lines" => []})

      Channel.handle_channels(conn, %{communication_module: Communication})
      refute_receive %Kalevala.Event{topic: Kalevala.Event.Message}, 100
    end

    test "发言时写入冷却时间戳，切断自激反馈环" do
      key = Kantele.Brain.Conditions.ChatChance.session_key()
      before = System.monotonic_time(:millisecond)

      conn =
        npc()
        |> build_conn()
        |> Kantele.Character.ChatAction.run(%{"lines" => @chat_lines})

      # ChatAction 往 NPC 自己订阅的 rooms:<id> 频道发言，SpawnController 会因
      # 此再次求值行为树；没有这个时间戳就会「说话→收到自己的消息→再说话」无限循环。
      stamped = get_session(conn, key)
      assert is_integer(stamped)
      assert stamped >= before
    end

    test "空台词池不写冷却时间戳" do
      key = Kantele.Brain.Conditions.ChatChance.session_key()

      conn =
        npc()
        |> build_conn()
        |> Kantele.Character.ChatAction.run(%{"lines" => []})

      assert get_session(conn, key) == nil
    end
  end

  describe "Kantele.Brain.Conditions.Random" do
    test "chance=100 必中" do
      assert Kantele.Brain.Conditions.Random.match?(%{}, build_conn(npc()), %{chance: 100})
    end

    test "chance=0 必不中" do
      refute Kantele.Brain.Conditions.Random.match?(%{}, build_conn(npc()), %{chance: 0})
    end
  end

  describe "Kantele.Brain.Conditions.ChatChance 冷却门控" do
    # 引用模块默认值，避免硬编码：调 @default_cooldown_ms 时测试自动跟随
    @cooldown Kantele.Brain.Conditions.ChatChance.default_cooldown_ms()

    test "无冷却时间戳时只看概率" do
      assert Kantele.Brain.Conditions.ChatChance.match?(
               %{},
               build_conn(npc()),
               %{chance: 100, cooldown_ms: @cooldown}
             )
    end

    test "冷却未到期一律不中（即使 chance=100）" do
      key = Kantele.Brain.Conditions.ChatChance.session_key()
      now = System.monotonic_time(:millisecond)

      conn =
        npc()
        |> build_conn()
        |> put_session(key, now)

      refute Kantele.Brain.Conditions.ChatChance.match?(
               %{},
               conn,
               %{chance: 100, cooldown_ms: @cooldown}
             )
    end

    test "冷却到期后恢复（chance=100 必中）" do
      key = Kantele.Brain.Conditions.ChatChance.session_key()

      conn =
        npc()
        |> build_conn()
        |> put_session(key, System.monotonic_time(:millisecond) - @cooldown - 100)

      assert Kantele.Brain.Conditions.ChatChance.match?(
               %{},
               conn,
               %{chance: 100, cooldown_ms: @cooldown}
             )
    end

    test "chance=0 必不中" do
      refute Kantele.Brain.Conditions.ChatChance.match?(
               %{},
               build_conn(npc()),
               %{chance: 0, cooldown_ms: @cooldown}
             )
    end
  end

  describe "Loader 挂载" do
    @tag :world_data
    test "jinhua 的 chat_chance/chats 组装为 ChatChance + ChatAction 行为树节点" do
      world = Kantele.World.Loader.load()
      jinhua = Enum.find(world.characters, &String.contains?(&1.name, "金花"))
      assert jinhua != nil

      assert %Kalevala.Brain{
               root: %Kalevala.Brain.Sequence{nodes: [chat, _base]}
             } = jinhua.brain

      assert %Kalevala.Brain.ConditionalSelector{nodes: [cond, action]} = chat

      # 必须是 ChatChance（带冷却），不能是裸 Random —— 否则多 NPC 房间会自激刷屏
      assert %Kalevala.Brain.Condition{
               type: Kantele.Brain.Conditions.ChatChance,
               data: %{chance: 5, cooldown_ms: 500}
             } = cond

      assert %Kalevala.Brain.Action{
               type: Kantele.Character.ChatAction,
               data: %{lines: lines}
             } = action

      assert lines == @chat_lines
    end

    @tag :world_data
    test "全世界的闲聊节点都用 ChatChance（回归：不得回退到裸 Random）" do
      world = Kantele.World.Loader.load()

      # 找出真正带 ChatAction 的 NPC：loader.build_brain/2 把闲聊挂成
      # Sequence[ ConditionalSelector[Condition, ChatAction], base ]。
      # 判据是节点树里出现 ChatAction，而不是"首位是 ConditionalSelector"——
      # 后者会把黑虎的 combat-engage、报讯人的 message-match 也算进来。
      {chatters, _plain} =
        Enum.split_with(world.characters, fn c -> contains_chat_action?(c.brain) end)

      assert chatters != [], "no chattering NPCs found - the assertion would be vacuous"

      offenders =
        chatters
        |> Enum.reject(fn c ->
          %Kalevala.Brain{root: %Kalevala.Brain.Sequence{nodes: [first | _]}} = c.brain

          match?(
            %Kalevala.Brain.ConditionalSelector{
              nodes: [%Kalevala.Brain.Condition{type: Kantele.Brain.Conditions.ChatChance}, _]
            },
            first
          )
        end)
        |> Enum.map(& &1.id)

      assert offenders == [],
             "these NPCs still gate chat on a cooldown-less condition: #{inspect(offenders)}"
    end
  end

  defp contains_chat_action?(%Kalevala.Brain{root: root}), do: contains_chat_action?(root)
  defp contains_chat_action?(%Kalevala.Brain.Action{type: Kantele.Character.ChatAction}), do: true
  defp contains_chat_action?(%{nodes: nodes}) when is_list(nodes),
    do: Enum.any?(nodes, &contains_chat_action?/1)

  defp contains_chat_action?(_), do: false
end