defmodule Kantele.Npc.EngageRule do
  @moduledoc """
  NPC 开战接受规则（accept_fight / accept_hit / accept_kill）

  由 converter 从 LPC 函数体抽取为 `meta.engage`，结构：

      %{
        fight: %{accept: bool, msg: 台词 | nil, retaliate: bool, spawn: [id]},
        hit:   %{...},
        kill:  %{...}
      }

  `decide/2`：按战斗类型取规则，返回
    - `{:deny, msg}`  明确拒绝（accept=false）
    - `:allow`        无规则或缺省放行
  纯函数，供房间侧 combat/attack 事件接线（room.ex）。
  """

  @doc "战斗类型是否命中拒绝规则；返回 {:deny, msg} 或 :allow"
  def decide(meta, type, name \\ nil) when is_map(meta) do
    do_decide(meta, type, name)
  end

  @doc """
  带 NPC 与攻击者的动态判定（ultra 大宗师 `accept_fight` 按 ask 次数/状态放拒）。

  `handler` 由 UCL `engage.fight.handler` 指定；目前仅
  `Kantele.NPC.Ultra` 实现了 `engage_decide/3`。未配置时与 `decide/3` 完全一致。
  """
  def decide(meta, type, name, npc, attacker) when is_map(meta) do
    case engage_rule(meta, type) do
      %{handler: handler} when is_binary(handler) and not is_nil(npc) and not is_nil(attacker) ->
        case dynamic_decide(handler, npc, attacker, type) do
          {:deny, _} = deny -> deny
          _ -> do_decide(meta, type, name)
        end

      _ ->
        do_decide(meta, type, name)
    end
  end

  def decide(_meta, _type, _name, _npc, _attacker), do: :allow

  defp do_decide(meta, type, name) do
    case engage_rule(meta, type) do
      %{accept: false} -> {:deny, deny_msg(meta, type, name)}
      _ -> :allow
    end
  end

  defp dynamic_decide("Kantele.NPC.Ultra", npc, attacker, type) do
    Kantele.NPC.Ultra.engage_decide(npc, attacker, type)
  end

  # #816 阿紫 accept_kill 六分支状态机（swmuding 标记 / 同门 / 全局原型 / 给鼎）。
  defp dynamic_decide("Kantele.NPC.XingXiuAzi", npc, attacker, type) do
    Kantele.NPC.XingXiuAzi.engage_decide(npc, attacker, type)
  end

  defp dynamic_decide(_, _npc, _attacker, _type), do: :allow

  @doc "取战斗类型对应的 engage 规则（fight/hit/kill → engage[type]）"
  def engage_rule(meta, type) do
    case Map.get(meta, :engage) do
      %{} = engage when map_size(engage) > 0 -> Map.get(engage, String.to_atom(type))
      _ -> nil
    end
  end

  defp deny_msg(meta, type, name) do
    case engage_rule(meta, type) do
      %{msg: msg} when is_binary(msg) and msg != "" -> msg <> "\n"
      _ -> default_deny_msg(name, type)
    end
  end

  defp default_deny_msg(name, type) do
    name = name || "对方"

    case type do
      "kill" -> "#{name}摇了摇头，道：“你要杀我？”\n"
      "hit" -> "#{name}避开你的攻击，喝道：动什么手！\n"
      _ -> "#{name}摇了摇头，拒绝与你切磋。\n"
    end
  end
end
