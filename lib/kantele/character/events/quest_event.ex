defmodule Kantele.Character.QuestEvent do
  @moduledoc """
  任务事件（A11/N6 v0，玩家侧）

  `quest/turnin-request`：NPC 发来的交付请求。玩家校验背包里是否有所需
  物品——有则收走物品、发放奖励并往 rumor 频道播报谣言；无则提示引导。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kalevala.World.Item
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records

  def turnin_request(conn, %{data: data}) do
    character = conn.character
    item_id = Map.get(data, :item_id)

    {instance, rest} =
      character.inventory
      |> Enum.split_with(&(&1.item_id == item_id))

    cond do
      instance == [] ->
        conn
        |> render(CommandView, "text", %{text: "#{Map.get(data, :prompt)}\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        complete(conn, character, rest, data)
    end
  end

  defp complete(conn, character, inventory_rest, data) do
    rewards = Map.get(data, :rewards) || %{}
    stats = character.meta.stats

    stats = %{
      stats
      | combat_exp: stats.combat_exp + (Map.get(rewards, :exp) || 0),
        potential: stats.potential + (Map.get(rewards, :potential) || 0),
        score: stats.score + (Map.get(rewards, :score) || 0),
        weiwang: stats.weiwang + (Map.get(rewards, :weiwang) || 0)
    }

    coins = (character.meta.coins || 0) + (Map.get(rewards, :coins) || 0)

    # 收走任务物品（v0 只收一个实例）
    character =
      character
      |> Map.put(:inventory, inventory_rest)
      |> Map.put(:meta, %{character.meta | stats: stats, coins: coins})

    Records.save(character)

    publish_rumor(Map.get(data, :rumor))

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: quest_text(data, rewards)})
    |> prompt(CommandView, "prompt", %{})
  end

  defp quest_text(data, rewards) do
    [
      "你把东西交给了#{Map.get(data, :vendor_name)}。\n",
      "任务完成！（实战经验+#{Map.get(rewards, :exp) || 0} 潜能+#{
        Map.get(rewards, :potential) || 0
      } 阅历+#{Map.get(rewards, :score) || 0} 威望+#{Map.get(rewards, :weiwang) || 0} 铜钱+#{
        Map.get(rewards, :coins) || 0
      }）\n"
    ]
  end

  # 谣言播报：rumor 频道全体在线玩家可见（登录时订阅）
  defp publish_rumor(rumor) when is_binary(rumor) and rumor != "" do
    event = %Kalevala.Event{
      acting_character: nil,
      from_pid: self(),
      topic: Kalevala.Event.Message,
      data: %Kalevala.Event.Message{
        channel_name: "rumor",
        character: Kantele.Communication.system_character(),
        id: Kalevala.Event.Message.generate_id(),
        text: rumor,
        type: "announcement"
      }
    }

    case Kantele.Communication.publish("rumor", event, []) do
      :ok -> :ok
      _ -> :error
    end
  end

  defp publish_rumor(_), do: :ok
end
