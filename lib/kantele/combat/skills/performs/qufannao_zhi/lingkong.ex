defmodule Kantele.Combat.Skills.Performs.QufannaoZhi.Lingkong do
  @moduledoc """
  perform「凌空指穴」（source qufannao-zhi/lingkong.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "qufannao-zhi/lingkong"
  @move_name "「凌空指穴」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "qufannao-zhi")
    # ap = force + finger + qufannao-zhi + neili/50
    ap =
      Stats.skill(stats, "force") +
        Stats.skill(stats, "finger") +
        Stats.skill(stats, "qufannao-zhi") +
        div(character.meta.vitals.neili, 50)

    # damage = qufannao-zhi / 2 + random(qufannao-zhi)
    zhi = Stats.skill(stats, "qufannao-zhi")
    damage = div(zhi, 2) + Engine.rand(rng, zhi)

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          ap: ap,
          damage: damage,
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
         :ok <- check_resources(character),
         :ok <- check_weapon(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "qufannao-zhi") < 100 -> {:error, "你的去烦恼指不够娴熟，不会使用#{@move_name}。\n"}
      Stats.skill(stats, "hunyuan-yiqi") < 100 -> {:error, "你的心意气混元功不够高，不能用内力催动指力伤敌。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "你现在内力太弱，不能使用#{@move_name}。\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      Combat.weapon(combat) != nil -> {:error, "你必须空手才能使用#{@move_name}！\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # 前置广播：本招无无条件消耗/Busy，命中/未中分支的消耗与忙乱由反馈回传攻击方
    conn = Broadcast.publish(conn, "$N默念佛经，只见手指微动，几道指气急射向$n，意欲以指力击晕$n。", n1: character.name)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「凌空指穴」只能对战斗中的对手使用。\n"}
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = Engine.rand(rng, ap) + Engine.rand(rng, div(ap, 3)) > dp

    if hit do
      vitals = character.meta.vitals
      vitals = Vitals.damage(vitals, :qi, damage)
      vitals = Vitals.wound(vitals, :qi, div(damage, 6))
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # 攻击方：start_busy(3) + add("neili", -damage/6)
      Performs.feedback(attacker, div(damage, 6), 3)
      # 目标：start_busy(random(3))
      character = %{
        character
        | meta:
            Map.put(
              character.meta,
              :combat,
              Combat.start_busy(character.meta.combat, Engine.rand(rng, 3))
            )
      }

      msg =
        cond do
          damage < 100 -> "$n受到$N的指力透击，闷哼一声，看上去很是疲惫。"
          damage < 300 -> "$n被$N的指力反击，只觉得胸中烦闷，只想好好休息休息。"
          damage < 500 -> "$n被$N以指力一震，脑中嗡嗡作响，意识开始模糊起来！"
          true -> "$n被$N的指力一震，眼前一黑，向后便倒，眼看就要不醒人事了！"
        end

      result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    else
      # 攻击方：start_busy(4)
      Performs.feedback(attacker, 0, 4)
      result = Messages.interpolate("可是$p看破了$P的企图，并没有上当。", n1: attacker.name, n2: character.name)

      conn
      |> Broadcast.publish(result)
      |> put_character(character)
    end
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"assign_refs": [{"ap", "force"}, {"damage", "qufannao-zhi"}, {"dp", "force"}], "busy_lines": ["me->start_busy(3);", "target->start_busy(random(3));", "me->start_busy(4);"], "level_gates": [{"hunyuan-yiqi", "100"}, {"qufannao-zhi", "100"}], "remote_damage": false, "resource_gates": [{"neili", "300"}], "var_gates": [{"damage", "100"}, {"damage", "300"}, {"damage", "500"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // lingkong
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # #define LING "「" HIW "凌空指穴" NOR "」" 
  # 
  # int perform(object me, object target)
  # {
  #         int damage;
  #         string msg;
  #         int ap, dp;
  # 
  #         //if (userp(me) && ! me->query("can_perform/qufannao-zhi/lingkong"))   
  #         //        return notify_fail("你所使用的外功中没有这种功能。\n");   
  # 
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target || !target->is_character() || !me->is_fighting(target) )
  #                 return notify_fail(LING "只能对战斗中的对手使用。\n");
  # 
  #         if( objectp(me->query_temp("weapon")) )
  #                 return notify_fail("你必须空手才能使用" LING "！\n");           
  # 
  #         if( (int)me->query_skill("qufannao-zhi", 1) < 100 )
  #                 return notify_fail("你的去烦恼指不够娴熟，不会使用" LING "。\n");
  # 
  #         if( (int)me->query_skill("hunyuan-yiqi", 1) < 100 )
  #                 return notify_fail("你的心意气混元功不够高，不能用内力催动指力伤敌。\n");
  # 
  #         if( (int)me->query("neili", 1) < 300 )
  #                 return notify_fail("你现在内力太弱，不能使用" LING "。\n");
  # 
  #         msg = CYN "$N默念佛经，只见手指微动，几道指气急射向$n，意欲以指力击晕$n。\n"NOR;
  # 
  #         ap = me->query_skill("force", 1) + me->query_skill("finger", 1) + 
  #              me->query_skill("qufannao-zhi", 1) + me->query("neili", 1) / 50;
  #         dp = target->query_skill("force", 1) + target->query_skill("dodge", 1) +
  #              target->query_skill("parry", 1);
  #         if (random(ap) + random(ap / 3) > dp )
  #         {
  #                 me->start_busy(3);
  #                 target->start_busy(random(3));
  #                 
  #                 damage = (int)me->query_skill("qufannao-zhi", 1);
  #                 
  #                 damage = damage / 2 + random(damage);
  #                 
  #                 target->receive_damage("qi", damage);
  #                 target->receive_wound("qi", damage / 6);
  #                 me->add("neili", -damage / 6);
  #                 
  #                 if( damage < 100 )
  #                         msg += HIY "$n受到$N的指力透击，闷哼一声，看上去很是疲惫。\n" NOR;
  #                 
  #                 else if( damage < 300 )
  #                         msg += HIY "$n被$N的指力反击，只觉得胸中烦闷，只想好好休息休息。\n" NOR;
  #         
  #                 else if( damage < 500 )
  #                         msg += RED "$n被$N以指力一震，脑中嗡嗡作响，意识开始模糊起来！\n" NOR;
  #                 else
  #                         msg += HIR "$n被$N的指力一震，眼前一黑，向后便倒，眼看就要不醒人事了！\n" NOR;
  #                 
  #         }
  #         else 
  #         {
  #                 me->start_busy(4);
  #                 msg += CYN "可是$p看破了$P的企图，并没有上当。\n" NOR;
  #         }
  #         message_vision(msg, me, target);
  # 
  #         return 1;
  # }
end
