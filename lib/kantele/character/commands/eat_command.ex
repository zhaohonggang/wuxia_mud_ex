defmodule Kantele.Character.EatCommand do
  @moduledoc """
  进食命令：`eat <物品>`

  消耗背包中的可食物品（verbs 含 eat）。效果来自 Item.Meta，经
  `Kantele.Item.Effect.consume/3` 数据驱动解读：

  - `food` 饱食度供给（本期仅文案展示；饥饿扣减属 O4）
  - `medicine` 药效 map `%{qi: n, jing: n, neili: n, stats: %{str: n, ...}}`
      - qi/jing/neili 立即回复（钳到各自上限）
      - stats 为四维永久提升，每维受软上限约束（数值待调）；
        声明的四维全部已达上限时拒绝消耗（"重复吃到上限被拒"）

  对应 LPC 吃丹药/食物（inherit F_FOOD / 丹药类 improve 属性），简化为一次吃完。
  """

  use Kalevala.Character.Command

  alias Kalevala.Verb
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Item.Effect
  alias Kantele.World.Items

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
    meta = item.meta || %{}
    vitals = character.meta.vitals || %{}
    stats = character.meta.stats || %{}

    case Effect.consume(vitals, stats, meta) do
      {:reject, reason} ->
        conn
        |> render(CommandView, "text", %{text: "#{reason}\n"})
        |> prompt(CommandView, "prompt", %{})

      {:ok, effect} ->
        new_meta = character.meta |> Map.put(:vitals, effect.vitals) |> Map.put(:stats, effect.stats)
        character =
          %{character | inventory: drop_instance(character.inventory, instance), meta: new_meta}

        text =
          narrator(item, effect)

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})
        |> save()
    end
  end

  # 食物/药效文案：药效（medicine）→ "服下...热气"；纯食物 → "吃下...肚子舒服"
  defp narrator(item, %{medicine?: true} = effect) do
    case effect.parts do
      [] -> "你吃下#{item.name}，一股暖意融入四肢百骸。\n"
      parts -> "你服下#{item.name}，只觉一股热气涌向四肢百骸。（#{Enum.join(parts, " ")}）\n"
    end
  end

  defp narrator(item, %{parts: parts}) do
    if parts == [] do
      "你吃下#{item.name}，觉得肚子舒服多了。\n"
    else
      "你吃下#{item.name}，一股暖流散入四肢百骸。（#{Enum.join(parts, " ")}）\n"
    end
  end

  defp drop_instance(inventory, instance) do
    Enum.reject(inventory, &(&1.id == instance.id))
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end
end
