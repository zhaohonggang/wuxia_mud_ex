defmodule Kantele.World.InquiryHandlers.XiaoyaoZhihuan do
  @moduledoc """
  无崖子「逍遥神仙环 / 掌门人信物」问询（`kind = "xiaoyao_zhihuan"`）。

  对应 LPC `kungfu/class/xiaoyao/wuyazi.c:605-654` 的 `ask_zhihuan()`：

    1. `family/family_name != "逍遥派"`            -> "给我滚开！"
    2. `family/master_id != query("id")`           -> "你还不配！"
    3. 折梅手 < 200 且 六阳掌 < 200                -> "你拿去也没用。"
    4. 沿 `environment()` 向上找信物持有者：
       - 持有者就是提问者 -> "本门的信物不就在你手中吗？"
       - 非角色对象       -> "你来晚了，逍遥神仙环现在不在我手中。"
       - 本派角色         -> "逍遥神仙环现在落在本派X手中，你要用就去找他吧。"
       - 外人             -> "我正为此事担忧呢，本门信物现在落入了X之手，你赶快去把他杀了，把指环取回来！"
    5. 在无崖子手中 -> `move(this_object())` + `message_vision` + `give`

  持有者遍历在 NPC 进程完成（与 LPC 的 `environment()` 遍历同相位），结果以
  `%{kind: :asker | :object | :character | :npc, name: ..., family: ...}` 随
  `npc/inquiry` 事件送到玩家进程；本模块只做门控、文案与发放落库。

  UCL 配置示例：

      value = {
        kind = "xiaoyao_zhihuan"
        item = "clone_lib:zhihuan"
        family = "逍遥派"
        master_id = true
        min_skill_levels_or = { zhemei_shou = 200 liuyang_zhang = 200 }
        in_hand = "本门的信物不就在你手中吗？"
        not_here = "你来晚了，逍遥神仙环现在不在我手中。"
        same_family = "逍遥神仙环现在落在本派{name}手中，你要用就去找他吧。"
        other_family = "我正为此事担忧呢，本门信物现在落入了{name}之手，你赶快去把他杀了，把指环取回来！"
        vision_msg = "$N微微一笑，道：“这逍遥神仙环你便拿去，希望日后你能继承我的衣钵。”"
      }
  """

  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.World.Items
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "item")) ->
        conn

      Map.get(data, :asker_id) != character.id ->
        conn

      true ->
        run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    cond do
      family_denied?(character, config) ->
        reply(conn, Map.get(config, "family_deny") || "给我滚开！")

      master_denied?(character, data) ->
        reply(conn, Map.get(config, "master_deny") || "你还不配！")

      skill_denied?(character, config) ->
        reply(conn, Map.get(config, "skill_deny") || "你拿去也没用。")

      true ->
        handle_owner(conn, config, data)
    end
  end

  # LPC 的 owner==me 分支优先于「不在我手中」，因为前者在 call 的玩家身上。
  defp handle_owner(conn, config, data) do
    case Map.get(data, :owner) do
      %{kind: :asker} ->
        reply(conn, Map.get(config, "in_hand") || "本门的信物不就在你手中吗？")

      %{kind: :object} ->
        reply(conn, Map.get(config, "not_here") || "你来晚了，逍遥神仙环现在不在我手中。")

      %{kind: :character} = owner ->
        name = Map.get(owner, :name) || "某人"
        template = owner_text(config, Map.get(owner, :family))
        reply(conn, String.replace(template, "{name}", name))

      _ ->
        grant_ring(conn, config, data)
    end
  end

  defp owner_text(config, family) do
    if is_binary(family) and family == Map.get(config, "family") do
      Map.get(config, "same_family") ||
        "逍遥神仙环现在落在本派{name}手中，你要用就去找他吧。"
    else
      Map.get(config, "other_family") ||
        "我正为此事担忧呢，本门信物现在落入了{name}之手，你赶快去把他杀了，把指环取回来！"
    end
  end

  defp grant_ring(conn, config, data) do
    item_id = Map.get(config, "item")

    case Items.get(item_id) do
      {:ok, _item} ->
        conn
        |> Helpers.give_item(item_id)
        |> broadcast_ring_vision(config, data)

      _ ->
        conn
    end
  end

  defp broadcast_ring_vision(conn, config, data) do
    case Map.get(data, :npc_room_id) do
      room_id when is_binary(room_id) ->
        npc_name = Map.get(data, :npc_name) || "无崖子"
        asker_name = to_string(Map.get(data, :asker_name) || "")

        template =
          Map.get(config, "vision_msg") ||
            "$N微微一笑，道：“这逍遥神仙环你便拿去，希望日后你能继承我的衣钵。”"

        rendered =
          template
          |> String.replace("$N", npc_name)
          |> String.replace("$n", asker_name)
          |> String.replace("{npc}", npc_name)
          |> String.replace("{name}", asker_name)

        Helpers.broadcast(conn, room_id, String.trim_trailing(rendered) <> "\n")

      _ ->
        conn
    end
  end

  # === 门控 ===

  defp family_denied?(character, config) do
    case {Map.get(config, "allowed_families"), Map.get(config, "family")} do
      {families, _} when is_list(families) and families != [] ->
        not Enum.any?(families, &(&1 == Helpers.family_name(character)))

      {_, family} when is_binary(family) and family != "" ->
        Helpers.family_name(character) != family

      _ ->
        false
    end
  end

  defp master_denied?(character, data) do
    family = meta_family(character)
    master_id = Map.get(family, :master_id) || Map.get(family, "master_id")

    case Map.get(data, :npc_id) do
      npc_id when is_binary(npc_id) -> not (is_binary(master_id) and master_id == npc_id)
      _ -> true
    end
  end

  defp meta_family(%{meta: %{family: family}}) when is_map(family), do: family
  defp meta_family(%{meta: %{family: family}}) when is_binary(family), do: %{"name" => family}
  defp meta_family(_character), do: %{}

  defp skill_denied?(character, config) do
    levels = Map.get(config, "min_skill_levels_or") || %{}
    skills = Map.get(character.meta.stats || %{}, :skills) || %{}

    is_map(levels) and map_size(levels) > 0 and
      not Enum.any?(levels, fn {skill, min} -> skill_level(skills, skill) >= min end)
  end

  defp skill_level(skills, skill) do
    level = Map.get(skills, skill, 0) || 0

    if level == 0 and is_binary(skill) and String.contains?(skill, "_"),
      do: Map.get(skills, String.replace(skill, "_", "-"), 0) || 0,
      else: level
  end

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
