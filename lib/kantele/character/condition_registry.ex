defmodule Kantele.Character.ConditionRegistry do
  @moduledoc """
  条件 daemon 注册表（对应 LPC condition_d.c set_condition_daemon 的宿主表）

  与 `Kantele.Combat.Skills` 同款模式：

  - 静态内建表 `@daemons`（起步 `poison`/`fire_poison`/`flower_poison`/`nishui`/
    `duyan`/`drunk`/`wuguan_job`；后续随 kungfu `condition/*.c` 逐个迁移补充，
    无需重启进程）。
  - 运行时可热增/热删（`:persistent_term` 覆盖静态表同名项，F1 验收里
    "假 condition/demo" 即走这条路径验证注册表热增）。

  `daemon/1` 解析条件名 → `{:ok, daemon_mod} | :error`，供
  `Kantele.Character.Conditions.update_condition/2` 与 `affect_by/4` 使用
  （对应 LPC `condition_d->daemon(me, cnd)` 与 condition 宿主把 cnd 名解开成模块）。
  """

  @daemons %{
    "poison" => Kantele.Poison,
    "fire_poison" => Kantele.Poison,
    "flower_poison" => Kantele.FlowerPoison,
    "nishui" => Kantele.Nishui,
    "duyan" => Kantele.Duyan,
    "drunk" => Kantele.Drunk,
    "wuguan_job" => Kantele.WuguanJob
  }

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

  # 条件 id → 中文名（对应 LPC `to_chinese(kc[i])`）。
  #
  # **本地补白**：LPC 的 `to_chinese` 走 `CHINESE_D->chinese()` 查 dict 表，
  # 而 dict 里**没有** `ill_*` / `drunk` 这些 condition id 的条目 → 原 mud
  # 输出的是「可是ill_shanghan不断折磨着你」这种中英混杂串。这里按 daemon
  # 已登记的范围补上中文名；未收录的回落 id 原样（与 `force/dispel.ex`
  # 的 `to_chinese/1` 同一约定）。
  @chinese_names %{
    "ill_dongshang" => "冻伤",
    "ill_fashao" => "发烧",
    "ill_kesou" => "咳嗽",
    "ill_shanghan" => "伤寒",
    "ill_zhongshu" => "中暑",
    "poison" => "中毒",
    "fire_poison" => "火毒",
    "nishui" => "溺水",
    "duyan" => "毒烟",
    "drunk" => "醉意"
  }

  @doc "条件 id → 中文名（未收录回落 id 原样）"
  def chinese_name(cnd) when is_binary(cnd), do: Map.get(@chinese_names, cnd, cnd)
  def chinese_name(cnd), do: cnd

  defp extras(), do: :persistent_term.get({__MODULE__, :extras}, %{})
end
