defmodule Kantele.Combat.Skills.Performs.QiankunDanuoyi.Nuoyi do
  @moduledoc """
  perform「nuoyi」（source qiankun-danuoyi/nuoyi.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "qiankun-danuoyi/nuoyi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qiankun-danuoyi")
    der = 0
    i = 0

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          rng: rng
        }
      })

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
      Stats.skill(stats, "qiankun-danuoyi") < 50 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 400 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 350}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}

    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "这里没有可供攻击的对手。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  # TODO(migrate) 目标侧结算：命中/闪避/伤害公式与文案需按原始源码（见文末）补齐。
  #   target->receive_damage("qi", damage / 2)  # UNSUPPORTED: unknown ident damage
  #   target->receive_wound("qi", damage / 2)  # UNSUPPORTED: unknown ident damage

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    _stats = character.meta.stats
    vitals = character.meta.vitals
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 350, 2)
    result = Messages.interpolate("结果$p一招击出，正好打在自己的要害上，不禁一声惨叫，摔跌开去。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-350"}], "assign_refs": [{"ap", "force"}, {"dp", "force"}, {"level", "qiankun-danuoyi"}], "busy_lines": ["me->start_busy(2);", "if (! der->is_busy()) der->start_busy(1);"], "level_gates": [{"qiankun-danuoyi", "50"}], "remote_damage": false, "resource_gates": [{"neili", "400"}], "var_gates": [{"i", "2"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // nuoyi.c 大挪移
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     // object weapon;
  #   object *obs;
  #   object der;
  #     string msg;
  #   int ap, dp;
  #   int damage;
  #   int level;
  #   int i;
  # 
  #   me->clean_up_enemy();
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #         return notify_fail("「大挪移」只能对战斗中的对手使用。\n");
  # 
  #     if ((level = (int)me->query_skill("qiankun-danuoyi", 1)) < 50)
  #         return notify_fail("你的乾坤大挪移还没有修炼到第二层，无法施展大挪移。\n");
  # 
  #         if (me->query("neili") < 400)
  #                 return notify_fail("你现在真气不够，无法使用「大挪移」。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIM "$N" HIM "招数忽然的一变，摹可明方，内力四处回旋，无形中牵引着$n"
  #               HIM "的招式！\n";
  # 
  #         ap = level + me->query_skill("force") * 2 / 3;
  #         dp = target->query_skill("force") * 2 / 3 +
  #              target->query_skill("dodge", 1);
  #         if (level >= 300)
  #         {
  #                 // layer 7 force
  #                 ap += level;
  #         }
  # 
  #         if (ultrap(target))
  #                 dp += target->query_skill("matrial-cognize", 1);
  # 
  #         der = 0;
  #         me->start_busy(2);
  #         me->add("neili", -350);
  #         if (ap / 3 + random(ap / 3) > dp)
  #         {
  #                 // Success to make the target attack hiself
  #                 msg += HIR "结果$p" HIR "一招击出，正好打在自己的"
  #                        "要害上，不禁一声惨叫，摔跌开去。\n" NOR;
  #                 damage = target->query("max_qi");
  #                 target->receive_damage("qi", damage / 2, me);
  #                 target->receive_wound("qi", damage / 2, me);
  #         } else
  #         if (ap / 3 + random(ap) < dp)
  #         {
  #                 // The enemy has defense
  #                 msg += CYN "然而$p" CYN "内功深厚，并没有被$P"
  #                        CYN "这巧妙的劲力所带动。\n" CYN;
  #         } else
  #         if (sizeof(obs = me->query_enemy() - ({ target })) == 0)
  #         {
  #                 // No other enemy
  #                 msg += HIC "结果$p" HIC "的招式莫名其妙的变"
  #                        "了方向，竟然控制不住！幸好身边没有别"
  #                        "人，没有酿成大祸。\n" NOR;
  #         } else
  #         {
  #                 string name;
  #                 // Sucess to make the target attack my enemy
  #                 der = obs[random(sizeof(obs))];
  #                 name = der->name();
  #                 if (name == target->name()) name = "另一个" + name;
  #                 msg += HIG "结果$p" HIG "发出的招式不由自主"
  #                        "的变了方向，突然攻向" + name + HIG "，不禁令" +
  #                        name + HIG "大吃一惊，招架不迭！" NOR;
  #         }
  # 
  #     message_combatd(msg, me, target);
  # 
  #         if (der)
  #         {
  #                 // Target attack my enemy
  #                 for (i = 0; i < 2 + random(3); i++)
  #                 {
  #                         if (! der->is_busy()) der->start_busy(1);
  #                         COMBAT_D->do_attack(target, der, target->query_temp("weapon"));
  #                 }
  #         }
  # 
  #     return 1;
  # }
end
