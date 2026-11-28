defmodule Kantele.World.SingletonItems do
  @moduledoc """
  全服单件物品登记表（对应 LPC `/clone/lonely/*.c` 的「单件、全服唯一」语义）。

  LPC 的做法（如 `kungfu/class/songshan/zuo.c` create()）：

      ob = find_object(CANYANG);
      if (! ob) ob = load_object(CANYANG);
      if (! environment(ob))   # 还在虚空 → 没人拿过
      {
              ob->move(this_object());  # 发给这个 NPC
              ob->wield();
      } else
      {
              ob = new("/clone/weapon/changjian");  # 已有持有者 → fallback 普通长剑
              ob->move(this_object());
              ob->wield();
      }

  关键点：`environment(ob)` 只在**剑从未被 move 过**时为空 —— 单件一旦发出去
  （无论是被 NPC 拿、被玩家拿、掉在地上、还是躺在尸体里），它永远"有环境"，
  不会回到虚空。**不存在"持有者消失 → 回池"的路径**（尸体腐烂是把物品
  `move(env)` 移到房间，不是销毁；且残阳剑 `no_sell`）。
  唯一的"回池"是服务器重启：LPC 重启后 `find_object` 重新 load，environment
  为空 → 又能发；对应这里 ETS 随进程重启清空，语义一致。

  我们没有全局对象表，用一张 **public ETS**（`register/taken?`）表达"已发放"：

  - 创建时机挂在 `Kantele.World.Items` 缓存的 `initialize/1` 回调（该 GenServer
    随 Kickoff 起来、长期存活，且已有 forge 模板恢复的 try/rescue 先例），
    避免 ETS 属主是某个短命 Foreman 进程、它一崩表就没了。
  - `SpawnController.equip_carry` 遇到 `singleton = true` 的 carry 项：
    未登记 → `register/1` 并正常装备；已登记 → 改用该项的 `fallback` 物品
    （LPC else 分支），无 fallback 则跳过（NPC 不带该件）。

  纯登记表：不做容量/持有者追踪 —— 那是 give_item 的 unique 检查
  （`present(name, me)`）与房间物品系统的事。
  """

  @table :kantele_singleton_items

  @doc "创建登记表（幂等）。由 Kantele.World.Items.initialize/1 调用。"
  def init do
    if :ets.whereis(@table) == :undefined do
      :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    end

    :ok
  rescue
    # 并发创建时 ArgumentError（表已存在）——幂等即可
    _ -> :ok
  end

  @doc "该单件是否已被发放。表未创建（测试/极早启动路径）视为未发放。"
  @spec taken?(String.t()) :: boolean()
  def taken?(item_id) when is_binary(item_id) do
    case :ets.whereis(@table) do
      :undefined -> false
      _ -> :ets.member(@table, item_id)
    end
  end

  @doc "登记发放。表未创建时先建（防御路径）。"
  @spec register(String.t()) :: :ok
  def register(item_id) when is_binary(item_id) do
    init()
    :ets.insert(@table, {item_id, true})
    :ok
  end
end
