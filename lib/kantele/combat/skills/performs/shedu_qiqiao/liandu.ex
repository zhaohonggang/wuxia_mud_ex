defmodule Kantele.Combat.Skills.Performs.SheduQiqiao.Liandu do
  @moduledoc """
  perform「liandu」（source shedu-qiqiao/liandu.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @perform_id "shedu-qiqiao/liandu"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # TODO(migrate) 门槛由提取器机械生成，文案/查法需按原始源码核对
  defp check_gates(character) do
    with :ok <- check_levels(character),
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "hamagong") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "shedu-qiqiao") < 80 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 200 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 50}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-50"}], "assign_refs": [{"lvl", "poison"}], "busy_lines": ["me->start_busy(random(3));"], "level_gates": [{"hamagong", "80"}, {"shedu-qiqiao", "80"}], "remote_damage": false, "resource_gates": [{"neili", "200"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // liandu.c 毒液练药
  # 
  # #include <ansi.h>
  # #include <skill.h>
  # #include <weapon.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         mapping p;
  #         string msg;
  #         object ob;
  #         int amount;
  #         int exp;
  #         int lvl;
  # //      int sk;
  #         int sk_lvl;
  # 
  #         if (! target)
  #                 return notify_fail("你要取哪条蛇的毒液练药？\n");
  # 
  #         if (! target->is_snake())
  #                 return notify_fail("看清楚些，那不是蛇，你瞎搞什么？\n");
  # 
  #         if (living(target))
  #                 return notify_fail("那条蛇还精神着呢，你找死啊。\n");
  # 
  #         if ((int)me->query_skill("shedu-qiqiao", 1) < 80)
  #                 return notify_fail("你的蛇毒奇巧还不够娴熟，不能炼制毒药。\n");
  # 
  #         //if ((int)me->query_skill("hamagong", 1) < 80)
  #                 //return notify_fail("你的蛤蟆功的修为不够，不能炼制毒药。\n");
  # 
  #         if ((int)me->query("neili") < 200)
  #                 return notify_fail("你现在的内力不够！\n");
  # 
  #         me->add("neili", -50);
  #         me->start_busy(random(3));
  # 
  #         msg = HIC "\n$N" HIC "伸出双指，捏住" + target->name() +
  #               HIC "的嘴巴，以内力迫出毒液练药。\n" NOR;
  # 
  #         p = target->query("snake_poison");
  #         if (! mapp(p))
  #                 return notify_fail("看来你是弄不出什么毒液来了。\n" NOR);
  # 
  #         lvl = (int) me->query_skill("poison", 1) / 2 +
  #               (int) me->query_skill("shedu-qiqiao", 1);
  # 
  #         amount = p["level"] * p["remain"];
  #         if (amount > lvl)
  #                 amount = lvl;
  # 
  #         if (! amount)
  #         {
  #                 msg += WHT "$N" WHT "挤了半天，结果啥也没有挤出来，算是白忙活了。\n\n" NOR;
  #                 message_vision(msg, me);
  #                 return 1;
  #         }
  # 
  #         p["remain"] = (p["level"] * p["remain"] - amount) /
  #                        p["level"];
  #         target->apply_condition("poison-supply", 1);
  # 
  #         if (amount < lvl)
  #         {
  #                 msg += WHT "$N" WHT "挤了一点毒液出来。\n\n" NOR;
  #                 message_vision(msg, me);
  #                 tell_object(me, HIY "可惜这点毒液连练一颗毒药都不够。\n" NOR);
  #                 return 1;
  #         }
  # 
  #         msg += HIM "$N" HIM "将" + target->name() + HIM "的毒液悉数挤"
  #                "出，在内力的作用下化成了一颗晶莹剔透的药丸。\n\n" NOR;
  #         message_vision(msg, me);
  #         tell_object(me, HIC "你炼制了一颗蛇毒药丸。\n" NOR);
  # 
  #         sk_lvl = to_int(pow(to_float(me->query("combat_exp") * 10), 1.0 / 3));
  # 
  #         // improve skill
  #         exp = lvl;
  #         //me->improve_skill("poison", exp + random(exp));
  #         if (me->can_improve_skill("shedu-qiqiao"))
  #                 me->improve_skill("shedu-qiqiao", exp + random(exp));
  # 
  #         //if (me->can_improve_skill("hamagong"))
  #         //        me->improve_skill("hamagong", 2 + random(exp / 6), 1);
  #         if (me->query_skill("poison", 1) < sk_lvl)
  #                 me->improve_skill("poison", (exp + random(exp)) * 3 / 2);
  # 
  #         // create the object
  #         ob = new("/clone/misc/shedu");
  #         ob->set("poison", ([
  #                 "level" : (lvl / 60 * 60),
  #                 "id"    : me->query("id"),
  #                 "name"  : "蛇毒",
  #                 "duration" : 10,
  #         ]));
  #         ob->move(me);
  # 
  #         return 1;
  # }
end
