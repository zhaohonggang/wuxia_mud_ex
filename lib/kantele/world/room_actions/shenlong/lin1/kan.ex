defmodule Kantele.World.RoomActions.Shenlong.Lin1.Kan do
  @moduledoc """
  神龙教林间（`d/shenlong/lin1.c`）的 `do_kan`（`add_action("do_kan","kan")`）。

  砍灌木开路：`kan bush`，须**手持刀/剑**。内力 > 100 才砍得开（扣 50），
  开 `north`→`shenlong:lin2`，20 秒后灌木合拢自动关；内力不足则砍不动并把内力清零。

  LPC 原文：

      if (arg != "bush") return notify_fail("你要砍什么？\\n");
      if (! objectp(weapon = me->query_temp("weapon")))
          return notify_fail("不用武器恐怕不行吧！\\n");
      if (weapon->query("skill_type") != "blade" && != "sword")
          return notify_fail(weapon->name() + "也能用来砍东西？\\n");
      message_vision("$N抽出兵刃，对着灌木丛就是一阵乱砍。\\n", me);
      if (me->query("neili") > 100) {
          set("exits/north", __DIR__"lin2");
          message_vision("$N累得气喘吁吁,终于砍出一条小路。\\n", me);
          me->add("neili", -50);
          remove_call_out("close"); call_out("close", 20);
      } else {
          message_vision("$N累得气喘吁吁,也没砍开一条路来。\\n", me);
          me->set("neili", 0);
      }

  注意本 verb 会覆盖同名全局命令 `kan`（看）——与 LPC `add_action` 优先于全局
  命令的语义一致；错词时给「你要砍什么？」而不是落到全局 `kan`。
  """
  use Kantele.World.RoomAction

  alias Kantele.World.RoomActions.Trigger

  @self_room "shenlong:lin1"
  @target_room "shenlong:lin2"
  @dir "north"
  @neili_gate 100
  @neili_cost 50
  @close_seconds 20

  @what "你要砍什么？\n"
  @no_weapon "不用武器恐怕不行吧！\n"
  @wrong_weapon_tpl "%s也能用来砍东西？\n"
  @chopping "$N抽出兵刃，对着灌木丛就是一阵乱砍。\n"
  @cut_open "$N累得气喘吁吁,终于砍出一条小路。\n"
  @cut_fail "$N累得气喘吁吁,也没砍开一条路来。\n"
  @close_msg "灌木丛渐渐合拢起来,终于又恢复了原状。\n"

  @impl true
  def run(conn, %{trailing: arg}) do
    char = Trigger.current(conn)

    cond do
      String.trim(arg) != "bush" ->
        Trigger.render(conn, @what)

      Trigger.weapon_skill_type(char) == nil ->
        Trigger.render(conn, @no_weapon)

      Trigger.weapon_skill_type(char) not in ["blade", "sword"] ->
        Trigger.render(conn, String.replace(@wrong_weapon_tpl, "%s", Trigger.weapon_name(char) || ""))

      true ->
        chop(conn, char)
    end
  end

  defp chop(conn, char) do
    conn = Trigger.broadcast(conn, @self_room, @chopping)

    if Trigger.neili(char) > @neili_gate do
      conn
      |> Trigger.deduct_neili(@neili_cost)
      |> Trigger.reveal(@self_room, @dir, @target_room, @cut_open, @close_msg, @close_seconds)
    else
      conn
      |> Trigger.broadcast(@self_room, @cut_fail)
      |> Trigger.set_neili(0)
    end
  end
end
