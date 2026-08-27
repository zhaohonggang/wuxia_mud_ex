defmodule Kantele.Character.GiveCommand do
  @moduledoc """
  赠送命令：`give <物品> to <人>` / `give <人> <物品>` / `give all to <人>` / `give <数量> <物品> to <人>`

  物品在自己的背包里找（按 name 或 instance id 匹配），校验不可装备/已装备后
  发 `room/give` 事件，由房间解析目标并把物品实例转交给对方进程；本进程在收到
  `give/result` 确认后再从自己背包移除物品并落盘。

  参数按空格切开后手工归类（兼容 LPC 的 `item to target` 与 `target item` 两种顺序）：
  - 含 ` to ` → 其前为物品（可带 `数量 前缀`），其后为目标
  - 否则 → 首词为目标，其余为物品
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

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
