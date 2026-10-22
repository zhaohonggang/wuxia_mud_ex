defmodule Kantele.World.FingerD do
  @moduledoc """
  通缉告示牌子系统（对应 LPC `FINGER_D->get_killer()`）。

  LPC 端 `adm/daemons/fingerd.c` 的 `get_killer()` 逻辑是：

      string get_killer()
      {
          object *ob = users();
          msg = "";
          for (i = 0; i < sizeof(ob); i++)
              if ((int)ob[i]->query_condition("killer"))
                  msg += (ob[i]->short() + "\n");
          if (msg == "")
              return "本城治安良好。\n";
          else
              return "现在本城正在缉拿以下人犯：\n\n" + msg;
      }

  也就是说：遍历在线玩家（`users()`，本端口 `Presence.characters()`），
  找出处于「杀手」通缉状态（`query_condition("killer")`）者，拼成告示正文。
  各城城门/关卡（look_gaoshi）再在后面追加上本城知府/提督落款（footer）。

  ## 为什么做成一个受监督的单例，而不是实时扫在线玩家

  LPC 是**实时**扫 `users()`，但在房间进程里这么干既慢又容易触发跨进程死锁
  （房间读在线玩家 → 在线玩家又在别的进程）。LPC 之所以能这么做，是因为它的
  `users()` 是直接读内核对象表，不涉及进程调用；本端口的 `Presence.characters()`
  背后是 PubSub/ETS，在房间进程里轮询并不优雅。

  因此这里集中成一个受监督的注册表（与 `Arena` 同款 `Kalevala.Cache` 模式）：

    - 战斗/剧情代码在某人变为通缉犯时调用 `FingerD.mark_killer(name)`，洗清时
      `FingerD.clear_killer(name)`；
    - `get_killer_text/0` 只读这个注册表，fail-safe（表没起来也只会显示治安良好，
      不会把房间进程带崩）。

  语义与 LPC 等价（通缉名单本来就该持久、跨进程可读），且更不容易在房间进程里
  出现死锁/卡顿。本端口目前尚未把「killer」条件接入战斗/杀戮判定（条件注册表只
  有 poison/fire_poison/nishui/duyan），所以告示默认显示「治安良好」—— 这是正确
  的默认值，等通缉逻辑接上后，mark/clear 自然会让告示动态变化。
  """

  use Kalevala.Cache

  @peaceful "本城治安良好。\n"
  @wanted_header "现在本城正在缉拿以下人犯：\n\n"
  @registry_key "wanted_killers"

  @doc "标记某玩家为通缉犯（幂等：同名只记一次）。"
  def mark_killer(name) when is_binary(name) and name != "" do
    names = MapSet.put(names_set(), name)
    put(@registry_key, %{names: MapSet.to_list(names)})
    :ok
  end

  def mark_killer(_), do: :ok

  @doc "解除某玩家的通缉状态。"
  def clear_killer(name) when is_binary(name) and name != "" do
    names = MapSet.delete(names_set(), name)
    put(@registry_key, %{names: MapSet.to_list(names)})
    :ok
  end

  def clear_killer(_), do: :ok

  @doc "清空全部通缉（测试清理用）。"
  def clear_all do
    put(@registry_key, %{names: []})
    :ok
  end

  @doc "当前通缉名单（字符串列表；fail-safe 返回 []）。"
  def wanted_killer_names do
    case safe_get(@registry_key) do
      {:ok, %{names: names}} when is_list(names) -> names
      _ -> []
    end
  end

  defp names_set do
    case safe_get(@registry_key) do
      {:ok, %{names: names}} when is_list(names) -> MapSet.new(names)
      _ -> MapSet.new()
    end
  end

  @doc """
  告示正文（与 LPC `get_killer()` 对齐）。

  - 无人被通缉：`"本城治安良好。\n"`
  - 有人被通缉：`"现在本城正在缉拿以下人犯：\n\n" + 各人名字 + "\n"`

  fail-safe：任何异常都回落到「治安良好」，绝不让房间进程崩。
  """
  def get_killer_text do
    names = wanted_killer_names()

    case names do
      [] -> @peaceful
      _ -> @wanted_header <> Enum.map_join(names, "", &"#{&1}\n")
    end
  rescue
    _ -> @peaceful
  catch
    _, _ -> @peaceful
  end

  defp safe_get(key) do
    get(key)
  rescue
    _ -> :error
  catch
    _, _ -> :error
  end
end
