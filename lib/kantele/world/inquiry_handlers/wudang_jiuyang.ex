defmodule Kantele.World.InquiryHandlers.WudangJiuyang do
  @moduledoc """
  武当张三丰「武当九阳功」授受问询（`kind = "wudang_jiuyang"`，#789）。

  对应 `kungfu/class/wudang/zhang.c` 的 `ask_jiuyang()`：

  1. 已有 `can_learn/jiuyang-shengong/wudang` → 「老道已经答应传授你武当九阳功了，你怎么还那么罗嗦？」；
  2. 缺 `can_learn/jiuyang-shengong/kunlun` → 「昔日《九阳真经》在我师父觉远大师手中丢失，现在也不知道流落何方。」；
  3. 缺 `can_learn/jiuyang-shengong/shaolin` → 「唉，如果当时能够追回《九阳真经》，觉远大师也不至于落难。」；
  4. 满足 → `message_vision` 广播 + 三句 say + `tell_object` 传授文案 +
     `improve_skill("martial-cognize", 1500000)` + `set("can_learn/jiuyang-shengong/wudang", 1)`。

  前置两个 mark（kunlun / shaolin）由昆仑、少林对应剧情 NPC 写入 `meta.marks`
  （LPC 同一 `can_learn/jiuyang-shengong/<source>` 命名空间）；本 handler 只读不写。

  UCL 配置（`inquiries` 的 map 值）：

      value = {
        kind = "wudang_jiuyang"
        wudang_mark = "can_learn/jiuyang-shengong/wudang"
        kunlun_mark = "can_learn/jiuyang-shengong/kunlun"
        shaolin_mark = "can_learn/jiuyang-shengong/shaolin"
        maxed = "老道已经答应传授你武当九阳功了，你怎么还那么罗嗦？"
        missing_kunlun = "昔日《九阳真经》在我师父觉远大师手中丢失，现在也不知道流落何方。"
        missing_shaolin = "唉，如果当时能够追回《九阳真经》，觉远大师也不至于落难。"
        vision = "张三丰仔细打量了{npc}好一阵，目光陡然一亮。"   # message_vision，向房间广播（{npc}=提问者）
        say_one = "你不就是当年还送经书予觉远大师之人吗？"
        say_two = "所谓‘大恩不言谢’，这九阳神功老道倒是通晓一点，现已化为武当九阳功。"
        say_three = "如果阁下不嫌弃，老道倒是可以将这套九阳功传授于你。"
        learned = "张三丰同意传授你「武当九阳功」。"
        improve_skill = "martial-cognize"   # LPC improve_skill(...,1500000) = 本引擎 +1 级
      }

  ## 与 LPC 的差异

  - `RANK_D->query_respect` 未使用（本问询文案不含敬称）。
  - `improve_skill("martial-cognize", 1500000)` 在本引擎里 = 该技能 +1 级
    （与昆仑内联 ask_skill* 的 improve 语义一致，见 sect_master_grant.ex）。
  """

  import Kalevala.Character.Conn, only: [put_character: 2, render: 4, prompt: 4]

  alias Kantele.Character, as: PlayerMeta
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.World.NpcActions.Helpers

  def run(conn, config, data) when is_map(config) and is_map(data) do
    character = current(conn)

    cond do
      not is_binary(Map.get(config, "wudang_mark")) -> conn
      Map.get(data, :asker_id) != character.id -> conn
      true -> run_for(conn, character, config, data)
    end
  end

  def run(conn, _config, _data), do: conn

  defp run_for(conn, character, config, data) do
    marks = character.meta.marks || %{}
    wudang_mark = config["wudang_mark"]
    kunlun_mark = config["kunlun_mark"]
    shaolin_mark = config["shaolin_mark"]

    cond do
      mark_set?(marks, wudang_mark) ->
        reply(conn, Map.get(config, "maxed"))

      not mark_set?(marks, kunlun_mark) ->
        reply(conn, Map.get(config, "missing_kunlun"))

      not mark_set?(marks, shaolin_mark) ->
        reply(conn, Map.get(config, "missing_shaolin"))

      true ->
        grant(conn, character, config, data, wudang_mark)
    end
  end

  defp grant(conn, character, config, data, wudang_mark) do
    # message_vision + 三句 say（向房间广播）
    conn = broadcast_vision(conn, data, Map.get(config, "vision"))
    conn = say_all(conn, data, config)

    # improve_skill("martial-cognize", 1500000) → 本引擎 +1 级
    stats = improve(character.meta.stats, Map.get(config, "improve_skill"))

    # set("can_learn/jiuyang-shengong/wudang", 1)
    meta =
      character.meta
      |> Map.put(:stats, stats)
      |> PlayerMeta.put_mark(wudang_mark, 1)

    character = %{character | meta: meta}
    Records.save(character)

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{
      text: Map.get(config, "learned") || "张三丰同意传授你「武当九阳功」。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp mark_set?(marks, mark) when is_binary(mark) and is_map(marks),
    do: Map.get(marks, mark) not in [nil, 0, false]

  defp mark_set?(_marks, _mark), do: false

  defp improve(%Stats{} = stats, skill) when is_binary(skill) and byte_size(skill) > 0 do
    {updated, _improved?} = Stats.improve_skill(stats, skill)
    updated
  end

  defp improve(stats, _skill), do: stats

  # LPC message_vision(msg, me)：向房间广播。
  # 本引擎约定模板用 `{npc}`（行动者=提问者，渲染「你」/提问者名）；
  # `Helpers.broadcast` 负责 `$N`→`{npc}` 归一，`VisionView` 按接收者渲染。
  # 文案里「张三丰」为字面量（LPC 原文即硬编码），提问者用 `{npc}`。
  defp broadcast_vision(conn, %{npc_room_id: room_id}, msg)
       when is_binary(room_id) and is_binary(msg) and byte_size(msg) > 0 do
    Helpers.broadcast(conn, room_id, msg)
  end

  defp broadcast_vision(conn, _data, _msg), do: conn

  defp say_all(conn, %{npc_room_id: room_id, npc_name: npc_name}, config)
       when is_binary(room_id) do
    # UCL 键不得含数字（elias 词法把 say_1 读成 word+digit），故用 say_one/two/three。
    ["say_one", "say_two", "say_three"]
    |> Enum.reduce(conn, fn key, acc ->
      case Map.get(config, key) do
        text when is_binary(text) and byte_size(text) > 0 ->
          Helpers.say(acc, room_id, npc_name || "张三丰", text)

        _ ->
          acc
      end
    end)
  end

  defp say_all(conn, _data, _config), do: conn

  defp reply(conn, text) when is_binary(text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(conn, _text), do: conn

  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character
end