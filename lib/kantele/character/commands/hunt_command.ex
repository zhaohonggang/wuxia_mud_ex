defmodule Kantele.Character.HuntCommand do
  @moduledoc """
  狩猎命令：`hunt <目标>`（别名 `猎` / `打猎`）

  对应 LPC `cmds/std/hunt.c`：在同房间内寻找可猎猎的野兽（QUARRY 继承，`power > 0`），
  基于玩家战斗等级与野兽 power 值做命中判定，命中则发起战斗；野兽死亡后按
  `meta.drop_a` / `meta.drop_b` / `meta.drop_c`（LPC `item1`/`item2`/`item3`）
  生成尸体与掉落物，由 `Kantele.World.Corpse.spawn/1` 在 `CombatEvent.die/3` 主路径落地。

  野兽均为 `attitude = "peaceful"`，普通 `fight` 命令对其守卫可能受限，
  `hunt` 为专门的狩猎通道，不受同门/非敌对限制。

  ## 与 LPC 的差异

  - LPC `hunt.c` 直接判定 `ob->query("power")` 与玩家 `query_skill("dodge")`；
    本端口用 `combat_exp` 换算等级（`level = :math.pow(combat_exp / 100, 1/3)` 近似）
    与 `power` 对比，等级 >= power 即命中。
  - LPC 有 `query_temp("hunting")` 并发锁，本端口因同步裁定省略。
  - LPC `quarry.c die()` 把战利品直接 `item->move(me, 1)` 给击杀者，并按
    `random(skill) > 10/30/60` 概率门控；本端口改为固定掉落、作为独立
    `Item.Instance` 放在死亡房间，任何人可 `get` 拾取（方案 A）。
  - 掉落物品由死亡管线 `Kantele.World.Corpse.spawn/1` 放入死亡房间，玩家可 `get` 拾取。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat

  def run(conn, %{"target" => target}) do
    character = conn.character

    cond do
      not is_nil(target) and target != "" ->
        hunt(conn, character, target)

      true ->
        usage(conn)
    end
  end

  def run(conn, %{}), do: usage(conn)

  # ---- 狩猎主流程 ----

  defp hunt(conn, character, target) do
    cond do
      Combat.fighting?(character.meta.combat) ->
        reject(conn, "你正在战斗中，无法狩猎。\n")

      Combat.busy?(character.meta.combat) ->
        reject(conn, "你现在正忙着呢，无法狩猎。\n")

      true ->
        quarry = find_quarry(conn, target)

        cond do
          is_nil(quarry) ->
            reject(conn, "这里没有这只野兽。\n")

          not quarry?(quarry) ->
            reject(conn, "#{quarry.name} 不是可猎猎的野兽。\n")

          true ->
            resolve_hunt(conn, character, quarry)
        end
    end
  end

  # ---- 房间内查找 quarry NPC ----

  defp find_quarry(conn, target) do
    key = to_string(target) |> String.trim()
    characters(conn) |> Enum.find(&matches_quarry?(&1, key))
  end

  defp characters(conn) do
    case Map.get(conn.private || %{}, :room) do
      %{private: %{characters: list}} when is_list(list) ->
        list

      _ ->
        try do
          case conn.character do
            nil -> []
            character ->
              case Kantele.World.Room.snapshot(character.room_id) do
                %{private: %{characters: list}} -> list
                _ -> []
              end
          end
        rescue
          _ -> []
        end
    end
  end

  defp matches_quarry?(npc, key) do
    key = String.downcase(key)

    id = to_string(Map.get(npc, :id)) |> String.downcase()
    short_id = id |> String.split(":") |> List.last()
    name = to_string(Map.get(npc, :name)) |> String.downcase()
    aliases = aliases_of(npc) |> Enum.map(&String.downcase(to_string(&1)))

    id == key or short_id == key or name == key or
      String.starts_with?(name, "#{key} ") or Enum.member?(aliases, key)
  end

  defp aliases_of(npc) do
    meta = Map.get(npc, :meta) || %{}
    attrs = Map.get(npc, :attributes) || %{}
    case Map.get(meta, :aliases) || Map.get(attrs, "aliases") || Map.get(attrs, :aliases) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  # ---- quarry 判定：meta.power > 0 ----

  defp quarry?(npc) do
    meta = Map.get(npc, :meta) || %{}
    is_integer(Map.get(meta, :power, 0)) and Map.get(meta, :power) > 0
  end

  # ---- 命中判定：玩家等级 >= power ----

  defp resolve_hunt(conn, character, quarry) do
    player_level = player_level(character)
    power = quarry_power(quarry)

    cond do
      player_level >= power ->
        send_attack(conn, character, quarry)

      true ->
        reject(conn, "#{quarry.name} 太强了，你还不是它的对手。\n")
    end
  end

  defp player_level(character) do
    combat_exp = character.meta.stats.combat_exp || 0
    # 近似 LPC 等级公式：level ~ (combat_exp/100)^(1/3)
    :math.pow(combat_exp / 100, 1.0 / 3.0) |> :math.floor() |> max(1)
  end

  defp quarry_power(quarry) do
    meta = Map.get(quarry, :meta) || %{}
    Map.get(meta, :power, 0)
  end

  # ---- 发起战斗：复用 combat/attack 事件（与 fight_command 一致）----

  defp send_attack(conn, character, quarry) do
    quarry_name = to_string(Map.get(quarry, :name))

    conn
    |> event("combat/attack", %{
           name: quarry_name,
           type: "hunt"
         })
    |> assign(:prompt, false)
    |> render(CommandView, "text", %{text: "你蓄势待发，对 #{quarry_name} 发起狩猎！\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 输出 ----

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp usage(conn) do
    conn
    |> render(CommandView, "text", %{text: "指令格式：hunt <目标>\n"})
    |> prompt(CommandView, "prompt", %{})
  end
end
