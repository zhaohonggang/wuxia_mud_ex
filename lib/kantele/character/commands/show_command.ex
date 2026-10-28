defmodule Kantele.Character.ShowCommand do
  @moduledoc """
  展示原料估价命令：`show <材料>`

  对应 LPC moye.c 的 `do_show`：玩家把锻造原料拿给莫邪看，莫邪估算锻造所需黄金。

  LPC 流程（moye.c:193-244，忠实移植）：
    - 无参数 → notify_fail "你想干什么呢？"
    - present(mat, me) 找不到 → "算了吧，你身上没有 X 这种东西。"
    - id == "qiankun stone" → 乾坤袋专用提示（见 §6 偏差：S4 乾坤袋分支，本切片暂不处理）
    - !material_attrib → "这种东西也能用来炼制，我没听说过。"
    - !power_point → "这样原料看来已经是锻造不了了。"
    - value = power_point*2 + 20
        → "这种原料打造道具，只需要 X 两黄金。要是没有问题，请给我原料并付钱。"

  门控说明：LPC 中 `show` 是注册在莫邪 NPC 上的动作（add_action("do_show","show")），
  玩家总在莫邪身边使用。本切片忠实实现估价三路；莫邪「在场」门控随 S1b 的给物议价
  流程自然成立（给物即隐含莫邪在场），此处不另加独立门控，避免与 S1b 重复。
  乾坤袋（qiankun stone）分支按计划 §3 S4 处理，本切片先给通用锻造提示兜底。
  """
  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.World.Items

  def run(conn, %{"rest" => arg}) do
    mat = String.trim(arg || "")

    cond do
      mat == "" ->
        fail(conn, "你想干什么呢？\n")

      true ->
        do_show(conn, mat)
    end
  end

  def run(conn, %{}), do: fail(conn, "你想干什么呢？\n")
  def run_bare(conn, %{}), do: run(conn, %{})

  defp do_show(conn, mat) do
    character = conn.character

    case find_item(character, mat) do
      nil ->
        fail(conn, "算了吧，你身上没有 #{mat} 这种东西。\n")

      inst ->
        item = Items.get!(inst.item_id)
        meta = item.meta

        cond do
          is_nil(meta.material_attrib) ->
            moye_say(conn, "这种东西也能用来炼制，我没听说过。\n")

          (meta.power_point || 0) == 0 ->
            moye_say(conn, "这样原料看来已经是锻造不了了。\n")

          true ->
            value = (meta.power_point || 0) * 2 + 20
            moye_say(conn, "这种原料打造道具，只需要 #{value} 两黄金。要是没有问题，请给我原料并付钱。\n")
        end
    end
  end

  defp find_item(character, name) do
    Enum.find(character.inventory, fn inst ->
      item = Items.get!(inst.item_id)
      item.callback_module.matches?(item, name)
    end)
  end

  # 莫邪对玩家说话（LPC message_vision("$N 对 $n 说道：...")，$N=莫邪，$n=玩家）。
  # S1a 仅做估价，直接送达玩家；S1b 接入真实房间 vision 时再改为房间广播。
  defp moye_say(conn, text) do
    conn
    |> render(CommandView, "text", %{text: "莫邪对你说道：" <> text})
    |> prompt(CommandView, "prompt", %{})
  end

  defp fail(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end
end
