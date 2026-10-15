defmodule Kantele.Combat.Skills.Performs.PangenCuojiefu.Cuo do
  @moduledoc """
  错字诀「cuo」（对照 `kungfu/skill/pangen-cuojiefu/cuo.c`）

  盘根错节斧绝技：需持锤、盘根错节斧>=100、内功>=120、max_neili>=800、
  真气>=100、激发 hammer 为盘根错节斧、目标未忙乱且存活。
  无条件扣 30 真气；命中判定 `random(盘根错节斧) > 目标parry/2`：
  命中令目标忙乱 `盘根错节斧/18 + 1` 轮；未命中令攻击方忙乱 2 轮。

  差异（TODO(migrate)）：
  - `.c` 的 `living(target)` 门槛由目标侧 `combat/perform-incoming` 的死亡检查兜底；
  - `target->is_busy()` 取引用快照（`%{id,pid,name,room_id}`）的 meta，缺 meta 时按「非忙」处理；
  - 攻击方忙乱经 `Performs.feedback/3` 由目标侧回传。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "pangen-cuojiefu/cuo"
  @move_name "「错字诀」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat
    rng = &:rand.uniform/1
    level = Stats.skill(stats, "pangen-cuojiefu")

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         {:ok, weapon} <- check_weapon(combat),
         :ok <- check_target_busy(target),
         :ok <- check_skill_level(level),
         :ok <- check_force(stats),
         :ok <- check_max_neili(character),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      send(target.pid, %Event{
        from_pid: self(),
        topic: "combat/perform-incoming",
        data: %{
          attacker: ref(character),
          perform_id: @perform_id,
          level: level,
          rng: rng
        }
      })

      apply_perform(conn, character, target, weapon)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/pangen-cuojiefu/cuo"))
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("weapon")) ||
  #          (string)weapon->query("skill_type") != "hammer")
  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "hammer" do
      {:ok, weapon}
    else
      {:error, "你使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if target_busy?(target) do
      {:error, "#{Map.get(target, :name)}目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp target_busy?(target) do
    case get_in(target, [:meta, :combat, :busy]) do
      busy when is_integer(busy) -> busy > 0
      _ -> false
    end
  end

  # LPC: if ((level = me->query_skill("pangen-cuojiefu", 1)) < 100)
  defp check_skill_level(level) do
    if level < 100 do
      {:error, "你盘根错节斧不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query_skill("force") < 120)
  defp check_force(stats) do
    if Stats.skill(stats, "force") < 120 do
      {:error, "你的内功火候不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("max_neili") < 800)
  defp check_max_neili(character) do
    if character.meta.vitals.max_neili < 800 do
      {:error, "你的内力修为不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 100)
  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你现在真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_skill_mapped("hammer") != "pangen-cuojiefu")
  defp check_mapped(stats) do
    if Stats.mapped(stats, "hammer") == "pangen-cuojiefu" do
      :ok
    else
      {:error, "你没有激发盘根错节斧，难以施展#{@move_name}。\n"}
    end
  end

  defp apply_perform(conn, character, target, weapon) do
    weapon_name = Map.get(weapon, :name, "")

    # LPC: me->add("neili", -30);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 30}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: msg = HIR "$N" HIR "高举手中" + weapon->name() + HIR "，陡然一声断喝，朝着$n"
    #           HIR "猛挥数斧，气势如虹。\n" NOR;
    conn
    |> Broadcast.publish(
      "$N高举手中" <> weapon_name <> "，陡然一声断喝，朝着$n猛挥数斧，气势如虹。\n",
      n1: character.name,
      n2: target.name
    )
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
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: if (random(level) > (int)target->query_skill("parry", 1) / 2)
    dp = div(Stats.skill(character.meta.stats, "parry"), 2)

    if Engine.rand(rng, level) > dp do
      # LPC: msg += HIR "$p" HIR "见$P" HIR "来势汹涌，不得不中途" "变招，这一下登时便失了先机！\n" NOR;
      #      target->start_busy(level / 18 + 1);
      combat = Combat.start_busy(character.meta.combat, div(level, 18) + 1)
      character = %{character | meta: %{character.meta | combat: combat}}

      conn
      |> Broadcast.publish(
        "$p见$P来势汹涌，不得不中途变招，这一下登时便失了先机！\n",
        bindings
      )
      |> put_character(character)
    else
      # LPC: msg += CYN "可是$p" CYN "看破$P" CYN "招式的来路，斜" "斜跳开，使这招未起到丝毫作用。\n" NOR;
      #      me->start_busy(2);
      Performs.feedback(attacker, 0, 2)

      conn
      |> Broadcast.publish("可是$p看破$P招式的来路，斜斜跳开，使这招未起到丝毫作用。\n", bindings)
      |> put_character(character)
    end
  end

  defp ref(character) do
    %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  end

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "pangen-cuojiefu/cuo",
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
  # #define CUO "「" HIR "错字诀" NOR "」"
  # 
  # inherit F_SSERVER;
  # 
  # int perform(object me, object target)
  # {
  #     object weapon;
  #     int level;
  #     string msg;
  # 
  #         if (userp(me) && ! me->query("can_perform/pangen-cuojiefu/cuo"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #         if (! target) target = offensive_target(me);
  # 
  #         if (! target || ! me->is_fighting(target))
  #                 return notify_fail(CUO "只能对战斗中的对手使用。\n");
  # 
  #         if (! objectp(weapon = me->query_temp("weapon")) ||
  #             (string)weapon->query("skill_type") != "hammer")
  #                 return notify_fail("你使用的武器不对，难以施展" CUO "。\n");
  # 
  #         if (target->is_busy())
  #                 return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  # 
  #         if ((level = me->query_skill("pangen-cuojiefu", 1)) < 100)
  #                 return notify_fail("你盘根错节斧不够娴熟，难以施展" CUO "。\n");
  # 
  #         if ((int)me->query_skill("force") < 120)
  #                 return notify_fail("你的内功火候不够，难以施展" CUO "。\n");
  # 
  #         if ((int)me->query("max_neili") < 800)
  #                 return notify_fail("你的内力修为不够，难以施展" CUO "。\n");
  # 
  #         if ((int)me->query("neili") < 100)
  #                 return notify_fail("你现在真气不够，难以施展" CUO "。\n");
  # 
  #         if (me->query_skill_mapped("hammer") != "pangen-cuojiefu")
  #                 return notify_fail("你没有激发盘根错节斧，难以施展" CUO "。\n");
  # 
  #         if (! living(target))
  #                 return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  # 
  #     msg = HIR "$N" HIR "高举手中" + weapon->name() + HIR "，陡然一声断喝，朝着$n"
  #               HIR "猛挥数斧，气势如虹。\n" NOR;
  # 
  #         me->add("neili", -30);
  #         if (random(level) > (int)target->query_skill("parry", 1) / 2)
  #         {
  #         msg += HIR "$p" HIR "见$P" HIR "来势汹涌，不得不中途"
  #                        "变招，这一下登时便失了先机！\n" NOR;
  #                 target->start_busy(level / 18 + 1);
  #     } else
  #         {
  #         msg += CYN "可是$p" CYN "看破$P" CYN "招式的来路，斜"
  #                        "斜跳开，使这招未起到丝毫作用。\n" NOR;
  #         me->start_busy(2);
  #     }
  #     message_combatd(msg, me, target);
  # 
  #     return 1;
  # }
end
