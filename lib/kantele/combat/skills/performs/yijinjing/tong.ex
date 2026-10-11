defmodule Kantele.Combat.Skills.Performs.Yijinjing.Tong do
  @moduledoc """
  exert「tong」（source yijinjing/tong.c，由 translate_perform.py 生成，inherit F_CLEAN_UP）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
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
      Stats.skill(stats, "yijinjing") < 100 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 500 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      vitals.max_qi < 10 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 4)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"skill", "yijinjing"}], "busy_lines": ["if (me->is_fighting()) me->start_busy(4);"], "level_gates": [{"yijinjing", "100"}], "remote_damage": false, "resource_gates": [{"max_neili", "500"}, {"max_qi", "10"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // shield.c 易筋经 易筋通脉
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  # 
  # 
  #         //if (me->query("family/family_name") != "少林派")
  #         //        return notify_fail("你不是少林弟子，无法使用“易筋通脉”。\n");
  #         if (userp(me) && ! me->query("can_perform/yijinjing/tong"))
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (target != me)
  #                 return notify_fail("你只能用易筋经来为自己易筋通脉。 \n");
  # 
  #         if ((skill = (int)me->query_skill("yijinjing", 1)) < 100)
  #                 return notify_fail("你的易筋经等级不够。\n");
  # 
  #         if ((int)me->query("eff_qi")*100/(int)me->query("max_qi") > 80)
  #                 return notify_fail("你伤势很轻，不用激励易筋经至高绝学。\n");
  # 
  #         if ((int)me->query("eff_qi")*100/(int)me->query("max_qi") < 10)
  #                 return notify_fail("你内伤太重，无法激励易筋经至高绝学。\n");
  # 
  #         if ((int)me->query("neili") < skill*5 || (int)me->query("max_neili") < 500)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         me->add("neili", -skill*4);
  #         me->receive_damage("qi", 0);
  # 
  #         message_combatd(HIM "$N" HIM "默念易筋经的口诀: "
  #                             "元气,气存于内,放于外。"
  #                             "易筋,孕怀于息,舒于支....\n"
  #                         HIW "一股详和的白色罡气自头顶迅速"
  #                         HIW "游遍" HIW "$N" HIW "的奇经八脉！\n"
  #                         HIC "$N" HIC "的内伤刹那间大为好转！！\n" NOR, me);
  # 
  #         me->add("max_neili", -skill/4);
  # 
  #         me->add("eff_qi",skill*8);
  #         if (me->query("eff_qi") > me->query("max_qi"))
  #                 me->set("eff_qi",me->query("max_qi"));
  #         me->set("qi",me->query("eff_qi"));
  # 
  #         if (me->is_fighting()) me->start_busy(4);
  # 
  #         return 1;
  # }
end
