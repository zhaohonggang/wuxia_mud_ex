defmodule Kantele.World.InquiryHandlers.WuxiuwenTools do
  @moduledoc """
  郭府后勤武修文的发工具问询（kind = "wuxiuwen_tools"）。

  LPC 源：`/d/wuguan/npc/wuxiuwen.c` 的 `give_tools()`（玩家
  `ask wu xiuwen about 工具/tools` 命中本 kind，NPC 侧 `NpcAskEvent` 回执到玩家
  进程，由本模块落会话 temp 并实际发工具）。

  ## 判定链（LPC give_tools 原序）

  1. `query_temp("mark/工具")` 已发过 → 「我不是已经给你了吗，怎么那么罗嗦？」
  2. `query_temp("mark/还了")` 已还过 → 「你还是先到耶律师兄那覆命了再说吧。」
  3. `job_name` 不在五种活计内（没领工）→ 「你又没有领工作，跑来要什么工具？」
  4. 否则按 `job_name` 选工具（锄草→chutou / 浇菜地→piao / 锯木头→juzi /
     劈柴→chaidao / 打扫马房→saozhou），实例化进玩家背包，置 `mark/工具`，
     回「东西交给你了，可要小心保管，别弄丢了。」

  `mark/工具` 是打工动词（`Wuguan.Work`）的工具门控（对应 LPC 检已装备武器 id，
  本端口按既定约定改查 `mark/工具`）。发出后玩家方能去对应工作房干活。

  ## 与 LPC 的差异

  - 房间广播 `message_vision("$N交给$n一把工具。", me, ob)`（me=武修文）：本端口
    以玩家进程内的私有回话呈现「武修文交给你一把工具。」+ 发工具台词，避免角色
    视角错乱（玩家进程广播会把行动者渲染成自己）。
  - 工具校验由 `Wuguan.Work` 在用工具时统一按 `mark/工具` 判定，本模块只负责下发。
  """
  import Kalevala.Character.Conn, only: [render: 4, prompt: 4]

  alias Kalevala.Character.Conn
  alias Kantele.Character.CommandView
  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Helpers

  # LPC give_tools：job_name → 工具 item id（见 d/wuguan/npc/wuxiuwen.c new(...)。
  # 工具定义已落在 wuguan.ucl（items 命名空间，LPCConverter 从 /d/wuguan/obj/*.c 抽来），
  # 故用全 id `wuguan:items.<key>`（Items 缓存以全 id 为键，裸 id 解析不到）。
  @tool_for_job %{
    "锄草" => "wuguan:items.chutou",
    "浇菜地" => "wuguan:items.piao",
    "锯木头" => "wuguan:items.juzi",
    "劈柴" => "wuguan:items.chaidao",
    "打扫马房" => "wuguan:items.saozhou"
  }

  def run(conn, _config, %{asker_id: asker_id}) do
    character = current(conn)

    case asker_id == character.id do
      false -> conn
      true -> give_tools(conn, character)
    end
  end

  def run(conn, _config, _data), do: conn

  defp give_tools(conn, character) do
    meta = character.meta || %PlayerMeta{}
    temp = meta.temp || %{}

    cond do
      # 1. 已发过
      present_temp?(temp, "mark/工具") ->
        reply(conn, "我不是已经给你了吗，怎么那么罗嗦？")

      # 2. 已还过
      present_temp?(temp, "mark/还了") ->
        reply(conn, "你还是先到耶律师兄那覆命了再说吧。")

      # 3. 没领工
      not Map.has_key?(@tool_for_job, Map.get(temp, "job_name")) ->
        reply(conn, "你又没有领工作，跑来要什么工具？")

      # 4. 按活计发工具
      true ->
        do_give(conn, Map.get(temp, "job_name"))
    end
  end

  defp do_give(conn, job_name) do
    tool_id = Map.fetch!(@tool_for_job, job_name)

    conn
    |> Helpers.give_item(tool_id)
    |> Helpers.put_temp("mark/工具", 1)
    |> reply("武修文交给你一把工具。\n东西交给你了，可要小心保管，别弄丢了。")
  end

  # LPC 真值语义：query_temp 未设置返回 0（假）
  defp present_temp?(temp, key) do
    case Map.get(temp, key) do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text <> "\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%Conn{character: character}), do: character
end
