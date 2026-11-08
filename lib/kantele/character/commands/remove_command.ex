defmodule Kantele.Character.RemoveCommand do
  @moduledoc """
  脱卸命令：`remove all | <物品名称>` / `脱 all | <物品名称>`

  对应 LPC `cmds/std/remove.c`，逐分支落地：

  - 无参数 → `你要脱掉什么？`
  - `all` → 遍历所有已穿戴护具逐个脱下，末尾 `你脱完了。`；
    一件都没有 → `你什么都没有脱下来。`
  - 指定名称 → 先 `present(arg, me)`（`你身上没有这样东西。`），
    再看是否有同 id 的**已穿戴**护具（`你并没有装备这样东西。`），
    最后调用 `do_remove`（`ob->unequip()` + `message_vision`）。
  - 其余参数（不存在的分类）不适用；本命令只接受物品名或 `all`。

  ## 与 LPC 的建模差异

  - LPC 用 `ob->query("equipped") == "worn"` 标记护具；Ex 用
    `meta.combat.equipped` 的 `armor_type` 槽位。武器/手持槽位
    (`:weapon` / `:secondary_weapon` / `:handing`) 不属于 `remove` 管辖，
    对应 LPC 的 `unwield` 与手持收回，本端口由 `unwield` / `hand nothing` 负责。
  - 单件脱卸复用 `Kantele.Character.WieldCommand.remove/2`（同款槽位回查、
    `Combat.unequip` + prop 扣减、自定义 `messages.remove/unequip` 房间广播）。
    LPC `do_remove` 里按 `armor_type` 硬编码的三套默认 `message_vision` 文案
    （cloth/armor/surcoat/boots、bandage、default）在 Ex 由物品自定义文案承载，
    无自定义文案时保持既有的「你卸下了X。」，不引入 ANSI 颜色。
  - LPC `query_temp("no_wear")` 的「脱下X以后你觉得舒服多了」附加句未建模
    （Ex 无该 temp 字段）。
  - `top2` / `topp` 之外，本命令不再有重复的 `remove` 路由：先前
    `WieldCommand` 与 `RemoveCommand` 各注册了一条 `remove`，因 router
    反转 parse 函数（后注册优先）导致裸 `remove` 落到占位桩、带参落到
    `WieldCommand`，`remove all` 被当成物品名。现统一由本模块持有
    `remove` / `脱` 两条路由。

  单测可用 `conn.private[:remove_present]`（arity 2 的 `(character, arg) -> boolean`
  函数）注入 `present()` 结果，避免依赖全局物品缓存。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.WieldCommand
  alias Kantele.World.Item
  alias Kantele.World.Items

  # 与 Combat 的武器/手持槽位互斥；remove.c 只处理 `equipped == "worn"` 的防具。
  @non_armor_slots [:weapon, :secondary_weapon, :handing]

  def run(conn, params) do
    arg =
      params
      |> Map.get("item_name", "")
      |> to_string()
      |> String.trim()

    cond do
      arg == "" -> render_error(conn, "你要脱掉什么？\n")
      arg == "all" -> remove_all(conn)
      true -> remove_one(conn, arg)
    end
  end

  # ---- LPC main() 的单件分支 ----

  defp remove_one(conn, arg) do
    cond do
      not present?(conn, conn.character, arg) ->
        render_error(conn, "你身上没有这样东西。\n")

      not worn?(conn.character, arg) ->
        # LPC 会再遍历 all_inventory(me) 找「同 id 且已 worn」的另一件；
        # Ex 的槽位回查在 worn?/2 里已覆盖同名多件的情形。
        render_error(conn, "你并没有装备这样东西。\n")

      true ->
        WieldCommand.remove(conn, %{"item_name" => arg})
    end
  end

  # ---- LPC main() 的 all 分支 ----

  defp remove_all(conn), do: WieldCommand.remove_all(conn)

  # ---- present() / 已穿戴判定 ----

  # present(arg, me)：按实例 id 或物品别名/名字在背包里找。
  # `Items.get!` 走 ETS；缓存未启动时 rescue 成 false，不让命令把进程带崩。
  defp present?(conn, character, arg) do
    case Map.get(conn.private, :remove_present) do
      fun when is_function(fun, 2) ->
        fun.(character, arg)

      _ ->
        Enum.any?(character.inventory || [], fn instance ->
          item = Items.get!(instance.item_id)
          instance.id == arg or item.callback_module.matches?(item, arg)
        end)
    end
  rescue
    _ -> false
  end

  defp worn?(character, arg) do
    character.meta.combat.equipped
    |> removable_slots()
    |> Enum.any?(fn {_slot, snap} -> snapshot_matches?(snap, arg) end)
  end

  # 快照只存全名，与 WieldCommand.snapshot_matches?/2 保持同一套匹配规则，
  # 否则会出现 present? 通过但后续 do_remove 又找不到的不一致。
  defp snapshot_matches?(snapshot, item_name) do
    name = Map.get(snapshot, :name)
    is_binary(name) and (Item.matches?(%{name: name}, item_name) or name == item_name)
  end

  defp removable_slots(equipped) do
    Enum.filter(equipped || %{}, fn {slot, snap} ->
      slot not in @non_armor_slots and is_map(snap)
    end)
  end

  # ---- 输出 ----

  defp render_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end
end
