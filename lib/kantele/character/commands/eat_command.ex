defmodule Kantele.Character.EatCommand do
  @moduledoc """
  进食命令：`eat <物品>`

  消耗背包中的可食物品（verbs 含 eat）。效果来自 Item.Meta：

  - `food` 饱食度供给（本期仅文案展示；饥饿扣减属 O4）
  - `medicine` 药效 map `%{qi: n, jing: n, neili: n, stats: %{str: n, ...}}`
      - qi/jing/neili 立即回复（钳到各自上限）
      - stats 为四维永久提升，每维受软上限约束（数值待调）；
        声明的四维全部已达上限时拒绝消耗（"重复吃到上限被拒"）
  - `poison` 毒药效果（按 Kantele.Poison 结算）

  ## 丹药类（`meta.effect.kind == "pill"`，对应 LPC `do_effect(object me)`）

  LPC 丹药/药品在 `do_effect` 里除了回血，还带冷却、满状态拒服、房间广播、
  `start_busy`、叠层消耗等编排逻辑。这部分走 `eat_pill/5`：

  - 冷却：`meta.effect.cooldown` + `meta.effect.cooldown_key`，命中则拒服
  - 满状态拒服：`meta.effect.full_vital` 已达上限则拒服
  - 回血：委托 `Effect.consume/3`（读 `meta.medicine`，单一权威）
  - 房间广播：`message_vision("$N吃下...", me)` → 他人看 `$N`，自己看「你」

  对应 LPC 吃丹药/食物（inherit F_FOOD / 丹药类 improve 属性），简化为一次吃完。
  """

  use Kalevala.Character.Command

  alias Kalevala.Verb
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Item.Effect
  alias Kantele.Item.Effect.Pill
  alias Kantele.World.Items
  alias Kantele.World.RoomActions.Helpers

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

    if pill?(meta) do
      eat_pill(conn, character, instance, item, meta)
    else
      eat_food(conn, character, instance, item, meta)
    end
  end

  defp pill?(meta) do
    case Map.get(meta, :effect) do
      %{kind: "pill"} -> true
      _ -> false
    end
  end

  # --- 丹药路径（LPC do_effect） -------------------------------------------

  defp eat_pill(conn, character, instance, item, _meta) do
    case Pill.plan(character, item) do
      {:reject, _reason, text} ->
        conn
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})

      {:ok, plan} ->
        vitals = character.meta.vitals || %{}
        stats = character.meta.stats || %{}

        case Effect.consume(vitals, stats, plan.heal_meta) do
          {:reject, reason} ->
            conn
            |> render(CommandView, "text", %{text: reason})
            |> prompt(CommandView, "prompt", %{})

          {:ok, effect} ->
            new_meta =
              character.meta
              |> Map.put(:vitals, effect.vitals)
              |> Map.put(:stats, effect.stats)
              |> Pill.apply_cooldown(plan)

            combat = Pill.apply_busy(character.meta.combat, plan)

            character =
              character
              |> Map.put(:meta, Map.put(new_meta, :combat, combat))
              |> Map.put(:inventory, drop_instance(character.inventory, instance))

            conn
            |> put_character(character)
            |> Helpers.broadcast_vision(character.room_id, plan.vision_text || "",
              exclude_actor: true
            )
            |> render_actor_vision(plan.vision_text)
            |> render_self_text(plan.self_text)
            |> prompt(CommandView, "prompt", %{})
            |> save()
        end
    end
  end

  # 行动者自己看到 "$N"/"{npc}" → "你"（LPC message_vision 对本人归一为「你」）
  defp render_actor_vision(conn, nil), do: conn

  defp render_actor_vision(conn, vision_text) when is_binary(vision_text) do
    Helpers.render_to_player(
      conn,
      vision_text |> String.replace("$N", "你") |> String.replace("{npc}", "你")
    )
  end

  # tell_object(me, "你...") — 仅对本人展示，无房间广播
  defp render_self_text(conn, nil), do: conn

  defp render_self_text(conn, text) when is_binary(text) do
    Helpers.render_to_player(conn, text)
  end

  # --- 食物 / 药效路径（既有） ----------------------------------------------

  defp eat_food(conn, character, instance, item, meta) do
    vitals = character.meta.vitals || %{}
    stats = character.meta.stats || %{}

    case Effect.consume(vitals, stats, meta) do
      {:reject, reason} ->
        conn
        |> render(CommandView, "text", %{text: "#{reason}\n"})
        |> prompt(CommandView, "prompt", %{})

      {:ok, effect} ->
        new_meta =
          character.meta
          |> Map.put(:vitals, effect.vitals)
          |> Map.put(:stats, effect.stats)

        character = %{
          character
          | inventory: drop_instance(character.inventory, instance),
            meta: new_meta
        }

        text = narrator(item, effect)

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
