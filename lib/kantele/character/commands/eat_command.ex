defmodule Kantele.Character.EatCommand do
  @moduledoc """
  进食命令：`eat <物品>`

  消耗背包中的可食物品（verbs 含 eat）。效果来自 Item.Meta：

  - `food` 饱食度供给（本期仅文案展示；饥饿扣减属 O4）
  - `medicine` 药效 map `%{qi: n, jing: n, neili: n, stats: %{str: n, ...}}`
      - qi/jing/neili 立即回复（钳到各自上限）
      - stats 为四维永久提升，每维受软上限 #{@stat_cap} 约束（数值待调）；
        声明的四维全部已达上限时拒绝消耗（"重复吃到上限被拒"）

  对应 LPC 吃丹药/食物（inherit F_FOOD / 丹药类 improve 属性），简化为一次吃完。
  """

  use Kalevala.Character.Command

  alias Kalevala.Verb
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Item.Meta
  alias Kantele.World.Items

  # 四维软上限（拍脑袋值，后续随大世界数值调整）
  @stat_cap 30
  @stats [:str, :dex, :con, :int]
  @restorable [:qi, :jing, :neili]

  @stat_names %{str: "臂力", dex: "身法", con: "根骨", int: "悟性"}
  @vital_names %{qi: "气血", jing: "精力", neili: "内力"}

  def run(conn, %{"item_name" => item_name}) do
    character = conn.character

    case find_instance(character.inventory, item_name) do
      nil ->
        conn
        |> render(CommandView, "text", %{text: "你身上没有这样东西。\n"})
        |> prompt(CommandView, "prompt", %{})

      instance ->
        item = Items.get!(instance.item_id)

        if edible?(item) do
          eat(conn, character, instance, item)
        else
          conn
          |> render(CommandView, "text", %{text: "#{item.name} 可不能这么往嘴里塞。\n"})
          |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  defp find_instance(inventory, item_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  end

  defp edible?(item) do
    Verb.has_matching_verb?(item.verbs, :eat, %Verb.Context{location: "inventory/self"})
  end

  defp eat(conn, character, instance, item) do
    meta = item.meta || %Meta{}
    medicine = Map.get(meta, :medicine)
    boosts = stat_boost(medicine)

    if boosts == %{} do
      plain_eat(conn, character, instance, item, medicine)
    else
      apply_medicine(conn, character, instance, item, medicine, boosts)
    end
  end

  # 无四维药效：普通进食（恢复类药效照常生效），单次吃完
  defp plain_eat(conn, character, instance, item, medicine) do
    {vital_parts, vitals} = restore_vitals(character.meta.vitals, medicine)

    character = %{character | inventory: drop_instance(character.inventory, instance)}
    character = put_vitals(character, vitals)

    text =
      case vital_parts do
        [] -> "你吃下#{item.name}，觉得肚子舒服多了。\n"
        parts -> "你吃下#{item.name}，一股暖流散入四肢百骸。（#{Enum.join(parts, " ")}）\n"
      end

    conn
    |> put_character(character)
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
    |> save()
  end

  # 有四维药效：声明的四维全部到顶则拒绝消耗；否则应用（钳到软上限）并吃掉
  defp apply_medicine(conn, character, instance, item, medicine, boosts) do
    stats = character.meta.stats

    capped? = Enum.all?(boosts, fn {key, _inc} -> Map.get(stats, key, 0) >= @stat_cap end)

    if capped? do
      names = boosts |> Map.keys() |> Enum.map(&stat_name/1) |> Enum.join("、")

      conn
      |> render(CommandView, "text", %{text: "你服药已多，#{names}再难精进，药力全然吸收不了。\n"})
      |> prompt(CommandView, "prompt", %{})
    else
      {stats, stat_parts} = boost_stats(stats, boosts)
      {vital_parts, vitals} = restore_vitals(character.meta.vitals, medicine)

      character =
        %{character | inventory: drop_instance(character.inventory, instance)}
        |> put_vitals(vitals)
        |> put_stats(stats)

      parts = Enum.join(vital_parts ++ stat_parts, " ")

      conn
      |> put_character(character)
      |> render(CommandView, "text", %{text: "你服下#{item.name}，只觉一股热气涌向四肢百骸。（#{
        parts
      }）\n"})
      |> prompt(CommandView, "prompt", %{})
      |> save()
    end
  end

  defp stat_name(key), do: Map.get(@stat_names, key, to_string(key))

  # 药效里声明的四维增量（%{str: 1}）；缺省/空返回空 map 表示无四维药效
  defp stat_boost(nil), do: %{}

  defp stat_boost(medicine) do
    case Map.get(medicine, :stats) do
      stats when is_map(stats) ->
        Enum.into(stats, %{}, fn {key, value} ->
          key = String.to_atom(to_string(key))
          if key in @stats, do: {key, value}, else: nil
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.into(%{})

      _ ->
        %{}
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
    {parts, new_vitals} =
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
          {"#{@vital_names[key]}+#{actual}", %{acc | key => Map.get(acc, key) + actual}}
        else
          {nil, acc}
        end
      end)

    {Enum.reject(parts, &is_nil/1), new_vitals}
  end

  defp restore_vitals(vitals, _), do: {[], vitals}

  defp drop_instance(inventory, instance) do
    Enum.reject(inventory, &(&1.id == instance.id))
  end

  defp put_vitals(character, vitals),
    do: %{character | meta: Map.put(character.meta, :vitals, vitals)}

  defp put_stats(character, stats),
    do: %{character | meta: Map.put(character.meta, :stats, stats)}

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
