defmodule Kantele.Character.FuseCommand do
  @moduledoc """
  熔炼命令：`fuse <物品>`

  对应 LPC cmds/skill/fuse.c：将某些原料物品熔化，获得灵慧 (magic_points)。

  LPC 原文流程：

    - 必须手持/持有该物品（`present(str, me)`）
    - 内功 >= 300、最大内力 >= 5000、当前内力 >= 3000
    - 物品须同时具备 `can_make` 与 `item_origin`（取自 `Item.Meta`），否则
      "这东西似乎熔炼不出什么。"
    - `p = item.power_point`；`p < 50` 直接化作青烟、什么都没留下
    - 否则 `p = random(p * 3 / 2)`，按阈值给对应灵石（stone1..stone5）：
      p>120→辉月华石 / >90→辉石 / >70→皓石 / >50→岚石 / 否则→炽石
    - 灵石 `value / 300` 决定灵慧：`mp = 5 + random(value/300)` 并夹在 [5,100]
    - 扣除 max_neili-1、neili-3000、`start_busy(5)`，灵石入包
  """
  use Kalevala.Character.Command

  alias Kalevala.Character.Conn
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Records
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items

  # `power_point` 阈值 → 灵石 item_id（clone_lib zone）。
  # LPC fuse.c: p>120→stone5 / >90→stone4 / >70→stone3 / >50→stone2 / else stone1
  @stones [
    {120, "clone_lib:fam_item_stone5"},
    {90, "clone_lib:fam_item_stone4"},
    {70, "clone_lib:fam_item_stone3"},
    {50, "clone_lib:fam_item_stone2"}
  ]

  def run(conn, %{"rest" => arg}) do
    character = conn.character
    item_name = String.trim(arg || "")

    cond do
      item_name == "" ->
        fail(conn, "你要熔炼什么物品？\n")

      Combat.busy?(character.meta.combat) ->
        fail(conn, "先忙完了你的事情再做这件事情吧。\n")

      Combat.fighting?(character.meta.combat) ->
        fail(conn, "你现在正在打架，没时间做这些事情。\n")

      true ->
        do_fuse(conn, character, item_name)
    end
  end

  def run(conn, %{}), do: fail(conn, "你要熔炼什么物品？\n")
  def run_bare(conn, %{}), do: run(conn, %{})

  defp do_fuse(conn, character, item_name) do
    vitals = character.meta.vitals

    cond do
      (character.meta.stats.skills["force"] || 0) < 300 ->
        fail(conn, "你的内功修为不够，难以熔炼物品。\n")

      vitals.max_neili < 5000 ->
        fail(conn, "你的内力修为不够，难以熔炼物品。\n")

      vitals.neili < 3000 ->
        fail(conn, "你现在的内力不足，难以熔炼物品。\n")

      true ->
        case find_item(character, item_name) do
          nil ->
            fail(conn, "你身上没有这件物品。\n")

          inst ->
            fuse_item(conn, character, inst)
        end
    end
  end

  defp find_item(character, name) do
    Enum.find(character.inventory, fn inst ->
      item = Items.get!(inst.item_id)
      item.callback_module.matches?(item, name)
    end)
  end

  defp fuse_item(conn, character, inst) do
    item = Items.get!(inst.item_id)
    meta = item.meta

    # LPC: !ob->query("can_make") || !ob->query("item_origin")
    if is_nil(meta.can_make) or is_nil(meta.item_origin) do
      fail(conn, "这东西似乎熔炼不出什么。\n")
    else
      p = meta.power_point || 0

      # message_vision("$N 将 X 握于掌中，默默运转内力，迫使其熔化。", me)
      conn = publish_vision(conn, character, "#{item.name}握于掌中，默默运转内力，迫使其熔化。\n")

      if p < 50 do
        # message_vision("突然却见 X 嗤的化作一股青烟，什么都没有留下。", me)
        conn
        |> remove_instance(inst)
        |> publish_vision(character, "#{item.name}嗤的化作一股青烟，什么都没有留下。\n")
        |> consume_and_busy(1, 3000, 5)
      else
        p = :rand.uniform(trunc(p * 3 / 2))
        stone_id = pick_stone(p)
        mp = compute_magic_points(stone_id)

        conn =
          conn
          |> remove_instance(inst)
          |> add_instance(stone_id)
          |> publish_vision(character, "霎时只见$N掌心白雾蒸腾，似乎发生了什么不同寻常的事情。\n")
          |> consume_and_busy(1, 3000, 5)

        if mp > 0 do
          # LPC: tell_object(me, "你通过熔炼 X 的过程，从而获得了 Y 点灵慧。")
          conn
          |> add_magic_points(mp)
          |> render_self("你通过熔炼#{item.name}的过程，从而获得了#{mp}点灵慧。\n")
        else
          render_self(conn, "你熔炼了#{item.name}，得到了一颗灵石。\n")
        end
      end
    end
  end

  # --- helpers ---

  defp cur(conn), do: conn.private.update_character || conn.character

  defp remove_instance(conn, inst) do
    character = cur(conn)
    new_inv = Enum.reject(character.inventory, fn i -> i.id == inst.id end)
    put_character(conn, %{character | inventory: new_inv})
  end

  defp add_instance(conn, item_id) do
    character = cur(conn)

    instance = %Instance{
      id: Instance.generate_id(),
      item_id: item_id,
      created_at: DateTime.utc_now()
    }

    put_character(conn, %{character | inventory: [instance | character.inventory]})
  end

  defp consume_and_busy(conn, max_neili_dec, neili_dec, busy_rounds) do
    character = cur(conn)
    vitals = character.meta.vitals

    # LPC: me->add("max_neili", -1) / me->add("neili", -3000)
    # 与门槛读取同一命名空间（vitals），不可为负。
    new_vitals = %{
      vitals
      | max_neili: max(0, vitals.max_neili - max_neili_dec),
        neili: max(0, vitals.neili - neili_dec)
    }

    new_combat = Combat.start_busy(character.meta.combat, busy_rounds)

    new_character = %{
      character
      | meta: %{character.meta | vitals: new_vitals, combat: new_combat}
    }

    conn = put_character(conn, new_character)
    Records.save(new_character)
    conn
  end

  defp add_magic_points(conn, mp) do
    character = cur(conn)
    new_mp = (character.attributes["magic_points"] || 0) + mp
    new_character = %{character | attributes: Map.put(character.attributes, "magic_points", new_mp)}
    conn = put_character(conn, new_character)
    Records.save(new_character)
    conn
  end

  defp pick_stone(p) when p > 120, do: "clone_lib:fam_item_stone5"
  defp pick_stone(p) when p > 90, do: "clone_lib:fam_item_stone4"
  defp pick_stone(p) when p > 70, do: "clone_lib:fam_item_stone3"
  defp pick_stone(p) when p > 50, do: "clone_lib:fam_item_stone2"
  defp pick_stone(_p), do: "clone_lib:fam_item_stone1"

  defp compute_magic_points(stone_id) do
    case Items.get(stone_id) do
      {:ok, stone} ->
        value = stone.meta.value || 0

        if value > 0 do
          # LPC: mp = stone->query("value") / 300; mp = 5 + random(mp)
          # 这里用 :rand.uniform 取 [1, value/300]，+5 后夹在 [5,100]
          max(5, min(100, 5 + :rand.uniform(max(1, div(value, 300)))))
        else
          0
        end

      _ ->
        0
    end
  end

  # 房间 vision 广播：{npc} 由 VisionView 按接收者渲染（自己→「你」，他人→行动者名）
  defp publish_vision(conn, character, text) do
    conn
    |> Conn.publish_message(
      "rooms:#{character.room_id}",
      "{npc}#{text}",
      [type: "vision"],
      &publish_error/2
    )
    |> assign(:prompt, false)
  end

  defp render_self(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp publish_error(conn, _error), do: conn
end
