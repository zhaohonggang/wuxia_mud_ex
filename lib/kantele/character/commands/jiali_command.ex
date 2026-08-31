defmodule Kantele.Character.JialiCommand do
  @moduledoc """
  加力命令：`jiali <0-N>`

  手动设置加力档位（对应 LPC combatd 的 jiali）：攻击时每刀消耗档位等量
  内力，换取伤害加成。上限为 enable 的特殊内功等级 / 2（LPC 惯例）。
  战斗外也可预设；0 为关闭加力。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  def run(conn, params) do
    character = conn.character
    stats = character.meta.stats

    case parse_level(params["arg"]) do
      nil ->
        fail(conn, "格式：jiali <档位>（0 为关闭）。\n")

      level ->
        with_force(conn, stats, level)
    end
  end

  defp with_force(conn, stats, level) do
    special_id = Stats.mapped(stats, "force")

    case special_id do
      nil ->
        fail(conn, "你还没用 enable 选择内功心法，无法加力。\n")

      _ ->
        cap = div(Stats.skill(stats, special_id), 2)

        cond do
          level > cap ->
            fail(
              conn,
              "你的#{special_name(special_id)}只有 #{Stats.skill(stats, special_id)} 级，最多加力 #{cap} 档。\n"
            )

          true ->
            set_level(conn, level, cap)
        end
    end
  end

  defp set_level(conn, level, cap) do
    character = conn.character
    combat = %{character.meta.combat | jiali: level}
    character = put_combat(character, combat)

    text =
      case level do
        0 ->
          "你收敛内息，不再加力。\n"

        level when is_integer(level) and level <= cap ->
          "你将内力提到 #{level} 成加力，出招将更为凌厉。（内力不足时自动失效）\n"
      end

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp put_combat(character, combat),
    do: %{character | meta: Map.put(character.meta, :combat, combat)}

  defp special_name("liuxi-neigong"), do: "柳溪内功"
  defp special_name(id), do: id

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp parse_level(arg) when is_binary(arg) do
    case Integer.parse(String.trim(arg)) do
      {value, _rest} when value >= 0 -> value
      _ -> nil
    end
  end

  defp parse_level(_), do: nil
end
