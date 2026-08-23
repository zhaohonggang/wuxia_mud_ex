defmodule Kantele.Combat.Messages do
  @moduledoc """
  战斗中文文案库（对照 combatd.c 的 damage_msg/status_msg/winner_msg 等文案表）

  占位符约定（与 LPC message_vision 一致）：

  - `$N` 攻击者名字
  - `$n` 防守者名字
  - `$l` 受击部位
  - `$w` 兵器名
  """

  @type rng :: (pos_integer() -> pos_integer())

  @limbs ["头部", "胸口", "腹部", "左肩", "右臂", "双腿"]

  @dodge_msgs [
    "但是$n身子一侧，轻轻巧巧地避开了。\n",
    "可是$n一个斜步，正好从$w的锋芒旁滑了出去。\n",
    "$n脚下一错，堪堪避过这一击。\n",
    "然而$n早有防备，身形微晃便让了开去。\n"
  ]

  @parry_msgs [
    "$n举起$W，稳稳架开了这一招。\n",
    "却被$n横兵一封，「当」地一声格挡住了。\n",
    "$n侧身运力，硬生生把这一招封出门外。\n"
  ]

  @guard_msgs [
    "$N注视着$n的行动，企图寻找机会出手。\n",
    "$N正盯着$n的一举一动，随时准备发动攻势。\n",
    "$N缓缓地移动脚步，想要找出$n的破绽。\n",
    "$N目不转睛地盯着$n的动作，寻找进攻的最佳时机。\n",
    "$N慢慢地移动着脚步，伺机出手。\n"
  ]

  @winner_msgs [
    "\n$N哈哈大笑，说道：承让了！\n\n",
    "\n$N双手一拱，笑着说道：承让！\n\n",
    "\n$N胜了这招，向后跃开三尺，笑道：承让！\n\n",
    "\n$n向后退了几步，说道：这场比试算我输了，佩服，佩服！\n\n"
  ]

  @death_msgs [
    "\n$N扑在地上挣扎了几下，腿一伸，口中喷出几口鲜血，死了！\n\n",
    "\n$N闷哼一声，摇晃两下，扑倒在地再也没能起来，死了！\n\n"
  ]

  @doc "受击部位随机（combatd.c limbs）"
  def random_limb(rng), do: Enum.at(@limbs, rand(rng, length(@limbs)))

  @doc "闪避文案（query_dodge_msg 的通用版）"
  def dodge_msg(), do: Enum.random(@dodge_msgs)

  @doc "招架文案（query_parry_msg 的通用版），$W 为防守者兵器"
  def parry_msg(), do: Enum.random(@parry_msgs)

  @doc "对峙文案（guard_msg）"
  def guard_msg(), do: Enum.random(@guard_msgs)

  @doc "比试分出胜负的收场文案（winner_msg）"
  def winner_msg(), do: Enum.random(@winner_msgs)

  @doc "死亡文案（announce dead）"
  def death_msg(), do: Enum.random(@death_msgs)

  @doc "复活/苏醒文案（announce revive）"
  def revive_msg(), do: "\n$N慢慢睁开眼睛，清醒了过来。\n\n"

  @doc "未造成伤害"
  def no_damage_msg(), do: "结果没有造成任何伤害。\n"

  @doc """
  伤害分级文案（damage_msg/2），按伤害类型与数值分档

  `$p` 与 `$n` 同指防守者（保留 LPC 占位习惯）
  """
  def damage_msg(damage, type)

  def damage_msg(_damage, nil), do: no_damage_msg()

  def damage_msg(damage, type) when damage < 15 do
    case type do
      t when t in ["擦伤", "割伤"] -> "结果只是轻轻地划破$p的皮肉。\n"
      "刺伤" -> "结果只是轻轻地刺破$p的皮肉。\n"
      t when t in ["瘀伤", "震伤"] -> "结果只是轻轻地碰到，比拍苍蝇稍微重了点。\n"
      "内伤" -> "结果只是把$n打得退了半步，毫发无损。\n"
      "点穴" -> "结果只是轻轻的碰到$n的$l，根本没有点到穴道。\n"
      "抽伤" -> "结果只是在$n的皮肉上碰了碰，好象只蹭破点皮。\n"
      _ -> "结果只是勉强造成一处轻微#{type}！\n"
    end
  end

  def damage_msg(damage, type) when damage < 40 do
    case type do
      t when t in ["擦伤", "割伤"] -> "结果在$p$l划出一道细长的血痕。\n"
      "刺伤" -> "结果在$p$l刺出一个创口。\n"
      t when t in ["瘀伤", "震伤"] -> "结果在$p的$l造成一处瘀青。\n"
      "内伤" -> "结果$n痛哼一声，在$p的$l造成一处瘀伤。\n"
      "点穴" -> "结果$n痛哼一声，在$p的$l造成一处淤青。\n"
      "抽伤" -> "结果在$n$l抽出一道轻微的紫痕。\n"
      _ -> "结果造成轻微的#{type}！\n"
    end
  end

  def damage_msg(damage, type) when damage < 100 do
    case type do
      t when t in ["擦伤", "割伤"] -> "结果「嗤」地一声，$w已在$p$l划出一道伤口！\n"
      "刺伤" -> "结果「噗」地一声，$w已刺入了$n$l寸许！\n"
      t when t in ["瘀伤", "震伤"] -> "结果一击命中，$n的$l登时肿了一块老高！\n"
      "内伤" -> "结果一击命中，把$n打得痛得弯下腰去！\n"
      "点穴" -> "结果一击命中，$N点中了$n$l上的穴道，$n只觉一阵麻木！\n"
      "抽伤" -> "结果「啪」地一声在$n$l抽出一道长长的血痕！\n"
      _ -> "结果造成一处#{type}！\n"
    end
  end

  def damage_msg(damage, type) when damage < 200 do
    case type do
      t when t in ["擦伤", "割伤"] -> "结果「嗤」地一声，$w已在$p$l划出一道血淋淋的伤口！\n"
      "刺伤" -> "结果「噗」地一声，$w已刺进$n的$l，使$p不由自主地退了几步！\n"
      t when t in ["瘀伤", "震伤"] -> "结果「砰」地一声，$n退了两步！\n"
      "内伤" -> "结果$n脸色一下变得惨白，昏昏沉沉接连退了好几步！\n"
      "点穴" -> "结果$n闷哼了一声，脸上一阵青一阵白，登时觉得$l麻木！\n"
      "抽伤" -> "结果只听「啪」地一声，$n的$l被抽得皮开肉绽！\n"
      _ -> "结果造成颇为严重的#{type}！\n"
    end
  end

  def damage_msg(damage, type) when damage < 400 do
    case type do
      t when t in ["擦伤", "割伤"] ->
        "结果「嗤」地一声，$w已在$p$l划出一道又长又深的伤口，溅得$N满脸鲜血！\n"

      "刺伤" ->
        "结果「噗嗤」地一声，$w已在$p$l刺出一个血肉模糊的血窟窿！\n"

      t when t in ["瘀伤", "震伤"] ->
        "结果这一下「砰」地一声打得$n连退了好几步，差一点摔倒！\n"

      "内伤" ->
        "结果重重地击中，$n「哇」地一声吐出一口鲜血！\n"

      "点穴" ->
        "结果$n脸色一下变得惨白，被$N点中$l的穴道，一阵疼痛遍布整个$l！\n"

      "抽伤" ->
        "结果只听「啪」地一声爆响，只抽得$n皮开肉绽，血花飞溅！\n"

      _ ->
        "结果造成十分严重的#{type}！\n"
    end
  end

  def damage_msg(damage, type) when damage < 800 do
    case type do
      t when t in ["擦伤", "割伤"] ->
        "结果只听见$n一声惨嚎，$w已在$p$l划出一道深及见骨的可怕伤口！\n"

      "刺伤" ->
        "结果只听见$n一声惨嚎，$w已在$p的$l对穿而出，鲜血溅得满地！\n"

      t when t in ["瘀伤", "震伤"] ->
        "结果重重地击中，$n「哇」地一声吐出一口鲜血！\n"

      "内伤" ->
        "结果「轰」地一声，$n全身气血倒流，口中鲜血狂喷而出！\n"

      "点穴" ->
        "结果$n一声大叫，$l的穴道被点中，疼痛直入心肺！\n"

      "抽伤" ->
        "结果「啪」地一声爆响！这一下好厉害，只抽得$n血花飞溅！\n"

      _ ->
        "结果造成极其严重的#{type}！\n"
    end
  end

  def damage_msg(damage, type) when damage >= 800 do
    case type do
      t when t in ["擦伤", "割伤"] ->
        "结果只听见$n一声惨嚎，$w已在$p$l划出一道深及见骨的可怕伤口！\n"

      "刺伤" ->
        "结果只听见$n一声惨嚎，$w已在$p的$l对穿而出，鲜血溅得满地！\n"

      t when t in ["瘀伤", "震伤"] ->
        "结果只听见「砰」地一声巨响，$n像一捆稻草般飞了出去！\n"

      "内伤" ->
        "结果只听见几声喀喀轻响，$n一声惨叫，像滩软泥般塌了下去！\n"

      "点穴" ->
        "结果只听见$n一声惨叫，一阵剧痛夹杂着麻痒游遍全身，跟着直挺挺的倒了下去！\n"

      "抽伤" ->
        "结果只听见$n一声惨嚎，十命断了九条！\n"

      _ ->
        "结果造成非常可怕的严重#{type}！\n"
    end
  end

  @doc """
  气血状态描述（eff_status_msg/1），ratio 为百分比
  """
  def eff_status_msg(ratio)
  def eff_status_msg(100), do: "看起来气血充盈，并没有受伤"
  def eff_status_msg(ratio) when ratio > 95, do: "似乎受了点轻伤，不过光从外表看不大出来"
  def eff_status_msg(ratio) when ratio > 90, do: "看起来可能受了点轻伤"
  def eff_status_msg(ratio) when ratio > 80, do: "受了几处伤，不过似乎并不碍事"
  def eff_status_msg(ratio) when ratio > 60, do: "受伤不轻，看起来状况并不太好"
  def eff_status_msg(ratio) when ratio > 40, do: "气息粗重，动作开始散乱，看来所受的伤着实不轻"
  def eff_status_msg(ratio) when ratio > 30, do: "已经伤痕累累，正在勉力支撑着不倒下去"
  def eff_status_msg(ratio) when ratio > 20, do: "受了相当重的伤，只怕会有生命危险"
  def eff_status_msg(ratio) when ratio > 10, do: "伤重之下已经难以支撑，眼看就要倒在地上"
  def eff_status_msg(ratio) when ratio > 5, do: "受伤过重，已经奄奄一息，命在旦夕了"
  def eff_status_msg(_ratio), do: "受伤过重，已经有如风中残烛，随时都可能断气"

  @doc """
  把带占位符的战斗文案替换为真名（message_vision 替代）

  绑定：keyword 或 map，键为 `n1/n2/p/limb/weapon/weapon2`
  """
  def interpolate(text, bindings) do
    bindings = Enum.into(bindings, %{})

    text
    |> String.replace("$N", Map.get(bindings, :n1, ""))
    |> String.replace("$n", Map.get(bindings, :n2, ""))
    |> String.replace("$p", Map.get(bindings, :n2, ""))
    |> String.replace("$l", Map.get(bindings, :limb, "身体"))
    |> String.replace("$w", Map.get(bindings, :weapon, "拳头"))
    |> String.replace("$W", Map.get(bindings, :weapon2, "兵器"))
  end

  defp rand(_rng, n) when n < 1, do: 0
  defp rand(rng, n), do: rng.(n) - 1
end
