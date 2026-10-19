defmodule Kantele.World.ItemActions.Read do
  @moduledoc """
  书册 `read` 动作（第十二批，物品动作通道）。

  对应 LPC `do_read`——全库 4 个实现逐字同构（`d/city/npc/shanzi/shan-book.c`
  与 `d/hengyang/yueqi/{huxian,yueqi,yuepu}-book.c`）：

      void init() { add_action("do_read", "read"); }

      int do_read(string arg)
      {
              if (arg == "shanshang book" || arg == "shanshang" || arg == "book")
                      return notify_fail("……长文案……");
      }

  ## 语义

  - `arg` 命中该书 id 表（LPC `set_name` 的 id 数组 = UCL `aliases`）→
    `notify_fail` 打印长文案（只给玩家，不广播）。Kantele 侧文案已由
    `scripts/backfill_item_actions.py` 回填为物品 `meta.read_text`
    （LPC 反转义 + 换行折空格，同世界数据管线惯例）。
  - `arg` 不命中 → LPC 函数穿底返回 nil = `return 0` → 分发器尝试下一个
    候选书册；全部落空则放行全局命令（本世界无全局 `read`，最终是
    「什么？」）。

  泛型实现：任何带 `meta.read_text` 的回填书册均可读，无需逐个注册。
  """
  use Kantele.World.ItemAction

  alias Kantele.World.Item
  alias Kantele.World.RoomActions.Helpers, as: RoomHelpers

  @impl true
  def run(conn, %{trailing: trailing, item: item}) do
    case read_text(item) do
      text when is_binary(text) ->
        if trailing != "" and Item.matches?(item, trailing) do
          # LPC notify_fail 的文案自带首尾换行（回填时被 strip），补一个收尾
          render(conn, text <> "\n")
        else
          :not_handled
        end

      _ ->
        :not_handled
    end
  end

  defp read_text(item) do
    case Map.get(item.meta || %{}, :read_text) do
      text when is_binary(text) and text != "" -> text
      _ -> nil
    end
  end

  defp render(conn, text), do: RoomHelpers.render_to_player(conn, text)
end
