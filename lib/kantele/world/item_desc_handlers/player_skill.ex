defmodule Kantele.World.ItemDescHandlers.PlayerSkill do
  @moduledoc """
  数据驱动动态 `item_desc`：按角色技能等级（可选叠加门派）选择文本（P5-4k，P5-4m 扩展）。

  对应 LPC 常见形式（如 xiakedao 石洞群 `look_bi`）：

      if (me->query_skill("literate", 1) || me->query("learned_literate"))
          msg = "识字者看到的蝌蚪文……";
      else
          msg = "文盲看到的壁画……";
      return msg;

  LPC 的 `query_skill("literate", 1)` 即「有效 literate 等级 > 0」；`|| query("learned_literate")`
  是或分支，而本引擎 `learned_literate` 未独立建模，识字技能 > 0 时该或分支恒真，故
  以 `Stats.skill(stats, "literate") >= min_level` 覆盖主路径（与 `study_command` 的
  `has_literate?` 口径一致）。

  P5-4m 扩展：星宿派后洞 `look_pet` 要求「门派 == 星宿派 且 星宿奇术技能 >= 160」才显示
  五圣剧毒文本，否则显示普通五毒描述。故本 handler 支持可选 `family` 字段——配置里出现
  `family` 时，玩家 `meta.family` 的派名必须等于该值，否则落到 `no_text`。

  UCL 示例：

      item_desc = {
       bi = {
        kind = "player_skill"
        skill = "literate"
        min_level = 1
        has_text = "识字者看到的蝌蚪文……"
        no_text = "文盲看到的壁画……"
       }
       pet = {
        kind = "player_skill"
        family = "星宿派"
        skill = "xingxiu-qishu"
        min_level = 160
        has_text = "门派弟子才看得到的五圣剧毒……"
        no_text = "上面刻有蜈蚣，蜘蛛，蝎子，蛇，蟾蜍五种毒物。"
       }
      }

  `has_text` / `no_text` 均按 UCL 单行字符串约定书写（换行折叠为 `\\n` 转义），handler
  统一补一个结尾换行，与静态 `item_desc` 渲染保持一致。
  """

  import Kalevala.World.Room.Context

  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @default_text "这里没有这个东西。\n"

  def run(context, requester, %{config: config}) do
    text =
      if gate_passes?(requester, config) do
        Map.get(config, "has_text") || @default_text
      else
        Map.get(config, "no_text") || @default_text
      end

    render(context, requester.pid, CommandView, "text", %{text: ensure_newline(text)})
  end

  # 门派 + 技能双重门控（P5-4m）。二者皆满足才显示 has_text；缺省 family 时只看技能。
  defp gate_passes?(requester, config) do
    family_ok?(requester, Map.get(config, "family")) and skill_ok?(requester, config)
  end

  defp family_ok?(_requester, nil), do: true

  defp family_ok?(%{meta: meta}, family_name) when is_binary(family_name) do
    family_name(meta) == family_name
  end

  defp family_ok?(_requester, _family_name), do: false

  # meta 可能是 PlayerMeta 结构体或普通 map，统一用 Map.get 防御式取值。
  defp family_name(meta) when is_map(meta) do
    case Map.get(meta, :family) do
      fam when is_map(fam) -> Map.get(fam, :name) || Map.get(fam, "name")
      _ -> nil
    end
  end

  defp family_name(_), do: nil

  defp skill_ok?(requester, config) do
    case Map.get(config, "skill") do
      nil -> true
      skill -> skill_level(requester, skill) >= Map.get(config, "min_level", 1)
    end
  end

  defp skill_level(%{meta: %{stats: stats}}, skill) when is_binary(skill) do
    Stats.skill(stats, skill)
  end

  defp skill_level(_requester, _skill), do: 0

  defp ensure_newline(text) when is_binary(text) do
    String.trim_trailing(text) <> "\n"
  end

  defp ensure_newline(_text), do: @default_text
end
