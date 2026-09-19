defmodule Kantele.Combat.Performs.Spec do
  @moduledoc """
  声明式绝招/运功规格（D3）

  T1/T2 的大量 exert/perform 是同一套固定模式：门槛链 → 扣资源 →
  临时加成/挂 buff → busy → 文案。把这类招式写成数据 spec，由
  `Kantele.Combat.Performs.Simple` 统一执行，人工只校对 spec。

  超出表达力的（动态分档、多段、目标交互、条件附加）仍手写模块。

  ## 形状

      %Spec{
        id: "force/power",
        kind: :exert,
        gates: [gate()],
        costs: %{neili: 100},
        effects: [effect()],
        busy: 3 | {:if_fighting, 3},
        message: "$N运起神功。\\n"
      }

  `gates` 每项自带失败文案，按序短路；`check_gate/2` 只支持下列元组，
  无法表达时用 `{:custom, fun, msg}`（`fun.(ctx) :: boolean`，ctx 见
  `Kantele.Combat.Performs.Simple`）。`message` 除字符串外也可用
  `fun.(ctx) :: String.t()`，应对 LPC 按修为分档的运功文案。

  效果中 buff 的 `applies` 传**正加成值**，解释器按引擎惯例落
  `Combat.apply_temp(+bonus)` 并记 `Buff.applies`（负值），到期由
  `combat/buff-expire` 回收。

  ## 数值表达式

  效果/busy 的数值可以是静态整数，也可以是随状态求值的表达式 `value()`：

      integer           静态值
      {:skill, id}      技能等级 Stats.skill/2
      {:effective, id}  有效等级 Stats.effective/2
      {:add, a, b} / {:sub, a, b} / {:mul, a, b} / {:div, a, b}
      {:random, min, max}  含端点均匀随机（依赖 run/3 注入的 rng）

  例：LPC `skill / 3` 写作 `{:div, {:skill, "bahuang-gong"}, 3}`；
  `skill * 2 / 5` 写作 `{:div, {:mul, {:skill, "force"}, 2}, 5}`。

  带 `duration` 的 spec 会在效果应用后对首个 `{:buff, key, applies}`
  投递 `combat/buff-expire`（`duration` 为秒，`{:skill, id}` 取该技能等级）。
  """

  @typedoc "数值表达式（效果/busy 用）"
  @type value ::
          integer()
          | {:skill, skill_id :: String.t()}
          | {:effective, skill_id :: String.t()}
          | {:add, value(), value()}
          | {:sub, value(), value()}
          | {:mul, value(), value()}
          | {:div, value(), value()}
          | {:random, integer(), integer()}

  @typedoc "门槛项：`{类型, 参数..., 失败文案}`"
  @type gate ::
          {:perform_known, perform_id :: String.t(), String.t()}
          | {:skill_min, skill_id :: String.t(), non_neg_integer(), String.t()}
          | {:mapped, usage :: String.t(), skill_id :: String.t(), String.t()}
          | {:neili_min, non_neg_integer(), String.t()}
          | {:max_neili_min, non_neg_integer(), String.t()}
          | {:qi_min, non_neg_integer(), String.t()}
          | {:jing_min, non_neg_integer(), String.t()}
          | {:no_buff, key :: String.t(), String.t()}
          | {:buff, key :: String.t(), String.t()}
          | {:custom, (map() -> boolean()), String.t()}

  @typedoc "效果项"
  @type effect ::
          {:temp, %{optional(atom()) => value()}}
          | {:buff, key :: String.t(), %{optional(atom()) => value()}}
          | {:set, vital :: atom(), value()}
          | {:add, vital :: atom(), value()}
          | {:message, String.t()}
          | {:custom, (map() -> map()) | (map(), map() -> map())}

  @typedoc "buff 到期时长：静态秒数或按技能等级取秒"
  @type duration :: non_neg_integer() | {:skill, skill_id :: String.t()}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          kind: :exert | :perform,
          gates: [gate()],
          costs: %{optional(atom()) => non_neg_integer()},
          effects: [effect()],
          busy: non_neg_integer() | {:if_fighting, value()},
          duration: duration() | nil,
          expire_message: String.t() | nil,
          message: String.t() | (map() -> String.t()) | nil
        }

  defstruct id: nil,
            kind: :exert,
            gates: [],
            costs: %{},
            effects: [],
            busy: 0,
            duration: nil,
            expire_message: nil,
            message: nil

  @doc "构造规格（关键字覆盖默认值；未知键报错）"
  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)
end
