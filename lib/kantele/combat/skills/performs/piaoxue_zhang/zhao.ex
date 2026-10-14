defmodule Kantele.Combat.Skills.Performs.PiaoxueZhang.Zhao do
  @moduledoc """
  perform「佛光普照」（对照 `kungfu/skill/piaoxue-zhang/zhao.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → **双手皆空** →
  内功>=300 → 飘雪穿云掌>=180 → 真气>=1000 且内力上限>=3500 →
  激发 strike 为飘雪穿云掌 → 准备 strike 为飘雪穿云掌 → **已提起全身功力**
  （`powerup` 加成生效中）→ 目标存活。
  （`.c` 中「激发内功为九阳神功」一段整块被 `/* */` 注释，未启用。）
  起手广播后由目标侧按三分支结算，`ap = 掌法 + 内功 + 膂力*5`、
  `dp = 目标闪避 + 目标内功 + 根骨*5`，`damage = random(ap/2) + ap/2`：
  ① 目标激发 force 为九阳神功 → 攻击方扣 600 真气、忙乱 3，广播
    「江河入海…」文案（**无伤害**）；
  ② 否则 `ap/2 + random(ap) > dp` → 攻击方同样扣 600、忙乱 3，目标受
    `do_damage(UNARMED_ATTACK, damage, 100)`；
  ③ 否则 → 攻击方扣 400 真气、忙乱 4，广播「躲开了这一击！」文案。

  差异（TODO(migrate)）：
  - `ap` 含攻击方 `str`、`dp` 含目标 `con`，故 ap 在攻击方算好经事件 data
    下发，dp 与「目标激发 force 为九阳神功」判定在目标侧完成；
  - 三分支的 neili 消耗/忙乱均为分支相关，经 `Performs.feedback/3` 回授攻击方；
  - `COMBAT_D->do_damage(..., 100, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 100, 100))`；
  - `.c` 三条文案中段各有一个 `\\n`（`向$n\\n全力拍出`、`江河入\\n海`、
    `重\\n重摔在地下`），按原样逐字保留；
  - `query_temp("powerup")` 以 `Combat.buff_active?(combat, "powerup")` 代理
    （同 `chousui_zhang/tao.ex`）；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs

  @perform_id "piaoxue-zhang/zhao"
  @move_name "「佛光普照」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("strike") + me->query_skill("force") + me->query("str") * 5;
    ap =
      Stats.skill(stats, "strike") + Stats.skill(stats, "force") +
        Stats.query_str(stats) * 5

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_resources(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_powerup(character),
         :ok <- check_target_alive(target) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          ap: ap,
          rng: rng
        }
      })

      apply_effect(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/piaoxue-zhang/zhao"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) target = offensive_target(me);
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  defp check_weapon(combat) do
    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "你必须空手才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill("force") < 300)
  #      if (me->query_skill("piaoxue-zhang", 1) < 180)
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 300 ->
        {:error, "你的内功的修为不够，无法施展#{@move_name}。\n"}

      Stats.skill(stats, "piaoxue-zhang") < 180 ->
        {:error, "你的飘雪穿云掌修为不够，无法施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query("neili") < 1000 || me->query("max_neili") < 3500)
  defp check_resources(character) do
    vitals = character.meta.vitals

    if vitals.neili < 1000 or vitals.max_neili < 3500 do
      {:error, "你的真气不够，无法施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("strike") != "piaoxue-zhang")
  #      （.c 中「激发内功为九阳神功」整块被 /* */ 注释，未启用）
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "strike") == "piaoxue-zhang" do
      :ok
    else
      {:error, "你没有激发飘雪穿云掌，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("strike") != "piaoxue-zhang")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "strike")

    if prepared != nil and hd(String.split(prepared, "/")) == "piaoxue-zhang" do
      :ok
    else
      {:error, "你没有准备飘雪穿云掌，无法施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! me->query_temp("powerup"))
  #              return notify_fail("你必须将全身功力尽数提起才能施展" ZHAO "。\n");
  defp check_powerup(character) do
    if Combat.buff_active?(character.meta.combat, "powerup") do
      :ok
    else
      {:error, "你必须将全身功力尽数提起才能施展#{@move_name}。\n"}
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 敌人列表只存引用快照（%{id,pid,name,room_id}）时无 meta 可查，此时恒判存活，
  # 由目标侧 combat/perform-incoming 的死亡检查兜底。
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_effect(conn, character, target) do
    # LPC: msg = HIY "$N" HIY "运起全身功力，顿时真气迸发，全身骨骼噼啪作"
    #            "响，猛然一掌向$n" HIY "\n全力拍出，力求一击毙敌，正是一"
    #            "招「佛光普照」。\n" NOR;
    #      三分支的 neili / busy / do_damage 均在目标侧结算。
    conn =
      Broadcast.publish(
        conn,
        "$N运起全身功力，顿时真气迸发，全身骨骼噼啪作响，猛然一掌向$n\n全力拍出，力求一击毙敌，正是一招「佛光普照」。\n",
        n1: character.name,
        n2: target.name
      )

    put_character(conn, character)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    # .c 的 !living(target) 在攻击方无 meta 可查，由此处死亡检查兜底。
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    ap = max(Map.get(data, :ap, 0), 1)
    stats = character.meta.stats

    # LPC: dp = target->query_skill("dodge") + target->query_skill("force")
    #           + target->query("con") * 5;
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "force") + Stats.query_con(stats) * 5

    # LPC: damage = random(ap / 2) + ap / 2;
    damage = Engine.rand(rng, div(ap, 2)) + div(ap, 2)
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (target->query_skill_mapped("force") == "jiuyang-shengong")
    #      { me->add("neili", -600);  me->start_busy(3);
    #        msg += HIW "只听轰然一声巨响，$n" HIW "已被一招正中，可$N"
    #               HIW "只觉全身内力犹如江河入\n海，又如水乳交融，登"
    #               "时消失得无影无踪。\n" NOR; }
    #      else if (ap / 2 + random(ap) > dp)
    #      { me->add("neili", -600);  me->start_busy(3);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
    #                    HIR "只听轰然一声巨响，$n" HIR "被$N"
    #                    HIR "一招正中，身子便如稻草般平平飞出"
    #                    "，重\n重摔在地下，呕出一大口鲜血，动"
    #                    "也不动。\n" NOR); }
    #      else
    #      { me->add("neili", -400);  me->start_busy(4);
    #        msg += CYN "可是$p" CYN "内力深厚，及时摆脱了"
    #               CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR; }
    cond do
      Stats.mapped(stats, "force") == "jiuyang-shengong" ->
        Performs.feedback(attacker, 600, 3)

        Broadcast.publish(
          conn,
          "只听轰然一声巨响，$n已被一招正中，可$N只觉全身内力犹如江河入\n海，又如水乳交融，登时消失得无影无踪。\n",
          bindings
        )

      div(ap, 2) + Engine.rand(rng, ap) > dp ->
        Performs.feedback(attacker, 600, 3)

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, div(damage * 100, 100))

        character = %{character | meta: %{character.meta | vitals: vitals}}

        conn
        |> Broadcast.publish(
          "只听轰然一声巨响，$n被$N一招正中，身子便如稻草般平平飞出，重\n重摔在地下，呕出一大口鲜血，动也不动。\n",
          bindings
        )
        |> put_character(character)

      true ->
        Performs.feedback(attacker, 400, 4)

        Broadcast.publish(
          conn,
          "可是$p内力深厚，及时摆脱了$P内力的牵扯，躲开了这一击！\n",
          bindings
        )
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define ZHAO "「" HIY "佛光普照" NOR "」"
  # 
  # inherit F_SSERVER; 
  #          
  # int perform(object me, object target) 
  # { 
  # //      object weapon; 
  #         string msg; 
  #         int ap, dp; 
  #         int damage; 
  # 
  #         if (userp(me) && ! me->query("can_perform/piaoxue-zhang/zhao"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me); 
  #         
  #         if (! target || ! me->is_fighting(target)) 
  #                 return notify_fail(ZHAO "只能在战斗中对对手使用。\n"); 
  #          
  #         if (me->query_temp("weapon") || 
  #             me->query_temp("secondary_weapon")) 
  #                 return notify_fail("你必须空手才能施展" ZHAO "。\n"); 
  #          
  #         if (me->query_skill("force") < 300) 
  #                 return notify_fail("你的内功的修为不够，无法施展" ZHAO "。\n"); 
  #         
  #         if (me->query_skill("piaoxue-zhang", 1) < 180) 
  #                 return notify_fail("你的飘雪穿云掌修为不够，无法施展" ZHAO "。\n"); 
  #          
  #         if (me->query("neili") < 1000 || me->query("max_neili") < 3500) 
  #                 return notify_fail("你的真气不够，无法施展" ZHAO "。\n"); 
  # 
  # /*
  #         if (me->query_skill_mapped("force") != "emei-jiuyang" &&
  #             me->query_skill_mapped("force") != "wudang-jiuyang" &&
  #             me->query_skill_mapped("force") != "shaolin-jiuyang" &&
  #             me->query_skill_mapped("force") != "jiuyang-shengong") 
  #                 return notify_fail("你没有激发内功为九阳神功，无法施展" ZHAO "。\n"); 
  # */
  # 
  #         if (me->query_skill_mapped("strike") != "piaoxue-zhang") 
  #                 return notify_fail("你没有激发飘雪穿云掌，无法施展" ZHAO "。\n"); 
  # 
  #         if (me->query_skill_prepared("strike") != "piaoxue-zhang")
  #                 return notify_fail("你没有准备飘雪穿云掌，无法施展" ZHAO "。\n"); 
  # 
  #         if (! me->query_temp("powerup"))
  #                 return notify_fail("你必须将全身功力尽数提起才能施展" ZHAO "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIY "$N" HIY "运起全身功力，顿时真气迸发，全身骨骼噼啪作"
  #               "响，猛然一掌向$n" HIY "\n全力拍出，力求一击毙敌，正是一"
  #               "招「佛光普照」。\n" NOR;
  #          
  #         ap = me->query_skill("strike") +
  #              me->query_skill("force") +
  #              me->query("str") * 5;
  # 
  #         dp = target->query_skill("dodge") +
  #              target->query_skill("force") +
  #              target->query("con") * 5;
  # 
  #         //damage = random(ap / 3) + ap / 3;
  #         damage = random(ap / 2) + ap / 2;
  # 
  #         if (target->query_skill_mapped("force") == "jiuyang-shengong")
  #         {
  #                 me->add("neili", -600);
  #                 me->start_busy(3);
  #                 msg += HIW "只听轰然一声巨响，$n" HIW "已被一招正中，可$N"
  #                        HIW "只觉全身内力犹如江河入\n海，又如水乳交融，登"
  #                        "时消失得无影无踪。\n" NOR; 
  #         } else
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -600);
  #                 me->start_busy(3);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 100,
  #                                            HIR "只听轰然一声巨响，$n" HIR "被$N"
  #                                            HIR "一招正中，身子便如稻草般平平飞出"
  #                                            "，重\n重摔在地下，呕出一大口鲜血，动"
  #                                            "也不动。\n" NOR);
  #         } else 
  #         { 
  #                 me->add("neili", -400);
  #                 me->start_busy(4);
  #                 msg += CYN "可是$p" CYN "内力深厚，及时摆脱了" 
  #                        CYN "$P" CYN "内力的牵扯，躲开了这一击！\n" NOR; 
  #         }
  #         message_combatd(msg, me, target);
  #        
  #         return 1; 
  # }
end
