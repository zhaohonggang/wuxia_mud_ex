defmodule Kantele.Drunk do
  @moduledoc """
  醉酒 condition：`apply_condition("drunk", N)`（P3 `liquid` 收尾，酒类消费端）。

  对应 LPC `kungfu/condition/drunk.c`。触发点是 `cmds/std/drink.c` 的

      switch (ob->query("liquid/type")) {
      case "alcohol":
          me->apply_condition("drunk",
              (int)me->query_condition("drunk") + (int)ob->query("liquid/drunk_apply"));
          break;
      }

  即**每喝一口酒累加醉度**，之后按心跳递减并分档发作。

  ## LPC 原始 `update_condition(me, duration)`（逐字保留）

      limit = (me->query("con") + (int)me->query("max_neili") / 50) * 2;

      if (duration > limit && living(me))        me->unconcious();  return 0;
      else if (!living(me))                      vision(…"依然烂醉如泥。");
      else if (duration > limit / 2)             tell(…"大概是醉了。");  vision(…);  receive_damage("jing", 10);
      else if (duration > limit / 4)             tell(…"眼皮有些沉重了。"); vision(…); receive_healing("jing", 10); receive_healing("qi", 15);

      me->apply_condition("drunk", duration - 1);
      if (!duration) return 0;
      return 1;

  三档共用一个 `limit`：超过 `limit` 直接昏厥并**清除**该 condition；`limit/2`
  扣精（醉得站不稳）；`limit/4` 反而回精回气（酒意微醺）。`limit` 随骨力 `con`
  与 `max_neili` 变化 —— 内力越深越能喝。

  ## 本引擎的拆分

  `Kantele.Character.Conditions` 把「生命周期」与「每跳效果」分成两个回调，
  而 LPC 的 `update_condition` 是混在一起的。这里按既有约定（见
  `Kantele.Duyan`）拆开：

  - `update_condition/1`：只递减与到期（`< 1` 即 `{:expire}`）。
  - `do_effect/3`：按**递减后**的 duration 分档发作。

  与 `Kantele.Duyan` 相同，这里不还原 LPC「用传入 duration 判定、却写回
  `duration - 1`」的 off-by-one（那会多打一跳）。

  ## 昏厥分支如何清除 condition

  LPC 的昏厥分支 `return 0` 会顺手把 condition 摘掉。本引擎的 `do_effect/3`
  只能返回新 state，没有「删条件」的返回值，所以这里把**醉度直接归零**
  （写回 `state.conditions`），下一跳生命周期看到 0 即 `{:expire}`。
  净效果等价，代价是昏厥后条件多存活约 1 秒（期间 duration=0，不触发任何档位）。

  ## 消息通道

  daemon 是纯函数、拿不到 conn，故消息经 `state.condition_messages`
  交给宿主 `Kantele.Character.ConditionEvent` 落地：

      {:tell, text}    → 只发给本人
      {:vision, text}  → 房间广播，`{npc}` 由 VisionView 按接收者渲染

  昏厥经 `state.condition_unconcious` 标记，由宿主调
  `Kantele.World.RoomActions.Break.unconcious/1`。

  **一处本地补白**：LPC 的 `unconcious()` 由 mudlib 自己播报（不在 `drunk.c` 里），
  而本引擎 `Kantele.Feature.Damage.unconcious/1` 不做任何播报（全库无
  「昏了过去」类文案）→ 若完全照搬，玩家会毫无提示地倒地。故此处补一句
  `"你醉得不省人事，一头栽倒在地。\n"` 给本人，避免静默。
  """

  alias Kantele.Character.Conditions

  @cnd "drunk"

  @msg_self_half "你觉得脑中昏昏沉沉，身子轻飘飘地，大概是醉了。\n"
  @msg_vision_half "{npc}摇头晃脑地站都站不稳，显然是喝醉了。\n"
  @msg_self_quarter "你觉得一阵酒意上冲，眼皮有些沉重了。\n"
  @msg_vision_quarter "{npc}脸上已经略显酒意了。\n"
  @msg_vision_unliving "{npc}打了个隔，不过依然烂醉如泥。\n"

  # limit/2 档：receive_damage("jing", 10)
  @half_jing_loss 10
  # limit/4 档：receive_healing("jing", 10) + receive_healing("qi", 15)
  @quarter_jing_gain 10
  @quarter_qi_gain 15

  @doc "给 'drunk' 返回 {:ok, Drunk}"
  def daemon("drunk"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc "生命周期：每跳 duration 减一，< 1 到期（与 `Kantele.Duyan` 同约定）"
  def update_condition(info) do
    d = int(Map.get(info, "duration")) - 1

    if d < 1 do
      {:expire}
    else
      {:continue, Map.put(info, "duration", d)}
    end
  end

  @doc """
  内功解酒（LPC `drunk.c dispel(me, ob, duration)`）。

      need_lvl = duration + 50;
      if (me != ob) need_lvl = need_lvl * 3 / 2;
      if (need_lvl > me->query_skill("force")) { …「内功火候尚有欠缺」…; return -1; }
      …成功文案…; ob->clear_condition("drunk"); return 1;

  `ctx`：`%{force: 内力技能等级, self?: 是否对自己运功, target_name: 他人名}`。
  返回 `:ok`/`{:ok, msg}`（驱散）/ `{:fail, msg}`（内力不够，保留醉度）。

  注意回调名是 `dispel_condition/2`（照搬 LPC `feature/condition.c` 的函数名），
  **不是** `dispel/2` —— `Kantele.Poison` 已有一个语义完全不同的
  `dispel/2`（状态变换式的解毒），同名会被 `Conditions` 误当成协议实现。
  """
  def dispel_condition(info, ctx) do
    duration = int(Map.get(info, "duration"))
    self? = Map.get(ctx, :self?, true)
    need = if self?, do: duration + 50, else: div((duration + 50) * 3, 2)
    force = Map.get(ctx, :force) || 0

    if need > force do
      {:fail, dispel_fail_message(self?, ctx)}
    else
      {:ok, dispel_ok_message(self?, ctx)}
    end
  end

  defp dispel_fail_message(true, _ctx), do: "你的内功火候尚有欠缺，无法消除醉酒的影响。\n"

  defp dispel_fail_message(false, ctx) do
    "你的内功火候尚有欠缺，无法帮助#{name_of(ctx)}消除醉酒的影响。\n"
  end

  defp dispel_ok_message(true, _ctx), do: "调息以后，你清醒多了，再没有半点醉酒的感觉。\n"

  defp dispel_ok_message(false, ctx) do
    "你将内力缓缓的输入到#{name_of(ctx)}经脉，#{name_of(ctx)}精神一振。\n"
  end

  defp name_of(ctx), do: Map.get(ctx, :target_name) || "对方"

  @doc "每 tick：按 `limit` 三档发作（见 moduledoc 的 LPC 原文）"
  def do_effect(state, _cnd, _para) do
    duration = duration(state)
    limit = limit(state)
    attrs = Map.get(state, :attributes) || %{}

    cond do
      duration > limit and living?(attrs) ->
        # LPC: me->unconcious(); return 0 —— 醉度归零，下一跳生命周期摘除
        {:ok,
         state
         |> push_message({:tell, "你醉得不省人事，一头栽倒在地。\n"})
         |> Map.put(:condition_unconcious, true)
         |> zero_duration()}

      not living?(attrs) ->
        {:ok, push_message(state, {:vision, @msg_vision_unliving})}

      duration > div(limit, 2) ->
        state
        |> push_message({:tell, @msg_self_half})
        |> push_message({:vision, @msg_vision_half})
        |> adjust(:jing, -@half_jing_loss, Map.get(attrs, :max_jing))
        |> ok()

      duration > div(limit, 4) ->
        state
        |> push_message({:tell, @msg_self_quarter})
        |> push_message({:vision, @msg_vision_quarter})
        |> adjust(:jing, @quarter_jing_gain, Map.get(attrs, :max_jing))
        |> adjust(:qi, @quarter_qi_gain, Map.get(attrs, :max_qi))
        |> ok()

      true ->
        {:ok, state}
    end
  end

  @doc """
  醉度上限（LPC `(query("con") + query("max_neili") / 50) * 2`）。

  公开供测试与将来的「解酒」判定复用。
  """
  def limit(state) do
    attrs = Map.get(state, :attributes) || %{}
    con = Map.get(attrs, :con) || 0
    max_neili = Map.get(attrs, :max_neili) || 0
    (con + div(max_neili, 50)) * 2
  end

  # ---- internal ----

  defp duration(state) do
    case Conditions.query_condition(state, @cnd) do
      %{"duration" => d} -> int(d)
      info when is_map(info) -> int(Map.get(info, "duration"))
      _ -> 0
    end
  end

  defp living?(attrs) do
    (Map.get(attrs, :qi) || 0) > 0 and (Map.get(attrs, :jing) || 0) > 0
  end

  # LPC 的 receive_damage 无下限保护（qi/jing 会被 unconcious 兜住），
  # receive_healing 则夹到 max；这里统一按「减不过 0、加不过 max」处理。
  defp adjust(state, key, delta, cap) do
    current = Map.get(state.attributes, key) || 0

    value =
      cond do
        delta < 0 -> max(current + delta, 0)
        is_integer(cap) and cap > 0 -> min(current + delta, cap)
        true -> current + delta
      end

    put_in(state, [:attributes, key], value)
  end

  defp zero_duration(state) do
    conditions = Map.get(state, :conditions) || %{}

    case Map.get(conditions, @cnd) do
      info when is_map(info) ->
        Map.put(state, :conditions, Map.put(conditions, @cnd, Map.put(info, "duration", 0)))

      _ ->
        state
    end
  end

  defp push_message(state, msg) do
    Map.update(state, :condition_messages, [msg], fn msgs -> msgs ++ [msg] end)
  end

  defp ok(state), do: {:ok, state}

  defp int(nil), do: 0
  defp int(n) when is_integer(n), do: n
  defp int(n) when is_float(n), do: trunc(n)

  defp int(n) when is_binary(n) do
    case Integer.parse(String.trim(n)) do
      {v, _} -> v
      _ -> 0
    end
  end

  defp int(_), do: 0
end
