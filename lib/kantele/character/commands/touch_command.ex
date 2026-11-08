defmodule Kantele.Character.TouchCommand do
  @moduledoc """
  触摸命令：`touch <物品>`（LPC `cmds/std/touch.c`）。

  LPC 门控顺序：

  1. 无参数 → `你要触摸什么物品？`
  2. `present(arg, me)` 与 `present(arg, environment(me))` 都找不到 →
     `你身上没有这样东西，附近也没有。`
  3. 找到的是人物 → `你别乱动X了。`
  4. 先设 `notify_fail("你摸了一下X。")`，再调 `obj->do_touch(me)`；
     没有该方法 / `return 0` 时这句兜底生效。

  与 `stab.c` 的差别是取物范围包含**当前房间**（地上的物品 + NPC），
  见 `Kantele.Character.ItemUse.find_present/2`。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.ItemUse

  def run(conn, params) do
    arg =
      params
      |> Map.get("rest", "")
      |> to_string()
      |> String.trim()

    cond do
      arg == "" ->
        reject(conn, "你要触摸什么物品？\n")

      true ->
        case ItemUse.find_present(conn, arg) do
          nil ->
            reject(conn, "你身上没有这样东西，附近也没有。\n")

          {:character, npc} ->
            reject(conn, "你别乱动#{Map.get(npc, :name)}了。\n")

          {:item, item, instance} ->
            ItemUse.dispatch(
              conn,
              item,
              instance,
              "do_touch",
              "touch",
              arg,
              "你摸了一下#{item.name}。\n"
            )
        end
    end
  end

  defp reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
