defmodule Kantele.Combat.Skills.Performs.Force.Tianmo do
  @moduledoc """
  exert「天魔解体大法」（source force/tianmo.c）

  极限门槛（按 `.c` 顺序）：未在运功 → `str>=30 || con>=30` → 真气>=8000 →
  `shen <= -10000000` → `martial-cognize>=300 && force>=300`。
  设真气为 0；`qi`/`jing` 各受 `skill + shen_lvl + random(1000)` 的
  直接伤害与创伤（`eff_*` 同步下降）；临时 `str/int/con/dex` 各 +自身值、
  `attack` +count、`damage`/`unarmed_damage` +`str*3`、每个已映射武学技能
  +count/2（`count = (shen_lvl + skill)/4`，`shen_lvl = int((-shen)^(1/3))`）；
  战斗中忙乱 3。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.Force.Tianmo`（`skills/force_tianmo.ex`）
    的 `Performs.Simple` spec，本文件为并存的对齐副本（仅供文案对齐）；
  - `.c` 的 `add_temp` 折合 `Combat.apply_temp/2` + `Buff{key: "tianmo"}`
    （引擎以 buff 记录久效状态，供 `heal` 等判定）；
  - LPC `eff_qi`/`eff_jing` 对应本引擎 `vitals.max_qi`/`vitals.max_jing`；
  - 本文件按 `.c` 使用 `:rand.uniform/1`（custom 效果不接受注入 rng）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast

  @move_name "「天魔解体大法」"

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
    with :ok <- check_not_powering_up(character),
         :ok <- check_attributes(character),
         :ok <- check_neili(character),
         :ok <- check_shen(character),
         :ok <- check_levels(character) do
      :ok
    end
  end

  # LPC: if (me->query_temp("tianmo")) return notify_fail("你已经在运功中了。\n");
  defp check_not_powering_up(character) do
    if Combat.buff_active?(character.meta.combat, "tianmo") do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("str") < 30 && me->query("con") < 30)
  #        return notify_fail("你的资质不适合使用" TIANMO "。\n");
  defp check_attributes(character) do
    stats = character.meta.stats

    if (stats.str || 0) < 30 and (stats.con || 0) < 30 do
      {:error, "你的资质不适合使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 8000) return notify_fail("你的内力不够!");
  defp check_neili(character) do
    if character.meta.vitals.neili < 8000 do
      {:error, "你的内力不够!\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query("shen") > -10000000)
  #        return notify_fail("你还没有入魔，无法使用" TIANMO "。\n");
  defp check_shen(character) do
    if (character.meta.stats.shen || 0) > -10_000_000 do
      {:error, "你还没有入魔，无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("martial-cognize", 1) < 300 ||
  #         (int)me->query_skill("force", 1) < 300)
  #        return notify_fail("你的修行还不够,无法使用" TIANMO "。\n");
  defp check_levels(character) do
    stats = character.meta.stats

    if Stats.skill(stats, "martial-cognize") < 300 or Stats.skill(stats, "force") < 300 do
      {:error, "你的修行还不够,无法使用#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_effect(conn, character) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    # LPC: shen_lvl = to_int(pow(to_float(-shen), 1.0 / 3));
    #      skill = me->query_skill("force", 1);
    #      count = (shen_lvl + skill) / 4;
    #      skills = keys(me->query_skill_map());
    skill = Stats.skill(stats, "force")
    shen = stats.shen || 0
    shen_lvl = :math.pow(-shen * 1.0, 1.0 / 3.0) |> floor()
    count = div(shen_lvl + skill, 4)
    mapped = stats.mapped |> Map.values() |> Enum.uniq()

    # LPC: me->set("neili", 0);
    #      me->receive_damage("qi", skill + shen_lvl + random(1000));
    #      me->receive_wound("qi", skill + shen_lvl + random(1000));
    #      me->receive_damage("jing", ...); me->receive_wound("jing", ...);
    damage = skill + shen_lvl + :rand.uniform(1000)

    vitals =
      vitals
      |> Map.put(:neili, 0)
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, damage)
      |> Vitals.damage(:jing, damage)
      |> Vitals.wound(:jing, damage)

    # LPC: add_temp("apply/str|int|con|dex", me->query(...))、apply/attack +count、
    #      apply/damage|unarmed_damage +str*3、每个 mapped 技能 +count/2。
    str = stats.str || 0

    applies = %{
      str: str,
      int: stats.int || 0,
      con: stats.con || 0,
      dex: stats.dex || 0,
      attack: count,
      damage: str * 3,
      unarmed_damage: str * 3
    }

    applies =
      Enum.reduce(mapped, applies, fn skill_id, acc ->
        Map.put(acc, skill_id, div(count, 2))
      end)

    # 久效状态以 buff 记录：到期（本招无到期时长）时按负值回收。
    buff = %Buff{
      key: "tianmo",
      applies: Map.new(applies, fn {key, value} -> {key, -value} end)
    }

    combat =
      character.meta.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # LPC: message_combatd(RED "$N蓦地大叫一声，喷出一口鲜血，"
    #                        "正是天下闻名的 " TIANMO "。\n" NOR, me);
    conn =
      Broadcast.publish(
        conn,
        "$N蓦地大叫一声，喷出一口鲜血，正是天下闻名的#{@move_name}。\n",
        n1: character.name
      )

    # LPC: if (me->is_fighting()) me->start_busy(3);
    combat =
      if Combat.fighting?(combat), do: Combat.start_busy(combat, 3), else: combat

    character = %{character | meta: %{character.meta | combat: combat}}

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // 天魔解体大法
  # //此buff下，不能yun heal，不能吃先天丹，无法中先天故事
  # 
  # #include <ansi.h>
  # #define TIANMO "「" RED "天魔解体大法" NOR "」"
  # 
  # inherit F_CLEAN_UP;
  # 
  # int exert(object me, object target)
  # {
  #     int shen, shen_lvl;
  #     int skill, count;
  #     int i;
  #     string *skills;
  # 
  #     shen = me->query("shen");
  #     shen_lvl = to_int(pow(to_float(-shen), 1.0 / 3));
  #     skill = me->query_skill("force", 1);
  #     count = (shen_lvl + skill) / 4;
  #     skills = keys(me->query_skill_map());
  # 
  #     if (me->query_temp("tianmo"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     if (me->query("str") < 30 && me->query("con") < 30)
  #         return notify_fail("你的资质不适合使用" TIANMO "。\n");
  # 
  #     if ((int)me->query("neili") < 8000)
  #         return notify_fail("你的内力不够!");
  # 
  #     if (me->query("shen") > -10000000)
  #         return notify_fail("你还没有入魔，无法使用" TIANMO "。\n");
  # 
  #     if ((int)me->query_skill("martial-cognize", 1) < 300 ||
  #         (int)me->query_skill("force", 1) < 300)
  #         return notify_fail("你的修行还不够,无法使用" TIANMO "。\n");
  # 
  #     me->set("neili", 0);
  #     me->receive_damage("qi", skill + shen_lvl + random(1000));
  #     me->receive_wound("qi", skill + shen_lvl + random(1000));
  #     me->receive_damage("jing", skill + shen_lvl + random(1000));
  #     me->receive_wound("jing", skill + shen_lvl + random(1000));
  # 
  #     message_combatd(RED "$N蓦地大叫一声，喷出一口鲜血，"
  #                         "正是天下闻名的 " TIANMO "。\n" NOR, me);
  # 
  #     me->add_temp("apply/str", me->query("str"));
  #     me->add_temp("apply/int", me->query("int"));
  #     me->add_temp("apply/con", me->query("con"));
  #     me->add_temp("apply/dex", me->query("dex"));
  #     //me->add_temp("apply/dodge", me->query("dex"));
  #     //me->add_temp("apply/parry", me->query("dex"));
  #     //me->add_temp("apply/force", me->query("con"));
  #     me->add_temp("apply/attack", count);
  #     me->add_temp("apply/damage", me->query("str") * 3);
  #     me->add_temp("apply/unarmed_damage", me->query("str") * 3);
  # 
  #     for (i = 0; i < sizeof(skills); i++)
  #     {
  #         me->add_temp("apply/" + skills[i], count / 2);
  #     }
  # 
  #     me->set_temp("tianmo", 1);
  # 
  #     if (me->is_fighting()) me->start_busy(3);
  # 
  #     return 1;
  # }
end
