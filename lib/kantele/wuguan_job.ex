defmodule Kantele.WuguanJob do
  @moduledoc """
  耶律齐派活计的时间限制 condition（`d/wuguan/npc/yelvqi.c` `ask_job()` 里的
  `apply_condition("wuguan_job", random(3) + 4)`）。

  ## LPC 语义

  玩家领活计后施加 `wuguan_job`，时限 `random(3) + 4`（心跳数）；在时限内 `task ok`
  覆命会被耶律齐以「怎么这么快，是不是没做完啊，吩咐你回来了吗？」拒绝（见
  `Kantele.World.NpcActions.Task` 分支 4），时限过后再覆命才放行。本 condition
  不带任何每跳效果，仅作倒计时。

  ## info 结构

  `%{"duration" => 整数}`：每跳（引擎心跳 1s）减一，`< 1` 到期清除（与
  `Kantele.Drunk` 同约定）。`do_effect` 为纯计时 no-op；未实现 `dispel_condition`，
  按 `Conditions.dispel` 默认行为可被驱散移除（不影响判定，本 condition 本就不
  该被解）。

  ## 注册

  在 `Kantele.Character.ConditionRegistry` 的 `@daemons` 注册
  `"wuguan_job" => Kantele.WuguanJob`。
  """

  alias Kantele.Character.Conditions

  @cnd "wuguan_job"

  @doc "给 'wuguan_job' 返回 {:ok, Kantele.WuguanJob}"
  def daemon("wuguan_job"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc "生命周期：每跳 duration 减一，< 1 到期（与 `Kantele.Drunk` 同约定）"
  def update_condition(info) do
    d = int(Map.get(info, "duration")) - 1

    if d < 1 do
      {:expire}
    else
      {:continue, Map.put(info, "duration", d)}
    end
  end

  @doc "纯计时 condition：无每跳效果"
  def do_effect(state, _cnd, _para), do: {:ok, state}

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
