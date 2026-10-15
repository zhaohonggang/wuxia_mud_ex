defmodule Kantele.Combat.Skills.Performs.DamoJian.Sanjue do
  @moduledoc """
  达摩三绝剑「sanjue」（对照 `kungfu/skill/damo-jian/sanjue.c`，inherit F_SSERVER）

  达摩剑法（剑 sword）连击绝技：三次 do_attack（apply/attack 0/100/200 后回退
  -300）；要求 dex>=30、force>=200、dodge>=200、sword>=200、neili>=150、
  sword 已激发映射 damo-jian。消耗内力 75，出招后忙乱 1+random(3)。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @perform_id "damo-jian/sanjue"

  @impl true
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with {:ok, target} <- target(combat),
         :ok <- check_weapon(combat),
         :ok <- check_dex(stats),
         :ok <- check_force(stats),
         :ok <- check_dodge(stats),
         :ok <- check_sword(stats),
         :ok <- check_neili(character),
         :ok <- check_mapped(stats) do
      apply_perform(conn, character, target)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「达摩三绝剑」只能在战斗中对对手使用。\n"}
    end
  end

  defp check_weapon(combat) do
    weapon = Combat.weapon(combat)

    if weapon && Map.get(weapon, :skill_type) == "sword" do
      :ok
    else
      {:error, "你使用的武器不对。\n"}
    end
  end

  defp check_dex(stats) do
    if Stats.query_dex(stats) < 30 do
      {:error, "你的身法不够，目前还不能使用这项绝技！\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功的修为不够，不能使用这一绝技！\n"}
    else
      :ok
    end
  end

  defp check_dodge(stats) do
    if Stats.skill(stats, "dodge") < 200 do
      {:error, "你的轻功修为不够，不能使用达摩三绝剑！\n"}
    else
      :ok
    end
  end

  defp check_sword(stats) do
    if Stats.skill(stats, "sword") < 200 do
      {:error, "你的剑法修为不够，目前不能使用达摩三绝剑！\n"}
    else
      :ok
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 150 do
      {:error, "你的真气不够，不能使用达摩三绝剑！\n"}
    else
      :ok
    end
  end

  defp check_mapped(stats) do
    if Stats.mapped(stats, "sword") == "damo-jian" do
      :ok
    else
      {:error, "你没有激发达摩剑，不能使用达摩三绝剑！\n"}
    end
  end

  defp apply_perform(conn, character, target) do
    # LPC: msg = HIC "$N" HIC "使出达摩剑的绝技「达摩三绝剑」，攻速陡然加快！\n" NOR;
    start_msg = "$N使出达摩剑的绝技「达摩三绝剑」，攻速陡然加快！\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name)

    # LPC: me->add("neili", -75); me->start_busy(1 + random(3));
    #      me->add_temp("apply/attack", 0/100/200); COMBAT_D->do_attack(me, target, weapon, 0);
    #      me->add_temp("apply/attack", -300);
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 75}
    combat = Combat.start_busy(character.meta.combat, 1 + Engine.rand(&:rand.uniform/1, 3))
    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    # TODO: 三次连击（apply/attack 0/100/200 回退 -300）对应 Engine.attack_round/3，
    #       需将 character/target 转为 Fighter 后调用，跨进程补全。
    _ = target

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
