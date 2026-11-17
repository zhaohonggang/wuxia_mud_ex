defmodule Kantele.Character.ShaolinPromotionEvent do
  @moduledoc """
  少林辈分晋升的跨进程回执（#633–#635）。

  玩家侧：`shaolin_promotion/give` 校验达摩令 / 推荐信并落 `fight_ok` /
  `apprentice_ok`；`shaolin_promotion/fight-started` 消费 `fight_ok`；
  `shaolin_promotion/duel-result` 收推荐信。

  NPC 侧：`shaolin_promotion/give-result` 播放 `accept_object/2` 的 say/smile；
  `shaolin_promotion/accept-fight` 起 LPC 1 拍 `call_out`，
  `checking/3` 轮询直到胜负分出。

  胜负不等号严格照 LPC `qing.h`/`dao.h`/`hui.h`/`cheng.h`：
  胜 `NPC.qi * 100 / NPC.max_qi <= 50`，败 `player.qi * 100 / player.max_qi < 50`。
  """

  use Kalevala.Character.Event

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.World.NpcActions.CallOut
  alias Kantele.World.NpcActions.Helpers, as: NpcHelpers
  alias Kantele.World.Room
  alias Kantele.World.Items
  alias Kalevala.World.Item

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  # ---- 玩家侧：give 回执 ----

  def give(conn, %{data: data}) do
    character = conn.character

    if Map.get(data, :from_id) == character.id do
      rule = Map.get(data, :rule) || %{}
      npc_name = Map.get(data, :npc_name) || "对方"

      case Map.get(rule, :action) do
        "duel" -> give_damo_ling(conn, character, data, rule, npc_name)
        "letter" -> give_letter(conn, character, data, rule, npc_name)
        _ -> give_decline(conn, character, data, npc_name, "这东西给我可没有什么用。")
      end
    else
      conn
    end
  end

  def give(conn, _event), do: conn

  # LPC qing/cheng/hui/dao.h：若已持有下一级推荐信，先拒绝达摩令，不消耗物品。
  defp give_damo_ling(conn, character, data, rule, npc_name) do
    award_item = Map.get(rule, :award_item)
    already? = truthy?(temp(character, "have_letter")) and carries_item?(character, award_item)
    generation = family_generation(character)
    master_generation = Map.get(rule, :master_generation)

    cond do
      already? ->
        give_decline(
          conn,
          character,
          data,
          npc_name,
          Map.get(rule, :already_msg) || ["怎么样，你拿我的推荐信去拜师了吗 ?"]
        )

      not is_integer(master_generation) or generation != master_generation + 1 ->
        give_decline(conn, character, data, npc_name, Map.get(rule, :fail_msg))

      true ->
        meta = PlayerMeta.put_temp(character.meta, "fight_ok", 1)
        character = consume(character, data)
        character = %{character | meta: meta}
        Records.save(character)

        text = Map.get(rule, :msg) || ["好，既然已得到方丈许可，我们就来验证一下武功。"]

        conn =
          conn
          |> put_character(character)
          |> NpcHelpers.render("你把#{item_name(data)}交给了#{npc_name}。\n")

        reply_to_npc(conn, data, true, text, fight_ok: true)
    end
  end

  # LPC cheng/hui/dao/xuan.h：收下一级推荐信 → apprentice_ok=1，销毁信件。
  defp give_letter(conn, character, data, rule, npc_name) do
    required = Map.get(rule, :require_flag) || "have_letter"

    cond do
      not truthy?(temp(character, required)) ->
        give_decline(conn, character, data, npc_name, Map.get(rule, :fail_msg))

      true ->
        flag = Map.get(rule, :set_flag) || "apprentice_ok"
        meta = PlayerMeta.put_temp(character.meta, flag, 1)
        character = consume(character, data)
        character = %{character | meta: meta}
        Records.save(character)

        text =
          (Map.get(rule, :msg) || ["好，%name%，你愿意拜我为师吗？"])
          |> pick()
          |> String.replace("%name%", character.name)

        conn =
          conn
          |> put_character(character)
          |> NpcHelpers.render("你把#{item_name(data)}交给了#{npc_name}。\n")

        reply_to_npc(conn, data, true, text, [])
    end
  end

  defp give_decline(conn, character, data, npc_name, text) do
    conn
    |> put_character(character)
    |> NpcHelpers.render("你把#{item_name(data)}交给了#{npc_name}。\n")
    |> reply_to_npc(data, false, text || ["这东西给我可没有什么用。"], [])
  end

  defp reply_to_npc(conn, data, ok, text, extra) do
    case Map.get(data, :reply_to) do
      pid when is_pid(pid) ->
        payload = %{
          ok: ok,
          text: pick(text),
          from_id: Map.get(data, :from_id),
          from_name: Map.get(data, :from_name),
          npc_name: Map.get(data, :npc_name),
          room_id: Map.get(data, :room_id)
        }

        send(pid, %Event{
          from_pid: self(),
          topic: "shaolin_promotion/give-result",
          data: Map.merge(payload, Map.new(extra))
        })

      _ ->
        :ok
    end

    conn
  end

  defp pick(lines) when is_list(lines) and lines != [], do: Enum.random(lines)
  defp pick(text) when is_binary(text), do: text
  defp pick(_), do: "这东西给我可没有什么用。"

  # ---- NPC 侧：accept_object 回执台词 + fight_ok 记账 ----

  def npc_give_result(conn, %{data: data}) do
    text = Map.get(data, :text)
    npc_name = Map.get(data, :npc_name) || conn.character.name
    room_id = Map.get(data, :room_id) || conn.character.room_id

    conn =
      if is_binary(text) and String.trim(text) != "" do
        NpcHelpers.say(conn, room_id, npc_name, text)
      else
        conn
      end

    if Map.get(data, :ok) and Map.get(data, :fight_ok) do
      flag = fight_flag(Map.get(data, :from_id) || Map.get(data, :from_name) || "")
      meta = put_npc_temp(conn.character.meta, flag, 1)
      put_character(conn, %{conn.character | meta: meta})
    else
      conn
    end
  end

  def npc_give_result(conn, _event), do: conn

  # ---- 玩家侧：accept_fight 消费 fight_ok ----

  def fight_started(conn, _event) do
    meta = PlayerMeta.delete_temp(conn.character.meta, "fight_ok")
    put_character(conn, %{conn.character | meta: meta})
  end

  # ---- NPC 侧：accept_fight + checking ----

  @doc "NPC 收到 `shaolin_promotion/accept-fight`：照 LPC `call_out(\"checking\", 1, ...)` 起轮询"
  def accept_fight(conn, %{data: data}) do
    player_id = Map.get(data, :player_id)
    npc = conn.character
    flag = fight_flag(player_id || "")

    if is_binary(player_id) and truthy?(get_npc_temp(npc.meta, flag)) do
      meta = delete_npc_temp(npc.meta, flag)
      conn = put_character(conn, %{npc | meta: meta})
      rule = Map.get(data, :rule) || %{}

      CallOut.schedule(
        conn.character,
        __MODULE__,
        :checking,
        1,
        [player_id, rule]
      )

      notify_player(conn.character, player_id, "shaolin_promotion/fight-started", %{})
      conn
    else
      conn
    end
  end

  def accept_fight(conn, _event), do: conn

  @doc """
  LPC `checking(me, ob)`：还在打就 2 拍后再查；玩家不在房则停。
  胜 `NPC.qi*100/max <= 50` 发信；败 `player.qi*100/max < 50` 只提示。
  """
  def checking(conn, player_id, rule) do
    npc = conn.character
    room_id = npc.room_id

    cond do
      fighting?(npc) ->
        CallOut.schedule(npc, __MODULE__, :checking, 2, [player_id, rule])
        conn

      true ->
        case player_snapshot(room_id, player_id) do
          nil ->
            conn

          player ->
            npc_pct = vitals_pct(npc)
            player_pct = vitals_pct(player)

            cond do
              npc_pct <= 50 -> finish_duel(conn, player, rule, :win)
              player_pct < 50 -> finish_duel(conn, player, rule, :lose)
              true -> conn
            end
        end
    end
  end

  def checking(conn, _player_id), do: conn

  defp finish_duel(conn, player, rule, outcome) do
    item_id = Map.get(rule, :award_item)

    data = %{
      outcome: outcome,
      item_id: item_id,
      instance_id:
        if(outcome == :win and is_binary(item_id),
          do: Item.Instance.generate_id(),
          else: nil
        ),
      npc_name: conn.character.name,
      room_id: conn.character.room_id,
      player_name: player.name,
      win_msg: Map.get(rule, :win_msg),
      lose_msg: Map.get(rule, :lose_msg)
    }

    notify_player(conn.character, player.id, "shaolin_promotion/duel-result", data)
    conn
  end

  # ---- 玩家侧：斗武结果 ----

  def duel_result(conn, %{data: data}) do
    character = conn.character

    if Map.get(data, :from_id) == character.id or
         Map.get(data, :player_name) == character.name do
      case Map.get(data, :outcome) do
        :win -> duel_win(conn, character, data)
        :lose -> duel_lose(conn, character, data)
        _ -> conn
      end
    else
      conn
    end
  end

  def duel_result(conn, _event), do: conn

  defp duel_win(conn, character, data) do
    item_id = Map.get(data, :item_id)
    instance_id = Map.get(data, :instance_id)

    character =
      if is_binary(item_id) and is_binary(instance_id) and not carries_instance?(character, instance_id) do
        instance = %Item.Instance{
          id: instance_id,
          item_id: item_id,
          created_at: DateTime.utc_now()
        }

        %{character | inventory: [instance | character.inventory]}
      else
        character
      end

    meta = PlayerMeta.put_temp(character.meta, "have_letter", 1)
    character = %{character | meta: meta}
    Records.save(character)

    room_id = Map.get(data, :room_id) || character.room_id
    npc_name = Map.get(data, :npc_name) || "对方"

    conn =
      conn
      |> put_character(character)
      |> NpcHelpers.say(room_id, npc_name, pick(data[:win_msg]) || win_text())

    if is_binary(room_id) do
      conn
      |> NpcHelpers.broadcast(room_id, "#{npc_name}交给#{character.name}一封推荐信。\n")
      |> NpcHelpers.render("你获得了一封推荐信。\n")
    else
      NpcHelpers.render(conn, "你获得了一封推荐信。\n")
    end
  end

  defp duel_lose(conn, character, data) do
    room_id = Map.get(data, :room_id) || character.room_id
    npc_name = Map.get(data, :npc_name) || "对方"

    NpcHelpers.say(
      conn,
      room_id,
      npc_name,
      pick(data[:lose_msg]) || "看来大侠还得多加练习，方能在少林诸多弟子中出人头地 !"
    )
  end

  defp win_text do
    "青出于蓝胜于蓝，不愧是少林寺的佳弟子！恭喜你了！"
  end

  # ---- 事件发送 / 快照工具 ----

  defp notify_player(npc, player_id, topic, data) when is_binary(player_id) do
    room_id = Map.get(npc, :room_id)

    if is_binary(room_id) do
      room_id
      |> Room.npc_characters_by_id()
      |> Enum.find(&(&1.id == player_id))
      |> case do
        %{pid: pid} when is_pid(pid) ->
          send(pid, %Event{
            from_pid: self(),
            topic: topic,
            data: Map.merge(data, %{npc_name: npc.name, from_id: player_id, from_name: npc.name})
          })

        _ ->
          :ok
      end
    else
      :ok
    end
  end

  defp notify_player(_npc, _player_id, _topic, _data), do: :ok

  defp fighting?(npc) do
    case Map.get(npc, :meta) || %{} do
      %{combat: combat} when is_map(combat) -> (Map.get(combat, :enemies) || []) != []
      _ -> false
    end
  end

  defp player_snapshot(room_id, player_id) when is_binary(room_id) do
    Enum.find(Room.npc_characters_by_id(room_id) || [], &(&1.id == player_id))
  end

  defp player_snapshot(_room_id, _player_id), do: nil

  defp vitals_pct(character) do
    vitals = Map.get(Map.get(character, :meta) || %{}, :vitals) || %{}
    qi = Map.get(vitals, :qi) || 0
    max_qi = Map.get(vitals, :max_qi) || 0

    if is_integer(max_qi) and max_qi > 0 do
      div(qi * 100, max_qi)
    else
      100
    end
  end

  defp family_generation(character) do
    case Map.get(Map.get(character.meta, :family) || %{}, :generation) do
      gen when is_integer(gen) -> gen
      _ -> 0
    end
  end

  # PlayerMeta.put_temp/3 只接受 %PlayerMeta{}；NPC 是 %NonPlayerMeta{}，
  # 但两者都以 meta.temp 存 LPC query_temp 语义，直接按 map 读写即可。
  defp get_npc_temp(meta, key) do
    temp = Map.get(meta, :temp) || %{}
    Map.get(temp, key)
  end

  defp put_npc_temp(meta, key, value) do
    temp = Map.get(meta, :temp) || %{}
    %{meta | temp: Map.put(temp, key, value)}
  end

  defp delete_npc_temp(meta, key) do
    temp = Map.get(meta, :temp) || %{}
    %{meta | temp: Map.delete(temp, key)}
  end

  defp fight_flag(id), do: "shaolin_promotion/fight_ok/#{id}"

  defp temp(character, key) do
    temp = Map.get(character.meta, :temp) || %{}
    Map.get(temp, key) || Map.get(temp, String.to_atom(key))
  rescue
    _ -> nil
  end

  defp truthy?(nil), do: false
  defp truthy?(false), do: false
  defp truthy?(0), do: false
  defp truthy?(""), do: false
  defp truthy?(_), do: true

  defp consume(character, data) do
    instance_id = Map.get(data, :instance_id)
    inventory = Enum.reject(character.inventory || [], &(&1.id == instance_id))
    %{character | inventory: inventory}
  end

  defp carries_item?(character, item_id) when is_binary(item_id) do
    Enum.any?(character.inventory || [], &(&1.item_id == item_id))
  end

  defp carries_item?(_character, _item_id), do: false

  defp carries_instance?(character, instance_id) do
    Enum.any?(character.inventory || [], &(&1.id == instance_id))
  end

  defp item_name(data) do
    case Items.get(Map.get(data, :item_id)) do
      {:ok, item} -> item.name
      _ -> "东西"
    end
  end
end
