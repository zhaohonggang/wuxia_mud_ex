defmodule Kantele.FlowerPoison do
  @moduledoc """
  断肠花毒 condition：`apply_condition("flower_poison", N)`

  对应 LPC `kungfu/condition/flower_poison.c`。触发点是神龙岛草坪
  （`d/shenlong/caoping.c` 的 `init()`）：

      if (objectp(present("duanchang hua", environment(me))))
      {
          me->apply_condition("flower_poison", 30 + (int)me->query_condition("flower_poison"));
          write(HIG "你只觉一股淡香袭来,顿时脑中一阵麻木！\\n" NOR);
      }

  即**房间里开着断肠花**时，一进去就中毒，毒性**累加** 30 点。

  ## LPC 原始 `update_condition(me, duration)`（逐字保留）

      if(me->query_temp("nopoison")) return 0;

      message("vision", HIG + me->name() + "一阵摇晃，立足不定。\\n" NOR,
              environment(me), me);

      if(! living(me) && (me->query("qi") < 25 || me->query("jing") < 25))
      {
          me->set_temp("die_reason", "断肠花毒发作，不治身亡了");
          me->die();
          return 0;
      }

      me->receive_wound("jing", 25 + random(25));
      me->receive_damage("jing", 25 + random(25));
      me->receive_wound("qi", 50 + random(50));
      me->receive_damage("qi", 50 + random(50));
      if (me->query_skill("force") >= 300)
          me->apply_condition("flower_poison", duration - 1);
      tell_object(me, HIG "你中的" HIR "断肠花毒" HIG "发作了！\\n" NOR );
      if( duration < 1 )
      {
          tell_object(me, HIR "你心口一阵剧痛，不禁一阵晕眩，过后感觉却好了一些。\\n" NOR);
          return 0;
      }
      return 1;

  ## 本引擎的拆分

  按既有约定（见 `Kantele.Duyan` / `Kantele.Drunk`）把「生命周期」与「每跳效果」
  分成两个回调：

  - `update_condition/1`：`duration - 1`，**`< 0` 才到期**。
  - `do_effect/3`：按**递减后**的 duration 结算。

  这里刻意让 `duration == 0` 的那一跳继续存在（下一跳才移除），因为 LPC 在
  `duration < 1` 时**仍然结算一次伤害并播末句**后才 `return 0`。若按常规
  「`< 1` 即到期」，末跳的伤害与「你心口一阵剧痛…」会整段丢失。

  ## 伤害语义

  `receive_wound` 削减上限（`max_jing` / `max_qi`），`receive_damage` 削减当前值。
  宿主 `Kantele.Character.ConditionEvent` 只回写当前值，故本模块在 `state.attributes`
  里同步维护 `max_jing` / `max_qi`，并把它们写回角色 vitals（宿主的回写已扩展）。

  ## 已知偏差

  - **致死分支未移植**：LPC 的 `! living(me) && (qi < 25 || jing < 25)` 会
    `me->die()`。本引擎对**玩家**没有「条件致死」通道（
    `ConditionDownEvent` 只处理登记过 `DownHandlers` 的 NPC），所以这里把
    `die_reason` 记到 `state.condition_die_reason` 供宿主/后续系统取用，并让
    毒性归零，不直接处决玩家。
  - `dispel/2`（运功化解）未移植：LPC 里它恒返回 `-1`（「撕心裂肺的疼痛」），
    即**断肠花毒无法用内力化解**。本引擎不注册 `dispel_condition/2` 即等价。
  """

  alias Kantele.Character.Conditions

  @cnd "flower_poison"

  @msg_vision "{npc}一阵摇晃，立足不定。\n"
  @msg_self "你中的断肠花毒发作了！\n"
  @msg_final "你心口一阵剧痛，不禁一阵晕眩，过后感觉却好了一些。\n"
  @die_reason "断肠花毒发作，不治身亡了"

  # `receive_wound` / `receive_damage` 的基数（LPC 字面量）
  @jing_base 25
  @jing_spread 25
  @qi_base 50
  @qi_spread 50

  # `query_skill("force") >= 300` 时额外多减 1（LPC `apply_condition(cnd, duration - 1)`）
  @force_threshold 300

  @doc "给 'flower_poison' 返回 {:ok, FlowerPoison}"
  def daemon("flower_poison"), do: {:ok, __MODULE__}
  def daemon(_), do: :error

  @doc """
  生命周期：每跳 duration 减一，**减到负数**才到期。

  与 `Kantele.Drunk`（`< 1` 到期）差一跳，是为了保留 LPC 的末跳结算
  （见 moduledoc「本引擎的拆分」）。
  """
  def update_condition(info) do
    d = int(Map.get(info, "duration")) - 1

    if d < 0 do
      {:expire}
    else
      {:continue, Map.put(info, "duration", d)}
    end
  end

  @doc "每 tick：房间广播 + 精/气双扣 + 末跳收尾（见 moduledoc 的 LPC 原文）"
  def do_effect(state, _cnd, _para) do
    duration = duration(state)

    cond do
      nopoison?(state) ->
        # LPC `if(query_temp("nopoison")) return 0;`
        {:ok, zero_duration(state)}

      die?(state) ->
        # LPC 在扣血**之前**就 return 0，故这里也不结算伤害
        {:ok, state |> Map.put(:condition_die_reason, @die_reason) |> zero_duration()}

      true ->
        state
        |> push_message({:vision_excl, @msg_vision})
        |> take_damage()
        |> maybe_extra_decrement()
        |> push_message({:tell, @msg_self})
        |> maybe_final_message(duration)
        |> ok()
    end
  end

  @doc "当前毒性（供测试与「累加毒性」复用）"
  def duration(state) do
    case Conditions.query_condition(state, @cnd) do
      %{"duration" => d} -> int(d)
      info when is_map(info) -> int(Map.get(info, "duration"))
      _ -> 0
    end
  end

  # ---- internal ----

  # LPC `me->query_temp("nopoison")`：临时免疫（吃了解药等）
  defp nopoison?(state) do
    case Map.get(state, :temp) do
      temp when is_map(temp) -> Map.get(temp, "nopoison") not in [nil, false, 0]
      _ -> false
    end
  end

  defp living?(attrs) do
    (Map.get(attrs, :qi) || 0) > 0 and (Map.get(attrs, :jing) || 0) > 0
  end

  # LPC：! living(me) && (qi < 25 || jing < 25) → set_temp("die_reason") + die()
  defp die?(state) do
    attrs = state.attributes

    not living?(attrs) and
      ((Map.get(attrs, :qi) || 0) < 25 or (Map.get(attrs, :jing) || 0) < 25)
  end

  # receive_wound("jing", 25+random(25)) → max_jing 削减
  # receive_damage("jing", 25+random(25)) → jing 削减
  # receive_wound("qi", 50+random(50))    → max_qi 削减
  # receive_damage("qi", 50+random(50))   → qi 削减
  defp take_damage(state) do
    jing_wound = @jing_base + :rand.uniform(@jing_spread) - 1
    jing_damage = @jing_base + :rand.uniform(@jing_spread) - 1
    qi_wound = @qi_base + :rand.uniform(@qi_spread) - 1
    qi_damage = @qi_base + :rand.uniform(@qi_spread) - 1

    state
    |> wound(:jing, jing_wound)
    |> damage(:jing, jing_damage)
    |> wound(:qi, qi_wound)
    |> damage(:qi, qi_damage)
  end

  # 上限削减：max_* 与当前值一起降（LPC receive_wound 语义）
  defp wound(state, key, amount) do
    max_key = :"max_#{key}"
    attrs = state.attributes
    max_now = Map.get(attrs, max_key) || 0
    new_max = max(max_now - amount, 0)
    cur = Map.get(attrs, key) || 0

    state
    |> put_in([:attributes, max_key], new_max)
    |> put_in([:attributes, key], min(cur, new_max))
  end

  defp damage(state, key, amount) do
    cur = Map.get(state.attributes, key) || 0
    put_in(state, [:attributes, key], max(cur - amount, 0))
  end

  # LPC `if (query_skill("force") >= 300) apply_condition(cnd, duration - 1)`
  # 引擎里再 apply 一次即多减 1（生命周期那一跳已经减过）。
  defp maybe_extra_decrement(state) do
    if (Map.get(state.attributes, :force) || 0) >= @force_threshold do
      conditions = Map.get(state, :conditions) || %{}

      case Map.get(conditions, @cnd) do
        info when is_map(info) ->
          d = max(int(Map.get(info, "duration")) - 1, 0)
          Map.put(state, :conditions, Map.put(conditions, @cnd, Map.put(info, "duration", d)))

        _ ->
          state
      end
    else
      state
    end
  end

  defp maybe_final_message(state, duration) do
    if duration < 1 do
      state |> push_message({:tell, @msg_final}) |> zero_duration()
    else
      state
    end
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
