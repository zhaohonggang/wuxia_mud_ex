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
    case engage_rule(meta, type) do
      %{accept: false} -> {:deny, deny_msg(meta, type, name)}
      _ -> :allow
    end
  end

  def decide(_meta, _type, _name), do: :allow

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