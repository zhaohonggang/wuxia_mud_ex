defmodule Kantele.Character.GiveCommand do
  @moduledoc """
  赠送命令：`give <物品> to <人>` / `give <人> <物品>` / `give all to <人>` / `give <数量> <物品> to <人>`

  物品在自己的背包里找（按 name 或 instance id 匹配），校验不可装备/已装备后
  发 `room/give` 事件，由房间解析目标并把物品实例转交给对方进程；本进程在收到
  `give/result` 确认后再从自己背包移除物品并落盘。

  参数按空格切开后手工归类（兼容 LPC 的 `item to target` 与 `target item` 两种顺序）：
  - 含 ` to ` → 其前为物品（可带 `数量 前缀`），其后为目标
  - 否则 → 首词为目标，其余为物品

  特殊：若物品为任务物品（`liuxi:task/*`），且目标为对应 NPC（owner_id 匹配），
  则触发任务奖励结算（exp/pot/score/银子+里程碑仙丹），物品消耗，通知 MirrorDaemon。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items
  alias Kantele.World.MirrorDaemon

  def run(conn, %{"rest" => rest}) do
    rest = String.trim(rest || "")

    case parse_args(rest) do
      {:error, msg} ->
        conn
        |> render(CommandView, "text", %{text: msg})
        |> prompt(CommandView, "prompt", %{})

      {:ok, target, item_spec} ->
        do_give(conn, target, item_spec)
    end
  end

  def run(conn, _params) do
    conn
    |> render(CommandView, "text", %{text: "你要给谁什么东西？\n"})
    |> prompt(CommandView, "prompt", %{})
  end

  # ---- 参数解析 ----

  defp parse_args(rest) do
    cond do
      rest == "" ->
        {:error, "你要给谁什么东西？\n"}

      String.contains?(rest, " to ") ->
        parse_with_to(rest)

      true ->
        parse_target_first(rest)
    end
  end

  # give <物品> to <人> / give <数量> <物品> to <人>
  defp parse_with_to(rest) do
    [item_part, target] = String.split(rest, " to ", parts: 2)

    if String.trim(target) == "" do
      {:error, "你要给谁什么东西？\n"}
    else
      {:ok, String.trim(target), item_part}
    end
  end

  # give <人> <物品> / give <人> all
  defp parse_target_first(rest) do
    case String.split(rest, ~r/\s+/, parts: 2) do
      [target, item] ->
        if String.trim(item) == "" do
          {:error, "你要给谁什么东西？\n"}
        else
          {:ok, target, item}
        end

      _ ->
        {:error, "你要给谁什么东西？\n"}
    end
  end

  # ---- 物品解析与开送 ----

  defp do_give(conn, target, item_spec) do
    item_instance = find_item(conn, item_spec)

    cond do
      is_nil(item_instance) ->
        conn
        |> render(CommandView, "text", %{text: "你身上没有这样东西。\n"})
        |> prompt(CommandView, "prompt", %{})

      equipped?(conn, item_instance) ->
        conn
        |> render(CommandView, "text", %{text: "这件东西必须先取下装备才能给别人。\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        item = Items.get!(item_instance.item_id)

        # 特殊：任务物品上交给对应 NPC
        if is_task_item?(item) do
          handle_task_give(conn, target, item_instance, item)
        else
          # 普通赠送走 room/give 事件
          conn
          |> event("room/give", %{
            target: target,
            item_instance: item_instance,
            item_name: item.name,
            from_id: conn.character.id,
            from_name: conn.character.name
          })
          |> assign(:prompt, false)
        end
    end
  end

  # 判断是否为任务物品
  defp is_task_item?(item) do
    String.starts_with?(item.id, "liuxi:task/")
  end

  # 处理任务物品上交
  defp handle_task_give(conn, target, item_instance, item) do
    # 在当前房间找目标 NPC
    target_npc = find_npc_in_room(conn, target)

    if target_npc && valid_task_target?(item, target_npc) do
      settle_task_reward(conn, item_instance, item, target_npc)
    else
      conn
      |> render(CommandView, "text", %{text: "这个人不需要这件东西。\n"})
      |> prompt(CommandView, "prompt", %{})
    end
  end

  defp find_npc_in_room(conn, target) do
    room = conn.room
    private = room.private || %{}
    characters = private.characters || []

    Enum.find(characters, fn char ->
      char.id == target || char.name == target
    end)
  end

  defp valid_task_target?(item, npc) do
    target_id = item.meta.owner_id
    target_id && (npc.id == target_id || npc.name == item.meta.owner)
  end

  defp settle_task_reward(conn, item_instance, item, target_npc) do
    character = conn.character

    # 1. 从背包移除物品实例
    conn = remove_item(conn, character, item_instance)

    # 2. 计算奖励（参考 LPC do_return）
    mirror_count = Map.get(character.meta.stats, :mirror_count, 0) + 1
    new_count = mirror_count

    exp = (100 + :rand.uniform(100)) * new_count

    pot = cond do
      new_count > 20 -> 2000 + :rand.uniform(2000)
      new_count > 10 -> 1000 + :rand.uniform(1000)
      new_count > 5  -> 500 + :rand.uniform(500)
      true -> 100 + :rand.uniform(100)
    end

    pot = case new_count do
      10 -> pot + 1000
      20 -> pot + 4000
      30 -> pot + 10000
      _  -> pot
    end

    kar = Map.get(character.meta.stats, :kar, 20)
    score = 10 + :rand.uniform(kar)

    # 发放奖励
    conn = add_exp(conn, character, exp)
    conn = add_pot(conn, character, pot)
    conn = add_score(conn, character, score)
    conn = give_silver(conn, character, 10)
    conn = update_mirror_count(conn, character, new_count)

    # 里程碑奖励
    conn = check_milestone_reward(conn, character, new_count)

    # 通知 MirrorDaemon
    task_name = String.replace(item.id, "liuxi:task/", "")
    MirrorDaemon.on_task_completed(task_name, %{id: character.id, name: character.name})

    # 广播
    conn
    |> render(CommandView, "text", %{
      text: "你将#{item.name}交给了#{target_npc.name}。\n" <>
            "获得#{exp}点经验、#{pot}点潜能、#{score}点阅历、10两白银。\n" <>
            "这是你这一轮完成的第#{new_count}个宝镜任务。\n"
    })
    |> prompt(CommandView, "prompt", %{})
  end

  defp remove_item(conn, character, item_instance) do
    new_inventory = Enum.reject(character.inventory, fn inst -> inst.id == item_instance.id end)
    conn |> put_character(%{character | inventory: new_inventory})
  end

  defp add_exp(conn, character, exp) do
    new_stats = Map.put(character.meta.stats, :combat_exp, character.meta.stats.combat_exp + exp)
    conn |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
  end

  defp add_pot(conn, character, pot) do
    limit = Map.get(character.meta.stats, :potential_limit, 10000)
    current = character.meta.stats.potential
    new_pot = min(current + pot, limit)
    new_stats = Map.put(character.meta.stats, :potential, new_pot)
    conn |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
  end

  defp add_score(conn, character, score) do
    new_stats = Map.put(character.meta.stats, :score, character.meta.stats.score + score)
    conn |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
  end

  defp give_silver(conn, character, amount) do
    new_stats = Map.put(character.meta.stats, :silver, (Map.get(character.meta.stats, :silver, 0) + amount))
    conn |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
  end

  defp update_mirror_count(conn, character, count) do
    new_stats = Map.put(character.meta.stats, :mirror_count, count)
    conn |> put_character(%{character | meta: %{character.meta | stats: new_stats}})
  end

  defp check_milestone_reward(conn, character, count) do
    gift_id = case count do
      100 -> random_gift(["liuxi:gift/perwan", "liuxi:gift/kardan", "liuxi:etc/prize4", "liuxi:etc/prize5"])
      200 -> random_gift(["liuxi:gift/str2", "liuxi:gift/int2", "liuxi:gift/con2", "liuxi:gift/dex2"])
      300 -> random_gift(["liuxi:gift/str3", "liuxi:gift/int3", "liuxi:gift/con3", "liuxi:gift/dex3"])
      400 -> random_gift(["liuxi:item/xuantie", "liuxi:etc/bipo", "liuxi:etc/huanshi", "liuxi:etc/binghuozhu", "liuxi:etc/leishenzhu"])
      500 -> random_gift(["liuxi:obj/guo", "liuxi:max/xuanhuang", "liuxi:max/longjia"])
      _ -> nil
    end

    if gift_id do
      case Kantele.World.Story.Gift.drop_to_random_room(gift_id, "一#{Map.get(Items.get!(gift_id).meta, "unit", "个")}#{Items.get!(gift_id).name}从天而降！", fn _ -> true end) do
        {:ok, _player} -> :ok
        _ -> :ok
      end
    end

    conn
  end

  defp random_gift(list) do
    Enum.random(list)
  end

  # 按 数量 前缀：`give 2 包子 to 人`。数量项本期简化为整物转移（数量拆分留待后续）。
  defp find_item(conn, item_spec) do
    item_name = strip_qty(item_spec)

    Enum.find(conn.character.inventory, fn instance ->
      item = Items.get!(instance.item_id)

      instance.id == item_name || item.callback_module.matches?(item, item_name)
    end)
  rescue
    _ -> nil
  end

  defp strip_qty(item_spec) do
    case Integer.parse(String.trim(item_spec)) do
      {_qty, rest} when rest != "" -> String.trim(rest)
      _ -> item_spec
    end
  end

  # 已装备物品不能赠送：装备快照没有 instance id，按名称比对（LPC equipped worn/wielded）
  defp equipped?(conn, item_instance) do
    item = Items.get!(item_instance.item_id)
    character = conn.private.update_character || conn.character

    character.meta.combat.equipped
    |> Enum.any?(fn {_slot, snap} -> Map.get(snap, :name) == item.name end)
  end
end
