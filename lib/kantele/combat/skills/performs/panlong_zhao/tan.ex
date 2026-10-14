defmodule Kantele.Combat.Skills.Performs.PanlongZhao.Tan do
  @moduledoc """
  perform「云中探爪」（对照 `kungfu/skill/panlong-zhao/tan.c`）

  门槛（按 .c 顺序）：已学此招 → 战斗中的对手 → 空手 → 越空盘龙爪>=130 →
  激发 claw 为越空盘龙爪 → 准备 claw 为越空盘龙爪 → 真气>=200 → 目标存活。
  起手广播后由目标侧结算：`ap = 爪法`、`dp = 目标招架`，
  `ap/2 + random(ap) > dp` 命中则 `damage = 60 + ap/3 + random(ap/3)`、
  攻击方扣 150 真气并忙乱 1 回合、目标受
  `do_damage(UNARMED_ATTACK, damage, 45)`；否则攻击方扣 50 真气并忙乱
  3 回合、广播「巧妙的招架开来」文案。

  差异（TODO(migrate)）：
  - 两条分支的 neili 消耗/忙乱为命中相关，故经
    `Performs.feedback(attacker, neili, busy)` 回授攻击方；
  - `COMBAT_D->do_damage(..., 45, msg)` 折算为
    `Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 45, 100))`；
  - `living(target)` 门槛在攻击方无 meta 可查，由目标侧 `combat/perform-incoming`
    的死亡检查兜底。
  说明：`.c` 未命中文案写作「看破了」、命中文案写作「更本无从招架」，
  均按原文逐字保留（不改写错别字）。
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

  @perform_id "panlong-zhao/tan"
  @move_name "「云中探爪」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1

    # LPC: ap = me->query_skill("claw");
    ap = Stats.skill(stats, "claw")

    with :ok <- check_perform_known(character),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
         :ok <- check_resources(character),
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

  # LPC: if (userp(me) && ! me->query("can_perform/panlong-zhao/tan"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target) { me->clean_up_enemy(); target = me->select_opponent(); }
  #      if (! target || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  defp check_weapon(combat) do
    if Combat.weapon(combat) == nil do
      :ok
    else
      {:error, "你必须空手才能使用#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill("panlong-zhao", 1) < 130)
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "panlong-zhao") < 130 do
      {:error, "你的越空盘龙爪等级不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("claw") != "panlong-zhao")
  defp check_mapped(character) do
    if Stats.mapped(character.meta.stats, "claw") == "panlong-zhao" do
      :ok
    else
      {:error, "你没有激发越空盘龙爪，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query_skill_prepared("claw") != "panlong-zhao")
  defp check_prepared(character) do
    prepared = Stats.prepared_perform(character.meta.stats, "claw")

    if prepared != nil and hd(String.split(prepared, "/")) == "panlong-zhao" do
      :ok
    else
      {:error, "你没有准备越空盘龙爪，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (me->query("neili") < 200)
  defp check_resources(character) do
    if character.meta.vitals.neili < 200 do
      {:error, "你的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
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
    # LPC: msg = HIW "$N" HIW "伸出两掌，朝$n" HIW "拍去，待掌至中途，却变掌为爪，幻作两"
    #            "道金光袭向$n" HIW "各处要脉！\n" NOR;
    #      message_combatd(msg, me, target);
    #      ap/dp 之后按分支扣 neili / start_busy / do_damage（在目标侧结算）。
    conn =
      Broadcast.publish(
        conn,
        "$N伸出两掌，朝$n拍去，待掌至中途，却变掌为爪，幻作两道金光袭向$n各处要脉！\n",
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

    # LPC: dp = target->query_skill("parry");
    dp = Stats.skill(character.meta.stats, "parry")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (ap / 2 + random(ap) > dp)
    #      { me->add("neili", -150);
    #        damage = 60 + ap / 3 + random(ap / 3);
    #        msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
    #                    HIR "$p" HIR "面对$P" HIR "这电光火石般"
    #                    "的双抓，更本无从招架，登时被抓得血肉飞"
    #                    "溅！\n" NOR);
    #        me->start_busy(1); }
    #      else
    #      { msg += CYN "可是$p" CYN "的看破了$P" CYN
    #               "的招式，巧妙的招架开来，没露半点破绽！\n" NOR;
    #        me->add("neili",-50);
    #        me->start_busy(3); }
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp

    {conn, character} =
      if hit do
        damage = 60 + div(ap, 3) + Engine.rand(rng, div(ap, 3))
        vitals = character.meta.vitals |> Vitals.damage(:qi, damage) |> Vitals.wound(:qi, div(damage * 45, 100))
        character = %{character | meta: %{character.meta | vitals: vitals}}
        Performs.feedback(attacker, 150, 1)

        conn =
          Broadcast.publish(
            conn,
            "$p面对$P这电光火石般的双抓，更本无从招架，登时被抓得血肉飞溅！\n",
            bindings
          )

        {conn, character}
      else
        Performs.feedback(attacker, 50, 3)

        conn =
          Broadcast.publish(
            conn,
            "可是$p的看破了$P的招式，巧妙的招架开来，没露半点破绽！\n",
            bindings
          )

        {conn, character}
      end

    put_character(conn, character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define TAN "「" HIW "云中探爪" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me)
  # {
  #         string msg;
  #         object target;
  #         int skill, ap, dp, damage;
  # 
  #         if (userp(me) && ! me->query("can_perform/panlong-zhao/tan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(TAN "只能在战斗中对对手使用。\n");
  # 
  #         if (objectp(me->query_temp("weapon")))
  #                 return notify_fail("你必须空手才能使用" TAN "。\n");
  # 
  #         skill = me->query_skill("panlong-zhao", 1);
  # 
  #         if (skill < 130)
  #                 return notify_fail("你的越空盘龙爪等级不够，难以施展" TAN "。\n");
  # 
  #         if (me->query_skill_mapped("claw") != "panlong-zhao")
  #                 return notify_fail("你没有激发越空盘龙爪，难以施展" TAN "。\n");
  # 
  #         if (me->query_skill_prepared("claw") != "panlong-zhao")
  #                 return notify_fail("你没有准备越空盘龙爪，难以施展" TAN "。\n");
  # 
  #         if (me->query("neili") < 200)
  #                 return notify_fail("你的真气不够，难以施展" TAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = HIW "$N" HIW "伸出两掌，朝$n" HIW "拍去，待掌至中途，却变掌为爪，幻作两"
  #               "道金光袭向$n" HIW "各处要脉！\n" NOR;
  # 
  #         ap = me->query_skill("claw");
  #         dp = target->query_skill("parry");
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 me->add("neili", -150);
  #                 damage = 60 + ap / 3 + random(ap / 3);
  #                 msg += COMBAT_D->do_damage(me, target, UNARMED_ATTACK, damage, 45,
  #                                            HIR "$p" HIR "面对$P" HIR "这电光火石般"
  #                                            "的双抓，更本无从招架，登时被抓得血肉飞"
  #                                            "溅！\n" NOR);
  #                 me->start_busy(1);
  #         } else
  #         {
  #                 msg += CYN "可是$p" CYN "的看破了$P" CYN
  #                        "的招式，巧妙的招架开来，没露半点破绽！\n" NOR;
  #                 me->add("neili",-50);
  #                 me->start_busy(3);
  #         }
  #         message_combatd(msg, me, target);
  # 
  #         return 1;
  # }
end
