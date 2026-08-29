defmodule Kantele.Item.Effect do
  @moduledoc """
  物品效果栈（对应 `feature/food.c` 与 `feature/liquid.c` 的 apply_effect 机制）

  食物/液体/药品等可叠加的效果函数列表（上限 12 个）。纯状态容器，
  宿主在吃/喝时 `do_effect/2` 依次执行。
  """

  @max_effects 12

  @doc "是否有效果 (is_food / is_liquid)"
  def has_effect?(effects) when effects != nil and effects != [], do: true
  def has_effect?(_), do: false

  @doc """
  追加效果 (LPC: apply_effect(f))；逻辑等价于把 f 追加到列表（上限 12，保序）
  """
  def apply_effect(nil, effect), do: [effect]
  def apply_effect(effects, nil), do: effects

  def apply_effect(effects, effect) when is_list(effects) do
    if length(effects) < @max_effects do
      effects ++ [effect]
    else
      effects
    end
  end

  def apply_effect(single, effect), do: [single, effect]

  @doc "清空效果 (LPC: clear_effect)"
  def clear_effect(_), do: []

  @doc "查询效果 (LPC: query_effect)"
  def query_effect(effects), do: effects

  @doc "执行全部效果 (LPC: do_effect(me))；以列表顺序依次执行"
  def do_effect(effects, ctx) when is_list(effects) do
    Enum.each(effects, &apply_fun(&1, ctx))
    :ok
  end

  def do_effect(effects, ctx), do: do_effect([effects], ctx)

  defp apply_fun(f, ctx) when is_function(f, 1), do: f.(ctx)
  defp apply_fun(f, _ctx) when is_function(f, 0), do: f.()
  defp apply_fun(_f, _ctx), do: nil

  # ---------------------------------------------------------------------------
  # 数据驱动消耗效果（food.c food_supply / medicine）
  #
  # 物品以**数据**形式在 meta 中声明效果（food 饱食值 / medicine 药效 map），
  # 宿主（eat/drink 等消耗命令）调用 `consume/3` 解读并作用于角色 vitals/stats。
  # 效果层是纯函数：数据进 → `{:ok, result}` / `{:reject, reason}` 出。
  # ---------------------------------------------------------------------------

  # 四维软上限（拍脑袋值，后续随大世界数值调整）
  @stat_cap 30
  @stats [:str, :dex, :con, :int]
  @restorable [:qi, :jing, :neili]

  @stat_names %{str: "臂力", dex: "身法", con: "根骨", int: "悟性"}
  @vital_names %{qi: "气血", jing: "精力", neili: "内力"}

  @doc """
  数据驱动地解读一个可消耗物品的 `%Item.Meta{}`（food / medicine）并对角色生效。

  返回：
    `{:ok, %{vitals:, stats:, parts: [], food?: bool, medicine?: bool}}` — 可消耗
    `{:reject, reason}` — 声明的四维全部已达软上限，拒绝消耗

  - `vitals` / `stats` 为应用后的新张量（钳到上限），宿主写回角色即可
  - `parts` 为中文效果描述串（"气血+N" / "臂力+1"），供宿主拼进文案
  - `food?`  表示物品有食物饱食效果（仅文案；饥饿扣减属 O4）
  - `medicine?` 表示物品带药效（有 medicine 段）
  """
  def consume(vitals, stats, meta) when is_map(meta) do
    medicine = Map.get(meta, :medicine)
    boosts = stat_boost(medicine)
    food? = is_integer(Map.get(meta, :food)) && Map.get(meta, :food) > 0
    medicine? = is_map(medicine) && medicine != %{}

    if boosts == %{} do
      {parts, new_vitals} = restore_vitals(vitals, medicine)

      {:ok,
       %{
         vitals: new_vitals,
         stats: stats,
         parts: parts,
         food?: food?,
         medicine?: medicine?
       }}
    else
      case boost_cap(stats, boosts) do
        {:reject, reason} ->
          {:reject, reason}

        :ok ->
          {new_stats, stat_parts} = boost_stats(stats, boosts)
          {vital_parts, new_vitals} = restore_vitals(vitals, medicine)

          {:ok,
           %{
             vitals: new_vitals,
             stats: new_stats,
             parts: vital_parts ++ stat_parts,
             food?: food?,
             medicine?: medicine?
           }}
      end
    end
  end

  def consume(_vitals, stats, _meta), do: {:ok, %{vitals: nil, stats: stats, parts: [], food?: false, medicine?: false}}

  # 药效里声明的四维增量（%{str: 1}）；缺省/空返回空 map 表示无四维药效
  defp stat_boost(nil), do: %{}

  defp stat_boost(medicine) do
    case is_map(medicine) && Map.get(medicine, :stats) do
      stats when is_map(stats) ->
        stats
        |> Enum.into(%{}, fn {key, value} ->
          key = String.to_atom(to_string(key))
          if key in @stats, do: {key, value}, else: nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})

      _ ->
        %{}
    end
  end

  # 声明的四维全部到达软上限 → 拒绝消耗；否则 :ok
  defp boost_cap(stats, boosts) do
    names =
      boosts
      |> Map.keys()
      |> Enum.map(&stat_name/1)
      |> Enum.join("、")

    if Enum.all?(boosts, fn {key, _inc} -> Map.get(stats, key, 0) >= @stat_cap end) do
      {:reject, "你服药已多，#{names}再难精进，药力全然吸收不了。"}
    else
      :ok
    end
  end

  # 应用四维增量并生成文案；超出软上限的部分截断为实际增量
  defp boost_stats(stats, boosts) do
    Enum.reduce(boosts, {stats, []}, fn {key, inc}, {stats, parts} ->
      current = Map.get(stats, key, 0)
      new_value = min(current + inc, @stat_cap)

      part =
        if new_value > current do
          "#{stat_name(key)}+#{new_value - current}"
        else
          "#{stat_name(key)}已臻极限"
        end

      {%{stats | key => new_value}, parts ++ [part]}
    end)
  end

  defp restore_vitals(vitals, medicine) when is_map(medicine) do
    {vital_parts, new_vitals} =
      @restorable
      |> Enum.map(fn key ->
        case Map.get(medicine, key) do
          amount when is_integer(amount) and amount > 0 -> {key, amount}
          _ -> nil
        end
      end)
      |> Enum.reject(&is_nil/1)
      |> Enum.map_reduce(vitals, fn {key, amount}, acc ->
        max = Map.get(acc, :"max_#{key}")
        actual = min(Map.get(acc, key) + amount, max) - Map.get(acc, key)

        if actual > 0 do
          {vital_part(key, actual), %{acc | key => Map.get(acc, key) + actual}}
        else
          {nil, acc}
        end
      end)

    {Enum.reject(vital_parts, &is_nil/1), new_vitals}
  end

  defp restore_vitals(vitals, _), do: {[], vitals}

  defp vital_part(key, actual), do: "#{@vital_names[key]}+#{actual}"
  defp stat_name(key), do: Map.get(@stat_names, key, to_string(key))
end
