defmodule Kantele.Combat.Skills.Performs.LeimingBian.Cibei do
  @moduledoc """
  perform「慈悲字诀」（source leiming-bian/cibei.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：目标在战斗中 → 雷鸣鞭法>=160 → 禅宗心法>=150 →
  正神>=200000 → 内力>=1500 → 手持鞭类武器 → 目标存活。
  命中判定 `random(at)+at/2 > df`（at=战斗经验*鞭法/1000，df=目标战斗经验*躲闪/1000）；
  命中则受佛法感动文案 + 气血状态 + 目标忙乱 3，伤害=正神/2000（上限 1500），
  随后 lmt（3~6）次挥鞭连击，攻击方扣 300 内力、忙乱 random(2)+2；
  未命中仅化解文案，扣 200 内力、忙乱 random(2)。

  差异（TODO(migrate)）：
  - LPC 的 can_perform 检查被注释掉，故无 check_perform_known（同
    jiuyin_shengong/zhen 先例）；
  - LPC 在未命中分支把起手式 msg 丢弃（只发布化解文案），故起手式仅在命中
    分支发布，apply_effect 无无条件攻击方效果；
  - lmt 次 `do_attack`（每次 apply/attack +extra/5、apply/damage +extra/5，
    加完即减）折算为每击 level/15 + extra/5 基础伤害，不落攻击方 temp；
  - `eff_status_msg` 用框架的 Messages.eff_status_msg/1（文案不同但语义一致）。
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

  @perform_id "leiming-bian/cibei"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "leiming-bian")

    with {:ok, target} <- target(combat),
         :ok <- check_levels(character),
         :ok <- check_shen(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(combat),
         :ok <- check_target_alive(target) do
      weapon_name =
        case Combat.weapon(combat) do
          nil -> ""
          weapon -> Map.get(weapon, :name)
        end

      # LPC: lmt = random(leiming-bian / 50) + 1，钳制 3~6
      hits = (Engine.rand(rng, div(lvl, 50)) + 1) |> max(3) |> min(6)

      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: lvl,
          skill: lvl,
          # LPC: at = combat_exp * leiming-bian / 1000
          at: div(stats.combat_exp * lvl, 1000),
          # LPC: damage = shen / 2000（上限 1500）
          shen_damage: min(div(stats.shen, 2000), 1500),
          hits: hits,
          extra: lvl,
          weapon_name: weapon_name,
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

  # LPC: if (! target || ! target->is_character() || ! me->is_fighting(target))
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "［慈悲字诀］只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (extra < 160) / if (skill < 150)（skill = buddhism）
  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "leiming-bian") < 160 ->
        {:error, "你的雷鸣鞭法修为太差,还不能使用慈悲字诀！\n"}
      Stats.skill(stats, "buddhism") < 150 ->
        {:error, "你的禅宗心法等级不够，怎能支持慈悲字诀？ \n"}
      true ->
        :ok
    end
  end

  # LPC: if (me->query("shen") < 200000)
  defp check_shen(character) do
    if character.meta.stats.shen < 200_000 do
      {:error, "慈悲字诀需以无边正气为辅,大师还是多行善事吧! \n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("neili") < 1500)
  defp check_resources(character) do
    if character.meta.vitals.neili < 1500 do
      {:error, "你的内力修为不够辅助慈悲字诀。\n"}
    else
      :ok
    end
  end

  # LPC: if (! weapon || weapon->query("skill_type") != "whip")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if is_map(weapon) and Map.get(weapon, :skill_type) == "whip" do
      :ok
    else
      {:error, "你手中没有兵器如何使用慈悲字诀。\n"}
    end
  end

  # LPC: if (! living(target))
  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  # LPC 无条件攻击方效果：无（内力/忙乱均在分支内，由目标侧 feedback 回执）。
  defp apply_effect(conn, _character) do
    conn
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
    at = max(Map.get(data, :at, 0), 1)
    stats = character.meta.stats
    # LPC: df = target->query("combat_exp") * target->query_skill("dodge", 1) / 1000
    df = div(stats.combat_exp * Stats.skill(stats, "dodge"), 1000)

    # LPC: if ((random(at) + at / 2) > df)
    if Engine.rand(rng, at) + div(at, 2) > df do
      resolve_hit(conn, character, attacker, data, rng)
    else
      resolve_miss(conn, character, attacker, rng)
    end
  end

  defp resolve_hit(conn, character, attacker, data, rng) do
    damage = Map.get(data, :shen_damage, 0)
    weapon_name = Map.get(data, :weapon_name, "")
    level = Map.get(data, :level, 0)
    hits = Map.get(data, :hits, 3)
    extra = Map.get(data, :extra, 0)

    # LPC: receive_damage("qi", damage); receive_wound("qi", damage / 3);
    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    # LPC: p = qi * 100 / max_qi; msg += "( $n" + eff_status_msg(p) + " )\n";
    ratio = div(vitals.qi * 100, max(vitals.max_qi, 1))

    combat = Combat.start_busy(character.meta.combat, 3)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: for (i = 1; i <= lmt; i++) { add_temp("apply/attack", extra/5);
    #      add_temp("apply/damage", extra/5); do_attack(...); add_temp(-…); }
    # 折算：每击 level/15 + extra/5 基础伤害（加成不落攻击方 temp）
    per_hit = max(div(level, 15), 1) + div(extra, 5)

    combo_damage =
      Enum.reduce(1..hits, 0, fn _, acc ->
        acc + per_hit + Engine.rand(rng, per_hit)
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, combo_damage)
      |> Vitals.wound(:qi, div(combo_damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -300); me->start_busy(random(2) + 2);
    Performs.feedback(attacker, 300, 2 + Engine.rand(rng, 2))

    # LPC 起手式仅在命中分支发布（msg 未被丢弃）：
    #   RED "只见$N喃喃自语道：慈悲为怀，手中的" + weapon->name() +
    #   RED "仿佛如来出世般倒卷向$n。\n" NOR
    conn
    |> Broadcast.publish(
      "只见$N喃喃自语道：慈悲为怀，手中的" <> weapon_name <> "仿佛如来出世般倒卷向$n。\n",
      n1: attacker.name,
      n2: character.name
    )
    |> Broadcast.publish(
      "$n不禁被$N的无边佛法打动，猛的后退，脸上没有一丝血色...\n",
      n1: attacker.name,
      n2: character.name
    )
    |> Broadcast.publish(
      "( $n" <> Messages.eff_status_msg(ratio) <> " )\n",
      n1: attacker.name,
      n2: character.name
    )
    |> Broadcast.publish(
      "\n紧接着$N手中的" <> weapon_name <> "连续晃动，竟然不知道有多少击。\n",
      n1: attacker.name,
      n2: character.name
    )
    |> put_character(character)
  end

  defp resolve_miss(conn, character, attacker, rng) do
    # LPC: me->add("neili", -200); me->start_busy(random(2));
    Performs.feedback(attacker, 200, Engine.rand(rng, 2))

    conn
    |> Broadcast.publish(
      "\n$n左躲右闪，强$N的攻击完全化于无形！\n",
      n1: attacker.name,
      n2: character.name
    )
    |> put_character(character)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # int perform(object me, object target)
  # {
  #         string msg; 
  #         int extra, skill, at, df, i, lmt, damage, p;
  #         object weapon;
  #         extra = me->query_skill("leiming-bian",1);
  # 
  #         //if (userp(me) && !me->query("can_perform/leiming-bian/cibei"))
  #        //       return notify_fail("你使用的外功中没有这个功能。\n");
  #         if( !target ) target = offensive_target(me);
  # 
  #         if( !target
  #                  || !target->is_character()
  #                  || !me->is_fighting(target) )
  #               return notify_fail("［慈悲字诀］只能对战斗中的对手使用。\n");
  # 
  #         if( extra < 160)
  #               return notify_fail("你的雷鸣鞭法修为太差,还不能使用慈悲字诀！\n");
  # 
  #         skill = me->query_skill("buddhism", 1);
  # 
  #         if( skill < 150)
  #               return notify_fail("你的禅宗心法等级不够，怎能支持慈悲字诀？ \n");
  # 
  #         if( me->query("shen") < 200000)
  #               return notify_fail("慈悲字诀需以无边正气为辅,大师还是多行善事吧! \n");
  # 
  #         if( me->query("neili") < 1500 )
  #               return notify_fail("你的内力修为不够辅助慈悲字诀。\n");
  # 
  #         weapon = me->query_temp("weapon");
  # 
  #         if( !weapon
  #          || weapon->query("skill_type") != "whip")
  #               return notify_fail("你手中没有兵器如何使用慈悲字诀。\n");
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = RED "只见$N喃喃自语道：慈悲为怀，手中的" + weapon->name() + RED "仿佛如来出世般倒卷向$n。\n" NOR;
  # 
  #         at = me->query("combat_exp") * me->query_skill("leiming-bian", 1) / 1000;
  #         df = target->query("combat_exp") * target->query_skill("dodge", 1) / 1000;
  # 
  #         if( (random(at) + at / 2)  > df )
  #         {
  #             damage = me->query("shen", 1) / 2000;
  # 
  #             //if(damage > 1500) damage = 1500 + (damage-1500)/100;
  #             if(damage > 1500) damage = 1500; //设定上限 2017-02-03
  # 
  #             msg += CYN "$n不禁被$N的无边佛法打动，猛的后退，脸上没有一丝血色...\n" NOR;
  #             target->receive_damage("qi", damage, me);
  #             target->receive_wound("qi", damage / 3, me);
  # 
  #             p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  #             msg += "( $n" + eff_status_msg(p) + " )\n";
  #             message_vision(msg, me, target);
  #             target->start_busy(3);
  # 
  #             weapon = me->query_temp("weapon");
  #             msg = HIG "\n紧接着$N手中的" + weapon->name() + HIG "连续晃动，竟然不知道有多少击。\n" NOR;
  #             message_vision(msg,me,target);
  # 
  #             lmt = random(me->query_skill("leiming-bian", 1) / 50) + 1;
  #             if ( lmt < 3 ) lmt = 3;
  #             if ( lmt > 6 ) lmt = 6;
  # 
  #             for(i=1;i <= lmt;i++)
  #             {
  #                  extra = me->query_skill("leiming-bian", 1);
  #                  me->add_temp("apply/attack", extra / 5);
  #                  me->add_temp("apply/damage", extra / 5);
  #                  COMBAT_D->do_attack(me,target, me->query_temp("weapon"), 1);
  #                  me->add_temp("apply/attack",-extra / 5);
  #                  me->add_temp("apply/damage",-extra / 5);
  #             }
  #             me->add("neili",-300);
  #             me->start_busy(random(2) + 2);
  #         } else
  #        {
  #               msg = HIG "\n$n左躲右闪，强$N的攻击完全化于无形！\n" NOR;
  #               message_vision(msg,me,target);
  #               me->add("neili",-200);
  #               me->start_busy(random(2));
  #        }
  #         return 1;
  # }
end
