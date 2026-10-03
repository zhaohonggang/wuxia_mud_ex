defmodule Kantele.World.Arena do
  @moduledoc """
  擂台（`city:leitai`）的「关闭 / 开放」状态

  对应 LPC `d/city/leitai.c` 的 `set("close_by", me)` / `delete("close_by")`，
  以及 `refuse/1`：

      int refuse(object ob)
      {
          if (!wizardp(ob) && query("close_by"))
              return 1;
          return 0;
      }

  调用方是 `d/city/underlt.c`（被 wudao1~4 继承）的 `valid_leave`：

      dest = query("exits/" + dir);
      if (!stringp(dest)) return ::valid_leave(me, dir);
      ob = find_object(dest);
      if (!objectp(ob) || wizardp(me)) return ::valid_leave(me, dir);
      if (ob->refuse(me)) return notify_fail("你凑什么热闹，现在不是你上去的时候。\\n");

  合起来就是：**要去的那个房间被关闭了、而自己不是巫师，就不许去。**

  ## 为什么状态放这里而不是房间进程里

  判定发生在「观众席」房间（`city:wudao1` 等）的 `movement_request` 里，
  而状态属于「擂台」房间（`city:leitai`）—— 是**跨房间读**。

  若让观众席房间 `GenServer.call` 擂台房间，就有了 A→B 的同步调用；两个房间
  一旦互相调用就会死锁。本模块走 `Kalevala.Cache`：
  `get/1` 底层是 `:ets.lookup`（**不经过任何进程**），`put/2` 才是 call，
  而 put 只发生在巫师执行 `lclose`/`lopen` 时。

  另外这也符合 LPC 语义：`close_by` 是房间运行态，房间重置就没了。

  ## 没有硬编码「擂台」

  `refused?/2` 只看「目标房间有没有关闭状态」，不认房间 id。所以将来别的
  擂台想复用这套，直接往同一个 key 里写状态即可。
  """

  use Kalevala.Cache

  @refuse_msg "你凑什么热闹，现在不是你上去的时候。"

  @doc "LPC 的拒绝原文（notify_fail）"
  def refuse_message, do: @refuse_msg

  @doc """
  读某个房间的关闭状态

  返回 `nil`（没人关闭）或 `%{by: 名字, at: 时间}`。

  ## 这里必须 fail-safe

  `Kalevala.Cache.get/2` 底层是 `:ets.lookup`，而 ETS 表由监督树创建。
  如果缓存没起来（`mix run --no-start` 的脚本、监督树异常重启），
  `:ets.lookup` 会抛 `ArgumentError`。

  而这个函数是在**房间的 `movement_request`** 里被调用的 —— 一抛异常就会
  把房间进程带走，所有人再也走不动。所以这里把异常吞掉当作「没关闭」，
  与 `LpcCondition.evaluate` 的「求值失败一律放行」同一套取舍：
  **宁可少拦，不能锁死玩家。**
  """
  def close_by(room_id) when is_binary(room_id) do
    case safe_get(room_id) do
      {:ok, %{close_by: by}} -> by
      _ -> nil
    end
  end

  def close_by(_), do: nil

  defp safe_get(key) do
    get(key)
  rescue
    # ETS 表不存在 / 参数不合法
    _ -> :error
  catch
    _, _ -> :error
  end

  @doc "关闭擂台（对应 LPC set(\"close_by\", me)）"
  def close(room_id, %{name: name}) do
    put(room_id, %{close_by: %{by: name, at: System.system_time(:second)}})
  end

  @doc "开放擂台（对应 LPC delete(\"close_by\")）"
  def open(room_id) do
    put(room_id, %{close_by: nil})
  end

  @doc """
  LPC `refuse/1` 的等价判定

  `wizard?` 为真时一律放行（对应 `!wizardp(ob) && query("close_by")`）。
  """
  def refused?(room_id, wizard?) do
    not wizard? and close_by(room_id) != nil
  end

  @doc """
  移动判定：返回 `{:allow, []}` 或 `{:block, msg, []}`

  `dest_room_id` 是这次移动的**目标房间**。目标房间没有关闭状态就放行
  ——等价于 LPC 里「只有定义了 refuse() 的房间才会拒绝」。
  """
  def refuse(dest_room_id, wizard?) do
    if refused?(dest_room_id, wizard?) do
      {:block, @refuse_msg, []}
    else
      {:allow, []}
    end
  end
end