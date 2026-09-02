defmodule Kantele.Character.CheckCommand do
  @moduledoc """
  查探命令：`check <玩家>`

  对应 LPC cmds/std/check.c。
  丐帮专用命令，用于查探其他玩家的技能。
  需要 checking 技能 >= 30 级，且房间中有可交谈的 NPC。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView

  def run(conn, %{"target" => target}) do
    character = conn.character

    family_name =
      case character.attributes["family"] do
        %{family_name: name} -> name
        _ -> nil
      end

    cond do
      family_name != "丐帮" ->
        conn
        |> render(CommandView, "text", %{text: "你不知道如何向人查探情报。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        checking_skill = character.meta.stats.skills["checking"] || 0

        if checking_skill < 30 do
          conn
          |> render(CommandView, "text", %{
            text: "你的打探本领尚未纯熟，无法了解别人的技能。\n"
          })
          |> prompt(CommandView, "prompt", %{})
        else
          conn
          |> event("check/request", %{target_name: target})
          |> assign(:prompt, false)
        end
    end
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：check|dating <某人>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
