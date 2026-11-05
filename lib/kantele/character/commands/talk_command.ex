defmodule Kantele.Character.TalkCommand do
  @moduledoc """
  对话命令：`talk NPC [内容]` / `talk NPC about 内容`

  对应 LPC `cmds/std/talk.c`：与「可对话 NPC」闲聊（LPC 里是接了 `shadow/ai.c`
  的 AI NPC，如 `u/mudren/npc/{butong,libai}.c`）。

  ## 逐条对齐的 LPC 语义

  1. 空参数 → `指令格式：talk NPC [内容]`；
  2. `sscanf("%s about %s")` / `sscanf("%s %s")` 两种解析，单词名字时
     默认话题「你好」；
  3. `present(npc_name, environment(me))` → 当前房间快照里按名字/别名找 NPC，
     找不到 → `这里没有X。`（精确原文）；
  4. `npc->accept_talk(me, message)` → 本端口用 `meta.inquiries` / `meta.ai_npc_id`
     判定「这个 NPC 接不接受对话」；不接受 → `X似乎不想和你聊天。`（精确原文）；
  5. 接受 → `你对X说：内容`，并给出 NPC 的应答。

  ## 与 LPC 的差异（本引擎没有 AI 服务）

  LPC 的 `accept_talk()` 只做一件事：把 `npc_id / player_id / 话题 / 上下文`
  （时间、天气、性别、年龄、门派、师父）打包丢给 `AI_CLIENT_D->send_chat_request()`，
  由**外部 LLM 服务**异步回调生成回答，然后立刻 `return 1`。本端口没有
  `AI_CLIENT_D` 这一层（`lib/` 中无 AI client / chat request 基础设施），故：

  - **应答来源改为 NPC 自带的 `meta.inquiries` 问答表**（与 `ask` 命令共用
    `NpcAskEvent.find_answer/2` 的「关键词子串命中」规则）。这是本引擎里唯一
    已有的、按 NPC 区分的对话内容，语义上等价于「只有配置了对话资源的 NPC
    才聊得起来」，正好对应 LPC 里 `accept_talk` 只挂在少数 AI NPC 上的事实。
  - 命中文本回答时回「NPC名说道：……」；命中闭包/脚本型回答（LPC
    `(: fname :)` 占位、hostile 脚本等）或未命中时，回一句不泄露内部形态的
    兜底台词。`ask` 的复杂脚本分支仍由 `characters/ask` 事件链负责，`talk`
    不重复触发那些副作用。
  - LPC 的消息是 `%s`（单个词）；本端口放宽为「`about` 之后 / 名字之后的
    整段文本」，与 `talk.c` 的 help 文案（「支持带空格的 NPC 名字，使用 about
    作为分隔符」）意图一致，也支持中文里带空格的话题。
  - 不构造 `NATURE_D` 时间/天气上下文，因为没有等价服务；如后续接入 AI
    服务，只需把 `reply/2` 换成异步请求，命令侧的门控/文案无需改动。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Room

  @default_topic "你好"

  @doc """
  解析 `talk` 参数，返回 `{npc_name, topic}`。

  LPC 的两种 `sscanf` 形式分别对应 `about` 分隔与普通空格分隔；只有名字时
  话题默认为「你好」。
  """
  def parse(rest) when is_binary(rest) do
    text = String.trim(rest)

    case text do
      "" ->
        {:error, :empty}

      _ ->
        matched =
          Regex.run(~r/^(\S+)\s+about\s+(.+)$/, text) ||
            Regex.run(~r/^(\S+)\s+(.+)$/, text)

        case matched do
          [_, name, topic] -> {:ok, name, String.trim(topic)}
          _ -> {:ok, text, @default_topic}
        end
    end
  end

  def parse(_), do: {:error, :empty}

  def run(conn, %{"rest" => rest}) when is_binary(rest) do
    case parse(rest) do
      {:error, :empty} -> usage(conn)
      {:ok, name, topic} -> attempt(conn, name, topic)
    end
  end

  def run(conn, _params), do: usage(conn)

  defp attempt(conn, name, topic) do
    case find_npc(conn, name) do
      nil ->
        reject(conn, "这里没有#{name}。\n")

      npc ->
        if accepts_talk?(npc) do
          talk(conn, npc, topic)
        else
          reject(conn, "#{npc.name}似乎不想和你聊天。\n")
        end
    end
  end

  defp talk(conn, npc, topic) do
    msg = "你对#{npc.name}说：#{topic}\n" <> reply(npc, topic)

    conn
    |> render(CommandView, "text", %{text: msg})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reply(npc, topic) do
    answer = find_answer(inquiries_of(npc), topic)

    usable? =
      is_binary(answer) and answer != "" and not closure_literal?(answer)

    if usable? do
      "#{npc.name}说道：#{answer}\n"
    else
      "#{npc.name}似乎没有听明白你的意思。\n"
    end
  end

  # 与 NpcAskEvent.find_answer/2 同款：问询表键作为子串命中话题。
  defp find_answer(inquiries, topic) when is_map(inquiries) and map_size(inquiries) > 0 do
    Enum.find_value(inquiries, fn {key, value} ->
      if String.contains?(topic, to_string(key)), do: value, else: nil
    end)
  end

  defp find_answer(_, _topic), do: nil

  # LPC 闭包占位（ask 链里判为「静默不回应」），talk 侧也不把源码形态吐给玩家。
  defp closure_literal?(text) when is_binary(text) do
    Regex.match?(~r/\(\s*:\s*[^)]*?:\s*\)/, text)
  end

  defp closure_literal?(_), do: false

  # ---- NPC 解析（与 AskCommand.find_ask_npc/2 同款，额外支持别名与前缀匹配） ----

  defp find_npc(conn, name) do
    room =
      Map.get(conn.private, :room) ||
        Map.get(conn, :room) ||
        Room.snapshot(conn.character.room_id)

    characters =
      (Map.get(room, :private, %{}) || %{})
      |> Map.get(:characters) ||
      Map.get(room, :characters) ||
      []

    Enum.find(characters, fn character ->
      character.pid != conn.character.pid and matches?(character, name)
    end)
  end

  defp matches?(character, name) do
    aliases = Map.get(character.meta || %{}, :aliases) || []
    character.name == name or name in aliases or Room.NameMatch.matches?(character, name)
  end

  # LPC `function_exists("accept_talk", npc)`（talk.c 里被注释掉，但驱动对未定义
  # 函数返回 0，效果相同）：只有挂了对话资源的 NPC 才聊得起来。
  defp accepts_talk?(npc) do
    meta = npc.meta || %{}
    inquiries = inquiries_of(npc)

    has_inquiries? = is_map(inquiries) and map_size(inquiries) > 0

    has_ai_id? =
      not is_nil(Map.get(meta, :ai_npc_id)) or not is_nil(Map.get(meta, :talk_id))

    has_inquiries? or has_ai_id?
  end

  defp inquiries_of(%{meta: meta}) when is_map(meta) do
    Map.get(meta, :inquiries) || Map.get(meta, "inquiries") || %{}
  end

  defp inquiries_of(_), do: %{}

  # ---- 输出 ----

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：talk NPC [内容]\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
