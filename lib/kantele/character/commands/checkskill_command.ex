defmodule Kantele.Character.CheckskillCommand do
  @moduledoc """
  查技能详情：`checkskill <技能>` / `查技能 <技能>`

  显示单项技能的等级、有效等级、类型、enable 状态、可学招式。
  对照 LPC cmds/skill/checkskill.c。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Skills

  @skill_titles %{
    "force" => "基本内功",
    "sword" => "基本剑法",
    "dodge" => "轻功",
    "parry" => "招架",
    "unarmed" => "基本拳脚",
    "liuxin-jian" => "柳心剑法",
    "liuxi-neigong" => "柳溪内功"
  }

  @skill_types %{
    "force" => "内功",
    "sword" => "剑法",
    "dodge" => "轻功",
    "parry" => "招架",
    "unarmed" => "拳脚"
  }

  def run(conn, params) do
    skill_name = String.trim(params["skill"] || "")

    case skill_name do
      "" ->
        conn
        |> render(CommandView, "text", %{text: "请指定要查询的技能，如：checkskill 柳心剑法\n"})
        |> prompt(CommandView, "prompt", %{})

      _ ->
        character = conn.character
        stats = character.meta.stats
        skill_id = resolve_skill_id(skill_name)

        case skill_id do
          nil ->
            conn
            |> render(CommandView, "text", %{text: "没有「#{skill_name}」这种技能。\n"})
            |> prompt(CommandView, "prompt", %{})

          _ ->
            text = format_checkskill(stats, skill_id)

            conn
            |> render(CommandView, "text", %{text: text})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  def resolve_skill_id(name) do
    # 先按 id 查（在标题表中查找）
    case Map.get(@skill_titles, name) do
      nil ->
        # 按中文标题模糊匹配
        @skill_titles
        |> Enum.find(fn {_id, title} -> String.contains?(title, name) end)
        |> case do
          nil -> nil
          {id, _title} -> id
        end

      _title ->
        name
    end
  end

  def format_checkskill(stats, skill_id) do
    level = Stats.skill(stats, skill_id)
    title = Map.get(@skill_titles, skill_id, skill_id)
    module = Skills.get(skill_id)

    header = "━━━ #{title} (#{skill_id}) ━━━\n\n"

    basic_info = "等级：#{level}\n"

    type_info =
      cond do
        skill_id in Map.keys(@skill_types) ->
          "类型：#{@skill_types[skill_id]}（基本技能）\n"

        module && module.valid_enable("force") ->
          "类型：内功（特殊技能）\n"

        module && module.valid_enable("sword") ->
          "类型：剑法（特殊技能）\n"

        module ->
          "类型：特殊技能\n"

        true ->
          "类型：基本技能\n"
      end

    effective_info = format_effective_info(stats, skill_id)
    enable_info = format_enable_info(stats, skill_id, module)
    perform_info = format_perform_info(module)
    exert_info = format_exert_info(module)

    header <>
      basic_info <> type_info <> effective_info <> enable_info <> perform_info <> exert_info
  end

  defp format_effective_info(stats, skill_id) do
    # 查找哪个 base usage 映射了此技能
    mapped_usage =
      stats.mapped
      |> Enum.find(fn {_usage, mapped_id} -> mapped_id == skill_id end)

    case mapped_usage do
      nil ->
        ""

      {usage, _mapped_id} ->
        base_level = Stats.skill(stats, usage)
        effective = base_level + Stats.skill(stats, skill_id)
        usage_title = Map.get(@skill_titles, usage, usage)

        "\n映射到：#{usage_title}（基本 #{base_level} + 特殊 #{Stats.skill(stats, skill_id)} = 有效 #{
          effective
        } 级）\n"
    end
  end

  defp format_enable_info(stats, skill_id, module) do
    if module == nil do
      ""
    else
      enabled_usages =
        ["force", "sword", "dodge", "parry", "unarmed"]
        |> Enum.filter(fn usage -> module.valid_enable(usage) end)
        |> Enum.map(fn usage -> Map.get(@skill_titles, usage, usage) end)

      case enabled_usages do
        [] -> "\n不可启用到任何用法。\n"
        usages -> "\n可启用到：#{Enum.join(usages, "、")}\n"
      end
    end
  end

  defp format_perform_info(module) do
    if module == nil do
      ""
    else
      performs = module.perform_list()

      case map_size(performs) do
        0 ->
          ""

        _ ->
          perform_names = Enum.join(Map.keys(performs), "、")
          "\n可施展绝招：#{perform_names}\n"
      end
    end
  end

  defp format_exert_info(module) do
    if module == nil do
      ""
    else
      exerts = module.exert_list()

      case map_size(exerts) do
        0 ->
          ""

        _ ->
          exert_names = Enum.join(Map.keys(exerts), "、")
          "\n可运功：#{exert_names}\n"
      end
    end
  end
end
