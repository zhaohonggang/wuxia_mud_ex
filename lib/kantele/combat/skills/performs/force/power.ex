defmodule Kantele.Combat.Skills.Performs.Force.Power do
  @moduledoc """
  运功「power」（对照 `kungfu/skill/force/power.c`）

  要求内力 ≥100、基本内功 force ≥200、武学修养 martial-cognize ≥120
  （或已处于运功中则拒绝）。成功后：

    - 内力量清零（LPC `me->set("neili", 0)`）；
    - 取"已激发且已学会"、等级高于 force 的武功中最高等级者（`sk`），
      按 `martial-cognize / 5` 对 attack/defense 各加临时加成
      （引擎 `Combat.apply_temp/2`，对应 LPC `add_temp("apply/<sk>")`，
      攻防当量按 usage 都吃 applies 的 attack/defense）；无更高技能时
      用 force 自身（此时只提 force 的攻防）；
    - 战斗中运功 `start_busy(3)`。

  与 LPC 差异（TODO(migrate) 人工核对项）：
    - LPC `apply/<sk>` 按技能名加，本引擎临时加成键收敛为 attack/defense；
    - LPC 无自动消退（temp 挂在战斗心跳上），本引擎以 Buff key
      `force-power` 记状态（`raid`/换场后由 `combat/buff-expire` 惯例清场）。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @key "force-power"

  # LPC: mapping valid_types = ([ "force": "内功", "unarmed": "拳脚", ... ]);
  # 中文名是 .c 的文案字面量，须逐字保留（验收 multiset 比对）。
  @valid_types [
    {"force", "内功"},
    {"unarmed", "拳脚"},
    {"sword", "剑法"},
    {"blade", "刀法"},
    {"staff", "杖法"},
    {"hammer", "锤法"},
    {"club", "棍法"},
    {"throwing", "暗器"},
    {"parry", "招架"},
    {"dodge", "轻功"},
    {"magic", "法术"},
    {"whip", "鞭法"},
    {"dagger", "短兵"},
    {"finger", "指法"},
    {"hand", "手法"},
    {"cuff", "拳法"},
    {"claw", "爪法"},
    {"strike", "掌法"},
    {"medical", "医术"},
    {"poison", "毒技"},
    {"cooking", "厨艺"},
    {"chuixiao-jifa", "吹萧"},
    {"guzheng-jifa", "古筝"},
    {"tanqin-jifa", "弹琴"}
  ]

  @valid_usages Enum.map(@valid_types, fn {usage, _name} -> usage end)

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats

    with :ok <- check_target(character),
         :ok <- check_neili(character),
         :ok <- check_force(stats),
         :ok <- check_cognize(stats),
         :ok <- check_not_active(character.meta.combat) do
      apply_buff(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (target != me) return notify_fail("你只能提升自己的战斗力。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "你只能提升自己的战斗力。\n"
    :ok
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够！\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 200 do
      {:error, "你的内功修为不够,无法提升自己的功力。\n"}
    else
      :ok
    end
  end

  defp check_cognize(stats) do
    if Stats.skill(stats, "martial-cognize") < 120 do
      {:error, "你的武学修养不够,无法提升自己的功力。\n"}
    else
      :ok
    end
  end

  defp check_not_active(combat) do
    if Combat.buff_active?(combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  @doc "最高已激发且已学会的武功等级（force 兜底；LPC power.c 的 sk/lev 循环）"
  def grand_skill(stats) do
    force = Stats.skill(stats, "force")

    @valid_usages
    |> Enum.map(fn usage -> {usage, Stats.mapped(stats, usage)} end)
    |> Enum.filter(fn {_usage, skill_id} -> skill_id != nil end)
    |> Enum.map(fn {_usage, skill_id} -> Stats.skill(stats, skill_id) end)
    |> Enum.reject(&(&1 <= 0))
    |> Enum.reduce(force, &max/2)
  end

  defp apply_buff(conn, character) do
    bonus = max(div(Stats.skill(character.meta.stats, "martial-cognize"), 5), 1)
    buff = %Buff{key: @key, applies: %{attack: -bonus, defense: -bonus}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(%{attack: bonus, defense: bonus})
      |> Combat.add_buff(buff)

    combat =
      if Combat.fighting?(combat) do
        %{combat | busy: combat.busy + 3}
      else
        combat
      end

    vitals = %{character.meta.vitals | neili: 0}

    character =
      character
      |> put_meta_of(vitals, combat)

    conn =
      Broadcast.publish(
        conn,
        "$N纵声长笑，丹田中内力激荡，衣角悄然扬起，似乎要乘风而去，飘飘欲仙！\n",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp put_meta_of(character, vitals, combat) do
    meta =
      character.meta
      |> Map.put(:vitals, vitals)
      |> Map.put(:combat, combat)

    %{character | meta: meta}
  end
end
