defmodule Kantele.World.InquiryHandlers.XueshanMidao do
  @moduledoc """
  大轮寺密道/秘道问询（`kind = "xueshan_midao"`）—— 金轮法王「密道/秘道」。

  LPC 源 `kungfu/class/xueshan/fawang.c:757-772` `ask_midao/0`（逐条忠实，不简化）：

      me = this_player();
      if (me->query("family/family_name") != "大轮寺")
              return "你找死么？";
      command("whisper " + me->query("id") + " 你既然投入我大轮寺，以后若
      要去中原办事，即可用我大轮寺先辈们留下的密道，直接去禅
      室转动(turn lunpan) 轮盘触发机关，地面便会开启密道，然
      后你顺着密道前进便能到达中原扬州。若要回寺可找我大轮寺
      伏在中原的唐楠，接口的密语是金轮九转，可记清楚了。");
      return "此秘密不可泄露于他人，否则我饶不了你！";

  两段输出：

  1. `command("whisper <me id> ...")` —— NPC 对提问者**密语**（仅该玩家可见，
     不广播房间）。在 ex 中 inquiry handler 运行于**玩家进程**，直接 render 给
     该玩家即等价于 LPC 的 `tell_object(me, ...)`：私密、不进房间频道。
     密语文案保留 LPC 原文（含手动换行与 `(turn lunpan)`、`金轮九转` 提示）。
  2. `return` 文案 —— 同 `tell_object` 回给玩家，紧接密语之后显示。

  ## 端口映射

  - `query("family/family_name")` → `Kantele.Character.Family.name(meta.family)`
  - `command("whisper ...")` → 玩家侧 text render（私密）
  - `return <text>` → 玩家侧 text render

  ## UCL 配置（金轮法王 inquiries）

      inquiries = [
        { key = "密道" value = { kind = "xueshan_midao" } },
        { key = "秘道" value = { kind = "xueshan_midao" } }
      ]
  """

  alias Kantele.Character.CommandView
  alias Kantele.Character.Family

  # LPC HIY/WHT 是 ANSI 颜色；ex 文案约定不嵌颜色码，保留纯文本与换行。
  @whisper_text "你既然投入我大轮寺，以后若\n要去中原办事，即可用我大轮寺先辈们留下的密道，直接去禅\n室转动(turn lunpan) 轮盘触发机关，地面便会开启密道，然\n后你顺着密道前进便能到达中原扬州。若要回寺可找我大轮寺\n伏在中原的唐楠，接口的密语是金轮九转，可记清楚了。\n"

  def run(conn, _config, data) when is_map(data) do
    character = conn.character

    if dailun?(character) do
      conn
      |> tell(@whisper_text)
      |> tell("此秘密不可泄露于他人，否则我饶不了你！\n")
    else
      tell(conn, "你找死么？\n")
    end
  end

  def run(conn, _config, _data), do: conn

  # LPC family/family_name == "大轮寺"：family name 存于 meta.family.name
  defp dailun?(character) do
    case Map.get(character.meta || %{}, :family) do
      family when is_map(family) -> Family.name(family) == "大轮寺"
      _ -> false
    end
  end

  defp tell(conn, text) do
    conn
    |> Kalevala.Character.Conn.render(CommandView, "text", %{text: text})
    |> Kalevala.Character.Conn.prompt(CommandView, "prompt", %{})
  end
end
