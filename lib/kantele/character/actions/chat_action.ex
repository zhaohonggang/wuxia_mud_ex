defmodule Kantele.Character.ChatAction do
  @moduledoc """
  NPC 闲聊动作（A10/N3，对应 LPC chat_chance）

  brain 节点 `actions/chat`：从 `lines` 台词池随机挑一条，
  以普通说话（type: "speech"）发到所在房间频道。
  """

  use Kalevala.Character.Action

  @impl true
  def run(conn, params) do
    lines = Map.get(params, "lines", [])

    case lines do
      [] ->
        conn

      lines ->
        line = Enum.random(lines)

        # Stamp the cooldown BEFORE publishing.  Publishing feeds the room
        # channel this NPC is subscribed to, so the brain runs again on our own
        # message; the stamp has to be visible to that very next run.
        conn = put_session(conn, Kantele.Brain.Conditions.ChatChance.session_key(),
                            System.monotonic_time(:millisecond))

        publish_message(
          conn,
          "rooms:#{conn.character.room_id}",
          line,
          [],
          &publish_error/2
        )
    end
  end

  def publish_error(conn, _error), do: conn
end

defmodule Kantele.Brain.Conditions.Random do
  @moduledoc """
  概率条件（A10/N3）：data %{chance: n}，n 为百分比（1-100）

  每次节点求值独立掷骰，命中即放行后续 action。
  """

  @behaviour Kalevala.Brain.Condition

  @impl true
  def match?(_event, _conn, %{chance: chance}) when is_integer(chance) and chance > 0 do
    :rand.uniform(100) <= chance
  end

  def match?(_event, _conn, _data), do: false
end

defmodule Kantele.Brain.Conditions.ChatChance do
  @moduledoc """
  NPC 闲聊门控：冷却 + 概率（A10/N3 chat_chance）

  `Kantele.World.Loader.build_brain/2` 把这个节点挂在 NPC 行为树的**最前面**，
  而 `Kantele.Character.SpawnController.event/2` 会对 NPC 收到的**每一个事件**
  求值一次行为树。NPC 订阅了 `rooms:<room_id>`，`Kantele.Character.ChatAction`
  又把闲聊发到同一个频道——**发言者会收到自己刚发的消息**，于是
  「说话 → 收到事件 → 掷骰 → 再说话」构成反馈环。

  单个 NPC 的 `chat_chance` 通常 < 100%（次临界），单独不会发散；但一间房里
  有 N 个同样配置的 NPC 时，每条消息会引发 N 次独立掷骰，繁殖率 = N × p/100。
  mingjiao 的 `miaorenbuluo` 房间放了 4 个 `miaozuwushi`、每个
  `chat_chance = 30`，繁殖率 4 × 0.3 = **1.2 > 1**，超临界 → 指数刷屏
  （日志里 ChatAction 队列涨到 47、46、29…）。

  LPC 侧 `chat_chance` 是在 NPC 的 `call_out` **心跳**上评估的，不是每条消息。
  这里用**时间冷却**还原那个语义：同一 NPC 两次闲聊之间至少间隔
  `cooldown_ms`，把过程从「无界繁殖」变成「有界速率」
  （上限 = 房间内 NPC 数 / cooldown），无论房间事件多密集都不会发散。

  `Kalevala.Brain.Conditions.Random` 保持原样（通用概率条件），只有闲聊走这里。
  """

  @behaviour Kalevala.Brain.Condition

  alias Kalevala.Character.Conn

  @default_cooldown_ms 3_000
  @session_key "npc_chat_at"

  @doc "Session key holding the monotonic timestamp (ms) of the last chat."
  def session_key, do: @session_key

  @doc "Default minimum gap between two chats of the same NPC, in ms."
  def default_cooldown_ms, do: @default_cooldown_ms

  @impl true
  def match?(_event, conn, data) do
    chance = Map.get(data, :chance, 0)
    cooldown_ms = Map.get(data, :cooldown_ms, @default_cooldown_ms)

    is_integer(chance) and chance > 0 and cooled_down?(conn, cooldown_ms) and
      :rand.uniform(100) <= chance
  end

  defp cooled_down?(conn, cooldown_ms) do
    case Conn.get_session(conn, @session_key) do
      nil ->
        true

      last ->
        System.monotonic_time(:millisecond) - last >= cooldown_ms
    end
  end
end
