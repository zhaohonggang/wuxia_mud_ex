defmodule Kantele.Character.DrinkCommand do
  @moduledoc """
  喝：`drink <物品>`（别名 `喝`、`heal`、`喝药`）

  两条互斥路径，判定依据是物品定义有没有 `liquid`（`Item.Meta.liquid`）：

  1. **容器液体**（`set("liquid", ([...]))` 的酒袋/茶碗/水壶）—— 按 LPC
     `cmds/std/drink.c` 的语义：余量减一、房间广播、喝空后提示；
     余量记在**实例** meta（`Kantele.World.Item.Liquid`），不动共享定义。
  2. **药水**（`Item.Meta.medicine`）—— 经 `Kantele.Item.Effect.consume/3`
     数据驱动解读（恢复气血/精力/内力等），喝完消耗掉这一件。

  ## 与 LPC 的已知差异

  - LPC `drink.c` 在 `liquid/type == "alcohol"` 时给玩家挂 `condition/drunk`
    （醉度，见 `kungfu/condition/drunk.c`：过量昏厥、半量扣精等）。
    本移植的 condition 子系统只注册了 `poison`/`fire_poison`/`nishui`/`duyan`，
    `drunk` daemon 尚未移植 → 醉酒副作用暂缺，只保留「喝」本身。
    登记见 `docs/data-world-comments-progress.zh-CN.md` §11。
  - LPC 的 `water` 摄入（`me->add("water", 30)`）与 `max_water_capacity()`
    属饥饿/口渴子系统（未建），同样不实现。
  - LPC 支持 `drink <液体> in <容器>` / `in all <包裹>` 的语法，
    本引擎的解析器只给单个 `item_name`，故只支持直接指定容器。
  """

  use Kalevala.Character.Command

  alias Kalevala.Verb
  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.Item.Effect
  alias Kantele.World.Item.Liquid
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

        cond do
          Liquid.state(item, instance) != nil ->
            drink_container(conn, character, instance, item)

          drinkable?(item) ->
            drink_effect(conn, character, instance, item)

          true ->
            conn
            |> render(CommandView, "text", %{text: "#{item.name} 可没法往嘴里灌。\n"})
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

  defp drinkable?(item) do
    Verb.has_matching_verb?(item.verbs, :drink, %Verb.Context{location: "inventory/self"})
  end

  # ---- 容器液体（LPC cmds/std/drink.c） ----

  defp drink_container(conn, character, instance, item) do
    liquid = Liquid.state(item, instance)

    cond do
      fighting?(character) ->
        text_only(conn, "你边打架边喝东西也不怕呛着？\n")

      Liquid.empty?(liquid) ->
        text_only(conn, empty_text(item, liquid))

      true ->
        consume_liquid(conn, character, instance, item, liquid)
    end
  end

  # LPC: ob->name() + (liquid/name ? "里的…已经被喝得一滴也不剩了。" : "是空的。")
  defp empty_text(item, %{name: nil}), do: "#{item.name}是空的。\n"
  defp empty_text(item, %{name: name}), do: "#{item.name}里的#{name}已经被喝得一滴也不剩了。\n"

  defp consume_liquid(conn, character, instance, item, liquid) do
    remaining = liquid.remaining - 1
    instance = Liquid.put_state(instance, %{liquid | remaining: remaining})
    character = %{character | inventory: replace_instance(character.inventory, instance)}

    # LPC `message_vision("$N拿起" + ob->name() + "咕噜噜地喝了几口" + liquid/name + "。")`
    # `{npc}` 由 VisionView 按接收者渲染（自己→「你」，他人→行动者名）。
    vision = "{npc}拿起#{item.name}咕噜噜地喝了几口#{liquid.name || ""}。\n"

    conn =
      conn
      |> put_character(character)
      |> publish_message(
        "rooms:#{character.room_id}",
        vision,
        [type: "vision"],
        &publish_error/2
      )
      |> assign(:prompt, false)

    conn =
      if remaining <= 0 do
        conn
        |> render(CommandView, "text", %{
          text: "你已经将#{item.name}里的#{liquid.name || ""}喝得一滴也不剩了。\n"
        })
        |> prompt(CommandView, "prompt", %{})
      else
        conn
      end

    save(conn)
  end

  defp fighting?(character) do
    combat = character.meta.combat || %Kantele.Character.Combat{}
    Map.get(combat, :enemies, []) != []
  end

  defp replace_instance(inventory, instance) do
    Enum.map(inventory, fn inst ->
      if Map.get(inst, :id) == instance.id, do: instance, else: inst
    end)
  end

  # ---- 药水（原有路径，未改动语义） ----

  defp drink_effect(conn, character, instance, item) do
    meta = item.meta || %{}
    vitals = character.meta.vitals || %{}
    stats = character.meta.stats || %{}

    case Effect.consume(vitals, stats, meta) do
      {:reject, reason} ->
        text_only(conn, "#{reason}\n")

      {:ok, effect} ->
        new_meta =
          character.meta |> Map.put(:vitals, effect.vitals) |> Map.put(:stats, effect.stats)

        character = %{
          character
          | inventory: drop_instance(character.inventory, instance),
            meta: new_meta
        }

        text =
          if effect.parts == [] do
            "你仰头喝下#{item.name}，顿觉神清气爽。\n"
          else
            "你仰头喝下#{item.name}，一股暖流涌遍全身，伤势顿时好转。（#{
              Enum.join(
                effect.parts,
                " "
              )
            }）\n"
          end

        conn
        |> put_character(character)
        |> render(CommandView, "text", %{text: text})
        |> prompt(CommandView, "prompt", %{})
        |> save()
    end
  end

  defp drop_instance(inventory, instance) do
    Enum.reject(inventory, &(&1.id == instance.id))
  end

  defp text_only(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp save(conn) do
    Records.save(conn.private.update_character || conn.character)
    conn
  end

  defp publish_error(conn, _error), do: conn
end
