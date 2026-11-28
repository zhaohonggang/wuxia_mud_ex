defmodule Kantele.World.InquiryHandlers.Weiwang do
  @moduledoc """
  北京 NPC `ask_weiwang()`（问「威望」/「江湖威望」）共享问询处理器。

  LPC 原文（`d/beijing/npc/fangang.c:64-71` 等 8 个 NPC 同构）：

      command("tell "+this_player()->query("id")+" 你现在的江湖威望是 "
              +(string)(this_player()->query("weiwang")));
      say("\\n樊纲说：如果你威望值很高，有些人见了你不但不会杀你，还会教你武功，送你宝贝。\\n"
          +"而且你还可以加入帮会，率领会众去攻打目标，就连去钱庄取钱也会有利息 。。。。。\\n");
      say("樊纲又说：杀某些坏人或救某些好人可以提高江湖威望。\\n");
      return 1;

  ## 端口映射

  - `command("tell <id> ...")`：玩家侧私有 render 一行，数值取自
    `character.meta.stats.weiwang`（LPC `query("weiwang")`；缺省 0）。
  - 两次 `say()`：两次向 `data.npc_room_id` 广播，文案顺序与 LPC 一致；
    说话人姓名取 `data.npc_name`（UCL 不重复存一份名字）。
  - `return 1` 只表示问询已消费，无额外输出。

  ## 文案变体

  徐天川（`d/beijing/npc/xutianchuan.c:74-81`）第一段的第二行以
  `利息。\\n` 结尾，其余 7 人是 `利息 。。。。。\\n`。UCL 用
  `interest_suffix = "。"` 覆写；缺省保持多数派的 `" 。。。。。"`。

  ## UCL 配置

      value = { kind = "weiwang" }
      # 徐天川：
      value = { kind = "weiwang" interest_suffix = "。" }
  """

  alias Kalevala.Character.Conn
  alias Kantele.Character.CommandView
  alias Kantele.World.NpcActions.Helpers

  @default_interest_suffix " 。。。。。"

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    if Map.get(data, :asker_id) != character.id do
      conn
    else
      npc_name = Map.get(data, :npc_name) || "某人"
      room_id = Map.get(data, :npc_room_id)

      conn
      |> Conn.render(CommandView, "text", %{
        text: "你现在的江湖威望是 #{weiwang(character)}\n"
      })
      |> Conn.prompt(CommandView, "prompt", %{})
      |> broadcast(room_id, first_say(npc_name, config))
      |> broadcast(room_id, second_say(npc_name))
    end
  end

  def run(conn, _config, _data), do: conn

  defp broadcast(conn, room_id, text)
       when is_binary(room_id) and byte_size(room_id) > 0,
       do: Helpers.broadcast(conn, room_id, text)

  defp broadcast(conn, _room_id, _text), do: conn

  defp first_say(npc_name, config) do
    "\n#{npc_name}说：如果你威望值很高，有些人见了你不但不会杀你，还会教你武功，送你宝贝。\n" <>
      "而且你还可以加入帮会，率领会众去攻打目标，就连去钱庄取钱也会有利息#{interest_suffix(config)}\n"
  end

  defp second_say(npc_name),
    do: "#{npc_name}又说：杀某些坏人或救某些好人可以提高江湖威望。\n"

  defp interest_suffix(config) do
    case Map.get(config, "interest_suffix") || Map.get(config, :interest_suffix) do
      suffix when is_binary(suffix) -> suffix
      _ -> @default_interest_suffix
    end
  end

  # LPC `query("weiwang")`：Stats.weiwang 是权威来源，历史存档也可能落在
  # meta.combat；两者都读，非整数（含 nil/字符串）按 0 处理。
  defp weiwang(character) do
    meta = character.meta || %{}
    stats = Map.get(meta, :stats) || Map.get(meta, "stats") || %{}
    combat = Map.get(meta, :combat) || Map.get(meta, "combat") || %{}

    case Map.get(stats, :weiwang) || Map.get(stats, "weiwang") ||
           Map.get(combat, :weiwang) || Map.get(combat, "weiwang") do
      value when is_integer(value) -> value
      _ -> 0
    end
  end

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end
