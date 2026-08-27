defmodule Kantele.Character.SkillsCommand do
  @moduledoc """
  技能列表：`skills` / `myskill` / `技能` / `我的技能`

  显示已学技能 + 等级 + 有效等级（基本+映射），按类型分组。
  对照 LPC cmds/skill/skills.c + myskill.c。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @base_skills ["force", "sword", "dodge", "parry", "unarmed"]

  @skill_titles %{
    "force" => "基本内功",
    "sword" => "基本剑法",
    "dodge" => "轻功",
    "parry" => "招架",
    "unarmed" => "基本拳脚",
    "liuxin-jian" => "柳心剑法",
    "liuxi-neigong" => "柳溪内功"
  }

  def run(conn, _params) do
    character = conn.character
    stats = character.meta.stats

    text = format_skills(stats)

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  def format_skills(stats) do
    header = "你目前所学到的所有技能\n"
    separator = "≡------------------------------------------------------------≡\n"

    base_lines =
      @base_skills
      |> Enum.filter(fn skill -> Stats.skill(stats, skill) > 0 end)
      |> Enum.map(fn skill -> format_base_skill(stats, skill) end)

    special_lines =
      stats.skills
      |> Enum.reject(fn {skill, _level} -> skill in @base_skills end)
      |> Enum.sort_by(fn {skill, _level} -> skill end)
      |> Enum.map(fn {skill, level} -> format_special_skill(stats, skill, level) end)

    lines = base_lines ++ special_lines

    header <> separator <> Enum.join(lines, "") <> separator
  end

  defp format_base_skill(stats, skill_id) do
    level = Stats.skill(stats, skill_id)
    effective = Stats.effective(stats, skill_id)
    title = Map.get(@skill_titles, skill_id, skill_id)
    mapped = Stats.mapped(stats, skill_id)

    effective_str =
      if mapped do
        special_level = Stats.skill(stats, mapped)
        special_title = Map.get(@skill_titles, mapped, mapped)
        "  →  #{special_title} #{special_level} 级（有效 #{effective} 级）"
      else
        ""
      end

    mapped_marker = if mapped, do: "□ ", else: "  "

    "#{mapped_marker}#{title} (#{skill_id})" <>
      String.pad_leading(to_string(level), 6) <> " 级" <> effective_str <> "\n"
  end

  defp format_special_skill(stats, skill_id, level) do
    title = Map.get(@skill_titles, skill_id, skill_id)

    enabled_usages =
      @base_skills
      |> Enum.filter(fn usage -> Stats.mapped(stats, usage) == skill_id end)
      |> Enum.map(fn usage -> Map.get(@skill_titles, usage, usage) end)

    enabled_str =
      case enabled_usages do
        [] -> ""
        usages -> "  [#{Enum.join(usages, "、")}已启用]"
      end

    has_performs = skill_has_performs?(skill_id)
    performs_str = if has_performs, do: " ★", else: ""

    "  #{title} (#{skill_id})" <>
      String.pad_leading(to_string(level), 6) <> " 级" <> enabled_str <> performs_str <> "\n"
  end

  defp skill_has_performs?(skill_id) do
    case Skills.get(skill_id) do
      nil -> false
      module -> map_size(module.perform_list()) > 0
    end
  end
end
