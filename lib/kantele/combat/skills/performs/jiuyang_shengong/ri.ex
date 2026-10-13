defmodule Kantele.Combat.Skills.Performs.JiuyangShengong.Ri do
  @moduledoc """
  perform「魔光日无极」（source jiuyang-shengong/perform/ri.c，inherit F_SSERVER）

  群体 AoE：自身消耗 1000 内力、忙乱 5；对每个敌人
  ap/2 + random(ap) > 其(force*2 + 武学参悟 + con*10) 则命中，造成
  qi 伤 + qi 创/2 + jing 伤/6 + jing 创/10，并随机播放 5 种重伤描述之一
  （外加 random(2) 两种私密提示）。框架内以单目标（selected enemy）近似群体结算
  （见 do_resolve_incoming 注释；群体无一人命中时的全局提示见 no_hit_message/0）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Performs

  @perform_id "jiuyang-shengong/ri"
  @move_name "「魔光日无极」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "jiuyang-shengong")
    ap = Stats.skill(stats, "force") + Stats.skill(stats, "unarmed") +
         Stats.skill(stats, "martial-cognize") + Stats.skill(stats, "jiuyang-shengong") +
         Stats.query_con(stats) * 10

    with :ok <- check_perform_known(character),
         :ok <- check_fighting(combat),
         :ok <- check_weapon(combat),
         :ok <- check_resources(character),
         :ok <- check_levels(character),
         :ok <- check_mapped(character),
         :ok <- check_prepared(character),
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

  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_fighting(combat) do
    if Combat.fighting?(combat) do
      :ok
    else
      {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    if Combat.weapon(combat) != nil or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "#{@move_name}只能空手施展。\n"}
    else
      :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.max_neili < 8000 ->
        {:error, "你的内力的修为不够，现在无法使用#{@move_name}。\n"}

      vitals.neili < 2000 ->
        {:error, "你的真气不够，无法运用#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "jiuyang-shengong") < 250 do
      {:error, "你的九阳神功还不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "unarmed") != "jiuyang-shengong" ->
        {:error, "你现在没有激发九阳神功为拳脚，难以施展#{@move_name}。\n"}

      Stats.mapped(stats, "force") != "jiuyang-shengong" ->
        {:error, "你现在没有激发九阳神功为内功，难以施展#{@move_name}。\n"}

      true ->
        :ok
    end
  end

  # LPC: if (me->query_skill_prepared("unarmed") != "jiuyang-shengong")
  # prepared_perform 返回绝招 ID（如 jiuyang-shengong/ri），须取技能前缀比对
  defp check_prepared(character) do
    stats = character.meta.stats
    prepared = Stats.prepared_perform(stats, "unarmed")

    if prepared == nil or hd(String.split(prepared, "/")) != "jiuyang-shengong" do
      {:error, "你现在没有准备使用九阳神功，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: msg 由 3 段字面量组成（武器名为空）；me->add("neili", -1000); me->start_busy(5);
  defp apply_effect(conn, character, target) do
    msg =
      ["只见$N双目微闭，单手托天。掌心顿时腾起一个无比刺眼的气团，正是奥\n义「",
       "魔光日无极",
       "」。霎时金光万道，尘沙四起，空气炽热，几欲沸腾。$N\n随即收拢掌心，气团爆裂开来，向四周电射而出，光芒足以和日月争辉。\n\n"]
      |> Enum.join("")

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 1000}
    character = %{character | meta: %{character.meta | vitals: vitals}}
    combat = Combat.start_busy(character.meta.combat, 5)
    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      if Enum.empty?(character.meta.combat.enemies) do
        Broadcast.publish(conn, no_hit_message())
      else
        conn
      end

    conn
    |> Broadcast.publish(Messages.interpolate(msg, [n1: character.name, n2: target.name]))
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
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

    # LPC: dp = obs[i]->query_skill("force") * 2 + 武学参悟 + con*10
    dp = Stats.skill(stats, "force") * 2 + Stats.skill(stats, "martial-cognize") + Stats.query_con(stats) * 10

    if div(ap, 2) + Engine.rand(rng, ap) > dp do
      # LPC: 命中
      damage = div(ap, 4) + Engine.rand(rng, div(ap, 3))

      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, damage)
        |> Vitals.wound(:qi, div(damage, 2))
        |> Vitals.damage(:jing, div(damage, 6))
        |> Vitals.wound(:jing, div(damage, 10))

      character = %{character | meta: %{character.meta | vitals: vitals}}

      Performs.feedback(attacker, 500, 1)

      # 私密提示（random(2) 两种）
      conn = render(conn, CommandView, "text", %{text: Enum.random(tell_hit_messages())})
      # 重伤描述（random(5) 五种，名字插入）
      dmg = Enum.random(damage_messages(character.name))
      conn = Broadcast.publish(conn, Enum.join(dmg, ""))

      conn
      |> put_character(character)
    else
      _no_hit = no_hit_message()
      conn = render(conn, CommandView, "text", %{text: tell_miss_message()})

      conn
      |> put_character(character)
    end
  end

  defp damage_messages(target_name) do
    [
      ["只听", target_name, "一声惨嚎，接连退了数步，“哇”的呕出一大口鲜血。\n"],
      ["只见", target_name, "向后飞出丈远，重重的跌落在地上，衣衫烧焦，再也没力气站起。\n"],
      ["只见", target_name, "跌跌撞撞向后连退数步，伏倒在地。须眉、衣衫都发出一股焦臭。\n"],
      ["光芒闪过，", target_name, "却是呆立当场，动也不动，七窍流血，神情扭曲，煞是恐怖。\n"],
      ["#{target_name}急忙抽身后退，可只见眼前光芒暴涨，一闪而过。全身已多了数个伤口，鲜血飞溅。\n"]
    ]
  end

  defp tell_hit_messages() do
    [
      "你只觉眼前金光万道，周围空气几欲沸腾，光芒便如利箭一般透体而入。\n",
      "你只觉眼前金光万道，周围空气几欲沸腾，光芒便如千万细针一齐扎入身体般。\n"
    ]
  end

  defp tell_miss_message() do
    "你只觉眼前金光万道，周围空气几欲沸腾，大惊之下连忙急运内功，抵御开来。\n"
  end

  defp no_hit_message() do
    "只见光芒顿敛，却没有任何人被这招击中。\n"
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # #define RI "「" HIW "魔光日无极" NOR "」"
  # 
  # int perform(object me)
  # {
  #         object *obs;
  #         string msg;
  #         int damage;
  #         int ap, dp;
  #         int flag;
  #         int i;
  #         int p;
  # 
  #         if (userp(me) && ! me->query("can_perform/jiuyang-shengong/ri"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         me->clean_up_enemy();
  #         if (! me->is_fighting())
  #                 return notify_fail(RI "只能对战斗中的对手使用。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail(RI "只能空手施展。\n");
  # 
  #         if (me->query("max_neili") < 8000)
  #                 return notify_fail("你的内力的修为不够，现在无法使用" RI "。\n");
  # 
  #         if (me->query_skill("jiuyang-shengong", 1) < 250)
  #                 return notify_fail("你的九阳神功还不够娴熟，难以施展" RI "。\n");
  # 
  #         if (me->query_skill_mapped("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为拳脚，难以施展" RI "。\n");
  # 
  #         if (me->query_skill_mapped("force") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有激发九阳神功为内功，难以施展" RI "。\n");
  # 
  #         if (me->query_skill_prepared("unarmed") != "jiuyang-shengong")
  #                 return notify_fail("你现在没有准备使用九阳神功，难以施展" RI "。\n");
  # 
  #         if ((int)me->query("neili") < 2000)
  #                 return notify_fail("你的真气不够，无法运用" RI "。\n");
  # 
  #         msg = HIY "只见$N" HIY "双目微闭，单手托天。掌心顿时腾起一个无比刺眼的"
  #               "气团，正是奥\n义「" NOR + HIW "魔光日无极" NOR + HIY "」。霎时"
  #               "金光万道，尘沙四起，空气炽热，几欲沸腾。$N" HIY "\n随即收拢掌心"
  #               "，气团爆裂开来，向四周电射而出，光芒足以和日月争辉。\n\n" NOR;
  # 
  #         message_combatd(msg, me);
  # 
  #         me->add("neili", -1000);
  #         me->start_busy(5);
  # 
  #         ap = me->query_skill("force", 1) +
  #              me->query_skill("unarmed", 1) +
  #              me->query_skill("martial-cognize", 1) +
  #              me->query_skill("jiuyang-shengong", 1) +
  #              me->query("con") * 10;
  # 
  #         obs = me->query_enemy();
  #         for (flag = 0, i = 0; i < sizeof(obs); i++)
  #         {
  #                 dp = obs[i]->query_skill("force") * 2 +
  #                      obs[i]->query_skill("martial-cognize", 1) +
  #                      obs[i]->query("con") * 10;
  # 
  #                 if (ap / 2 + random(ap) > dp)
  #                 {
  #                         switch (random(2))
  #                         {
  #                         case 0:
  #                                 tell_object(obs[i], HIR "你只觉眼前金光万道，周围空气几欲沸"
  #                                                     "腾，光芒便如利箭一般透体而入。\n" NOR);
  #                                 break;
  # 
  #                         default:
  #                                 tell_object(obs[i], HIR "你只觉眼前金光万道，周围空气几欲沸"
  #                                                     "腾，光芒便如千万细针一齐扎入身体般。\n"
  #                                                     NOR);
  #                                 break;
  #                         }
  # 
  #                         damage = ap / 4 + random(ap / 3);
  # 
  #                         obs[i]->receive_damage("qi", damage, me);
  #                         obs[i]->receive_wound("qi", damage / 2, me);
  # 
  #                         obs[i]->receive_damage("jing", damage / 6, me);
  #                         obs[i]->receive_wound("jing", damage / 10, me);
  # 
  #                     p = (int)obs[i]->query("qi") * 100 / (int)obs[i]->query("max_qi");
  # 
  #                         switch (random(5))
  #                         {
  #                         case 0:
  #                                 msg = HIR "只听" + obs[i]->name() +
  #                                       HIR "一声惨嚎，接连退了数步，“"
  #                                       "哇”的呕出一大口鲜血。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 1:
  #                                 msg = HIR "只见" + obs[i]->name() +
  #                                       HIR "向后飞出丈远，重重的跌落在"
  #                                       "地上，衣衫烧焦，再也没力气站起"
  #                                       "。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 2:
  #                                 msg = HIR "只见" + obs[i]->name() +
  #                                       HIR "跌跌撞撞向后连退数步，伏倒"
  #                                       "在地。须眉、衣衫都发出一股焦臭"
  #                                       "。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         case 3:
  #                                 msg = HIR "光芒闪过，" + obs[i]->name() +
  #                                       HIR "却是呆立当场，动也不动，七"
  #                                       "窍流血，神情扭曲，煞是恐怖。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  # 
  #                         default:
  #                                 msg = HIR + obs[i]->name() +
  #                                       HIR "急忙抽身后退，可只见眼前光"
  #                                       "芒暴涨，一闪而过。全身已多了数"
  #                                       "个伤口，鲜血飞溅。\n" NOR;
  #                     msg += "( " + obs[i]->name() + eff_status_msg(p) + " )\n\n";
  #                                 break;
  #                         }
  #                         obs[i]->start_busy(1);
  #                         message("vision", msg, environment(me), ({ obs[i] }));
  #                         obs[i]->add("neili", -500);
  #                         flag = 1;
  #                 } else
  #                 {
  #                         tell_object(obs[i], HIY "你只觉眼前金光万道，周围空气几"
  #                                             "欲沸腾，大惊之下连忙急运内功，抵御"
  #                                             "开来。\n" NOR);
  #                 }
  #                 if (obs[i]->query("neili") < 0)
  #                         obs[i]->set("neili", 0);
  #         }
  # 
  #         if (! flag)
  #                 message_vision(HIY "只见光芒顿敛，却没有任何人被$N"
  #                    HIY "这招击中。\n\n" NOR, me, 0, obs);
  # 
  #         return 1;
  # }
end
