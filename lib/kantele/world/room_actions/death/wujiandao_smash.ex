defmodule Kantele.World.RoomActions.Death.WujiandaoSmash do
  @moduledoc """
  `d/death/liudaolunhui/wujiandao.c` 的 `do_smash`（`add_action("do_smash", "smash")`）。

  玩家装备「无间闪电」后可使用 smash 攻击房间内生物：
  1. 未装备无间闪电 → 提示「你没有装备无间闪电，无法使用其 smash 神力！」
  2. 无目标参数 → 提示「指令格式: smash <living>」
  3. 目标不存在 → 提示「找不到这个生物。」
  4. 目标是非角色物品 → 广播「X从这个世界上消失了...」
  5. 目标是角色 → 广播闪电攻击文案，标记目标死亡

  对应 LPC `do_smash/1`。
  """

  use Kantele.World.RoomAction

  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.Character.Combat.StatusTracker

  @wujian_item_id "death:wujian"

  @no_weapon "你没有装备无间闪电，无法使用其 smash 神力！\n"
  @no_arg "指令格式: smash <living>\n"
  @not_found "找不到这个生物。\n"
  @smash_vision "无间闪电化作无数闪电击向{npc}...\n\n"
  @disappear_vision "{npc}从这个世界上消失了...\n\n"

  @impl true
  def run(conn, %{trailing: arg, room_id: room_id}) do
    character = current(conn)
    tname = String.trim(arg)

    cond do
      not wielding_wujian?(character) ->
        Helpers.render_to_player(conn, @no_weapon)

      tname == "" ->
        Helpers.render_to_player(conn, @no_arg)

      true ->
        target = find_target(room_id, tname)

        cond do
          target == nil ->
            Helpers.render_to_player(conn, @not_found)

          not character?(target) ->
            conn
            |> Helpers.broadcast_vision(room_id, @smash_vision)
            |> Helpers.broadcast_vision(room_id, @disappear_vision)

          true ->
            conn
            |> Helpers.broadcast_vision(room_id, @smash_vision)
            |> kill_target(room_id, target)
        end
    end
  end

  # 装备判定走 Map.get/2，不用 `equipped[:weapon]` 链式 Access：
  # 运行态若 combat/equipped 尚未初始化（nil），链式 Access 会抛 ArgumentError；
  # 这里对 nil 一律按「未装备」处理，与 LPC「查不到武器即拒绝」一致。
  defp wielding_wujian?(character) do
    combat = character.meta.combat || %{}
    equipped = Map.get(combat, :equipped) || %{}
    weapon = Map.get(equipped, :weapon)

    case weapon do
      %{} -> Map.get(weapon, :item_id) == @wujian_item_id
      _ -> false
    end
  end

  defp find_target(room_id, name) do
    room_id
    |> Room.npc_characters_by_id()
    |> List.wrap()
    |> Enum.find(&matches_name?(&1, name))
  end

  defp matches_name?(character, name) when is_binary(name) and name != "" do
    character.name == name or
      (Map.get(character.meta, :aliases, []) |> List.wrap() |> Enum.member?(name)) or
      character.id == name
  end

  defp matches_name?(_character, _name), do: false

  defp character?(%{meta: %Kantele.Character.PlayerMeta{}}), do: true
  defp character?(%{meta: %Kantele.Character.NonPlayerMeta{}}), do: true
  defp character?(_), do: false

  defp kill_target(conn, room_id, target) do
    # 标记 NPC 死亡（LPC ob->die()）
    StatusTracker.mark_dead(target.id)

    # 广播死亡文案
    Helpers.broadcast_vision(
      conn,
      room_id,
      "#{target.name}被无间闪电劈成飞灰，从此消散于无间之中。\n"
    )
  end

  defp current(%{private: %{update_character: c}} = _conn) when not is_nil(c),
    do: c

  defp current(%{character: c}), do: c
end
