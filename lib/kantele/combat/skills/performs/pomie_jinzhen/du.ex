defmodule Kantele.Combat.Skills.Performs.PomieJinzhen.Du do
  @moduledoc """
  金针渡劫「du」（对照 `kungfu/skill/pomie-jinzhen/du.c`）

  破灭金针暗器绝技：手中须持 throwing 类暗器（≥30 枚）、破灭金针>=150、
  内功>=200、真气>=150、目标存活。掷尽全部暗器，扣 100 内力、忙乱 2。
  命中判定 `random(my_exp) > 目标combat_exp`
  （`my_exp = combat_exp + 破灭金针³/10`）：命中按 `n = 4+random(4)` 起算，
  再以 `random(my_exp)` / `random(my_exp/2)` / `random(my_exp/4)` 三档各追加
  `4+random(4)`（末档为 `4+random(8)`），上限为暗器数量；造成
  `破灭金针 + random(破灭金针)` 外伤与 `破灭金针/2 + random(破灭金针/2)` 内伤。

  差异（TODO(migrate)）：
  - `COMBAT_D->clear_ahinfo`/`query_ahinfo`/`eff_status_msg` 与 `hit_ob`
    的附加信息未建模，折算为单次伤害结算；
  - `chinese_number(n)` 折算为 `Integer.to_string/1`（不引入额外中文字面量）；
  - `.c` 的数量门槛为 30（文案仍写「二十枚」，逐字保留）；
  - 引子在攻击方广播，命中/落空在目标侧结算。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "pomie-jinzhen/du"
  @move_name "「金针渡劫」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, anqi} <- check_anqi(character),
         :ok <- check_anqi_amount(anqi),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_force(stats),
         :ok <- check_neili(character) do
      apply_perform(conn, character, target, level, anqi)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/pomie-jinzhen/du"))
  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing"))
  #         || (string)weapon->query("skill_type") != "throwing")
  defp check_anqi(character) do
    case handing_anqi(character) do
      nil -> {:error, "你现在手中并没有拿着暗器。\n"}
      anqi -> {:ok, anqi}
    end
  end

  # LPC: if (weapon->query_amount() < 30)
  defp check_anqi_amount(anqi) do
    if (Map.get(anqi.meta, :amount) || 1) < 30 do
      {:error, "你至少要拿有二十枚暗器才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("pomie-jinzhen", 1)) < 150)
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "pomie-jinzhen")

    if level < 150 do
      {:error, "你的破灭金针不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 200)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你现在的真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, anqi) do
    stats = character.meta.stats
    weapon_name = Map.get(anqi.meta, :name, "")
    amount = Map.get(anqi.meta, :amount) || 1

    # LPC: weapon->set_amount(0);
    character = consume_anqi(character, anqi, amount)

    # LPC: msg = YEL "只见$N" YEL "右手一扬，施出「" HIR "金针渡劫" NOR +
    #           YEL "」，手中" + weapon->name() + YEL "如急风暴雨般向$n"
    #           YEL "射去！\n" NOR;
    # C 侧被 `+` 切成 "只见$N右手一扬，施出「金针渡劫」" / "」，手中" 两段，
    # 故用列表保持同粒度。
    text =
      Enum.join(
        [
          "只见$N右手一扬，施出「金针渡劫",
          "」，手中",
          weapon_name,
          "如急风暴雨般向$n射去！\n"
        ],
        ""
      )

    conn = Broadcast.publish(conn, text, n1: character.name, n2: target.name)

    # LPC: my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
    my_exp = stats.combat_exp + div(level * level, 10) * level

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        my_exp: my_exp,
        amount: amount,
        weapon_name: weapon_name,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
      Broadcast.publish(conn, "对方都已经这样了，用不着这么费力吧？\n",
        n1: attacker.name,
        n2: character.name
      )
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    rng = Map.get(data, :rng, &:rand.uniform/1)
    level = max(Map.get(data, :level, 0), 1)
    my_exp = max(Map.get(data, :my_exp, 0), 1)
    amount = Map.get(data, :amount, 0)
    ob_exp = character.meta.stats.combat_exp
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(my_exp) > ob_exp)
    conn =
      if Engine.rand(rng, my_exp) > ob_exp do
        n = hit_count(rng, my_exp, ob_exp, amount)

        # LPC: target->receive_damage("qi", skill + random(skill), me);
        #      target->receive_wound("qi", skill / 2 + random(skill / 2), me);
        damage = level + Engine.rand(rng, level)
        wound = div(level, 2) + Engine.rand(rng, div(level, 2))

        vitals =
          character.meta.vitals
          |> Vitals.damage(:qi, damage)
          |> Vitals.wound(:qi, wound)

        character = %{character | meta: %{character.meta | vitals: vitals}}

        # LPC: msg += HIR "霎时间一片金芒笼罩$n" HIR "四方，听得一声"
        #           "惨叫，" + chinese_number(n) + "柱鲜血飞溅而出" "。\n" NOR;
        text =
          Enum.join(
            ["霎时间一片金芒笼罩$n四方，听得一声惨叫，", chinese_number(n), "柱鲜血飞溅而出。\n"],
            ""
          )

        conn = Broadcast.publish(conn, text, bindings)
        put_character(conn, character)
      else
        # LPC: msg += CYN "可是$n" CYN "丝毫不敢大意，当即左闪右" "避，躲开了所有的暗器。\n" NOR;
        Broadcast.publish(
          conn,
          "可是$n丝毫不敢大意，当即左闪右避，躲开了所有的暗器。\n",
          bindings
        )
      end

    # LPC: me->add("neili", -100); me->start_busy(2);
    Performs.feedback(attacker, 100, 2)

    conn
  end

  # LPC: n = 4 + random(4); 三档 random(my_exp/*) > ob_exp 各追加，上限为暗器数。
  defp hit_count(rng, my_exp, ob_exp, amount) do
    n = 4 + Engine.rand(rng, 4)
    n = if Engine.rand(rng, my_exp) > ob_exp, do: n + 4 + Engine.rand(rng, 4), else: n
    n = if Engine.rand(rng, div(my_exp, 2)) > ob_exp, do: n + 4 + Engine.rand(rng, 4), else: n
    n = if Engine.rand(rng, div(my_exp, 4)) > ob_exp, do: n + 4 + Engine.rand(rng, 8), else: n
    min(n, amount)
  end

  # LPC: chinese_number(n) —— 折算为十进制数字（不引入额外中文字面量）。
  defp chinese_number(n), do: Integer.to_string(n)

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  # （对应 LPC `me->query_temp("handing")`）
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        (Map.get(item.meta, :amount) || 1) >= 1
    end)
  end

  # LPC: weapon->set_amount(0)（数量归零则移除该实例）
  defp consume_anqi(character, anqi, n) do
    if anqi do
      amount = (Map.get(anqi.meta, :amount) || 1) - n

      inventory =
        if amount >= 1 do
          Enum.map(character.inventory, fn item ->
            if item == anqi, do: %{item | meta: Map.put(item.meta, :amount, amount)}, else: item
          end)
        else
          Enum.reject(character.inventory, &(&1 == anqi))
        end

      %{character | inventory: inventory}
    else
      character
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "pomie-jinzhen/du",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # #include <combat.h>
  # 
  # #define DU "「" YEL "金针渡劫" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # int perform(object me, object target)
  # {
  #         int skill, p;
  #         int n;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (userp(me) && ! me->query("can_perform/pomie-jinzhen/du"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(DU "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing"))
  #            || (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中并没有拿着暗器。\n");
  # 
  #         if (weapon->query_amount() < 30)
  #                 return notify_fail("你至少要拿有二十枚暗器才能施展" DU "。\n");
  # 
  #         if ((skill = me->query_skill("pomie-jinzhen", 1)) < 150)
  #                 return notify_fail("你的破灭金针不够娴熟，难以施展" DU "。\n");
  # 
  #         if ((int)me->query_skill("force") < 200)
  #                 return notify_fail("你的内功火候不够，难以施展" DU "。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你现在的真气不足，难以施展" DU "。\n");
  # 
  #         if (! living(target))
  #                return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         msg = YEL "只见$N" YEL "右手一扬，施出「" HIR "金针渡劫" NOR +
  #               YEL "」，手中" + weapon->name() + YEL "如急风暴雨般向$n"
  #               YEL "射去！\n" NOR;
  # 
  #         my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
  #         ob_exp = target->query("combat_exp");
  # 
  #         if (random(my_exp) > ob_exp)
  #         {
  #                 n = 4 + random(4);
  #                 if (random(my_exp) > ob_exp) n += 4 + random(4);
  #                 if (random(my_exp / 2) > ob_exp) n += 4 + random(4);
  #                 if (random(my_exp / 4) > ob_exp) n += 4 + random(8);
  #                 if (weapon->query_amount() < n) n = weapon->query_amount();
  # 
  #                 msg += HIR "霎时间一片金芒笼罩$n" HIR "四方，听得一声"
  #                        "惨叫，" + chinese_number(n) + "柱鲜血飞溅而出"
  #                        "。\n" NOR;
  # 
  #                 target->receive_damage("qi", skill + random(skill), me);
  #                 target->receive_wound("qi", skill / 2 + random(skill / 2), me);
  #             p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  #                 while (n--)
  #                 {
  #                         COMBAT_D->clear_ahinfo();
  #                         weapon->hit_ob(me, target, me->query("jiali") * 2 + 300 + n * 15);
  #                 }
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += CYN "可是$n" CYN "丝毫不敢大意，当即左闪右"
  #                        "避，躲开了所有的暗器。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  #         weapon->set_amount(0);
  #         me->add("neili", -100);
  #         me->start_busy(2);
  #         me->reset_action();
  #         return 1;
  # }
end
