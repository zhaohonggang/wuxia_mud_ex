defmodule Kantele.World.InquiryHandlers.QuestLilian do
  @moduledoc """
  QUEST_D 历练问询（`kind = "quest_lilian"`）—— 完整移植 LPC
  `adm/daemons/questd.c:398-468` 的 `accept_ask(me, who, topic)`。

  LPC 由各门派师父的 `accept_ask` 把「历练／历炼／锻炼」转给 QUEST_D：
  `QUESTION_D->accept_ask(this_object(), me, topic)`，即 `me` = NPC、`who` = 玩家。
  逐条门序（与 LPC 完全一致）：

  1. `my_fam = NPC.family/family_name`；玩家门派不同 → 「你是谁？…」；
  2. 玩家已有 `out_family` → 「去吧！<玩家名>，好自为之！」；
  3. 玩家 `combat_exp < 50000` → NPC 叹气 vision（不设标记）；
  4. 玩家 `score < 100` → NPC 摆手 vision（不设标记）；
  5. 玩家 `set("out_family", 1)`；
  6. NPC `is_good()` (`shen > 500 || shen_type == 1`) → 欣慰 message_sort；
     `is_bad()` (`shen < -500 || shen_type == -1`) → 大笑 message_sort；
     否则 → 叮嘱 message_sort；
  7. 赠地图册 message_sort + 私有「你获得了师傅赠给你的地图册」提示；
  8. rumor 频道「听说<玩家名>已经开始闯荡江湖。」

  第 6/7 步的 `message_sort` 直接复用 `Kantele.World.InquiryHandlers.MessageSort`：
  LPC 传的是 `(msg, me = NPC, you = 玩家)`，因此问询玩家看到 `$N`=NPC、`$n`=「你」，
  旁观者看到 `$N`=NPC、`$n`=玩家名 —— 与 #803 的三视角渲染完全相同。

  与已有 `kind = "quest"`（张无忌 #955 的任务 spec 登记）**不是同一机制**，故用独立
  kind，互不覆盖。其它门派师父的 QUEST_D 占位可在各自 GAP 批次切到本 handler。

  UCL 配置示例（丁春秋）：

      { key = "历练" value = {
        kind = "quest_lilian"
        family = "星宿派"
        npc_shen = 0
        npc_shen_type = -1
        min_combat_exp = 50000
        min_score = 100
        family_deny = "你是谁？找我有什么事情么？"
        out_family_deny = "去吧！{name}，好自为之！"
        exp_deny = "{npc}叹了一口气，看了看{name}道：你的武功基础还不太好，还是再好好锻炼吧。"
        score_deny = "{npc}摆摆手道：你的江湖阅历太少，现在不可外出独自行走江湖。"
        good_msg = "{npc}对{name}欣慰的点了点头，道：看来我们星宿派又出了一位人才啊！…"
        bad_msg = "{npc}对{name}哈哈大笑道：好！好！好！你可以出去走走看看了…"
        neutral_msg = "{npc}对{name}叮嘱道：以后你行走江湖常常是孤身一人…"
        map_msg = "{npc}翻出一本小册子，对{name}道：今后你行走江湖…"
        map_got = "你获得了师傅赠给你的地图册。"
        map_help = "请参见帮助(help quest)以获得更详细的信息。"
        rumor = "听说{name}已经开始闯荡江湖。"
      } }
  """

  import Kalevala.Character.Conn, only: [prompt: 4]

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Communication
  alias Kantele.World.InquiryHandlers.MessageSort
  alias Kantele.World.NpcActions.Helpers

  @family_deny "你是谁？找我有什么事情么？"
  @out_family_deny "去吧！{name}，好自为之！"
  @exp_deny "{npc}叹了一口气，看了看{name}道：你的武功基础还不太好，还是再好好锻炼吧。"
  @score_deny "{npc}摆摆手道：你的江湖阅历太少，现在不可外出独自行走江湖。"
  @good_msg "{npc}对{name}欣慰的点了点头，道：看来我们{family}又出了一位人才啊！" <>
              "你记住了，我辈武人，切忌不可好勇争斗，要多做行侠仗义之事！"
  @bad_msg "{npc}对{name}哈哈大笑道：好！好！好！你可以出去走走看看了，" <>
             "对那些自认所谓大侠之辈可不要手软，去吧！"
  @neutral_msg "{npc}对{name}叮嘱道：以后你行走江湖常常是孤身一人，" <>
                 "记得要敬重前辈，不可狂妄自大，切记了，去吧！"
  @map_msg "{npc}翻出一本小册子，对{name}道：今后你行走江湖，许多山川地理，" <>
             "世间风情你都可以记录在这本地图册上，以供参考，对你多少也会有些帮助。"
  @map_got "你获得了师傅赠给你的地图册。"
  @map_help "请参见帮助(help quest)以获得更详细的信息。"
  @rumor "听说{name}已经开始闯荡江湖。"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      accept(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp accept(conn, character, config, data) do
    npc_name = Map.get(data, :npc_name) || "某人"
    asker_name = Map.get(data, :asker_name) || character.name
    npc_family = Map.get(data, :npc_family) || text(config, "family")

    cond do
      is_nil(npc_family) or npc_family == "" ->
        reply(conn, text(config, "family_deny", @family_deny), npc_name, asker_name, npc_family)

      Helpers.family_name(character) != npc_family ->
        reply(conn, text(config, "family_deny", @family_deny), npc_name, asker_name, npc_family)

      Helpers.flag?(character, :out_family) ->
        reply(
          conn,
          text(config, "out_family_deny", @out_family_deny),
          npc_name,
          asker_name,
          npc_family
        )

      stat(character, :combat_exp) < int_config(config, "min_combat_exp", 50_000) ->
        vision(conn, data, text(config, "exp_deny", @exp_deny), npc_name, asker_name, npc_family)

      stat(character, :score) < int_config(config, "min_score", 100) ->
        vision(
          conn,
          data,
          text(config, "score_deny", @score_deny),
          npc_name,
          asker_name,
          npc_family
        )

      true ->
        grant(conn, character, config, data, npc_name, asker_name, npc_family)
    end
  end

  # LPC who->set("out_family", 1) 先于所有 message_sort 与 tell_object。
  defp grant(conn, character, config, data, npc_name, asker_name, npc_family) do
    conn = Helpers.put_env(conn, :out_family, 1)
    character = current(conn)

    conn
    |> message_sort(data, tutorial_text(config, npc_family))
    |> message_sort(data, text(config, "map_msg", @map_msg))
    |> Helpers.render(
      "\n#{text(config, "map_got", @map_got)}\n#{text(config, "map_help", @map_help)}"
    )
    |> announce_rumor(text(config, "rumor", @rumor), npc_name, asker_name, npc_family)
    |> prompt(CommandView, "prompt", %{})
    |> tap(fn _ -> Records.save(character) end)
  end

  # LPC is_good() / is_bad()：inherit/char/char.c:60-61。
  defp tutorial_text(config, npc_family) do
    shen = int_config(config, "npc_shen", 0)
    shen_type = int_config(config, "npc_shen_type", 0)

    cond do
      shen > 500 or shen_type == 1 ->
        text(config, "good_msg", @good_msg) |> String.replace("{family}", npc_family || "")

      shen < -500 or shen_type == -1 ->
        text(config, "bad_msg", @bad_msg)

      true ->
        text(config, "neutral_msg", @neutral_msg)
    end
  end

  # 模板的 `{npc}` / `{name}`（或 `$N` / `$n`）必须原样交给 MessageSort：
  # 只有它知道问询玩家要看 `你`、旁观者要看玩家姓名（LPC message_sort 三视角）。
  defp message_sort(conn, data, template) do
    MessageSort.run(conn, %{"text" => template}, data)
  end

  defp vision(conn, data, template, npc_name, asker_name, npc_family) do
    text = render(template, npc_name, asker_name, npc_family)

    conn =
      case Map.get(data, :npc_room_id) do
        room_id when is_binary(room_id) -> Helpers.broadcast(conn, room_id, text)
        _ -> Helpers.render(conn, text)
      end

    prompt(conn, CommandView, "prompt", %{})
  end

  defp reply(conn, template, npc_name, asker_name, npc_family) do
    conn
    |> Helpers.render(render(template, npc_name, asker_name, npc_family))
    |> prompt(CommandView, "prompt", %{})
  end

  defp announce_rumor(conn, template, npc_name, asker_name, npc_family) do
    Communication.announce("rumor", render(template, npc_name, asker_name, npc_family))
    conn
  end

  defp render(template, npc_name, asker_name, npc_family) do
    template
    |> String.replace("$N", npc_name)
    |> String.replace("$n", asker_name)
    |> String.replace("{npc}", npc_name)
    |> String.replace("{name}", asker_name)
    |> String.replace("{family}", npc_family || "")
  end

  defp text(config, key, default) do
    case Map.get(config, key) || Map.get(config, String.to_atom(key)) do
      value when is_binary(value) and byte_size(value) > 0 -> value
      _ -> default
    end
  end

  defp text(config, key), do: text(config, key, "")

  defp int_config(config, key, default) do
    case Map.get(config, key) || Map.get(config, String.to_atom(key)) do
      value when is_integer(value) -> value
      value when is_binary(value) -> String.to_integer(value)
      _ -> default
    end
  rescue
    _ -> default
  end

  defp stat(character, key) do
    case Map.get(character.meta || %{}, :stats) do
      stats when is_map(stats) -> Map.get(stats, key) || 0
      _ -> 0
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
