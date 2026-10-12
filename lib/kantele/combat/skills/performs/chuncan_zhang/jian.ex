defmodule Kantele.Combat.Skills.Performs.ChuncanZhang.Jian do
  @moduledoc """
  perform「作茧自缚」（source chuncan-zhang/jian.c，inherit F_CLEAN_UP + F_SSERVER）

  自我增益：门槛（按 .c 顺序）已学此招 → 未在运行本招 → 春蚕掌法>=80 →
  内功>=120 → 内力上限>=800 → 激发 strike 为春蚕掌法 → 准备春蚕掌法 →
  真气>=200。扣 150 真气；`attack -skill/4`、`dodge +skill/3`，持续
  `skill/2` 秒，到期由 `combat/buff-expire` 回收；战斗中忙乱 2。

  差异（TODO(migrate)）：
  - `.c` 的 `set_temp("ccz_jian")` 临时标记由引擎 buff（key `"ccz_jian"`）承担；
  - `.c` 的 `remove_effect(me, skill/4, skill/3)` 与施加值互为镜像
    （attack `-skill/4` ↔ `+skill/4`、dodge `+skill/3` ↔ `-skill/3`），
    引擎 `Buff.applies` 精确抵消，行为一致；
  - `.c` 的 `query_skill_prepared("strike") == "chuncan-zhang"` 由
    `perform` 命令的 D4 预备校验按 `spec.id` 精确把关（本 spec 只校验「已预备」）。

  实现方式：声明式 `Performs.Simple` spec（同 `jingang_buhuaiti/jingang.ex`）。
  """

  @move_name "「作茧自缚」"

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "chuncan-zhang/jian",
      kind: :perform,
      gates: [
        {:perform_known, "chuncan-zhang/jian", "你所使用的外功中没有这种功能。\n"},
        {:no_buff, "ccz_jian", "你已经运起#{@move_name}了。\n"},
        {:skill_min, "chuncan-zhang", 80, "你的春蚕掌法不够娴熟，难以施展#{@move_name}。\n"},
        {:skill_min, "force", 120, "你的内功火候不够，难以施展#{@move_name}。\n"},
        {:max_neili_min, 800, "你的内力修为不够，难以施展#{@move_name}。\n"},
        {:mapped, "strike", "chuncan-zhang", "你没有激发春蚕掌法，难以施展#{@move_name}。\n"},
        {:prepared, "strike", "你没有准备春蚕掌法，难以施展#{@move_name}。\n"},
        {:neili_min, 200, "你的真气不够，难以施展#{@move_name}。\n"}
      ],
      costs: %{neili: 150},
      effects: [
        {:buff, "ccz_jian",
         %{
           attack: {:sub, 0, {:div, {:skill, "chuncan-zhang"}, 4}},
           dodge: {:div, {:skill, "chuncan-zhang"}, 3}
         }}
      ],
      busy: {:if_fighting, 2},
      duration: {:div, {:skill, "chuncan-zhang"}, 2},
      expire_message: "你的#{@move_name}运行完毕，将内力收回丹田。\n",
      message: "$N凝聚内力，掌劲吞吐，顿时双掌掀起一层气劲，护住周身经脉。\n\n"
    }

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # #define JIAN "「" HIW "作茧自缚" NOR "」"
  # 
  # inherit F_CLEAN_UP;
  # inherit F_SSERVER;
  # 
  # void remove_effect(object me, int a_amount, int d_amount);
  # 
  # int perform(object me)
  # {
  # //      object weapon;
  #         int skill;
  #         string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/chuncan-zhang/jian"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if ((int)me->query_temp("ccz_jian"))
  #                 return notify_fail("你已经运起" JIAN "了。\n");
  # 
  #         if ((int)me->query_skill("chuncan-zhang", 1) < 80)
  #                 return notify_fail("你的春蚕掌法不够娴熟，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query_skill("force", 1) < 120)
  #                 return notify_fail("你的内功火候不够，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不够，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_mapped("strike") != "chuncan-zhang")
  #                 return notify_fail("你没有激发春蚕掌法，难以施展" JIAN "。\n");
  # 
  #         if (me->query_skill_prepared("strike") != "chuncan-zhang")
  #                 return notify_fail("你没有准备春蚕掌法，难以施展" JIAN "。\n");
  # 
  #         if ((int)me->query("neili") < 200 )
  #                 return notify_fail("你的真气不够，难以施展" JIAN "。\n");
  # 
  #         msg = HIW "$N" HIW "凝聚内力，掌劲吞吐，顿时双掌掀起一层气劲，护住周身经脉。\n\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         skill = me->query_skill("chuncan-zhang", 1);
  # 
  #         me->add_temp("apply/attack", -skill / 4);
  #         me->add_temp("apply/dodge", skill / 3);
  #         me->set_temp("ccz_jian", 1);
  # 
  #         me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill / 4, skill / 3 :), skill / 2);
  # 
  #         me->add("neili", -150);
  #         if (me->is_fighting()) me->start_busy(2);
  # 
  #         return 1;
  # }
  # 
  # void remove_effect(object me, int a_amount, int d_amount)
  # {
  #         if (me->query_temp("ccz_jian"))
  #         {
  #                 me->add_temp("apply/attack", a_amount);
  #                 me->add_temp("apply/dodge", -d_amount);
  #                 me->delete_temp("ccz_jian");
  #                 tell_object(me, "你的" JIAN "运行完毕，将内力收回丹田。\n");
  #         }
  # }
end
