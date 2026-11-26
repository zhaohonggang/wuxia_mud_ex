defmodule Kantele.World.InquiryHandlers.XuedaoMidao do
  @moduledoc """
  血刀派 #792：血刀老祖「密道/秘道」问询（`kind = "xuedao_midao"`）。

  LPC 源 `kungfu/class/xuedao/laozu.c:681-695` `ask_midao/0`（逐条忠实，不简化）：

      me = this_player();
      if (me->query("family/family_name") != "血刀门")
              return "你他奶奶的，嘀嘀咕咕到底要说什么？";
      command("whisper " + me->query("id") + " 你既然已经入我门来，以"
              "后若\n要去中原办事，即可用我门血刀先辈们留下的密道，你"
              "可到山\n外杂物堆处进入(" NOR + HIY "enter mash" NOR + WHT
              ")，然后便能到达中原扬州。回来\n是找我血刀伏在中原的铁匠"
              "，接口密语是" NOR + HIR "血海无边" NOR + WHT "。\n");
      return "此秘密不可泄露于他人，否则天诛地灭！";

  两段输出：

  1. `command("whisper <me id> ...")` —— NPC 对提问者**密语**（仅该玩家可见，
     不广播房间）。在 ex 中 inquiry handler 运行于**玩家进程**，直接 render 给
     该玩家即等价于 LPC 的 `tell_object(me, ...)`：私密、不进房间频道。
     密语文案保留 LPC 原文（含手动换行与 `(enter mash)`、`血海无边` 提示）。
  2. `return <text>` —— 同 `tell_object` 回给玩家，紧接密语之后显示。

  ## 端口映射

  - `query("family/family_name")` → `Kantele.Character.Family.name(meta.family)`
  - `command("whisper ...")` → 玩家侧 text render（私密）
  - `return <text>` → 玩家侧 text render

  ## UCL 配置（血刀老祖 inquiries）

      inquiries = [
        { key = "密道" value = { kind = "xuedao_midao" } },
        { key = "秘道" value = { kind = "xuedao_midao" } }
      ]
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family

  # LPC HIY/WHT/HIR 是 ANSI 颜色；ex 文案约定不嵌颜色码，保留纯文本与换行。
  @whisper_text "你既然已经入我门来，以后若\n要去中原办事，即可用我门血刀先辈们留下的密道，你\n可到山外杂物堆处进入(enter mash)，然后便能到达中原扬州。回来\n是找我血刀伏在中原的铁匠，接口密语是血海无边。\n"

  def run(conn, _config, data) when is_map(data) do
    character = conn.character

    if xuedao_men?(character) do
      conn
      |> tell(@whisper_text)
      |> tell("此秘密不可泄露于他人，否则天诛地灭！\n")
    else
      tell(conn, "你他奶奶的，嘀嘀咕咕到底要说什么？\n")
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC family/family_name == "血刀门"：family name 存于 meta.family.name
  defp xuedao_men?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Family.name(family) == "血刀门"
      _ -> false
    end
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end
end
