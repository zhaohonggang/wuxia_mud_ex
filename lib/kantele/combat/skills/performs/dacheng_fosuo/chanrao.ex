defmodule Kantele.Combat.Skills.Performs.DachengFosuo.Chanrao do
  @moduledoc """
  缠绕诀「chanrao」（对照 `kungfu/skill/dacheng-fosuo/chanrao.c`，inherit F_SSERVER）

  大乘佛索（鞭 whip）攻击绝招：要求内力 >= 500、大乘佛索 >= 80、鞭已激发映射；
  按 combat_exp / dex 判定命中，命中令目标忙乱（dacheng-fosuo/20+2），
  出招方固定消耗内力 200。
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

  @perform_id "dacheng-fosuo/chanrao"
  @move_name "缠绕诀"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_weapon(combat, stats),
         :ok <- check_neili(character),
         :ok <- check_target_busy(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! target || !target->is_character() || !me->is_fighting(target))
  #          return notify_fail("缠绕诀只能对战斗中的对手使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "缠绕诀只能对战斗中的对手使用。\n"}
    end
  end

  # LPC: if (me->query_skill("dacheng-fosuo",1) < 80)
  #          return notify_fail("你的大乘佛索还不够娴熟，不会使用缠绕诀。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "dacheng-fosuo") < 80 do
      {:error, "你的大乘佛索还不够娴熟，不会使用缠绕诀。\n"}
    else
      :ok
    end
  end

  # LPC: if (!weapon || weapon->query("skill_type") != "whip"
  #     || me->query_skill_mapped("whip") != "dacheng-fosuo")
  #          return notify_fail("你现在无法使用缠绕诀。\n");
  defp check_weapon(combat, stats) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "whip" &&
         Stats.mapped(stats, "whip") == "dacheng-fosuo" do
      :ok
    else
      {:error, "你现在无法使用缠绕诀。\n"}
    end
  end

  # LPC: if (me->query("neili") < 500)
  #          return notify_fail("你的内力不够。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (target->is_busy())
  #          return notify_fail(target->name() + "目前正自顾不暇，放胆攻击吧。\n");
  defp check_target_busy(target) do
    if Combat.busy?(target.meta.combat) do
      {:error, target.name <> "目前正自顾不暇，放胆攻击吧。\n"}
    else
      :ok
    end
  end

  defp apply_perform(conn, character, target, stats) do
    # LPC: me->start_perform(5, "缠绕诀");
    _move_label = "缠绕诀"

    # LPC: msg = HIG "$N使出缠绕诀，鞭子一挥向$n的双腿卷去！\n";
    start_msg = "$N使出缠绕诀，鞭子一挥向$n的双腿卷去！\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    # LPC: me->start_busy(random(2));
    level = Stats.skill(stats, "dacheng-fosuo")

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: stats.combat_exp,
        dp: target.meta.stats.combat_exp,
        adex: stats.dex,
        tdex: target.meta.stats.dex,
        level: level,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
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
    ap = Map.get(data, :ap, 0)
    dp = Map.get(data, :dp, 0)
    adex = Map.get(data, :adex, 0)
    tdex = Map.get(data, :tdex, 0)
    level = Map.get(data, :level, 0)
    rng = Map.get(data, :rng, &:rand.uniform/1)

    # LPC: if ((random(me->query("combat_exp")) > target->query("combat_exp")/2)
    #       || (random(me->query_dex()) > target->query_dex()/2))
    hit = Engine.rand(rng, max(ap, 1)) > div(dp, 2) or
          Engine.rand(rng, max(adex, 1)) > div(tdex, 2)

    if hit do
      # LPC: msg += HIY "结果$p被$P一卷，两条腿被结结实实的捆起来，在地上无法爬起。\n" NOR;
      #      target->start_busy((int)me->query_skill("dacheng-fosuo",1)/20+2);
      combat = Combat.start_busy(character.meta.combat, div(level, 20) + 2)
      character = %{character | meta: %{character.meta | combat: combat}}

      hit_msg = "结果$p被$P一卷，两条腿被结结实实的捆起来，在地上无法爬起。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: me->start_busy(random(2));  me->add("neili", -200);
      Performs.feedback(attacker, 200, Engine.rand(rng, 2))
    else
      # LPC: msg += HIW "可是$p看破了$P的缠绕诀，身子一跃便躲开了。\n" NOR;
      #      me->start_busy(2);
      miss_msg = "可是$p看破了$P的缠绕诀，身子一跃便躲开了。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      # LPC: me->start_busy(2);  me->add("neili", -200);
      Performs.feedback(attacker, 200, 2)
    end

    conn
    |> put_character(character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
