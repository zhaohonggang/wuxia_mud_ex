defmodule Kantele.Illness do
  @moduledoc """
  疾病 condition 家族（Q2 v2 疾病系统，对应 LPC `kungfu/condition/ill_*.c` 五族）

  五族共用同一套 condition 机制，只差每跳 qi 伤害、发作文案、`min_qi_needed`
  睡眠门控、驱散文案：

  | cnd            | 季节      | 每跳 qi | min_qi_needed | 死因（qi<1）        |
  |----------------|----------|---------|---------------|---------------------|
  | `ill_kesou`    | 春/秋     | 2       | 10            | 咳嗽久病不愈吐血身亡 |
  | `ill_zhongshu` | 夏       | 4       | 15            | 中暑太深暴毙身亡     |
  | `ill_shanghan` | 秋       | 6       | 20            | 伤寒发作不治身亡     |
  | `ill_dongshang`| 冬       | 2       | 10            | 被活活冻死          |
  | `ill_fashao`   | 1/4 覆盖 | 2       | 10            | 发烧太重折磨死       |

  与 `Kantele.Poison` 同款「单一模块承载家族」模式；`daemon/1` 把五个 cnd 名
  统一指到本模块。生命周期（`update_condition/1` 倒计时）与每跳效果
  （`do_effect/3` 扣 qi + 广播文案）分离，与 `Kantele.Drunk`/`Kantele.Duyan` 一致。

  ## LPC 原始 `update_condition(me, duration)`（五族逐字一致，仅文案/伤害不同）

      if (duration < 1) return 0;
      message("vision", HIG + me->name() + "<发作文案>" NOR, environment(me), me);
      if (!living(me) && me->query("qi") < 1) {
          me->set_temp("die_reason", "<死因>");
          me->die();
          return 0;
      } else tell_object(me, HIB "<本人文案>" NOR);
      me->receive_wound("qi", X);
      me->receive_damage("qi", X);
      me->apply_condition(name(), duration - 1);
      if (duration < 1) return 0;
      return CND_CONTINUE;

  LPC 的 `receive_wound` + `receive_damage` 各扣 X 点 qi（wound 削上限、damage 削当前）。
  本端口的 condition 宿主（`Kantele.Character.ConditionEvent`）只回写**当前** qi
  （见 `condition.ex` @todo：eff_* 三层模型未落地前统一扣当前值），故这里把两级
  各 X 点合并为每跳 `qi - 2X`（kesou/fashao/dongshang = 2，zhongshu = 4，
  shanghan = 6）。死亡由宿主的 `condition/down` 链路处理（NPC 有专属处决函数；
  玩家在端口当前实现下 qi 归 0 但不自动死亡 —— 与现有 `Poison`/`Drunk` 行为一致，
  非本模块引入的回归）。

  ## 驱散（对应 LPC `inherit/condition/illness.c dispel/3`）

  由 `Kantele.Character.Conditions.dispel/3` 经 `dispel_condition/2` 回调触发
  （本端口运功驱毒/驱病的调用点复用同一通道，与 `Kantele.Drunk` 同）：

      need_lvl = duration + 60;  me != ob → ×3/2
      need_neili = duration * 10; me != ob → ×3/2
      need_lvl > force  → 失败「内功火候尚有欠缺」
      neili < need_neili → 失败「内力现在不足」
      成功：扣 neili，clear_condition
  """

  alias Kantele.Character.Conditions

  # 家族表：cnd => %{qi: 每跳当前 qi 减额, min_qi: sleep 门控, self: 本人文案,
  #                  others: 房间广播文案}
  @family %{
    "ill_kesou" => %{
      qi: 2,
      min_qi: 10,
      self: "你嘶哑着嗓子咳了两声，然后又连续咳了好一阵，看来是病的不轻！\n",
      others: "{npc}嘶哑着嗓子咳了两声，然后\n又连续咳了好一阵，看来是病的不轻！\n"
    },
    "ill_zhongshu" => %{
      qi: 4,
      min_qi: 15,
      self: "你觉得胸臆之间一阵翻腾，头重脚轻，脑门发热，看来是中暑了。\n",
      others: "{npc}头重脚轻，晕晕乎乎抬不起头来，看来是中暑了。\n"
    },
    "ill_shanghan" => %{
      qi: 6,
      min_qi: 20,
      self: "你打了个冷战，头昏沉沉的，好象是得伤寒病了！\n",
      others: "{npc}冷不丁打了个冷战，头昏沉沉的，好象是得伤寒病了。\n"
    },
    "ill_dongshang" => %{
      qi: 2,
      min_qi: 10,
      self: "你觉得肢体末端一阵僵直，看来是被冻伤了！\n",
      others: "{npc}的肢体僵直青肿，看来被冻伤了。\n"
    },
    "ill_fashao" => %{
      qi: 2,
      min_qi: 10,
      self: "你的脸蛋烧得通红，看来是发高烧了。\n",
      others: "{npc}的脸蛋烧得通红，看来是发高烧了。\n"
    }
  }

  @doc "疾病家族表（cnd => 数据变体），供注册表/测试核对"
  def family(), do: @family

  @doc "给五个疾病 cnd 返回 {:ok, __MODULE__}"
  def daemon(cnd) when is_binary(cnd) do
    if Map.has_key?(@family, cnd), do: {:ok, __MODULE__}, else: :error
  end

  def daemon(_), do: :error

  @doc "Conditions 系统调用：每 tick 倒计时；< 1 到期"
  def update_condition(info) when is_map(info) do
    d = int(Map.get(info, "duration")) - 1

    if d < 1 do
      {:expire}
    else
      {:continue, Map.put(info, "duration", d)}
    end
  end

  def update_condition(_), do: {:expire}

  @doc """
  Conditions 系统调用：每 tick 扣 qi + 广播发作文案。

  LPC 的 `receive_wound` + `receive_damage` 合并为当前 qi 减 `2 * family.qi`
  （与 `Kantele.Poison.do_effect` 的夹 0 约定一致，不击穿下限）。
  """
  def do_effect(state, cnd, _para) do
    case Map.get(@family, cnd) do
      nil ->
        {:ok, state}

      %{qi: qi_loss, self: self_msg, others: others_msg} ->
        {:ok,
         state
         |> adjust_qi(-(qi_loss * 2))
         |> push_message({:tell, self_msg})
         |> push_message({:vision, others_msg})}
    end
  end

  @doc """
  睡眠门控：对应 LPC `ill_*.c min_qi_needed()`（条件宿主 `Conditions.blocked_by_vitals`）。

  宿主按 `apply(mod, :min_qi_needed, [attributes])` 调用（单参数，见 `Conditions.min_needed`），
  无法携带 cnd，故返回家族内**最严**阈值（伤寒 20），保证「患病即难眠」的语义。
  各 cnd 的精确阈值见 `@family.min_qi`（kesou/fashao/dongshang=10，zhongshu=15，
  shanghan=20），待宿主改为带 cnd 调用后可逐族精确门控。未实现该函数的 condition 默认 0（不拦）。
  """
  def min_qi_needed(_attributes), do: 20

  @doc """
  驱散（对应 LPC `illness.c dispel/3`，由 `Conditions.dispel/3` 经
  `dispel_condition/2` 回调触发）。

  `ctx`：`%{force: force 技能等级, neili: 当前内力, self?: 是否对自己运功,
  target_name: 他人名}`。
  返回 `:ok`/`{:ok, msg}`（驱散成功）/ `{:fail, msg}`（内力/火候不足，保留条件）。
  """
  def dispel_condition(info, ctx) when is_map(info) do
    duration = int(Map.get(info, "duration"))
    self? = Map.get(ctx, :self?, true)
    need_lvl = if self?, do: duration + 60, else: div((duration + 60) * 3, 2)
    need_neili = if self?, do: duration * 10, else: div(duration * 10 * 3, 2)
    force = Map.get(ctx, :force) || 0
    neili = Map.get(ctx, :neili) || 0
    cname = Map.get(ctx, :cname) || "此症"

    cond do
      need_lvl > force ->
        {:fail, "你的内功火候尚有欠缺，无法驱除#{cname}。\n"}

      neili < need_neili ->
        {:fail, "你的内力现在不足，无法施展以驱除#{cname}。\n"}

      true ->
        {:ok, dispel_ok_message(self?, ctx)}
    end
  end

  def dispel_condition(_info, _ctx), do: :skip

  # ---- internal ----

  defp dispel_ok_message(true, _ctx), do: "调息以后，你舒服多了，感觉此症被消除了。\n"

  defp dispel_ok_message(false, ctx) do
    "你将内力缓缓的输入到#{name_of(ctx)}经脉，#{name_of(ctx)}精神一振。\n"
  end

  defp name_of(ctx), do: Map.get(ctx, :target_name) || "对方"

  defp adjust_qi(state, delta) do
    current = Map.get(state.attributes, :qi) || 0
    value = max(current + delta, 0)
    put_in(state, [:attributes, :qi], value)
  end

  defp push_message(state, msg) do
    Map.update(state, :condition_messages, [msg], fn msgs -> msgs ++ [msg] end)
  end

  defp int(nil), do: 0
  defp int(n) when is_integer(n), do: n
  defp int(n) when is_float(n), do: trunc(n)

  defp int(n) when is_binary(n) do
    case Integer.parse(String.trim(n)) do
      {v, _} -> v
      _ -> 0
    end
  end

  defp int(_), do: 0
end
