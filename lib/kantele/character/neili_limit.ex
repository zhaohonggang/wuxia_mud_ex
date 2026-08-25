defmodule Kantele.Character.NeiliLimit do
  @moduledoc """
  内力天花板计算（对应 LPC clone/user/user.c `query_current_neili_limit`）

  current 语义：基本线（force 基本等级/2 × 10）＋ enable 的那门特殊内功
  等级 × 10 ＋ 该内功的 improve 贡献。瓶颈检查（打坐判定）用本式；
  硬天花板取 valid_enable 最高者的加法式，只有一门内功时两者等价。

  百分比加成（improve/neili%、breakup 任督等）本期不做，留待后续。
  """

  alias Kantele.Character.Stats

  @doc """
  当前内力上限

  - force 基本内功未映射特技时：`force/2 × 10`
  - 已映射时：基本线 + 特殊内功等级 × 10 + improve 贡献
  """
  def current(%Stats{} = stats) do
    base = div(Stats.skill(stats, "force"), 2) * 10

    special =
      case Stats.mapped(stats, "force") do
        nil ->
          0

        skill_id ->
          Stats.skill(stats, skill_id) * 10 + improve(stats, skill_id)
      end

    base + special
  end

  # 特殊内功的 improve 贡献钩子（LPC query_neili_improve）。
  # 现有技能模块无此字段，一律计 0；后续接入时按 skill_id 分发
  defp improve(_stats, _skill_id), do: 0
end
