defmodule Kantele.Combat.Performs.Simple do
  @moduledoc """
  声明式绝招/运功解释器（D3）

  按 `Kantele.Combat.Performs.Spec` 执行：校验门槛 → 扣消耗 → 应用效果 →
  busy → 广播文案；失败时渲染门槛自带文案。

  用法（为每招生成一个实现模块）：

      defmodule Kantele.Combat.Skills.Performs.Force.Powerup do
        use Kantele.Combat.Performs.Simple,
          spec: %Kantele.Combat.Performs.Spec{
            id: "force/powerup",
            gates: [{:neili_min, 100, "你的内力不够！\\n"}],
            costs: %{neili: 100},
            effects: [{:buff, "powerup", %{attack: 20}}],
            busy: {:if_fighting, 3},
            message: "$N运功完毕。\\n"
          }
      end

  生成模块导出 `run/1`（满足 `Kantele.Combat.Perform`）与 `spec/0`；
  `perform_list/0`/`exert_list/0` 照常映射到该模块。

  `{:custom, fun, msg}` 的入参 ctx：

      %{conn:, character:, stats:, combat:, vitals:}

  超出 spec 表达力时，回退手写模块，不要硬塞。
  """

  import Kalevala.Character.Conn

  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Performs.Spec

  @doc "为声明式 spec 生成实现模块（注入 `run/1` 与 `spec/0`）"
  defmacro __using__(opts) do
    spec = Keyword.fetch!(opts, :spec)

    quote do
      @behaviour Kantele.Combat.Perform

      @impl true
      def run(conn), do: Kantele.Combat.Performs.Simple.run(conn, unquote(spec))

      @doc "本模块的声明式规格"
      def spec(), do: unquote(spec)
    end
  end

  @doc "按 spec 执行"
  @spec run(Kalevala.Character.Conn.t(), Spec.t()) :: Kalevala.Character.Conn.t()
  def run(conn, %Spec{} = spec) do
    character = conn.character

    with :ok <- check_gates(spec.gates, context(conn, character)) do
      apply_spec(conn, character, spec)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp context(conn, character) do
    %{
      conn: conn,
      character: character,
      stats: character.meta.stats,
      combat: character.meta.combat,
      vitals: character.meta.vitals
    }
  end

  # -- 门槛 ---------------------------------------------------------------

  defp check_gates(gates, ctx) do
    Enum.reduce_while(gates, :ok, fn gate, :ok ->
      case check_gate(gate, ctx) do
        :ok -> {:cont, :ok}
        {:error, _} = error -> {:halt, error}
      end
    end)
  end

  defp check_gate({:perform_known, perform_id, message}, ctx),
    do: gate(Stats.perform_known?(ctx.stats, perform_id), message)

  defp check_gate({:skill_min, skill_id, needed, message}, ctx),
    do: gate(Stats.skill(ctx.stats, skill_id) >= needed, message)

  defp check_gate({:mapped, usage, skill_id, message}, ctx),
    do: gate(Stats.mapped(ctx.stats, usage) == skill_id, message)

  defp check_gate({:neili_min, needed, message}, ctx),
    do: gate(ctx.vitals.neili >= needed, message)

  defp check_gate({:max_neili_min, needed, message}, ctx),
    do: gate(ctx.vitals.max_neili >= needed, message)

  defp check_gate({:qi_min, needed, message}, ctx),
    do: gate(ctx.vitals.qi >= needed, message)

  defp check_gate({:jing_min, needed, message}, ctx),
    do: gate(ctx.vitals.jing >= needed, message)

  defp check_gate({:no_buff, key, message}, ctx),
    do: gate(not Combat.buff_active?(ctx.combat, key), message)

  defp check_gate({:buff, key, message}, ctx),
    do: gate(Combat.buff_active?(ctx.combat, key), message)

  defp check_gate({:custom, fun, message}, ctx), do: gate(fun.(ctx), message)

  defp gate(true, _message), do: :ok
  defp gate(false, message), do: {:error, message}

  # -- 效果 ---------------------------------------------------------------

  defp apply_spec(conn, character, spec) do
    vitals = apply_costs(character.meta.vitals, spec.costs)

    state =
      Enum.reduce(spec.effects, %{vitals: vitals, combat: character.meta.combat, messages: []}, fn effect,
                                                                                                   state ->
        apply_effect(effect, state)
      end)

    combat = apply_busy(state.combat, spec.busy)
    messages = if spec.message, do: state.messages ++ [spec.message], else: state.messages

    character = %{
      character
      | meta:
          character.meta
          |> Map.put(:vitals, state.vitals)
          |> Map.put(:combat, combat)
    }

    conn =
      Enum.reduce(messages, conn, fn text, conn ->
        Broadcast.publish(conn, text, n1: character.name)
      end)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp apply_costs(vitals, costs) do
    Enum.reduce(costs, vitals, fn {key, amount}, vitals ->
      Map.update!(vitals, key, &max(&1 - amount, 0))
    end)
  end

  defp apply_effect({:temp, applies}, state),
    do: %{state | combat: Combat.apply_temp(state.combat, applies)}

  defp apply_effect({:buff, key, applies}, state) do
    buff = %Buff{key: key, applies: negate(applies)}

    combat =
      state.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)

    %{state | combat: combat}
  end

  defp apply_effect({:set, vital, value}, state),
    do: %{state | vitals: Map.put(state.vitals, vital, value)}

  defp apply_effect({:add, vital, delta}, state),
    do: %{state | vitals: Map.update!(state.vitals, vital, &(&1 + delta))}

  defp apply_effect({:message, text}, state),
    do: %{state | messages: state.messages ++ [text]}

  defp apply_busy(combat, {:if_fighting, rounds}) do
    if Combat.fighting?(combat), do: Combat.start_busy(combat, rounds), else: combat
  end

  defp apply_busy(combat, rounds) when is_integer(rounds), do: Combat.start_busy(combat, rounds)

  defp negate(applies), do: Map.new(applies, fn {key, value} -> {key, -value} end)
end
