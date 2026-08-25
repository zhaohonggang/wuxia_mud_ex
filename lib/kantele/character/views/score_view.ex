defmodule Kantele.Character.ScoreView do
  @moduledoc """
  score 命令的展示（assigns 均为命令层展开后的纯值）
  """

  use Kalevala.Character.View

  alias Kalevala.Character.Conn.EventText
  alias Kantele.Combat.Messages

  def render("display", assigns) do
    %EventText{
      topic: "Character.Score",
      data: assigns,
      text: render("_display", assigns)
    }
  end

  def render("_display", assigns) do
    %{vitals: vitals} = assigns

    ratio = div(vitals.qi * 100, max(vitals.max_qi, 1))

    skills_text =
      assigns.skills
      |> Enum.map(fn skill ->
        base = "  #{skill.name}  #{skill.level} 级"

        case skill.mapped do
          nil -> base
          mapped -> "#{base}（映射：#{mapped}）"
        end
      end)
      |> Enum.intersperse("\n║ ")

    performs =
      case assigns.performs do
        [] -> "无"
        performs -> Enum.join(performs, "、")
      end

    """
    ╔══════════════════════════════
    ║ {room-title}#{assigns.name}{/room-title}
    ╠══════════════════════════════
    ║ 气血：{hp}#{vitals.qi}/#{vitals.max_qi}{/hp}　精力：{sp}#{vitals.jing}/#{vitals.max_jing}{/sp}　内力：{ep}#{vitals.neili}/#{vitals.max_neili}{/ep}
    ║ 状态：#{Messages.eff_status_msg(ratio)}。
    ╠══════════════════════════════
    ║ 膂力 #{assigns.str}　身法 #{assigns.dex}　根骨 #{assigns.con}　悟性 #{assigns.int}
    ║ 实战经验 #{assigns.combat_exp}　潜能 #{assigns.potential}　铜钱 #{assigns.coins}文
    ║ 阅历 #{assigns.score}　威望 #{assigns.weiwang}　贡献 #{assigns.gongxian}
    ╠══════════════════════════════
    ║ 武学：
    ║ #{skills_text}
    ║ 绝招：#{performs}
    ╚══════════════════════════════
    """
  end

  def skill_title(name), do: skill_titles()[name] || name

  def mapped_title(stats, usage) do
    case Map.get(stats.mapped, usage) do
      nil -> nil
      skill_id -> skill_titles()[skill_id] || skill_id
    end
  end

  def perform_title("liuxin-jian/liu"), do: "「柳浪闻莺」"
  def perform_title(other), do: "「#{other}」"

  defp skill_titles() do
    %{
      "unarmed" => "基本拳脚",
      "sword" => "基本剑法",
      "dodge" => "轻功",
      "parry" => "招架",
      "force" => "基本内功",
      "liuxin-jian" => "柳心剑法",
      "liuxi-neigong" => "柳溪内功"
    }
  end
end
