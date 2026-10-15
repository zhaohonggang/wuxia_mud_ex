defmodule Kantele.Combat.Skills.Performs.MantianXing.Shan do
  @moduledoc """
  星光闪烁「shan」（对照 `kungfu/skill/mantian-xing/shan.c`）

  满天星暗器绝技：手中须持 throwing 类暗器（≥3 枚）、满天星>=100、真气>=100、
  目标存活。扣 80 内力、掷出 3 枚暗器后，命中判定
  `random(my_exp) > 目标combat_exp`（`my_exp = combat_exp + 满天星³/10`）：
  命中造成 `满天星/3 + random(满天星/3)` 外伤；未命中则被闪过。攻击方忙乱 2。

  差异（TODO(migrate)）：
  - `COMBAT_D->clear_ahinfo`/`query_ahinfo`/`eff_status_msg` 与 `hit_ob`
    的附加信息未建模，折算为单次 wound 结算；
  - `weapon->query("base_unit")` 未建模，省略该插入段；
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

  @perform_id "mantian-xing/shan"
  @move_name "「星光闪烁」"

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
      [] -> {:error, "#{@move_name}只能在战斗中对对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing")) ||
  #           (string)weapon->query("skill_type") != "throwing")
  defp check_anqi(character) do
    case handing_anqi(character) do
      nil -> {:error, "你现在手中没有拿着暗器，难以施展#{@move_name}。\n"}
      anqi -> {:ok, anqi}
    end
  end

  # LPC: if (weapon->query_amount() < 3)
  defp check_anqi_amount(anqi) do
    if (Map.get(anqi.meta, :amount) || 1) < 3 do
      {:error, "至少要有三枚暗器才能施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((skill = me->query_skill("mantian-xing", 1)) < 100)
  defp check_skill_level(stats) do
    level = Stats.skill(stats, "mantian-xing")

    if level < 100 do
      {:error, "你的满天星不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不足，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, level, anqi) do
    stats = character.meta.stats
    weapon_name = Map.get(anqi.meta, :name, "")

    # LPC: weapon->add_amount(-3);
    character = consume_anqi(character, anqi, 3)

    # LPC: msg = HIY "$N" HIY "突然纵身向后一个翻滚，就在快落地的一瞬间，$n"
    #           HIY "陡然发现几点寒光闪烁不定地袭向自己！\n" NOR;
    conn =
      Broadcast.publish(
        conn,
        "$N突然纵身向后一个翻滚，就在快落地的一瞬间，$n陡然发现几点寒光闪烁不定地袭向自己！\n",
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(my_exp) > ob_exp)（ob_exp = target->query("combat_exp")）
    if Engine.rand(rng, my_exp) > character.meta.stats.combat_exp do
      # LPC: target->receive_wound("qi", skill / 3 + random(skill / 3), me);
      wound = div(level, 3) + Engine.rand(rng, max(div(level, 3), 1))

      vitals = Vitals.wound(character.meta.vitals, :qi, wound)
      character = %{character | meta: %{character.meta | vitals: vitals}}

      # LPC: msg += HIR "结果$p" HIR "反应不及，中了$P" + HIR "一"
      #           + weapon->query("base_unit") + weapon->name() + HIR "！\n" NOR;
      # C 侧被 `+` 切成 "结果$p反应不及，中了$P" 与 "一" 两段，故用列表保持同粒度。
      conn =
        Broadcast.publish(
          conn,
          Enum.join(["结果$p反应不及，中了$P", "一", weapon_name, "！\n"], ""),
          bindings
        )

      Performs.feedback(attacker, 80, 2)
      put_character(conn, character)
    else
      # LPC: msg += HIG "可是$p" HIG "从容不迫，轻巧的闪过了$P" HIG "发出的"
      #           + weapon->name() + HIG "。\n" NOR;
      conn =
        Broadcast.publish(
          conn,
          "可是$p从容不迫，轻巧的闪过了$P发出的" <> weapon_name <> "。\n",
          bindings
        )

      Performs.feedback(attacker, 80, 2)
      conn
    end
  end

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

  # LPC: weapon->add_amount(-3)（数量归零则移除该实例）
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

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "mantian-xing/shan",
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
  # #define SHAN "「" HIY "星光闪烁" NOR "」"
  # 
  # #include "/kungfu/skill/eff_msg.h";
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #         int skill/*, i*/, p/*, n*/;
  #         int my_exp, ob_exp;
  #         string pmsg;
  #         string msg;
  #         object weapon;
  # 
  #         if (userp(me) && ! me->query("can_perform/mantian-xing/shan"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(SHAN "只能在战斗中对对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("handing")) ||
  #             (string)weapon->query("skill_type") != "throwing")
  #                 return notify_fail("你现在手中没有拿着暗器，难以施展" SHAN "。\n");
  # 
  #         if (weapon->query_amount() < 3)
  #                 return notify_fail("至少要有三枚暗器才能施展" SHAN "。\n");
  # 
  #         if ((skill = me->query_skill("mantian-xing", 1)) < 100)
  #                 return notify_fail("你的满天星不够娴熟，难以施展" SHAN "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不足，难以施展" SHAN "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #         me->add("neili", -80);
  #         weapon->add_amount(-3);
  # 
  #         msg= HIY "$N" HIY "突然纵身向后一个翻滚，就在快落地的一瞬"
  #              "间，$n" HIY "陡然发现几点寒光闪烁不定地袭向自己！\n" NOR;
  # 
  #         me->start_busy(2);
  #         my_exp = me->query("combat_exp") + skill * skill / 10 * skill;
  #         ob_exp = target->query("combat_exp");
  #         if (random(my_exp) > ob_exp)
  #         {
  #                 msg += HIR "结果$p" HIR "反应不及，中了$P" + HIR "一" +
  #                        weapon->query("base_unit") + weapon->name() +
  #                        HIR "！\n" NOR;
  #                 target->receive_wound("qi", skill / 3 + random(skill / 3), me);
  #                 COMBAT_D->clear_ahinfo();
  #                 weapon->hit_ob(me, target, me->query("jiali") + 120);
  # 
  #                 p = (int)target->query("qi") * 100 / (int)target->query("max_qi");
  # 
  #                 if (stringp(pmsg = COMBAT_D->query_ahinfo()))
  #                         msg += pmsg;
  #                         msg += "( $n" + eff_status_msg(p) + " )\n";
  #                 message_combatd(msg, me, target);
  #         } else
  #         {
  #                 msg += HIG "可是$p" HIG "从容不迫，轻巧的闪过了$P" HIG "发出的" +
  #                        weapon->name() + HIG "。\n" NOR;
  #                 message_combatd(msg, me, target);
  #         }
  # 
  #         me->reset_action();
  #         return 1;
  # }
end
