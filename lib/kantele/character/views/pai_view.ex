defmodule Kantele.Character.PaiView do
  @moduledoc """
  门派信息展示（A11/N5 v0）
  """

  use Kalevala.Character.View

  def render("display", assigns) do
    family = assigns.family || %{}

    name = Map.get(family, :name)
    master_name = Map.get(family, :master_name)

    {family_line, master_line} =
      case {name, master_name} do
        {nil, _} -> {"门派：无（可寻找带门派的 NPC 拜师，如练武场的王重九）", ""}
        {name, nil} -> {"门派：#{name}", ""}
        {name, master} -> {"门派：#{name}", "师父：#{master}"}
      end

    lines =
      [
        "══════ 门派信息 ══════",
        family_line,
        master_line,
        "门派贡献：#{assigns.gongxian}",
        "江湖阅历：#{assigns.score}",
        "威望：#{assigns.weiwang}",
        "正邪：#{shen_text(assigns.shen)}"
      ]
      |> Enum.reject(&(&1 == ""))

    Enum.join(lines, "\n") <> "\n"
  end

  # 正邪数值本期只存不用；正数记正道
  defp shen_text(shen) when shen > 0, do: "正(#{shen})"
  defp shen_text(shen) when shen < 0, do: "恶(#{-shen})"
  defp shen_text(_), do: "中庸"
end
