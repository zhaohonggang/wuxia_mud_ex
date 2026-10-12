defmodule Kantele.Combat.Skills.Performs.WeituoGun.Fumo do
  @moduledoc """
  perform「fumo」（source weituo-gun/fumo.c，由 translate_perform.py 生成，inherit F_SSERVER）

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

  @perform_id "weituo-gun/fumo"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "weituo-gun")
    ap = 0
    damage = (div(ap, 2) + Engine.rand(rng, div(ap, 2)))

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
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
         :ok <- check_mapped(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "force") < 200 -> {:error, "你的内功的修为不够，难以使用这一绝技！\n"}
      Stats.skill(stats, "weituo-gun") < 140 -> {:error, "你的韦陀棍法修为不够，目前不能使用韦陀伏魔！\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "club") != "weituo-gun" -> {:error, "你没有激发韦陀棍法，不能使用韦陀伏魔！\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 800 -> {:error, "你的真气不够，不能使用韦陀伏魔！\n"}
      true -> :ok
    end
  end

  defp check_weapon(character) do
    combat = character.meta.combat

    cond do
      combat.weapon == nil -> {:error, "你使用的武器不对。\n"}
      true -> :ok
    end
  end

  defp check_other(character) do
    # TODO(migrate) 其它门槛（战斗/临时状态/道具等）需人工核对：
    #   {:error, "你还没有受过高人指点，无法施展「韦陀伏魔」。\n"}
    :ok

  end

  defp apply_effect(conn, character) do
    # 无条件攻击方效果：消耗/Busy/Apply/暗器数量 + 前置广播
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 100}
    vitals = %{vitals | neili: vitals.neili - 300}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}
    combat = character.meta.combat
    combat = Combat.start_busy(combat, 2)
    combat = Combat.start_busy(combat, 3)
    character = %{character | meta: Map.put(character.meta, :combat, combat)}
    conn = Broadcast.publish(conn, "$N脸色柔和，尽显一派慈祥之意，手中的某物轻旋，恍惚中显出佛家韦陀神像，
神光四射，笼罩住$n！", n1: character.name)

    conn
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

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？", n1: attacker.name, n2: character.name)
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    ap = Map.get(data, :ap, 0)
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    hit = div(ap, 2) + Engine.rand(rng, ap) > dp
    vitals = character.meta.vitals
    if hit do
          vitals = Vitals.damage(vitals, :qi, damage)
    end

    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 300, 3)
    msg = if hit, do: "结果只听$p一声惨叫，被$P一下子打中要害，七窍一起生烟，耳鼻都渗出血来！", else: "可是$p强摄心神，没有被$P所迷惑，硬生生的架住了$P这一招！"
    result = Messages.interpolate(msg, n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-100"}, {"neili", "-300"}], "assign_refs": [{"dp", "force"}], "busy_lines": ["me->start_busy(2);", "me->start_busy(3);"], "level_gates": [{"force", "200"}, {"weituo-gun", "140"}], "map_gates": [{"club", "weituo-gun"}], "remote_damage": true, "resource_gates": [{"neili", "800"}, {"shen", "10000"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // fumo.c 韦陀伏魔
  # 
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     string msg;
  #         int ap, dp;
  #         int damage;
  #   //if (userp(me) && ! me->query("can_perform/weituo-gun/fumo"))
  #   //              return notify_fail("你还没有受过高人指点，无法施展「韦陀伏魔」。\n");
  # 
  #     if (! target) target = offensive_target(me);
  # 
  #     if (! target || ! me->is_fighting(target))
  #             return notify_fail("「韦陀伏魔」只能在战斗中对对手使用。\n");
  # 
  #     if (! objectp(weapon = me->query_temp("weapon")) ||
  #               (string)weapon->query("skill_type") != "club")
  #         return notify_fail("你使用的武器不对。\n");
  # 
  #     if (me->query_skill("force") < 200)
  #         return notify_fail("你的内功的修为不够，难以使用这一绝技！\n");
  # 
  #     if (me->query_skill("weituo-gun", 1) < 140)
  #         return notify_fail("你的韦陀棍法修为不够，目前不能使用韦陀伏魔！\n");
  # 
  #     if (me->query("neili") < 800)
  #         return notify_fail("你的真气不够，不能使用韦陀伏魔！\n");
  # 
  #         if (me->query_skill_mapped("club") != "weituo-gun")
  #                 return notify_fail("你没有激发韦陀棍法，不能使用韦陀伏魔！\n");
  # 
  #         if (me->query("shen") < 10000)
  #                 return notify_fail("你正气不足，难以理解韦陀伏魔的精髓。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIY "$N" HIY "脸色柔和，尽显一派慈祥之意，手中的" + weapon->name() +
  #               HIY "轻旋，恍惚中显出佛家韦陀神像，\n神光四射，笼罩住$n" + HIY "！\n" NOR;
  # 
  #         if (target->is_bad())
  #         {
  #                 ap = me->query("shen") / 1000;
  #                 if (ap > 100) ap = (ap - 100) / 4 + 100;
  #                 if (ap > 200) ap = (ap - 200) / 4 + 200;
  #                 if (ap > 300) ap = (ap - 300) / 4 + 300;
  #                 if (ap > 400) ap = 400;
  #                 msg += HIR "$n" HIR "平日作恶不少，见了此情此景，心中不禁颤然！\n" NOR;
  #         } else
  #                 ap = 0;
  #         ap += me->query_skill("club");
  #         dp = target->query_skill("force");
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 damage = ap / 2 + random(ap / 2);
  #                 me->add("neili", -300);
  #                 me->start_busy(2);
  #                 msg += COMBAT_D->do_damage(me, target, WEAPON_ATTACK, damage, 60,
  #                                            HIR "结果只听$p" HIR "一声惨叫，被$P"
  #                                            "一下子打中要害，七窍一起生烟，耳鼻都渗出血来！\n" NOR);
  # 
  #         } else
  #         {
  #                 me->add("neili", -100);
  #                 me->start_busy(3);
  #                 msg += CYN "可是$p" CYN "强摄心神，没有被$P"
  #                        CYN "所迷惑，硬生生的架住了$P" CYN "这一招！\n"NOR;
  #         }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
