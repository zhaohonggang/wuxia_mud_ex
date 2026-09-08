defmodule Kantele.Character.SkillCommand do
  @moduledoc """
  技能详情命令：`skill <技能名>`

  对应 LPC cmds/std/skill.c。
  显示技能等级、映射特技、已学绝招等信息。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  def run(conn, %{"skill_name" => skill_name}) do
    character = conn.character
    stats = character.meta.stats
    level = Stats.skill(stats, skill_name)
    special = Stats.mapped(stats, skill_name)
    effective = Stats.effective(stats, skill_name)

    lines = [
      "关于「#{skill_name}」的详细属性：\n",
      "  技能等级：  #{level}\n",
      "  有效等级：  #{effective}\n"
    ]

    lines =
      if special do
        special_level = Stats.skill(stats, special)
        lines ++ ["  映射特技：  #{special}（#{special_level}级）\n"]
      else
        lines
      end

    matching_performs =
      stats.performs
      |> MapSet.to_list()
      |> Enum.filter(&String.starts_with?(&1, "#{skill_name}/"))

    lines =
      if matching_performs != [] do
        lines ++ ["  已学绝招：  #{Enum.join(matching_performs, "、")}\n"]
      else
        lines
      end

    conn
    |> render(CommandView, "text", %{text: Enum.join(lines)})
    |> prompt(CommandView, "prompt", %{})
  end

  def run(conn, %{}) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：skill <技能名>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
