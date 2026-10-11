defmodule Kantele.Combat.Skills.Performs.YuxiaoJian.Bihai do
  @moduledoc """
  perform「碧海潮生按玉箫」（source yuxiao-jian/bihai.c，由 translate_perform.py 生成，inherit F_SSERVER）

  门槛/资源消耗由提取器机械生成；攻击/命中/伤害/影响/回调等语义需人工按原始源码补齐（见文末参考注释）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kalevala.Event
  alias Kantele.Combat.Engine
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs

  @perform_id "yuxiao-jian/bihai"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    combat = character.meta.combat
    stats = character.meta.stats
    rng = &:rand.uniform/1
    lvl = Stats.skill(stats, "yuxiao-jian")
    skill = Stats.skill(stats, "yuxiao-jian")
    damage = 0

    with :ok <- check_perform_known(character),
         :ok <- check_gates(character),
         {:ok, target} <- target(combat) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{attacker: ref(character), perform_id: @perform_id,
          level: lvl,
          skill: lvl,
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
         :ok <- check_resources(character) do
      :ok
    end
  end

  defp check_levels(character) do
    stats = character.meta.stats

    cond do
      Stats.skill(stats, "bibo-shengong") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      Stats.skill(stats, "bihai-chaosheng") < 180 -> {:error, "TODO(migrate) 门槛不足。\n"}
      true -> :ok
    end
  end

  defp check_mapped(character) do
    stats = character.meta.stats

    cond do
      Stats.mapped(stats, "sword") != "yuxiao-jian" -> {:error, "TODO(migrate) 未激发/未准备相应武功。\n"}
      true -> :ok
    end
  end

  defp check_resources(character) do
    vitals = character.meta.vitals

    cond do
      vitals.neili < 300 -> {:error, "TODO(migrate) 气血/内力/精神不足。\n"}
      true -> :ok
    end
  end

  defp apply_effect(conn, character) do
    # TODO(migrate) 资源/时序需按原始源码核对（消耗或 busy/apply 加成可能仅在命中分支生效）
    vitals = character.meta.vitals
    vitals = %{vitals | neili: vitals.neili - 200}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

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

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    _stats = character.meta.stats
    damage = Map.get(data, :damage, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    stats = character.meta.stats
    dp = Stats.skill(stats, "dodge") + Stats.skill(stats, "parry")
    vitals = character.meta.vitals
        vitals = Vitals.damage(vitals, :jing, damage)
        vitals = Vitals.wound(vitals, :jing, div((damage * 2), 3))
    character = %{character | meta: %{character.meta | vitals: vitals}}
    Performs.feedback(attacker, 200, 1)
    result = Messages.interpolate("$n只感心头一震，脸上情不自禁的露出了一丝微笑。
$n只感全身热血沸腾，就只想手舞足蹈的乱动一番。
霎时间$n只感心头滚热，喉干舌燥，说不出的难受。
此时$n已身陷绝境，全身气血逆流，再也无法脱身。", n1: attacker.name, n2: character.name)
    conn
    |> Broadcast.publish(result)
    |> put_character(character)
  end

  # TODO(migrate) 原始抽取事实（供核对；完成后删除）：
  #   %{"add_costs": [{"neili", "-200"}], "assign_refs": [{"ap", "yuxiao-jian"}, {"dp", "force"}, {"skill", "yuxiao-jian"}], "busy_lines": ["me->start_busy(1 + random(3));"], "level_gates": [{"bibo-shengong", "180"}, {"bihai-chaosheng", "180"}], "map_gates": [{"sword", "yuxiao-jian"}], "remote_damage": false, "resource_gates": [{"neili", "300"}], "var_gates": [{"skill", "180"}]}

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define BIHAI "「" HIW "碧海潮生按玉箫" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         string msg;
  #         int ap, dp;
  #         int damage, skill;
  #         object ob;
  # 
  #         if (userp(me) && ! me->query("can_perform/yuxiao-jian/bihai"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target)
  #         {
  #                 me->clean_up_enemy();
  #                 target = me->select_opponent();
  #         }
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(BIHAI "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(ob = me->query_temp("handing")) || ! ob->valid_as_xiao())
  #         {
  #                 if (! objectp(ob = me->query_temp("weapon"))
  #                    || ! ob->valid_as_xiao())
  #                 {
  #                         // 手里的兵器也不能作为萧使用
  #                         return notify_fail("你手里没有拿萧，难以施展" BIHAI "。\n");
  #                 }
  #         }
  # 
  #         skill = me->query_skill("yuxiao-jian", 1);
  # 
  #         if (skill < 180)
  #                 return notify_fail("你玉箫剑法等级不够, 难以施展" BIHAI "。\n");
  # 
  #         if ((int)me->query_skill("bibo-shengong", 1) < 180)
  #                 return notify_fail("你碧波神功修为不够，难以施展" BIHAI "。\n");
  # 
  #         if ((int)me->query_skill("bihai-chaosheng", 1) < 180)
  #                 return notify_fail("你的碧海潮生曲太低，难以施展" BIHAI "。\n");
  # 
  #         if (me->query_skill_mapped("sword") != "yuxiao-jian")
  #                 return notify_fail("你没有激发玉箫剑法，难以施展" BIHAI "。\n");
  # 
  #         if (me->query("neili") < 300)
  #                 return notify_fail("你现在的内力不够，难以施展" BIHAI "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         ap = me->query_skill("yuxiao-jian", 1) +
  #              me->query_skill("bibo-shengong", 1) +
  #              me->query_skill("chuixiao-jifa");
  # 
  #         dp = target->query_skill("force") +
  #              target->query_skill("parry") +
  #              target->query_skill("chuixiao-jifa") / 2;
  # 
  #         damage = 0;
  # 
  #         msg = HIW "\n只见$N" HIW "手按玉箫，脚踏八卦四方之位，奏出"
  #               "一曲「碧海潮生按玉箫」。便听得那箫声如鸣琴击玉，轻轻"
  #               "发了几声，接着悠悠扬扬，飘下清亮柔和的洞箫声来。\n" NOR;
  # 
  #         if (ap + random(ap) > dp)
  #         {
  #                 msg += HIR "$n" HIR "只感心头一震，脸上情不自禁的露"
  #                        "出了一丝微笑。\n" NOR;
  #                 damage += ap / 5 + random(ap / 5);
  #         } else
  #                 msg += HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
  #                        "裕如。\n" NOR;
  # 
  #         msg += HIW "\n突然又听那洞箫声情致飘忽，缠绵宛转，便似一个女"
  #                "子一会儿叹息，一会儿又似呻吟，一会儿却又软语温存或柔"
  #                "声叫唤。\n" NOR;
  # 
  #         if (ap + random(ap / 2) > dp)
  #         {
  #                 msg += HIR "$n" HIR "只感全身热血沸腾，就只想手舞足"
  #                        "蹈的乱动一番。\n" NOR;
  #                 damage += ap / 4 + random(ap / 4);
  #         } else
  #                 msg += HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
  #                        "裕如。\n" NOR;
  # 
  #         msg += HIW "\n那箫声清亮宛如大海浩淼，万里无波，远处潮水缓缓"
  #                "推近，渐近渐快，其后洪涛汹涌，白浪连山，而潮水中鱼跃"
  #                "鲸浮，海面风啸鸥飞，水妖海怪群魔弄潮，极尽变幻之能事"
  #                "。\n" NOR;
  # 
  #         if (ap / 2 + random(ap) > dp)
  #         {
  #                 msg += HIR "霎时间$n" HIR "只感心头滚热，喉干舌燥，"
  #                        "说不出的难受。\n" NOR;
  #                 damage += ap / 3 + random(ap / 3);
  #         } else
  #                 msg += HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
  #                        "裕如。\n" NOR;
  # 
  #         msg += HIW "\n时至最后，却听那箫声愈来愈细，几乎难以听闻，便"
  #                "尤如大海潮退后水平如镜一般，但海底却又是暗流湍急，汹"
  #                "涌澎湃。\n" NOR;
  # 
  #         if (ap / 2 + random(ap / 2) > dp)
  #         {
  #                 msg += HIR "此时$n" HIR "已身陷绝境，全身气血逆流，"
  #                        "再也无法脱身。\n" NOR;
  #                 damage += ap / 2 + random(ap / 2);
  #         } else
  #                 msg += HIC "$n" HIC "暗暗凝神守一，对这箫声自是应付"
  #                        "裕如。\n" NOR;
  # 
  #         target->receive_damage("jing", damage, me);
  #         target->receive_wound("jing", damage * 2 / 3, me);
  # 
  #         me->start_busy(1 + random(3));
  #         me->add("neili", -200);
  # 
  #         message_sort(msg, me, target);
  #         return 1;
  # }
end
