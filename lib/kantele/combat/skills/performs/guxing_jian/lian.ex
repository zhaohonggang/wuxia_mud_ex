defmodule Kantele.Combat.Skills.Performs.GuxingJian.Lian do
  @moduledoc """
  九星连珠「lian」（对照 `kungfu/skill/guxing-jian/lian.c`，inherit F_SSERVER）

  孤星剑法（剑 sword）连击绝招：要求真气 >= 300、guxing-jian >= 100、剑已激发
  映射；按 sword 与 dodge 判定命中，随后连续 do_attack（attack_time 次）。

  TODO(migrate): LPC 在命中后循环 do_attack(attack_time) 多次连击（attack_time
  起始 4，随 ap/40 增加，上限 8，消耗 neili = attack_time*20，busy = 1+random(attack_time)）。
  此处仅实现命中/落空文案与基础判定，连击循环待补全。
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

  @perform_id "guxing-jian/lian"
  @move_name "「九星连珠」"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_skill_level(stats),
         :ok <- check_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
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

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "#{@move_name}只能对战斗中的对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你所使用的武器不对，难以施展#{@move_name}。\n"}
    end
  end

  defp check_skill_level(stats) do
    if Stats.skill(stats, "guxing-jian") < 100 do
      {:error, "你的孤星剑法不够娴熟，难以施展#{@move_name}。\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "guxing-jian" do
      :ok
    else
      {:error, "你没有激发孤星剑法，难以施展#{@move_name}。\n"}
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

  defp apply_perform(conn, character, target, stats) do
    combat = character.meta.combat
    weapon = Combat.weapon(combat)
    weapon_name = weapon && Map.get(weapon, :name)

    # LPC: msg = HIW "\n$N" HIW "蓦的一声清啸，施出绝学「" HIM "九星连珠"
    #            HIW "」，手中" + weapon->name() + HIW "呼呼作响。霎时间"
    #            "孤星剑法剑招连绵涌出，此起彼伏，剑气笼罩$n" HIW "全身。" NOR;
    # NOTE: weapon->name() 将起始文案拆成两段字面量。
    p1 = "\n$N蓦的一声清啸，施出绝学「九星连珠」，手中"
    p2 = "呼呼作响。霎时间孤星剑法剑招连绵涌出，此起彼伏，剑气笼罩$n全身。"
    start_msg = p1 <> (weapon_name || "") <> p2
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    ap = Stats.skill(stats, "sword")
    dp = Stats.skill(target.meta.stats, "dodge")

    # TODO(migrate): 连击循环 attack_time = 4 + random(ap/40)（上限 8），
    #                neili -= attack_time*20，命中后循环 do_attack。
    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        ap: ap,
        dp: dp,
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
    rng = Map.get(data, :rng, &:rand.uniform/1)

    if div(ap, 2) + Engine.rand(rng, max(ap, 1)) > dp do
      # LPC: msg = HIY "$n" HIY "见$P" HIY "剑势汹涌，寒意顿生，竟"
      #            "被逼得连连后退，狼狈不已。\n" NOR;
      # TODO(migrate): 命中后循环 do_attack(attack_time) 连击。
      hit_msg = "$n见$P剑势汹涌，寒意顿生，竟被逼得连连后退，狼狈不已。\n"
      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 80, 1)

      conn
      |> put_character(character)
    else
      # LPC: msg = HIC "$n" HIC "见$N" HIC "这几剑来势迅猛无比，毫"
      #            "无破绽，只得小心应付。\n" NOR;
      miss_msg = "$n见$N这几剑来势迅猛无比，毫无破绽，只得小心应付。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      Performs.feedback(attacker, 80, 1)

      conn
      |> put_character(character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
end
