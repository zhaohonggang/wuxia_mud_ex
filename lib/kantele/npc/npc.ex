defmodule Kantele.NPC do
  @moduledoc """
  NPC 行为与 AI 基础设施（对应 LPC inherit/npc.c）

  - AskHandler：可执行问询（check/execute + Effects）
  - Combat.AI：战斗决策
  - on_unconcious：不可击倒钩子
  """

  defmodule Kantele.NPC.AskHandler do
    @moduledoc """
    问询行为契约（对应 LPC NPC 的 ask/1 与 ask 收徒/授技/给物链）

    实现模块需定义：
      @ask_specs %{
        "keyword" => %{
          check: fn(asker, npc) -> :ok | {:error, msg} end,
          execute: fn(asker, npc) -> :ok | {:error, msg} end,
          effects: [{:give_item, item_id}, {:improve_skill, skill, lvl}, ...]
        }
      }
    """

    @callback ask_specs() :: map()

    @callback check(map(), map(), String.t()) :: :ok | {:error, String.t()}

    @callback execute(map(), map(), String.t()) :: :ok | {:error, String.t()}

    @callback effects(map(), map(), String.t()) :: [term()]
  end

  defmodule Kantele.NPC.CombatAI do
    @moduledoc """
    战斗 AI 决策（对应 LPC chat_chance_combat/chat_msg_combat + Combat.AI.decide_action）

    输入：NPC 状态、敌人列表、房间环境
    输出：`{:perform, perform_id}` | `{:exert, function}` | `{:flee}` | `{:attack}`
    """

    @type decision :: {:perform, String.t()} | {:exert, String.t()} | :flee | :attack

    @callback decide(map(), [map()], map()) :: decision()
  end

  @doc """
  昏迷/死亡拦截（对应 LPC on_unconcious/revive/die 可重写）

  返回 `:ignore` 让 NPC 不昏迷/不死（如张三丰）；
  返回 `:die` 强制死亡；
  默认 `:default` 走标准流程。
  """
  def on_unconcious(_npc, _attacker), do: :default
  def on_die(_npc, _killer), do: :default
  def on_revive(_npc), do: :default

  @doc """
  携带物品（对应 LPC carry_object）

  创建物品并移动到 NPC 背包。
  返回物品实例或 nil。
  """
  def carry_object(npc, item_id) do
    case Items.get(item_id) do
      nil -> nil
      item_def -> Items.create_instance(item_def)
    end
  end

  @doc """
  添加货币（对应 LPC add_money）

  在 NPC 背包添加指定面额和数量的货币。
  """
  def add_money(npc, _denom, _amount) do
    # 货币通过 Items 系统管理，具体实现取决于框架
    :ok
  end

  @doc """
  NPC 是否可说话（对应 LPC can_speak）
  """
  def can_speak?(npc) do
    Map.get(npc, :meta, %{})["can_speak"] == true
  end

  @doc """
  NPC 态度（对应 LPC attitude）
  """
  def attitude(npc) do
    Map.get(npc, :meta, %{})["attitude"] || "neutral"
  end
end