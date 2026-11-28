defmodule Kantele.World.PrototypeObject do
  @moduledoc """
  LPC `find_object/1` / `load_object/1` 载入的**非克隆原型对象**登记处。

  对应 `kungfu/class/xingxiu/azi.c:111-113` 的 GLOBAL 对象检查：

      obs = children("/clone/misc/swmuding");
      obs = filter_array(obs, (: !clonep($1) :));
      if (sizeof(obs)) { say("呜呜，神王木鼎真的被人抢走啦！"); return -1; }

  LPC 里原型对象（`clonep() == 0`）由 `d/xiyu/houdong.c:38-39` 的
  `look desk` 和 `:122-123` 的 `do_pick` 用 `find_object/load_object`
  载入全局对象表，再 `ob->move(me)` 交给玩家。ex 没有全局对象环境链，
  因此用具名 ETS 表登记同一状态：

    * `mark_loaded/2` —— 原型被载入（carrier 为 `nil` 表示尚无环境，
      对应 LPC `environment(ob) == 0`）
    * `move_to/2`      —— `ob->move(me)`，记录持有者 id
    * `loaded?/1`      —— 原型是否仍在对象表中（含已被拿走者），
      对应 `children(...)` 过滤 `!clonep` 后非空
    * `carried_by?/2`  —— 是否被指定角色拿走（对应 `environment(ob)`）
    * `reset/1` / `reset_all/0` —— 测试与会话清理

  只登记**原型**。`azi.c:125` 的 `new("/clone/misc/swmuding")` 是克隆物
  （`clonep() == 1`），绝不登记——否则阿紫自己给出的鼎会反过来触发
  「被人抢走」分支，与 LPC 顺序相反。
  """

  @table __MODULE__

  @doc "确保具名表存在（幂等，可从任意进程调用）。"
  def ensure do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  rescue
    ArgumentError -> :ok
  end

  @doc "登记原型对象已载入；`carrier` 缺省为 nil（无环境）。"
  def mark_loaded(object_id, carrier \\ nil) do
    ensure()
    :ets.insert(@table, {normalize(object_id), normalize_carrier(carrier)})
    :ok
  end

  @doc "`ob->move(me)`：把已载入的原型交给持有者。"
  def move_to(object_id, carrier) do
    ensure()
    :ets.insert(@table, {normalize(object_id), normalize_carrier(carrier)})
    :ok
  end

  @doc "原型是否已被载入（`children()` 过滤非克隆后非空）。"
  def loaded?(object_id) do
    ensure()
    key = normalize(object_id)

    case :ets.lookup(@table, key) do
      [{^key, _carrier}] -> true
      _ -> false
    end
  rescue
    ArgumentError -> false
  end

  @doc "原型当前的持有者 id；未载入或尚未被拿走时返回 nil。"
  def carrier(object_id) do
    ensure()

    case :ets.lookup(@table, normalize(object_id)) do
      [{_key, carrier}] -> carrier
      _ -> nil
    end
  rescue
    ArgumentError -> nil
  end

  @doc "原型是否被指定角色（结构体或 id）持有。"
  def carried_by?(object_id, character_or_id) do
    case carrier(object_id) do
      nil -> false
      carried -> carried == normalize_carrier(character_or_id)
    end
  end

  @doc "清除单个原型的登记。"
  def reset(object_id) do
    ensure()
    :ets.delete(@table, normalize(object_id))
    :ok
  end

  @doc "清空全部原型登记（测试用）。"
  def reset_all do
    ensure()
    :ets.delete_all_objects(@table)
    :ok
  end

  defp normalize(id) when is_binary(id), do: id
  defp normalize(id) when is_atom(id), do: to_string(id)
  defp normalize(%{id: id}), do: normalize(id)
  defp normalize(id), do: to_string(id)

  defp normalize_carrier(nil), do: nil
  defp normalize_carrier(%{id: id}) when is_binary(id), do: id
  defp normalize_carrier(id) when is_binary(id), do: id
  defp normalize_carrier(other), do: to_string(other)
end
