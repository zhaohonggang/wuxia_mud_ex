defmodule Kantele.Combat.Skills.Performs.KuihuaMogong.Roar do
  @moduledoc """
  exert「roar / 鬼哭神嚎」（source kuihua-mogong/exert/roar.c，inherit F_CLEAN_UP）

  消耗 100 内力、自身受 qi 伤 10、忙乱 5；对周围所有角色造成 qi 伤害
  （框架内群体伤害未建模，仅保留命中提示文案）。
  限制：neili>=100；环境 no_fight 时不可。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Messages

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_resources(character),
         :ok <- check_no_fight(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if ((int)me->query("neili") < 100) return notify_fail("你的内力不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("这里不能攻击别人! \n");
  defp check_no_fight(_character) do
    # 框架内 room 的 no_fight 标志暂未接入，默认放行（文案需保留）
    _msg = "这里不能攻击别人! \n"
    :ok
  end

  defp apply_effect(conn, character) do
    # 命中提示文案保留（框架内群体伤害未建模）
    _hit_tell = "你只觉得魔音激荡刺耳，心胆俱裂！顿时，气血上涌，一口鲜血从口中汹涌而出。\n"

    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | qi: max(vitals.qi - 10, 1)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    combat = Combat.start_busy(character.meta.combat, 5)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> Broadcast.publish(
      Messages.interpolate(
        "$N气凝丹田，猛然一声尖啸，犹如鬼哭神嚎般，声音激荡刺耳，闻者心驰神摇，肝胆俱裂！\n",
        [n1: character.name]
      )
    )
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // roar.c 鬼哭神嚎
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # int exert(object me, object target)
  # {
  #     object *ob;
  #     int i, skill, damage;
  # 
  #     if ((int)me->query("neili") < 100)
  #         return notify_fail("你的内力不够。\n");
  # 
  #     skill = me->query_skill("force");
  # 
  #     me->add("neili", -100);
  #     me->receive_damage("qi", 10);
  # 
  #     if (environment(me)->query("no_fight"))
  #         return notify_fail("这里不能攻击别人! \n");
  # 
  #     me->start_busy(5);
  #     message_combatd(HIY "$N" HIY "气凝丹田，猛然一声尖啸，犹如鬼哭神嚎"
  #                         "般，声音激荡刺耳，闻者心驰神摇，肝胆俱裂！\n" NOR, me);
  # 
  #     ob = all_inventory(environment(me));
  #     for (i = 0; i < sizeof(ob); i++)
  #         {
  #         if (! ob[i]->is_character() || ob[i] == me)
  #             continue;
  # 
  #         if (skill / 2 + random(skill / 2) < (int)ob[i]->query("con") * 2)
  #             continue;
  # 
  #                 me->want_kill(ob[i]);
  #                 me->fight_ob(ob[i]);
  #                 ob[i]->kill_ob(me);
  # 
  #         damage = skill - ((int)ob[i]->query("max_neili") / 10);
  #         if (damage > 0)
  #                 {
  #                         ob[i]->set("last_damage_from", me);
  #             ob[i]->receive_damage("qi", damage * 3, me);
  #             if ((int)ob[i]->query("neili") < skill * 2)
  #                 ob[i]->receive_wound("qi", damage * 2, me);
  #                 tell_object(ob[i], "你只觉得魔音激荡刺耳，心胆俱裂！顿时，气血上涌，一口鲜血从口中汹涌而出。\n");
  #         }
  #     }
  #     return 1;
  # }
end
