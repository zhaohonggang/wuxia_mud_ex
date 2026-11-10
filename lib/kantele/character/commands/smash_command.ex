defmodule Kantele.Character.SmashCommand do
  @moduledoc """
  雷劈命令：`smash`（对应 LPC `cmds/arch/smash.c`）。

  指令格式：`smash <生物>`

  一道闪电从天而降劈中目标并令其死亡。LPC 的查找顺序为
  `present(arg, environment(me))` → `find_player` → `find_living` → `find_object`；
  本端口通过 `smash/strike` 房间事件在**同房间**按名字找目标，再由
  `character/smitten` 事件让目标进程自己执行 `Damage.die/1`
  （`smash_event.ex`，含 R24 `ensure_death_state` 兜底）。

  门控：巫师（`WizArch.guard`）+ arch 权限（`Access.archwizp`，对应 LPC
  `SECURITY_D->valid_grant(me, "(arch)")`）。LPC 还比较 `wiz_level(me)` 与
  `wiz_level(ob)`，等级不足则「身上冒着缕缕青烟，却没有半点事情」——本端口
  在房间事件里做同一比较（见 `Room.SmashStrikeEvent`）。

  自劈：LPC 允许 `ob == me`（「活得不耐烦，用雷把自己劈死了」），本端口保留。

  与 LPC 的已知差异：无 `query_site_privilege("smash")` 的 `npc`/`all` 分档，
  不跨房间 `find_player`/`find_living`，非角色对象的 `destruct()` 亦未建模。
  """

  use Kalevala.Character.Command

  alias Kantele.Admin.Access
  alias Kantele.Character.CommandView
  alias Kantele.Character.Commands.WizArch

  def run(conn, params) do
    WizArch.guard(conn, params, fn conn, params ->
      do_smash(conn, Map.get(params, "rest", ""))
    end)
  end

  defp do_smash(conn, rest) do
    unless Access.archwizp(conn.character) do
      reply(conn, "只有 arch 巫师（及以上）可以施展雷劈。")
    else
      case String.trim(rest) do
        "" ->
          reply(conn, "指令格式：smash <生物>")

        target_name ->
          strike(conn, target_name)
      end
    end
  end

  defp strike(conn, target_name) do
    me = conn.character

    die_reason =
      if target_name == me.name do
        "活得不耐烦，用雷把自己劈死了"
      else
        "被#{me.name}用雷劈死了"
      end

    conn =
      event(conn, "smash/strike", %{
        target_name: target_name,
        smiter_name: me.name,
        smiter_level: Access.wiz_level(me),
        die_reason: die_reason
      })

    reply(conn, "一道闪电从天而降，直落而下正正劈中#{target_name}！\n")
  end

  defp reply(conn, text) do
    conn
    |> render(CommandView, "text", %{text: if(String.ends_with?(text, "\n"), do: text, else: text <> "\n")})
    |> prompt(CommandView, "prompt", %{})
  end
end
