defmodule ExKantele.World.NameGenerator do
  @moduledoc """
  中文姓名生成器（对照 lpc_example/class_npc/generate/chinese.c）

  结论：**框架工具**，单文件可直落但属“工具/服务”而非世界数据。
  该文件是只为“随机生成中文NPC姓名”服务的类（inherit 给将相/花名用），
  在 Kalevala 对应一个纯函数模块（无副作用），放 lib/ 下即可，
  不属于战斗/房间/物品任何一类，也不拖带底层改动。
  """

  @surnames ["赵", "钱", "孙", "李", "周", "吴", "郑", "王", "冯", "陈"]
  @given ["", "无", "逍遥", "远", "青", "别鹤", "孤鸿", "惊云"]

  def random_name(rng \\ &:rand.uniform/1) do
    pick(@surnames, rng) <> pick(@given, rng)
  end

  defp pick(list, rng), do: Enum.at(list, rng.(length(list)) - 1)

  @note "纯函数，直接可直落为 Kantele.World.NameGenerator；无需底层改动"
end
