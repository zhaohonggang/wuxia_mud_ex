defmodule Kantele.World.NpcActions.Choose do
  @moduledoc """
  P5-1e NPC 私有动作：`choose`（宠物店老板选坐骑，`d/city/npc/horseboss.c`
  `do_selete()`，LPC 函数名拼写即如此）。

  仅注册于 `city:zhujuan`（猪院/宠物店，UCL `characters.horseboss` 经
  `room_characters "zhujuan"` 挂入）。

  ## 移植范围（守门分支）

  LPC `do_selete` 的判定链：

  1. `query_skill("training", 1) < 30` → `notify_fail`「你的驭兽术太低了，
     即使养了坐骑，也会离你而去。」
  2. 无 `temp pet/money` → `command("say 这位<respect>，每只宠物一百两黄金！")`
     + `return 1`。
  3. 有 `pet/money` → 写坐骑类型菜单（20 选 1）后 `input_to` 进入
     性别/id/中文名/描述四步定制，`build_pet()` 读 `/clone/npc/pet.c` 模板
     做字符串替换、`write_file` 落盘 `/data/pet/<id>-pet.c` 再 `load_object`
     实例化——整套宠物养成系统，**不可移植**（@todo）。

  ## 关于第 3 分支的死代码性质

  全 LPC 代码库检索 `pet/money` 只有 horseboss.c **读**、没有任何文件**写**
  ——即在原世界该分支也不可达。本模块对「已付钱」状态同样落**静默消费**
  （返回未改动 conn），并在 moduledoc 记录；若未来接入宠物系统，此处补
  菜单与 input_to 流程。

  ## 未建模依赖（@todo）

  - 宠物定制全链（input_to 四步 + 模板落盘 + load_object + whistle 召唤），
    见上。依赖文件系统级 NPC/物品生成，与 Kantele 的世界数据模型不兼容，
    需重新设计（如预置宠物模板 + 存档），不限于「接线」。
  - `query_skill("training", ...)` 的 Kantele 落点是 `stats.skills`
    （世界数据无该技能注册时恒 0 → 守卫恒触发，与「没人学过驭兽术」
    的现状一致）。
  """

  use Kantele.World.NpcAction

  alias Kantele.Character.PlayerMeta
  alias Kantele.World.NpcActions.Helpers

  @room_id "city:zhujuan"
  @npc_name "老板"
  # LPC set_name("老板", ...) —— command("say") 前缀用 NPC 名。
  @training_required 30
  @skill_training "training"

  @impl true
  def run(conn, %{room_id: room_id}) when is_binary(room_id) do
    if room_id == @room_id do
      do_selete(conn)
    else
      :not_handled
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_selete(conn) do
    cond do
      # LPC: query_skill("training", 1) < 30
      skill_level(conn, @skill_training) < @training_required ->
        Helpers.render(conn, "你的驭兽术太低了，即使养了坐骑，也会离你而去。\n")

      # LPC: ! me->query_temp("pet/money")
      blank_temp?(conn, "pet/money") ->
        Helpers.say(conn, @room_id, @npc_name, "这位#{Helpers.respect(conn.character)}，每只宠物一百两黄金！")

      # @todo 宠物定制链不可移植（见 moduledoc）；原世界亦不可达（无人写 pet/money）。
      true ->
        conn
    end
  end

  # stats.skills 读取（先归一化，规避 Stats.skill/2 对 skills: nil 裸 struct 的
  # Map.get(nil) 崩溃，同 txbw.ex）。
  defp skill_level(conn, name) do
    stats = (conn.character.meta || %PlayerMeta{}).stats || %{}
    Map.get(stats, :skills) |> then(&(&1 || %{})) |> Map.get(name, 0)
  end

  defp blank_temp?(conn, key) do
    case Helpers.temp(conn, key) do
      nil -> true
      false -> true
      0 -> true
      "" -> true
      _ -> false
    end
  end
end
