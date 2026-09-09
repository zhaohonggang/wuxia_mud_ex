defmodule Kantele.Character.QuestEvent do
  @moduledoc """
  任务事件（A11/N6 v0 + v1，玩家侧）

  `quest/turnin-request`：NPC 发来的交付请求。玩家校验背包里是否有所需
  物品——有则收走物品、发放奖励并往 rumor 频道播报谣言；无则提示引导。

  `quest/report`：NPC 发来的无物品完成请求（师门击杀类）。玩家校验在办任务
  的击杀进度已达标后结算（奖励走 `Kantele.Quest.Reward` 阶梯/里程碑）。

  `quest/ask-result`：NPC 应答请求任务。成功则记录任务到 todo；失败则提示原因。
  `quest/cancel-result`：NPC 应答取消任务。成功则从 todo 移除；失败则提示原因。
  """

  use Kalevala.Character.Event

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Quest
  alias Kantele.Quest.Reward

  def turnin_request(conn, %{data: data}) do
    character = conn.character

    if kill_requirement_met?(PlayerMeta.quests(character.meta), Map.get(data, :quest)) do
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
    else
      conn
      |> render(CommandView, "text", %{text: "#{Map.get(data, :prompt)}\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  @doc "无物品完成结算（师门击杀类）：在办任务 + 击杀进度达标才结算"
  def report(conn, %{data: data}) do
    character = conn.character
    quest_id = Map.get(data, :quest)
    state = PlayerMeta.quests(character.meta)

    with true <- is_binary(quest_id) and quest_id != "",
         %{} <- Quest.get_todo(state, quest_id),
         true <- kill_requirement_met?(state, quest_id) do
      complete(conn, character, character.inventory, data)
    else
      _ ->
        conn
        |> render(CommandView, "text", %{text: "#{Map.get(data, :prompt)}\n"})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def ask_result(conn, %{data: %{ok: true, quest: quest} = data}) do
    character = conn.character

    # 任务规格：%{file:, kill:, item:}
    case Quest.set_todo(PlayerMeta.quests(character.meta), quest) do
      {:ok, new_quests} ->
        meta = Map.put(character.meta, :quests, new_quests)
        character = %{character | meta: meta}
        Records.save(character)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{
          text: "#{Map.get(data, :npc_name)}道：「好，这#{quest.file}之事便托付给你了，务必小心。」\n"
        })
        |> prompt(CommandView, "prompt", %{})

      {:error, reason} ->
        conn
        |> render(CommandView, "text", %{text: reason_text(reason)})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  def ask_result(conn, %{data: %{ok: false, reason: reason, npc_name: npc_name}}) do
    conn
    |> render(CommandView, "text", %{text: "#{npc_name}摇头道：「#{reason}」\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # 接受失败原因转武侠风文案（Q1-T4 链式前置提示）
  defp reason_text(reason) when is_atom(reason) do
    case reason do
      :chain_blocked -> "周不通捻须叹道：「欲成此事，须先把前头的差事办妥，一步一个脚印，方是正理。」\n"
      :mutex_blocked -> "你正有相涉的要事在身，眼下接不得这桩差事。\n"
      :full -> "你手头要办的事已经够多了，先了结几桩再来说话。\n"
      :done -> "这桩差事你早已办妥，无需重复。\n"
      :duplicate -> "这差事你已在办，何必再问？\n"
      :invalid -> "这差事不似真的，恕老夫不相托付。\n"
      other -> "#{inspect(other)}\n"
    end
  end

  defp reason_text(reason), do: "#{reason}\n"

  def cancel_result(conn, %{data: %{ok: true, quest: quest_file, npc_name: npc_name}}) do
    character = conn.character
    state = PlayerMeta.quests(character.meta)
    new_state = Quest.del_todo(state, quest_file)
    meta = Map.put(character.meta, :quests, new_state)
    character = %{character | meta: meta}
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: "#{npc_name}点头道：「#{quest_file}之事既已作罢，你便自去忙吧。」\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  def cancel_result(conn, %{data: %{ok: false, reason: reason, npc_name: npc_name}}) do
    conn
    |> render(CommandView, "text", %{text: "#{npc_name}道：「#{reason}」\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp kill_requirement_met?(quests_state, quest_file) when is_map(quests_state) do
    case Quest.get_todo(quests_state, quest_file) do
      # 未登记任务（纯物品交付路径）：跳过击杀校验
      nil ->
        true

      task ->
        killed = Map.get(task, :killed, %{})

        # 无击杀要求则通过；否则每个已登记怪物都须击杀至少 1
        map_size(killed) == 0 or
          Enum.all?(killed, fn {_monster, count} -> count >= 1 end)
    end
  end

  defp kill_requirement_met?(nil, _quest_file), do: true

  defp complete(conn, character, inventory_rest, data) do
    quest_id = Map.get(data, :quest)
    state0 = PlayerMeta.quests(character.meta)
    rewards = Reward.final(state0, quest_id, Map.get(data, :rewards))
    milestone = Quest.milestone(Quest.quest_count(state0) + 1)
    stats = character.meta.stats

    stats = %{
      stats
      | combat_exp: stats.combat_exp + (Map.get(rewards, :exp) || 0),
        potential: stats.potential + (Map.get(rewards, :potential) || 0),
        score: stats.score + (Map.get(rewards, :score) || 0),
        weiwang: stats.weiwang + (Map.get(rewards, :weiwang) || 0),
        gongxian: stats.gongxian + (Map.get(rewards, :gongxian) || 0)
    }

    coins = (character.meta.coins || 0) + (Map.get(rewards, :coins) || 0)

    # 记录任务进度：标记已解、连续计数 +1 并从在办移除（quest id 见 data[:quest]）
    {quest_state, quest_id} = update_quests(character.meta, data)

    character =
      character
      |> Map.put(:inventory, inventory_rest)
      |> Map.put(:meta, %{
        character.meta
        | stats: stats,
          coins: coins,
          quests: quest_state
      })

    Records.save(character)

    publish_rumor(Map.get(data, :rumor))

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: quest_text(data, rewards, quest_id, milestone)})
    |> prompt(CommandView, "prompt", %{})
  end

  # 任务进度更新（CORE_USER_QUEST）：有 quest id 则 set_solved + 连续计数 +1 + del_todo
  defp update_quests(meta, data) do
    quest_id = Map.get(data, :quest)

    if is_binary(quest_id) and quest_id != "" do
      state = PlayerMeta.quests(meta)

      state =
        case Quest.set_solved(state, %{file: quest_id}) do
          {:ok, s} -> s
          _ -> state
        end

      {Quest.del_todo(state, quest_id) |> Quest.bump_quest_count(), quest_id}
    else
      {PlayerMeta.quests(meta), nil}
    end
  end

  defp quest_text(data, rewards, _quest_id, milestone) do
    milestone_line =
      case milestone do
        {:ok, tier} -> "\n（连续完成 #{tier} 次，气息鼓荡——有额外的江湖名望！）\n"
        _ -> ""
      end

    [
      "你把东西交给了#{Map.get(data, :vendor_name)}。\n",
      "任务完成！（实战经验+#{Map.get(rewards, :exp) || 0} 潜能+#{Map.get(rewards, :potential) || 0} 阅历+#{
        Map.get(rewards, :score) || 0
      } 威望+#{Map.get(rewards, :weiwang) || 0} 门派贡献+#{Map.get(rewards, :gongxian) || 0} 铜钱+#{
        Map.get(rewards, :coins) || 0
      }）\n",
      milestone_line
    ]
    |> IO.iodata_to_binary()
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
