defmodule Kantele.Character.BegCommand do
  @moduledoc """
  乞讨命令：`beg <财物> from <人物>`（别名 `乞讨`）

  对应 LPC cmds/std/beg.c。向同房间内其他角色乞讨铜钱。

  ## 与 LPC 的差异（金钱模型）

  LPC 里钱是 4 个独立钱物对象（cash/gold/silver/coin），`beg.c` 取 victim 身上
  **面值最大**的那个对象，转移其 `amount/5`（至少 1）。本引擎的 `meta.coins` 是
  **单一扁平整数池**（见 bank_command.ex），故：
  - `what ∈ {cash, gold, silver, coin}` 仅做语法校验（LPC 的硬通货限制），
    实际转移的是 victim 整池 `meta.coins` 的 1/5（至少 1）；
  - 没有「victim 身上无匹配钱物」这一概念——改为判定 `meta.coins <= 0`。

  ## 门派与时序
  - 仅 `丐帮`（family_name == "丐帮"）可乞讨。
  - LPC 用 `call_out("compelete_beg", 3, ...)` 做 3 秒延迟，延迟期间用
    `query_temp("begging")` 阻止并发乞讨。本引擎房间定时器不可用（见
    `Kantele.World.Room.set_timer` 文档），且房间事件不回写 `context.characters`，
    跨角色改币必须在**角色进程**落地。故改为**同步**裁定：命令进程做
    门派/flag/语法闸门 + `beg/attempt` 事件进房间；房间进程解析 victim、广播
    vision、裁定成败，再分别向 victim/beggar 发 `beg/debit`/`beg/credit` 事件，
    由各自角色进程改币并 `Records.save`（与 casino/payout 同款跨进程模式）。
    因裁定同步（无异步窗口），LPC 的 `query_temp("begging")` 并发闸门一并省略。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.World.NpcActions.Helpers

  @money_keywords ["cash", "gold", "silver", "coin"]

  def run(conn, %{"coin" => coin, "target" => target}) do
    if coin == "" or target == "" do
      usage(conn)
    else
      character = conn.character

      cond do
        Helpers.family_name(character) != "丐帮" ->
          reject(conn, "只有乞丐才能乞讨。\n")

        Enum.member?(Kantele.World.room_flags(character.room_id), "no_beg") or
          Enum.member?(Kantele.World.room_flags(character.room_id), "no_fight") ->
          reject(conn, "这里不是你叫化子能来讨饭的地方。\n")

        not (coin in @money_keywords) ->
          reject(conn, "你只能乞讨硬通货。\n")

        fighting?(character) ->
          reject(conn, "你还是先把你面前的家伙放倒再说吧。\n")

        busy?(character) ->
          reject(conn, "你现在正忙着呢。\n")

        true ->
          conn
          |> event("beg/attempt", %{coin: coin, target: target})
          |> assign(:prompt, false)
      end
    end
  end

  def run(conn, %{}), do: usage(conn)

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：beg <财物> from <人物>\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fighting?(character) do
    combat = character.meta.combat || %Combat{}
    Combat.fighting?(combat)
  end

  defp busy?(character) do
    combat = character.meta.combat || %Combat{}
    Combat.busy?(combat)
  end
end
