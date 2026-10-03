defmodule Kantele.Character.ArenaCommand do
  @moduledoc """
  擂台开关：`lclose` / `lopen`

  对应 LPC `d/city/leitai.c`：

      int do_lclose(string arg)
      {
          me = this_player();
          if (wiz_level(me) < 3)
              return notify_fail("你没有资格关闭擂台。\\n");
          if (arg != "here")
              return notify_fail("如果你要关闭擂台，请输入(lclose here)。\\n");
          if (objectp(query("close_by")))
              return notify_fail("这个擂台已经被" + query("close_by")->name(1) + "关闭用于比武了。\\n");
          set("close_by", me);
          message("vision", HIW "【武林盛会】" + me->name(1) + "关闭了擂台，开始举行比武盛会。\\n" NOR,
                  all_interactive());
          return 1;
      }

      int do_lopen(string arg)   // 「你没有资格打开擂台。」「这个擂台目前并没有被关闭。」
                                  // 「如果你要打开擂台，请输入(lopen here)。」

  两处与 LPC 的差异：

    * `wiz_level(me) < 3` —— Elixir 侧用 `Kantele.Admin.Access.adminp/1`（wiz_level >= 3）
    * 状态存在 `Kantele.World.Arena`（ETS），不是房间进程。判定发生在
      **观众席**房间里（`city:wudao1` 等），要读的是**擂台**的状态，
      跨房间；走 ETS 读取避免房间之间互相 `GenServer.call` 造成死锁。

  未实现（LPC 同文件里另外三条，多人比武用的管理命令）：
  `invite`（巫师把台下的人请上台）、`kickout`（把人踢下台）、
  以及 `city/underlt.c` 的 `pass`（巫师指定某人上台）。它们只影响多人
  比武流程，不影响「关闭时非巫师上不去」这条规则，故留待后续。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.World.Arena

  @leitai "city:leitai"

  def run(conn, params), do: lclose(conn, params)

  # 裸 `lclose` / `lopen`（没带 here）：LPC 里是**接受**的，然后自己回
  # 「如果你要关闭擂台，请输入(lclose here)。」所以这里不能报「What?」。
  def run_bare(conn, _params), do: lclose(conn, %{})
  def lopen(conn, params), do: do_lopen(conn, params)
  def lopen_bare(conn, _params), do: do_lopen(conn, %{})

  # 词汇表里参数是 optional 的，所以 `lclose`（不带 here）也能解析到，
  # 此时 params 里没有 :arg。LPC 就是在这种情况下回那句提示的。
  # 词汇表里 params 的 key 是**字符串**（实测 params=%{"arg" => "here"}）
  defp arg(params) when is_map(params) do
    Map.get(params, "arg") || Map.get(params, :arg) || ""
  end

  defp arg(_), do: ""

  @doc "lclose here"
  def lclose(conn, params) do
    character = conn.character

    cond do
      not Access.adminp(character) ->
        error(conn, "你没有资格关闭擂台。\n")

      arg(params) != "here" ->
        error(conn, "如果你要关闭擂台，请输入(lclose here)。\n")

      Arena.close_by(@leitai) ->
        error(
          conn,
          "这个擂台已经被" <> Arena.close_by(@leitai).by <> "关闭用于比武了。\n"
        )

      true ->
        Arena.close(@leitai, character)
        announce(conn, "【武林盛会】" <> character.name <> "关闭了擂台，开始举行比武盛会。")
    end
  end

  @doc "lopen here"
  defp do_lopen(conn, params) do
    character = conn.character

    cond do
      not Access.adminp(character) ->
        error(conn, "你没有资格打开擂台。\n")

      is_nil(Arena.close_by(@leitai)) ->
        error(conn, "这个擂台目前并没有被关闭。\n")

      arg(params) != "here" ->
        error(conn, "如果你要打开擂台，请输入(lopen here)。\n")

      true ->
        Arena.open(@leitai)

        announce(
          conn,
          "【武林盛会】" <> character.name <> "结束了比武，重新开放了擂台。"
        )
    end
  end

  # LPC 是 message("vision", ..., all_interactive())：广播给房间里所有人。
  #
  # 用 `Kantele.Communication.announce/2`（它内部用 system_character() 作
  # 发起者并按频道 publish），**不要**自己拼 %Event 再调 publish ——
  # `Kantele.Communication` 只有 initial_channels/0、system_character/0、
  # announce/2 三个函数，没有 broadcast/2。
  # announce/2 内部是 try/rescue + catch :exit 包着的，广播失败也不会
  # 把玩家的命令处理进程带崩。
  defp announce(conn, text) do
    Kantele.Communication.announce("rooms:#{conn.character.room_id}", text <> "\n")

    conn
    |> prompt(CommandView, "prompt", %{})
  end

  defp error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end