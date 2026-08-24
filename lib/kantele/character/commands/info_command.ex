defmodule Kantele.Character.InfoCommand do
  use Kalevala.Character.Command

  alias Kantele.Character.InfoView
  alias Kantele.Character.Stats

  def run(conn, _params) do
    character = conn.character
    stats = character.meta.stats

    # EventText.data 会经 Jason 编码推送至 Web 端：只放标量与字符串，
    # 结构体（stats/combat）一律拆散（vitals 已派生编码器可保留）
    conn
    |> render(InfoView, "display", %{
      vitals: character.meta.vitals,
      str: stats.str,
      dex: stats.dex,
      con: stats.con,
      int: stats.int,
      combat_exp: stats.combat_exp,
      potential: stats.potential,
      force_level: level_with_special(stats, "force"),
      sword_level: level_with_special(stats, "sword"),
      dodge_level: Stats.skill(stats, "dodge"),
      parry_level: Stats.skill(stats, "parry"),
      unarmed_level: Stats.skill(stats, "unarmed")
    })
  end

  defp level_with_special(stats, base) do
    base_lvl = Stats.skill(stats, base)

    case Map.get(stats.mapped, base) do
      nil ->
        "#{base_lvl} 级"

      special_id ->
        "#{base_lvl} 级（#{special_title(special_id: special_id)} #{Stats.skill(stats, special_id)} 级）"
    end
  end

  defp special_title(special_id: id), do: special_titles()[id] || id

  defp special_titles() do
    %{
      "liuxin-jian" => "柳心剑法",
      "liuxi-neigong" => "柳溪内功"
    }
  end
end
