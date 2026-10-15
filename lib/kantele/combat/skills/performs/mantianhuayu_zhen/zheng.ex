defmodule Kantele.Combat.Skills.Performs.MantianhuayuZhen.Zheng do
  @moduledoc """
  花雨金针「zheng」（对照 `kungfu/skill/mantianhuayu-zhen/zheng.c`）

  满天花雨掷金针绝技：手中须持 throwing 类暗器（≥20 枚）、
  满天花雨掷金针>=100、内功>=150、真气>=150、目标存活。扣 100 内力、
  掷出 10 枚暗器后，命中判定 `random(my_exp) > 目标combat_exp`
  （`my_exp = combat_exp + 满天花雨掷金针³/10`）：命中则连中
  `n = 1+random(2)` 并可能再叠加三次数，造成 `skill/4 + random(skill/4)`
  外伤；未命中则被躲过。攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `COMBAT_D->clear_ahinfo`/`query_ahinfo` 与逐枚 `hit_ob` 的附加信息未建模，
    折算为单次 wound 结算；`weapon->query("base_unit")` 未建模，省略；
  - `chinese_number` 折算为十进制字符串（同 `Kantele.World.Room`）；
  - LPC 无 can_perform 门槛，保留 perform_known 守卫（多 1 条信息性 EXTRA）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "mantianhuayu-zhen/zheng"

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

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你只能在战斗中对对手掷金针。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing")) ||
  #           (string)weapon->query("skill_type") != "throwing")
  defp check_anqi(character) do
    case handing_anqi(character) do
      nil -> {:error, "你现在手中并没有拿着暗器。\n"}
      anqi -> {:ok, anqi}
    end
  end

  # LPC: if (weapon->query_amount() < 20)
  defp check_anqi_amount(anqi) do
    if (Map.get(anqi.meta, :amount) || 1) < 20 do
      {:error, "至少要有二十枚暗器你才能施展花雨金针。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("mantianhuayu-zhen", 1)) < 100)
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "mantianhuayu-zhen")

    if level < 100 do
      {:error, "你的满天花雨掷金针不够娴熟，还不知怎么掷出金针。\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if ((int)me->query_skill("force") < 150)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功火候不够，无法掷出金针。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 150)
  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你内力不够了。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, anqi) do
    stats = character.meta.stats
    weapon_name = Map.get(anqi.meta, :name, "")

    # LPC: me->add("neili", -100); weapon->add_amount(-10); me->start_busy(2);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}
    combat = Combat.start_busy(character.meta.combat, 2)
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}
    character = consume_anqi(character, anqi, 10)

    # LPC: msg = HIY "$N" HIY "飞身跃起，右手一张，顿时洒出一片金芒，"
    #           "手中" + weapon->name() + HIY "如急风暴雨一般直射$n" HIY "而去！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N飞身跃起，右手一张，顿时洒出一片金芒，手中" <>
          weapon_name <> "如急风暴雨一般直射$n而去！\n",
        n1: character.name,
        n2: target.name
      )

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
    weapon_name = Map.get(data, :weapon_name, "")
    ob_exp = character.meta.stats.combat_exp
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(my_exp) > ob_exp)
    if Engine.rand(rng, my_exp) > ob_exp do
      # LPC: n = 1 + random(2); 若再三次判定通过则各 n += 1 + random(2);
      n = 1 + Engine.rand(rng, 2)

      n = if Engine.rand(rng, my_exp) > ob_exp, do: n + 1 + Engine.rand(rng, 2), else: n

      n =
        if Engine.rand(rng, max(div(my_exp, 2), 1)) > ob_exp,
          do: n + 1 + Engine.rand(rng, 2),
          else: n

      n =
        if Engine.rand(rng, max(div(my_exp, 4), 1)) > ob_exp,
          do: n + 1 + Engine.rand(rng, 2),
          else: n

      # LPC: target->receive_wound("qi", skill / 4 + random(skill / 4), me);
      wound = div(level, 4) + Engine.rand(rng, max(div(level, 4), 1))
      vitals = Vitals.wound(character.meta.vitals, :qi, wound)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += HIR "结果$p" HIR "一声惨嚎，连中了$P" HIR "发出的" HIR
      #           + chinese_number(n) + weapon->query("base_unit")
      #           + weapon->name() + HIR "。\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          "结果$p一声惨嚎，连中了$P发出的" <> chinese_number(n) <> weapon_name <> "。\n",
          bindings
        )

      put_character(conn, character)
    else
      # LPC: msg += "可是$p" HIG "躲过了$P" HIG "漫天射出的" + weapon->name()
      #           + HIG "。\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          "可是$p躲过了$P漫天射出的" <> weapon_name <> "。\n",
          bindings
        )

      conn
    end
  end

  # 手持暗器：inventory 中带 handing 标记且 skill_type=="throwing" 的实例
  defp handing_anqi(character) do
    Enum.find(character.inventory, fn item ->
      is_map(item.meta) and
        Map.get(item.meta, :handing) and
        Map.get(item.meta, :skill_type) == "throwing" and
        (Map.get(item.meta, :amount) || 1) >= 1
    end)
  end

  # LPC: weapon->add_amount(-10)（数量归零则移除该实例）
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

  defp chinese_number(n), do: Integer.to_string(n)

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "mantianhuayu-zhen/zheng",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end

  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // zheng.c
  # 
  # #include <ansi.h>
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill;
  #         int n;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail("你只能在战斗中对对手掷金针。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中并没有拿着暗器。\n");
  # 
  #         if (weapon->query_amount() < 20)
  #                 return notify_fail("至少要有二十枚暗器你才能施展花雨金针。\n");
  # 
  #         if ((skill = me->query_skill("mantianhuayu-zhen", 1)) < 100)
  #                 return notify_fail("你的满天花雨掷金针不够娴熟，还不知怎么掷出金针。\n");
  # 
  #         if ((int)me->query_skill("force") < 150)
  #                 return notify_fail("你的内功火候不够，无法掷出金针。\n");
  # 
  #         if ((int)me->query("neili") < 150)
  #                 return notify_fail("你内力不够了。\n");
  # 
  #        if (! living(target))
  #               return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -100);
  #         weapon->add_amount(-10);
  # 
  #         msg= HIY "$N" HIY "飞身跃起，右手一张，顿时洒出一片金芒，"
  #              "手中" + weapon->name() + HIY "如急风暴雨一般直射$n"
  #              HIY "而去！\n" NOR;
  # 
  #         me->start_busy(2);
  #         my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
  #         ob_exp = target->query("combat_exp");
  #         if (random(my_exp) > ob_exp)
  #         {
  #                 n = 1 + random(2);
  #                 if (random(my_exp) > ob_exp) n += 1 + random(2);
  #                 if (random(my_exp / 2) > ob_exp) n += 1 + random(2);
  #                 if (random(my_exp / 4) > ob_exp) n += 1 + random(2);
  #                 msg += HIR "结果$p" HIR "一声惨嚎，连中了$P" HIR "发出的" HIR +
  #                        chinese_number(n) + weapon->query("base_unit") +
  #                        weapon->name() + HIR "。\n" NOR;
  #                 target->receive_wound("qi", skill / 4 + random(skill / 4), me);
  #                 while (n--)
  #                 {
  #                         COMBAT_D->clear_ahinfo();
  #                         weapon->hit_ob(me, target,
  #                                        me->query("jiali") + 100 + n * 10);
  #                 }
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += "可是$p" HIG "躲过了$P" HIG "漫天射出的" +
  #                        weapon->name() + HIG "。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         me->reset_action();
  #         return 1;
  # }
end
