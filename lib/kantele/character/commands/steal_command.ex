defmodule Kantele.Character.StealCommand do
  @moduledoc """
  偷窃命令：`steal <物品> from <人物>`

  对应 LPC cmds/std/steal.c 的移植。
  使用 stealing 技能判定，成功则转移物品，失败可能被发觉并触发战斗。

  流程：
  1. 前置检查（忙/战斗/精）后发送 steal/attempt 到房间
  2. 房间验证目标有效性后立即显示「正在下手」并设置延迟回调
  3. 延迟 3 秒后触发 steal/resolve，完成技能判定和物品转移
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"item" => item, "target" => target}) do
    if item == "" or target == "" do
      conn
      |> render(CommandView, "text", %{text: "指令格式：steal <物品> from <人物>\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      character = conn.character

      cond do
        character.meta.combat.enemies != [] ->
          conn
          |> render(CommandView, "text", %{text: "你还是好好打你的架吧。\n"})
          |> prompt(CommandView, "prompt", %{})

        character.meta.temp["stealing"] ->
          conn
          |> render(CommandView, "text", %{text: "你已经在找机会下手了。\n"})
          |> prompt(CommandView, "prompt", %{})

        Map.get(character.attributes, "jing", 0) < 80 ->
          conn
          |> render(CommandView, "text", %{text: "你现在难以集中精神，不敢贸然下手偷窃。\n"})
          |> prompt(CommandView, "prompt", %{})

        true ->
          conn
          |> event("steal/attempt", %{item: item, target: target})
          |> assign(:prompt, false)
      end
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：steal <物品> from <人物>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
