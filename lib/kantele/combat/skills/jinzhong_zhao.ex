defmodule Kantele.Combat.Skills.JinzhongZhao do
  @moduledoc """
  金钟罩（对照 `kungfu/skill/jinzhong-zhao.c`）

  护体内功载体：`valid_enable("parry")`。

  绝招实现见 `lib/kantele/combat/skills/performs/jinzhong_zhao/`。

  差异（TODO(migrate)）：
  - LPC `valid_learn` 的 max_neili>=4000 门槛本版以 force>=350+str/con>=33 代理；
  - LPC `valid_damage` 被动（护体罡气反弹）与 `query_effect_parry` 未建模。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "jinzhong-zhao"

  @impl true
  def valid_damage(attacker, victim, damage, _action, rng) do
    if Map.get(victim.skills, "jinzhong-zhao", 0) < 150 or victim.neili < 400 or
         not is_nil(attacker.weapon_name) do
      {damage, nil}
    else
      ap = Map.get(attacker.skills, "force", 0) * 12 + attacker.max_neili
      dp = Map.get(victim.skills, "force", 0) * 12 + victim.neili

      if div(dp, 2) + rng.(max(dp, 1)) - 1 > ap do
        {0, jinzhong_msg(rng)}
      else
        {damage, nil}
      end
    end
  end

  defp jinzhong_msg(rng) do
    case rng.(5) - 1 do
      0 -> "$n不退反进，一股无形气流直把$N副得难以招架，连连退后。\n"
      1 -> "只见$N移至$n身后，猛然一招朝$n的后心拍去，但不料反被震退数步。\n"
      2 -> "$N冲破$n的无形真气，接着全力一掌拍在$n身上，可万万无料到另一股气墙直撞而出，将$N的攻击硬生生地弹开。\n"
      3 -> "$N一招拍在$n身上，可见$n不闪不避，只是全身迅猛一抖，$N的力道反被护体罡气震退了开来。\n"
      _ -> "$n见$N来势凶凶攻来，不由嘴角轻轻一笑，飞身一跃直往$N的力道撞去，竟把$N震个人仰马翻，狼狈不堪!\n"
    end
  end

  @impl true
  def valid_enable(usage), do: usage == "parry"

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 350 ->
        {:error, "你的内功火候不够，难以修习这等神功。\n"}

      stats.con < 33 ->
        {:error, "你的先天根骨太差了，难以修习这等神功。\n"}

      stats.str < 33 ->
        {:error, "你的先天臂力太差了，难以修习这等神功。\n"}

      Stats.skill(stats, "force") < Stats.skill(stats, id()) ->
        {:error, "你的基本内功水平有限，无法领会更高深的金钟罩。\n"}

      true ->
        :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 未建模）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def perform_list() do
    %{"zhao" => Kantele.Combat.Skills.Performs.JinzhongZhao.Zhao}
  end
end
