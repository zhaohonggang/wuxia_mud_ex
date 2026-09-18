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
  `Kantele.Combat.Performs.Simple`）。

  效果中 buff 的 `applies` 传**正加成值**，解释器按引擎惯例落
  `Combat.apply_temp(+bonus)` 并记 `Buff.applies`（负值），到期由
  `combat/buff-expire` 回收。
  """

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
          {:temp, %{optional(atom()) => number()}}
          | {:buff, key :: String.t(), %{optional(atom()) => number()}}
          | {:set, vital :: atom(), number()}
          | {:add, vital :: atom(), number()}
          | {:message, String.t()}

  @type t :: %__MODULE__{
          id: String.t() | nil,
          kind: :exert | :perform,
          gates: [gate()],
          costs: %{optional(atom()) => number()},
          effects: [effect()],
          busy: non_neg_integer() | {:if_fighting, non_neg_integer()},
          message: String.t() | nil
        }

  defstruct id: nil,
            kind: :exert,
            gates: [],
            costs: %{},
            effects: [],
            busy: 0,
            message: nil

  @doc "构造规格（关键字覆盖默认值；未知键报错）"
  @spec new(keyword()) :: t()
  def new(fields), do: struct!(__MODULE__, fields)
end
