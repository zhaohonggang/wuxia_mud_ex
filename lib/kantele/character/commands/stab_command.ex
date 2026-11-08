defmodule Kantele.Character.StabCommand do
  @moduledoc """
  插命令：`stab <物品>`（LPC `cmds/std/stab.c`）。

  LPC 全文不过 30 行，三道门 + 一次 `obj->do_stab(me)`：

  1. 无参数 → `你要用什么物品？`
  2. `present(arg, me)` 在**背包**里找不到 → `你身上没有这样东西。`
  3. 先设 `notify_fail("你翻来复去的弄了一会儿，也没能折腾好X。")`，再调
     `obj->do_stab(me)`；物品没有该方法 / 方法 `return 0` 时这句兜底生效。

  第 3 步的 Ex 映射见 `Kantele.Character.ItemUse.dispatch/7`：物品
  `meta.actions` 里注册了 `do_stab` 类 handler 就执行，否则渲染兜底文案。
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
        reject(conn, "你要用什么物品？\n")

      true ->
        case ItemUse.find_in_inventory(conn, arg) do
          nil ->
            reject(conn, "你身上没有这样东西。\n")

          {item, instance} ->
            ItemUse.dispatch(
              conn,
              item,
              instance,
              "do_stab",
              "stab",
              arg,
              "你翻来复去的弄了一会儿，也没能折腾好#{item.name}。\n"
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
