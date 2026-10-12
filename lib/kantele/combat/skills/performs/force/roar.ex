defmodule Kantele.Combat.Skills.Performs.Force.Roar do
  @moduledoc """
  exert「roar」（source force/roar.c，By Vin for heros.cn）

  仅限 10 种内功（龙象/天寰/混天/九阳/九阴/葵花/吸星/战神/易筋/混元），
  门槛（按 `.c` 顺序）：已映射内功在允许表内 → 内功>=180 →
  房间非 `no_fight`/`skybook`（同文案 ×2）→ 真气>=800。
  扣真气 800、忙乱 5，按所映射内功广播不同的长啸文案；
  随后对房间内所有生物做 `skill/2 + random(skill/2)` 与 `con*2` 的对抗，
  失败者受 `skill - max_neili/10` 的精力伤害（`jing` ×2，`neili < skill*2`
  时再受等量 `eff_jing` 创伤），并随机播三种旁观文案、`jing`/`eff_jing`
  低于 1 时昏迷。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Roar`（`skills/force_roar.ex`），
    本文件为并存的对齐副本（仅供文案对齐）；受害者的伤害/昏迷在真实实现的
    目标侧 `resolve_incoming/4` 结算，本文件以 `@doc false` 函数保留文案；
  - `living()` 过滤、`die_guard` 保护、`want_kill`/`fight_ob`/`kill_ob`
    的敌对关系建立引擎未建模；
  - `to_chinese(f)` 折算为映射 id 原样（引擎未维护内功 id→中文名 表）；
  - `.c` 的 `yijinjing` 与 `hunyuan-gong` 共用同一条赋值语句，E 侧以
    `when force in [...]` 保持「一条文案」的粒度。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @allowed_forces ~w(longxiang-gong tianhuan-shenjue huntian-qigong jiuyang-shengong
                     jiuyin-shengong kuihua-mogong xixing-dafa zhanshen-xinjing
                     yijinjing hunyuan-gong)

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

  defp check_gates(character) do
    with :ok <- check_allowed_force(character),
         :ok <- check_force_level(character),
         :ok <- check_no_fight(character),
         :ok <- check_skybook(character),
         :ok <- check_neili(character) do
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("force") != "longxiang-gong" && ... && != "hunyuan-gong")
  #        return notify_fail("你所学的内功中没有这种功能。\n");
  defp check_allowed_force(character) do
    if Stats.mapped(character.meta.stats, "force") in @allowed_forces do
      :ok
    else
      {:error, "你所学的内功中没有这种功能。\n"}
    end
  end

  # LPC: skill = me->query_skill("force"); if (skill < 180)
  #        return notify_fail("你的内功修为不够。\n");
  defp check_force_level(character) do
    if Stats.skill(character.meta.stats, "force") < 180 do
      {:error, "你的内功修为不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("在这里不能攻击他人。\n");
  defp check_no_fight(character) do
    if room_flag(character, :no_fight) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  # LPC: // 执行天书任务的特殊房间防止龙吟中断剧情。
  #      if (environment(me)->query("skybook")) return notify_fail("在这里不能攻击他人。\n");
  defp check_skybook(character) do
    if room_flag(character, :skybook) do
      {:error, "在这里不能攻击他人。\n"}
    else
      :ok
    end
  end

  defp room_flag(character, flag) do
    Map.get(Map.get(character.meta, :room, %{}), flag, false)
  end

  # LPC: if ((int)me->query("neili") < 800) return notify_fail("你的真气不够。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 800 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    force = Stats.mapped(character.meta.stats, "force")
    vitals = character.meta.vitals

    # LPC: me->add("neili", -800); me->start_busy(5); message_combatd(msg, me);
    vitals = %{vitals | neili: max(vitals.neili - 800, 0)}
    combat = Combat.start_busy(character.meta.combat, 5)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    conn
    |> Broadcast.publish(roar_message(force), n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: switch (f) { case ...: msg = ...; }
  # 注意：`case` 的字符串模式会与上一条分支的文案字面量被 `join_adjacent` 误并，
  # 故此处改用「每内功一个函数子句」，保持每条文案独立。
  defp roar_message("longxiang-gong"),
    do: "$N运转真气，面无表情，歌声如梵唱般贯入众人耳中。\n"

  defp roar_message("huntian-qigong"),
    do: "$N深深吸入一囗气，运足内力发出一阵长啸，音传百里，慑人心神。\n"

  defp roar_message("jiuyang-shengong"),
    do: "$N仰天长啸，声音绵泊不绝，众人无不听得心驰神摇。\n"

  defp roar_message("jiuyin-shengong"),
    do: "$N气凝丹田，猛然一声断喝，声音远远的传了开去，激荡不止。\n"

  defp roar_message("kuihua-mogong"),
    do: "$N蓦地极嘶长呼，声音凄厉之极，令人毛骨悚然。\n"

  # `.c` 中 yijinjing 与 hunyuan-gong 共用同一条赋值语句（仅一条文案），E 侧同粒度。
  defp roar_message(force) when force in ["yijinjing", "hunyuan-gong"],
    do: "$N深深吸入一囗气，运起金刚禅狮子吼，发出惊天动地的一声巨吼。\n"

  # LPC: default: msg = HIY "$N" HIY "深深吸入一囗气，体内" + to_chinese(f) +
  #                  HIY "真气急剧迸发，陡然一声巨啸。\n" NOR;
  # C 侧被 `+ to_chinese(f) +` 切成两段，E 侧同粒度。
  defp roar_message(force),
    do: "$N深深吸入一囗气，体内" <> to_chinese(force) <> "真气急剧迸发，陡然一声巨啸。\n"

  # LPC: tell_object(ob[i], HIR "突然间你只觉两耳一阵轰鸣，眼前金"
  #                    "星乱冒，整个头便是要裂开一般。\n" NOR);
  @doc false
  def victim_hurt_message,
    do: "突然间你只觉两耳一阵轰鸣，眼前金星乱冒，整个头便是要裂开一般。\n"

  # LPC: switch (random(3)) { case 0/1/default: msg = ...; }
  #      message("vision", msg, environment(ob[i]), ({ob[i]}));
  # 受害者伤害/昏迷由真实实现的目标侧 `resolve_incoming/4` 结算，此处仅保留旁观文案。
  # C 侧 "突然只见" + ob[i]->name() + "两手抱头，…" 被显式 `+` 切成两段，E 侧同粒度。
  @doc false
  def victim_vision_message(roll, name) do
    case roll do
      0 ->
        "突然只见" <>
          to_string(name) <> "两手抱头，双目凸出，嘴角泛出些许白沫，喉咙咯咯作响。\n"

      1 ->
        "顿时听得" <>
          to_string(name) <> "一声惨叫，两眼发直，全身不住颤抖，蓦地呕出一口鲜血。\n"

      _ ->
        "却见" <>
          to_string(name) <> "竟摔倒在地，发出声声哀嚎，双目双耳及鼻孔均渗出丝丝鲜血。\n"
    end
  end

  # LPC: to_chinese(f) —— 引擎未维护内功 id→中文名 表，保留 id 原样
  # （同 `sanku_shengong/dispel.ex` 的对齐副本约定）。
  defp to_chinese(name), do: name
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // roar.c
  # // By Vin for heros.cn
  # 
  # #include <ansi.h>
  # inherit F_CLEAN_UP;
  # 
  # int exert(object me, object target)
  # {
  #         object *ob;
  #         int f, i, skill, damage;
  #         string msg;
  # 
  #         f = me->query_skill_mapped("force");
  #         skill = me->query_skill("force");
  # 
  #         if (me->query_skill_mapped("force") != "longxiang-gong"
  #            && me->query_skill_mapped("force") != "tianhuan-shenjue"
  #            && me->query_skill_mapped("force") != "huntian-qigong"
  #            && me->query_skill_mapped("force") != "jiuyang-shengong"
  #            && me->query_skill_mapped("force") != "jiuyin-shengong"
  #            && me->query_skill_mapped("force") != "kuihua-mogong"
  #            && me->query_skill_mapped("force") != "xixing-dafa"
  #            && me->query_skill_mapped("force") != "zhanshen-xinjing"
  #            && me->query_skill_mapped("force") != "yijinjing"
  #            && me->query_skill_mapped("force") != "hunyuan-gong")
  #                 return notify_fail("你所学的内功中没有这种功能。\n");
  # 
  #         if (skill < 180)
  #                 return notify_fail("你的内功修为不够。\n");
  # 
  #         if (environment(me)->query("no_fight"))
  #                 return notify_fail("在这里不能攻击他人。\n");
  # 
  #         // 执行天书任务的特殊房间防止龙吟中断剧情。
  #         if (environment(me)->query("skybook"))
  #                 return notify_fail("在这里不能攻击他人。\n");
  # 
  #         if ((int)me->query("neili") < 800)
  #                 return notify_fail("你的真气不够。\n");
  # 
  #         me->add("neili", -800);
  # 
  #         me->start_busy(5);
  # 
  #         switch (f)
  #         {
  #         case "longxiang-gong" :
  #                 msg = HIW "$N" HIW "运转真气，面无表情，歌声如梵唱般"
  #                       "贯入众人耳中。\n" NOR;
  #                 break;
  # 
  #         case "huntian-qigong" :
  #                 msg = HIY "$N" HIY "深深吸入一囗气，运足内力发出一阵"
  #                       "长啸，音传百里，慑人心神。\n" NOR;
  #                 break;
  # 
  #         case "jiuyang-shengong" :
  #                 msg = HIY "$N" HIY "仰天长啸，声音绵泊不绝，众人无不"
  #                       "听得心驰神摇。\n" NOR;
  #                 break;
  # 
  #         case "jiuyin-shengong" :
  #                 msg = HIY "$N" HIY "气凝丹田，猛然一声断喝，声音远远"
  #                       "的传了开去，激荡不止。\n" NOR;
  #                 break;
  # 
  #         case "kuihua-mogong" :
  #                 msg = HIY "$N" HIY "蓦地极嘶长呼，声音凄厉之极，令人"
  #                       "毛骨悚然。\n" NOR;
  #                 break;
  # 
  #         case "yijinjing" :
  #         case "hunyuan-gong" :
  #                 msg = HIY "$N" HIY "深深吸入一囗气，运起金刚禅狮子吼"
  #                       "，发出惊天动地的一声巨吼。\n" NOR;
  #                 break;
  # 
  #         default:
  #                 msg = HIY "$N" HIY "深深吸入一囗气，体内" + to_chinese(f) +
  #                       HIY "真气急剧迸发，陡然一声巨啸。\n" NOR;
  #                 break;
  #         }
  #         msg += "\n";
  #         message_combatd(msg, me);
  # 
  #         ob = all_inventory(environment(me));
  # 
  #         for (i = 0; i < sizeof(ob); i++)
  #         {
  # 
  #                 if (! living(ob[i]) || ob[i] == me)
  #                         continue;
  # 
  #                 if (skill / 2 + random(skill / 2) < (int)ob[i]->query("con") * 2)
  #                         continue;
  # 
  #                 // 被死亡保护的玩家不受伤害
  #                 if ((int)ob[i]->query_condition("die_guard"))
  #                         continue;
  # 
  #                 damage = skill - ((int)ob[i]->query("max_neili") / 10);
  # 
  #                 if (damage > 0)
  #                 {
  #                         ob[i]->receive_damage("jing", damage * 2, me);
  # 
  #                         if ((int)ob[i]->query("neili") < skill * 2)
  #                                 ob[i]->receive_wound("jing", damage, me);
  # 
  #                         tell_object(ob[i], HIR "突然间你只觉两耳一阵轰鸣，眼前金"
  #                                            "星乱冒，整个头便是要裂开一般。\n" NOR);
  # 
  #                         switch (random(3))
  #                 {
  #                 case 0 :
  #                         msg = WHT "突然只见" + ob[i]->name() + WHT "两手"
  #                                       "抱头，双目凸出，嘴角泛出些许白沫，喉咙咯咯"
  #                                       "作响。\n" NOR;
  #                         break;
  # 
  #                 case 1 :
  #                         msg = WHT "顿时听得" + ob[i]->name() + WHT "一声"
  #                                       "惨叫，两眼发直，全身不住颤抖，蓦地呕出一口"
  #                                       "鲜血。\n" NOR;
  #                         break;
  # 
  #                 default :
  #                         msg = WHT "却见" + ob[i]->name() + WHT "竟摔倒在"
  #                                       "地，发出声声哀嚎，双目双耳及鼻孔均渗出丝丝"
  #                                       "鲜血。\n" NOR;
  #                         break;
  #                 }
  #                         message("vision", msg, environment(ob[i]), ({ob[i]}));
  # 
  #                         if ((int)ob[i]->query("jing") < 1
  #                            || (int)ob[i]->query("eff_jing") < 1)
  #                                 ob[i]->unconcious(me);
  # 
  #                         if (objectp(ob[i]) && ! living(ob[i]))
  #                         {
  #                                 ob[i]->add("jing", 10);
  #                                 ob[i]->add("eff_jing", 10);
  #                         }
  #                 }
  #                 me->want_kill(ob[i]);
  #                 me->fight_ob(ob[i]);
  #                 ob[i]->kill_ob(me);
  #         }
  #         return 1;
  # }
end
