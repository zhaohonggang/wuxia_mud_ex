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

  ## 数值表达式

  效果/busy 里的数值可为整数或表达式（spec 的 `value()` 类型），
  按当前角色状态求值：

      {:skill, id}        Stats.skill/2
      {:effective, id}    Stats.effective/2
      {:add, a, b} {:sub, a, b} {:mul, a, b} {:div, a, b}
      {:random, min, max} 含端点均匀随机（rng 可注入，便于测试）

  ## buff 到期

  spec 带 `duration`（秒；`{:skill, id}` 取技能等级）时，效果应用后对其
  首个 `{:buff, key, applies}` 投递 `combat/buff-expire`（`expire_message`
  为到期文案），对应 LPC 的 `start_call_out(remove_effect, skill)`。

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

  @typedoc "随机源：`rng.(n)` 返回 1..n"
  @type rng :: (pos_integer() -> pos_integer())

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

  @doc "按 spec 执行（默认随机源 `:rand.uniform/1`）"
  @spec run(Kalevala.Character.Conn.t(), Spec.t()) :: Kalevala.Character.Conn.t()
  def run(conn, %Spec{} = spec), do: run(conn, spec, &:rand.uniform/1)

  @doc "按 spec 执行，随机源可注入（测试用）"
  @spec run(Kalevala.Character.Conn.t(), Spec.t(), rng()) :: Kalevala.Character.Conn.t()
  def run(conn, %Spec{} = spec, rng) do
    character = conn.character
    ctx = context(conn, character)

    with :ok <- check_gates(spec.gates, ctx) do
      apply_spec(conn, character, spec, ctx, rng)
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

  defp apply_spec(conn, character, spec, ctx, rng) do
    vitals = apply_costs(character.meta.vitals, spec.costs)

    state =
      Enum.reduce(
        spec.effects,
        %{vitals: vitals, combat: character.meta.combat, messages: [], buff: nil},
        fn
          effect, state -> apply_effect(effect, state, ctx, rng)
        end
      )

    combat = apply_busy(state.combat, spec.busy, ctx, rng)
    messages = state.messages ++ message_texts(spec.message, ctx)

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

    schedule_expire(spec, state.buff, ctx, rng)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp apply_costs(vitals, costs) do
    Enum.reduce(costs, vitals, fn {key, amount}, vitals ->
      Map.update!(vitals, key, &max(&1 - amount, 0))
    end)
  end

  defp apply_effect({:temp, applies}, state, ctx, rng),
    do: %{state | combat: Combat.apply_temp(state.combat, eval_map(applies, ctx, rng))}

  defp apply_effect({:buff, key, applies}, state, ctx, rng) do
    applies = eval_map(applies, ctx, rng)
    buff = %Buff{key: key, applies: negate(applies)}

    combat =
      state.combat
      |> Combat.apply_temp(applies)
      |> Combat.add_buff(buff)

    %{state | combat: combat, buff: {key, buff.applies}}
  end

  defp apply_effect({:set, vital, value}, state, ctx, rng),
    do: %{state | vitals: Map.put(state.vitals, vital, eval(value, ctx, rng))}

  defp apply_effect({:add, vital, delta}, state, ctx, rng),
    do: %{state | vitals: Map.update!(state.vitals, vital, &(&1 + eval(delta, ctx, rng)))}

  defp apply_effect({:message, text}, state, _ctx, _rng),
    do: %{state | messages: state.messages ++ [text]}

  defp apply_busy(combat, {:if_fighting, rounds}, ctx, rng) do
    if Combat.fighting?(combat),
      do: Combat.start_busy(combat, eval(rounds, ctx, rng)),
      else: combat
  end

  defp apply_busy(combat, rounds, ctx, rng), do: Combat.start_busy(combat, eval(rounds, ctx, rng))

  # -- 数值表达式 ---------------------------------------------------------

  defp eval(value, _ctx, _rng) when is_integer(value), do: value

  defp eval({:skill, skill_id}, ctx, _rng), do: Stats.skill(ctx.stats, skill_id)
  defp eval({:effective, skill_id}, ctx, _rng), do: Stats.effective(ctx.stats, skill_id)

  defp eval({:add, a, b}, ctx, rng), do: eval(a, ctx, rng) + eval(b, ctx, rng)
  defp eval({:sub, a, b}, ctx, rng), do: eval(a, ctx, rng) - eval(b, ctx, rng)
  defp eval({:mul, a, b}, ctx, rng), do: eval(a, ctx, rng) * eval(b, ctx, rng)
  defp eval({:div, a, b}, ctx, rng), do: div(eval(a, ctx, rng), eval(b, ctx, rng))

  defp eval({:random, min, max}, _ctx, rng), do: min + rng.(max - min + 1) - 1

  defp eval_map(applies, ctx, rng),
    do: Map.new(applies, fn {key, value} -> {key, eval(value, ctx, rng)} end)

  defp negate(applies), do: Map.new(applies, fn {key, value} -> {key, -value} end)

  defp message_texts(nil, _ctx), do: []
  defp message_texts(message, _ctx) when is_binary(message), do: [message]
  defp message_texts(fun, ctx) when is_function(fun, 1), do: [fun.(ctx)]

  # -- buff 到期 ----------------------------------------------------------

  defp schedule_expire(%Spec{duration: nil}, _buff, _ctx, _rng), do: :ok
  defp schedule_expire(_spec, nil, _ctx, _rng), do: :ok

  defp schedule_expire(%Spec{} = spec, {key, applies}, ctx, rng) do
    seconds = eval(spec.duration, ctx, rng)

    if seconds > 0 do
      Process.send_after(
        self(),
        %Kalevala.Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{key: key, applies: applies, message: spec.expire_message}
        },
        seconds * 1000
      )
    end

    :ok
  end
end
