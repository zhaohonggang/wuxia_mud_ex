defmodule Kantele.Character.ScoreCommand do
  @moduledoc """
  状态命令：`score`，显示气血、属性、经验与武学

  视图层拿到的是 Trimmed 后的角色（仅 vitals），因此在命令层
  把需要展示的数据展开为纯值传入。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.ScoreView

  def run(conn, _params) do
    character = conn.character
    stats = character.meta.stats

    skills =
      stats.skills
      |> Enum.sort_by(fn {name, _level} -> name end)
      |> Enum.map(fn {name, level} ->
        %{
          name: ScoreView.skill_title(name),
          level: level,
          mapped: ScoreView.mapped_title(stats, name)
        }
      end)

    performs =
      stats.performs
      |> Enum.map(&ScoreView.perform_title/1)
      |> Enum.sort()

    conn
    |> render(ScoreView, "display", %{
      name: character.name,
      vitals: character.meta.vitals,
      str: stats.str,
      dex: stats.dex,
      con: stats.con,
      int: stats.int,
      combat_exp: stats.combat_exp,
      potential: stats.potential,
      coins: character.meta.coins || 0,
      score: stats.score || 0,
      weiwang: stats.weiwang || 0,
      gongxian: stats.gongxian || 0,
      skills: skills,
      performs: performs
    })
  end
end
