defmodule Kantele.Character.FillCommand do
  @moduledoc """
  灌水：`fill <容器>`（别名 `灌水`）

  对应 LPC `cmds/std/fill.c`：在有水的地方把容器灌满清水。

  判定顺序与 LPC 逐条对齐：

  1. 房间没有水（`resource/water`）→「这里没有地方可以装水。」
  2. 忙 →「你上一个动作还没有完成。」
  3. 战斗中 →「你正忙着打架，没工夫装水！」
  4. 身上没有该物品 →「你身上没有这样东西。」
  5. 物品没有 `liquid`（不是容器）→「这个容器装不了水。」
  6. 里面还剩别的液体（且不是清水）→ 先广播倒掉，再广播装满清水
  7. 落状态：`type = "water"`、`name = "清水"`、`remaining = max_liquid`

  第 7 步写的是**实例** meta（`Kantele.World.Item.Liquid`），不是共享定义 ——
  否则一个玩家灌水会让所有玩家的同一个容器都变成清水。

  ## 与 LPC 的已知差异

  - LPC 还会写 `liquid["drink_func"] = 0`（清掉容器自带的饮用回调），
    本引擎没有 `drink_func` 模型 → 不实现。
  - 房间 `resource/water`（LPC 48 处 `set("resource/water", 1)`）在 UCL 数据里
    **尚未回填**，故当前所有房间都会走到「这里没有地方可以装水。」。
    命令本身已按真实语义实现，数据补齐即生效；缺口登记在
    `docs/data-world-comments-progress.zh-CN.md` §11。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Records
  alias Kantele.World.Item.Liquid
  alias Kantele.World.Items

  def run(conn, %{"item_name" => item_name}) do
    character = conn.character
    room = Kantele.World.Room.snapshot(character.room_id)

    cond do
      not water_here?(room) ->
        text_only(conn, "这里没有地方可以装水。\n")

      busy?(character) ->
        text_only(conn, "你上一个动作还没有完成。\n")

      fighting?(character) ->
        text_only(conn, "你正忙着打架，没工夫装水！\n")

      true ->
        case find_instance(character.inventory, item_name) do
          nil ->
            text_only(conn, "你身上没有这样东西。\n")

          instance ->
            fill(conn, character, instance)
        end
    end
  end

  defp fill(conn, character, instance) do
    item = Items.get!(instance.item_id)

    case Liquid.state(item, instance) do
      nil -> text_only(conn, "这个容器装不了水。\n")
      liquid -> do_fill(conn, character, instance, item, liquid)
    end
  end

  defp do_fill(conn, character, instance, item, liquid) do
    # LPC: if (my["remaining"] && my["name"] != "清水")
    #          message_vision("$N将" + ob->name() + "里剩下的" + my["name"] + "倒掉。\n");
    conn =
      if liquid.remaining > 0 and liquid.name not in [nil, "清水"] do
        vision(conn, character, "{npc}将#{item.name}里剩下的#{liquid.name}倒掉。\n")
      else
        conn
      end

    conn = vision(conn, character, "{npc}将#{item.name}装满清水。\n")

    # LPC: my["remaining"] = ob->query("max_liquid") —— 无 max_liquid 时保持原容量
    capacity = liquid.max || liquid.remaining
    filled = %{liquid | type: "water", name: "清水", remaining: capacity}

    instance = Liquid.put_state(instance, filled)
    character = %{character | inventory: replace_instance(character.inventory, instance)}

    conn
    |> put_character(character)
    |> save()
  end

  defp water_here?(room) do
    Map.get(room, :attrs, %{})["water"] == true
  end

  defp busy?(character) do
    character.meta.temp["busy"] not in [nil, false, 0]
  end

  defp fighting?(character) do
    combat = character.meta.combat || %Kantele.Character.Combat{}
    Map.get(combat, :enemies, []) != []
  end

  defp find_instance(inventory, item_name) do
    Enum.find(inventory, fn instance ->
      item = Items.get!(instance.item_id)
      instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  rescue
    _ -> nil
  end

  defp replace_instance(inventory, instance) do
    Enum.map(inventory, fn inst ->
      if Map.get(inst, :id) == instance.id, do: instance, else: inst
    end)
  end

  defp vision(conn, character, text) do
    conn
    |> publish_message(
      "rooms:#{character.room_id}",
      text,
      [type: "vision"],
      &publish_error/2
    )
    |> assign(:prompt, false)
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
