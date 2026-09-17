defmodule Kantele.Character.ConditionRegistry do
  @moduledoc """
  条件 daemon 注册表（对应 LPC condition_d.c set_condition_daemon 的宿主表）

  与 `Kantele.Combat.Skills` 同款模式：

  - 静态内建表 `@daemons`（起步仅 `"poison" => Kantele.Poison`；后续随 kungfu
    `condition/*.c` 逐个迁移补充，无需重启进程）。
  - 运行时可热增/热删（`:persistent_term` 覆盖静态表同名项，F1 验收里
    "假 condition/demo" 即走这条路径验证注册表热增）。

  `daemon/1` 解析条件名 → `{:ok, daemon_mod} | :error`，供
  `Kantele.Character.Conditions.update_condition/2` 与 `affect_by/4` 使用
  （对应 LPC `condition_d->daemon(me, cnd)` 与 condition 宿主把 cnd 名解开成模块）。
  """

  @daemons %{"poison" => Kantele.Poison, "fire_poison" => Kantele.Poison}

  @doc "给条件名返回 `{:ok, mod} | :error`（先查运行时增量，再查静态表）"
  def daemon(cnd) when is_binary(cnd) do
    case Map.get(extras(), cnd) do
      nil ->
        case Map.get(@daemons, cnd) do
          nil -> :error
          mod -> {:ok, mod}
        end

      mod ->
        {:ok, mod}
    end
  end

  @doc "注册（热增）：`register(name, mod)`，返回 :ok"
  def register(name, mod) when is_binary(name) and is_atom(mod) do
    :persistent_term.put({__MODULE__, :extras}, Map.put(extras(), name, mod))
    :ok
  end

  @doc "注销：`unregister(name)`，返回 :ok"
  def unregister(name) do
    :persistent_term.put({__MODULE__, :extras}, Map.delete(extras(), name))
    :ok
  end

  @doc "全部已注册条件名（静态表 + 运行时增量，去重）"
  def all() do
    Map.keys(@daemons) |> Kernel.++(Map.keys(extras())) |> Enum.uniq()
  end

  defp extras(), do: :persistent_term.get({__MODULE__, :extras}, %{})
end
