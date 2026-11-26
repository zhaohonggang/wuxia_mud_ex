defmodule Kantele.World.InquiryHandlers.Quest do
  @moduledoc """
  历练问询（`kind = "quest"`）—— 张无忌 "历练"/"历炼"/"锻炼" → QUEST_D 接任务。

  LPC 源 `kungfu/class/mingjiao/zhangwuji.c:158-162`：
  张无忌 accept_ask("历练"/"历炼"/"锻炼") → QUEST_D->accept_ask(me)
  → 返回任务 spec → 登记到 player 的 todo 列表。

  玩家侧：收到 `npc/inquiry`（kind="quest"），从 config 读取 quest spec，
  调用 `Kantele.Quest.set_todo/3` 登记进 meta.quests，落盘并渲染接受文案。

  UCL 配置示例（张无忌 inquiries）：

      { key = "历练" value = {
        kind = "quest"
        file = "mingjiao_lilian"
        master_name = "张无忌"
        master_id = "mingjiao_zhangwuji"
        place = "明教大殿"
      } }
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Quest

  def run(conn, config, data) when is_map(config) and is_map(data) do
    case Map.get(data, :asker_id) do
      asker_id when asker_id == conn.character.id -> run_for(conn, config, data)
      _ -> conn
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, config, data) do
    character = current(conn)
    spec = quest_spec(config)

    case Quest.set_todo(PlayerMeta.quests(character.meta), spec) do
      {:ok, new_quests} ->
        meta = PlayerMeta.put_quests(character.meta, new_quests)
        character = %{character | meta: meta}
        Records.save(character)

        conn
        |> Kalevala.Character.Conn.put_character(character)
        |> render(CommandView, "text", %{
          text: "#{Map.get(data, :npc_name) || "他"}道：「好，这#{spec[:file]}之事便托付给你了，务必小心。」\n"
        })
        |> prompt(CommandView, "prompt", %{})

      {:error, reason} ->
        conn
        |> render(CommandView, "text", %{text: reason_text(reason)})
        |> prompt(CommandView, "prompt", %{})
    end
  end

  defp quest_spec(config) do
    file = Map.get(config, "file") || Map.get(config, "quest_file")

    spec = %{
      file: file,
      kill: List.wrap(Map.get(config, "kill") || []),
      item: List.wrap(Map.get(config, "item") || [])
    }

    Map.merge(spec, optional_meta(config))
  end

  defp optional_meta(config) do
    %{
      type: Map.get(config, "type"),
      level: Map.get(config, "level"),
      master_name: Map.get(config, "master_name"),
      master_id: Map.get(config, "master_id"),
      place: Map.get(config, "place")
    }
    |> Map.filter(fn {_k, v} -> not is_nil(v) end)
  end

  defp reason_text(reason) when is_atom(reason) do
    case reason do
      :chain_blocked -> "欲成此事，须先把前头的差事办妥，一步一个脚印，方是正理。\n"
      :mutex_blocked -> "你正有相涉的要事在身，眼下接不得这桩差事。\n"
      :full -> "你手头要办的事已经够多了，先了结几桩再来说话。\n"
      :done -> "这桩差事你早已办妥，无需重复。\n"
      :duplicate -> "这差事你已在办，何必再问？\n"
      :invalid -> "这差事不似真的，恕老夫不相托付。\n"
      other -> "#{inspect(other)}\n"
    end
  end

  defp reason_text(reason), do: "#{reason}\n"

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
