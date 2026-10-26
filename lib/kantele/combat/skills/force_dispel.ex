defmodule Kantele.Combat.Skills.Force.Dispel do
  @moduledoc """
  排除异常（对照 `kungfu/skill/force/dispel.c`）

  自我版：逐条件尝试驱散；需 neili>=300，扣 neili 100，busy 1+random(2)。

  LPC 原可对他人运功（neili>=250、扣 250、校验目标战斗/忙碌/条件）；
  本引擎 exert 无目标侧 -> TODO(migrate): 他人路径待目标侧结算接入后再补。

  ## 2026-10-26 修复：以前是空操作

  `condition` 框架把条件存在 **`session["conditions"]`**（见
  `Kantele.Character.ConditionEvent`），而这里原先清的是
  `character.meta.conditions` —— 那个字段**全库无人写入** → 运功「排除异常」
  实际什么都没做。现在改成：

  1. 从 `session["conditions"]` 取条件；
  2. 走 `Conditions.dispel/3` 逐条问 daemon（`Kantele.Drunk.dispel_condition/2`
     按 LPC `duration + 50`（他人 ×3/2）比对 `force` 等级，不够则拒绝）；
  3. 把剩余条件写回 session（`Simple` 的 custom 效果支持携带 conn 副作用，
     见 `apply_spec/5` 的 `state.conn` 合并）。

  三种结局照搬 LPC 文案：全部驱散 → 「你调息完毕，将内力收回丹田。」；
  有失败 → 「你调息良久，没有一点效果。」；本来就没条件 →
  「结果你没发现自己有任何异常。」。逐条 daemon 给的文案（如解酒成功/内力
  火候不足）夹在中间输出。
  """

  use Kantele.Combat.Performs.Simple, spec: :local

  import Kalevala.Character.Conn, only: [get_session: 2, put_session: 3]

  alias Kantele.Character.ConditionRegistry
  alias Kantele.Character.Conditions
  alias Kantele.Character.Stats
  alias Kantele.Combat.Performs.Spec

  def spec do
    %Spec{
      id: "force/dispel",
      kind: :exert,
      gates: [
        {:neili_min, 300, "你的内力不足，无法运满一个周天。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:custom, &effect_dispel/2}
      ],
      busy: {:random, 1, 3},
      message: fn ctx ->
        force = to_chinese(Map.get(ctx.stats.mapped, "force") || "force")
        "$N深吸一口气，又缓缓的吐了出来。\n你默运#{force}，开始排除身体中的异常症状。\n"
      end
    }
  end

  # LPC: conditions = target->query_condition(); for(...) dispel_condition(...)
  defp effect_dispel(state, ctx) do
    conn = ctx.conn
    conditions = get_session(conn, "conditions") || %{}

    if map_size(conditions) == 0 do
      # LPC: 「结果你没发现自己有任何异常。」
      %{state | messages: state.messages ++ ["结果你没发现自己有任何异常。\n"]}
    else
      dispel_ctx = %{force: force_level(ctx.stats), self?: true}
      {remaining, results} = Conditions.dispel(conditions, dispel_ctx, &ConditionRegistry.daemon/1)

      # 顺序：逐条 daemon 文案 → 总结文案（LPC 是「成功即 return，失败走 still_ill」）
      detail = for {_cnd, res} <- results, msg = result_message(res), do: msg
      cleared? = Enum.any?(results, fn {_c, r} -> r == :ok or match?({:ok, _}, r) end)
      failed? = Enum.any?(results, fn {_c, r} -> match?({:fail, _}, r) end)

      summary =
        cond do
          cleared? -> "你调息完毕，将内力收回丹田。\n"
          failed? -> "你调息良久，没有一点效果。\n"
          true -> "结果你没发现自己有任何异常。\n"
        end

      state
      |> Map.put(:messages, state.messages ++ detail ++ [summary])
      |> Map.put(:conn, put_session(conn, "conditions", remaining))
    end
  end

  defp result_message({:ok, msg}), do: msg
  defp result_message({:fail, msg}), do: msg
  defp result_message(_), do: nil

  defp force_level(stats) do
    case stats do
      %Stats{} -> Stats.skill(stats, "force")
      _ -> 0
    end
  end

  defp to_chinese(name) do
    case name do
      "hunyuan-yiqi" -> "混元一气"
      "taiji-shengong" -> "太极神功"
      "xiaowuxiang" -> "小无相"
      _ -> name
    end
  end
end
