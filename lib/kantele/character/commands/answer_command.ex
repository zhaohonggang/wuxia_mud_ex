defmodule Kantele.Character.AnswerCommand do
  @moduledoc """
  回答命令：`answer <类型>` / `answer <玩家> <消息>` / `answer Y|N`

  对应 LPC cmds/std/answer.c 与 moye.c `do_answer`。

  三条路径（按优先级）：

  1. Forge 路径：处于 `Forging` 会话 status=="answer_type" 时，
     `answer <类型>` 把选择转交莫邪进程裁决（room/forge_answer）。

  2. quest_gift 路径：`answer Y|N`（或 是/否）。
     读 `temp[:quest_gift]` = %{npc, obj, gongxian}：
     - Y：扣除门贡 gongxian，发放物品 obj，清 temp
     - N：婉拒，清 temp
     由 `AskCommand` 在 `ask <npc> quest` 时设置 temp[:quest_gift]。

  3. ask_you 路径：`answer <玩家> <消息>`。
     读 `temp[:ask_you]`（由 `ask <玩家>` 设置），在房间广播回答。

  否则走 stub 行为（回答系统/你要回答什么）。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.World.Forging
  alias Kantele.World.Items
  alias Kantele.World.RoomActions.Helpers
  alias Kalevala.World.Item.Instance

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    case maybe_forge(conn, rest) do
      {:ok, conn} -> conn
      :passthrough ->
        case handle_quest_gift(conn, rest) do
          {:ok, conn} -> conn
          :passthrough ->
            case handle_ask_you(conn, rest) do
              {:ok, conn} -> conn
              :passthrough -> stub_message(conn)
            end
        end
    end
  end

  def run(conn, %{}) do
    case maybe_forge(conn, nil) do
      {:ok, conn} -> conn
      :passthrough -> stub_empty(conn)
    end
  end

  # ---- Forge 路径（保持原有逻辑） ----

  defp maybe_forge(conn, type) do
    character = conn.character
    session = Forging.get(character.id)

    if is_nil(session) or session.status != "answer_type" or is_nil(type) or
         String.trim(type) == "" do
      :passthrough
    else
      conn
      |> event("room/forge_answer", %{
        type: String.trim(type),
        target: "moye",
        from_id: character.id,
        from_name: character.name,
        reply_to: self()
      })
      |> then(fn conn -> {:ok, conn} end)
    end
  end

  # ---- quest_gift 路径：answer Y|N ----

  defp handle_quest_gift(conn, rest) do
    character = conn.character
    quest_gift = PlayerMeta.get_temp(character.meta, :quest_gift)
    answer = String.downcase(String.trim(rest))

    case {quest_gift, answer} do
      {%{npc: npc, obj: obj, gongxian: gongxian}, answer}
          when answer in ["y", "yes", "是"] ->
        accept_quest_gift(conn, character, npc, obj, gongxian)

      {%{npc: _npc, obj: _obj, gongxian: _gongxian}, answer}
          when answer in ["n", "no", "否"] ->
        decline_quest_gift(conn, character)

      {nil, _} ->
        :passthrough

      {_, _} ->
        {:ok,
         conn
         |> render(CommandView, "text", %{text: "请输入 Y 接受或 N 拒绝。\n"})
         |> prompt(CommandView, "prompt", %{})}
    end
  end

  defp accept_quest_gift(conn, character, npc, obj, gongxian) do
    stats = character.meta.stats || %Stats{}
    current_gongxian = stats.gongxian || 0

    cond do
      current_gongxian < gongxian ->
        {:ok,
         conn
         |> render(CommandView, "text", %{text: "你的门贡不足，无法接受#{npc}的赠予。\n"})
         |> prompt(CommandView, "prompt", %{})}

      true ->
        item = Items.get!(obj)
        instance = %Instance{
          id: Instance.generate_id(),
          item_id: item.id,
          created_at: DateTime.utc_now(),
          item: item
        }

        new_stats = %{stats | gongxian: current_gongxian - gongxian}
        new_meta =
          character.meta
          |> Map.put(:stats, new_stats)
          |> PlayerMeta.delete_temp(:quest_gift)

        new_character = %{
          character
          | meta: new_meta,
            inventory: [instance | character.inventory]
        }

        {:ok,
         conn
         |> put_character(new_character)
         |> render(
           CommandView,
           "text",
           %{text: "你从#{npc}处接过了#{item.name}，支付了#{gongxian}门贡。\n"}
         )
         |> prompt(CommandView, "prompt", %{})}
    end
  end

  defp decline_quest_gift(conn, character) do
    new_meta = PlayerMeta.delete_temp(character.meta, :quest_gift)
    new_character = %{character | meta: new_meta}

    {:ok,
     conn
     |> put_character(new_character)
     |> render(CommandView, "text", %{text: "你婉拒了赠予。\n"})
     |> prompt(CommandView, "prompt", %{})}
  end

  # ---- ask_you 路径：answer <玩家> <消息> ----

  defp handle_ask_you(conn, rest) do
    character = conn.character
    asker_name = PlayerMeta.get_temp(character.meta, :ask_you)

    case {asker_name, rest} do
      {asker_name, rest} when is_binary(asker_name) and is_binary(rest) ->
        case split_ask_you(rest) do
          {target, msg} when is_binary(target) and is_binary(msg) ->
            if String.trim(msg) != "" and String.downcase(target) == String.downcase(asker_name) do
              broadcast_ask_you(conn, character, asker_name, msg)
            else
              :passthrough
            end

          _ ->
            :passthrough
        end

      {nil, _} ->
        :passthrough

      {_, _} ->
        :passthrough
    end
  end

  defp split_ask_you(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [target, msg] -> {String.trim(target), String.trim(msg)}
      [target] -> {String.trim(target), ""}
      _ -> {nil, nil}
    end
  end

  defp broadcast_ask_you(conn, character, asker_name, msg) do
    room_id = character.room_id
    template = "{npc} 回答 #{asker_name}: '#{msg}'"

    new_meta = PlayerMeta.delete_temp(character.meta, :ask_you)
    new_character = %{character | meta: new_meta}

    {:ok,
     conn
     |> put_character(new_character)
     |> Helpers.broadcast_vision(room_id, template)
     |> assign(:prompt, false)}
  end

  # ---- Stub（保留原有） ----

  defp stub_message(conn) do
    conn
    |> render(CommandView, "text", %{text: "回答系统目前不支持该选项。\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp stub_empty(conn) do
    conn
    |> render(CommandView, "text", %{text: "你要回答什么？\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
