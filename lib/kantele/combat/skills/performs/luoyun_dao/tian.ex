defmodule Kantele.Combat.Skills.Performs.LuoyunDao.Tian do
  @moduledoc """
  天刀落云式「tian」（对照 `kungfu/skill/luoyun-dao/tian.c`）

  洛云刀法连击绝招：消耗真气 `attack_time*20`，对战斗中对手出招。

  差异（TODO(migrate)）：
  - LPC 仅 `level:luoyun-dao>=100`；本版逐条对齐各门槛；
  - `attack_time = 4 + random(ap/40)`（初值 4，上限 8）；
  - 命中判定：`ap/2 + rand(ap) > dp`（dp=dodge），命中/失手各一句；
  - 随后 `attack_time` 次 `COMBAT_D->do_attack` 折算为连击伤害。
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
  alias Kantele.Character.Vitals

  @perform_id "luoyun-dao/tian"
  @move_name "「天刀落云式」"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- check_target(combat),
         :ok <- check_weapon(combat),
         {:ok, level} <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, level)
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
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "blade" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    level = Stats.skill(stats, "luoyun-dao")

    if level < 100 do
      {:error, "你的落云刀法不够娴熟，难以施展#{@move_name}。\n"}
    else
      {:ok, level}
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "blade") == "luoyun-dao" do
      :ok
    else
      {:error, "你没有激发落云刀法，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你目前的真气不够，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, level) do
    weapon = Combat.weapon(character.meta.combat)
    wn = weapon && Map.get(weapon, :name)
    ap = Stats.skill(character.meta.stats, "blade")

    # LPC: msg = HIY "\n$N" HIY "将手中" + wn + HIY "立于胸前，施出绝招「" HIW "天"
    #           "刀落云式" HIY "」，$N身法陡然加快，手中" + wn + HIY "连连挥出，犹"
    #           "如万马奔腾般袭向$n" HIY "。" NOR;
    # NOTE: wn 把起始文案拆成三段字面量。
    s1 = "\n$N将手中"
    s2 = "立于胸前，施出绝招「天刀落云式」，$N身法陡然加快，手中"
    s3 = "连连挥出，犹如万马奔腾般袭向$n。"
    start_msg = s1 <> (wn || "") <> s2 <> (wn || "") <> s3
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        level: level,
        ap: ap,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @doc false
  def resolve_incoming(conn, character, attacker, data) do
    ap = max(Map.get(data, :ap, 0), 1)
    level = max(Map.get(data, :level, 0), 1)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dp = Stats.skill(character.meta.stats, "dodge")
    bindings = [n1: attacker.name, n2: character.name]

    # LPC: attack_time = 4; ... attack_time += random(ap / 40);
    #      if (attack_time > 8) attack_time = 8;
    attack_time = min(4 + Engine.rand(rng, max(div(ap, 40), 1)), 8)

    conn =
      if div(ap, 2) + Engine.rand(rng, ap) > dp do
        # LPC: msg = HIG "$n" HIG "见$P" HIG "这招来势汹涌，势不可"
        #            "挡，被$N" HIG "攻得连连后退。\n" NOR;
        Broadcast.publish(conn, "$n见$P这招来势汹涌，势不可挡，被$N攻得连连后退。\n", bindings)
      else
        # LPC: msg = HIC "$n" HIC "见$N" HIC "这几刀来势迅猛无比，毫"
        #            "无破绽，只得小心应付。\n" NOR;
        Broadcast.publish(conn, "$n见$N这几刀来势迅猛无比，毫无破绽，只得小心应付。\n", bindings)
      end

    # LPC: for (i = 0; i < attack_time; i++) COMBAT_D->do_attack(me, target, weapon, 0);
    # 折算：每击 level/10 基础伤害 + 命中判定。
    per_hit = max(div(level, 10), 1)

    damage =
      Enum.reduce(1..attack_time, 0, fn _, acc ->
        if div(ap, 2) + Engine.rand(rng, ap) > dp do
          acc + per_hit + Engine.rand(rng, per_hit)
        else
          acc
        end
      end)

    vitals =
      character.meta.vitals
      |> Vitals.damage(:qi, damage)
      |> Vitals.wound(:qi, div(damage, 3))

    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add("neili", -attack_time * 20); me->start_busy(1 + random(attack_time));
    Performs.feedback(attacker, attack_time * 20, 1 + Engine.rand(rng, attack_time))

    put_character(conn, character)
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "luoyun-dao/tian",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
