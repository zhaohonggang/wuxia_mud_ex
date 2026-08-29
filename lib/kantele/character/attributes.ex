defmodule Kantele.Character.Attributes do
  @moduledoc """
  派生属性计算（对应 `lpc_example/feature/attribute.c` from ES2/XKX/Heros.cn）

  把基础值 + 纹身(tattoo) + 转世(reborn) + 技能加成(skill/10) + 临时 apply
  逐属性归并，输出角色"有效属性"。

  纯函数：不持有角色状态，入参 = 属性片断，返回有效值。宿主调用方负责从
  Stats / PlayerMeta temp / 角色 dbase 汇集输入。
  """

  @doc """
  有效力量 query_str

  取 `unarmed/cuff/finger/strike/hand/claw` 中最高的技能，`/10` 加成。
  """
  def str(base, opts \\ %{}) do
    best_unarmed_skill = max_skill(opts, ["unarmed", "cuff", "finger", "strike", "hand", "claw"])
    base + tattoo_reborn(opts, "str") + div(best_unarmed_skill, 10) + apply_of(opts, "str")
  end

  @doc "有效智力 query_int（由 literate 技能加成）"
  def int(base, opts \\ %{}) do
    lit = skill_of(opts, "literate")
    base + tattoo_reborn(opts, "int") + div(lit, 10) + apply_of(opts, "int")
  end

  @doc "有效体质 query_con（由 force 技能加成）"
  def con(base, opts \\ %{}) do
    force = skill_of(opts, "force")
    base + tattoo_reborn(opts, "con") + div(force, 10) + apply_of(opts, "con")
  end

  @doc "有效身法 query_dex（由 dodge 技能加成）"
  def dex(base, opts \\ %{}) do
    dodge = skill_of(opts, "dodge")
    base + tattoo_reborn(opts, "dex") + div(dodge, 10) + apply_of(opts, "dex")
  end

  @doc "有效容貌 query_per（随年龄衰减；有 special_skill/youth 则不变）"
  def per(base, opts \\ %{}) do
    result = base + tattoo_reborn(opts, "per") + apply_of(opts, "per")

    if Map.get(opts, "special_skill/youth") || Map.get(opts, :youth?) do
      result
    else
      age = Map.get(opts, :age) || Map.get(opts, "age") || 0
      result - age_penalty(age)
    end
  end

  @doc "有效等级 query_level = floor((combat_exp*10)^(1/3)) + 1"
  def level(combat_exp) when is_integer(combat_exp) and combat_exp >= 0 do
    trunc(:math.pow(combat_exp * 10, 1.0 / 3)) + 1
  end

  def level(_), do: 1

  # ---- helpers ----

  defp max_skill(opts, keys) do
    keys
    |> Enum.map(&skill_of(opts, &1))
    |> Enum.max(fn -> 0 end)
  end

  defp skill_of(opts, key) do
    skills = Map.get(opts, :skills) || Map.get(opts, "skills") || %{}
    Map.get(skills, key, 0)
  end

  defp tattoo_reborn(opts, key) do
    t = Map.get(opts, {:tattoo, key}) || Map.get(opts, "tattoo/#{key}") || 0
    r = Map.get(opts, {:reborn, key}) || Map.get(opts, "reborn/#{key}") || 0
    t + r
  end

  defp apply_of(opts, key) do
    apply = Map.get(opts, :apply) || Map.get(opts, "apply") || %{}
    Map.get(apply, key, 0)
  end

  defp age_penalty(age) when age > 70, do: 6
  defp age_penalty(age) when age > 60, do: 5
  defp age_penalty(age) when age > 50, do: 4
  defp age_penalty(age) when age > 40, do: 3
  defp age_penalty(age) when age > 30, do: 2
  defp age_penalty(_), do: 0
end
