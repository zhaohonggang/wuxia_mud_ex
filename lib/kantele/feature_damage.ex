defmodule Kantele.Feature.Damage do
  @moduledoc """
  伤害/治疗/昏迷/死亡/复活/心跳回复系统（对应 LPC feature_damage.c / feature_damage.ex）

  纯函数逻辑已在 `lpc_example/ex/feature_damage/feature_damage.ex` 移植并测试通过；
  本模块负责把纯逻辑接入真实框架：Character/Combat/World 循环。
  """

  alias Kantele.Character.{Vitals, Stats, PlayerMeta}
  alias Kantele.Character.Combat
  alias Kantele.Combat.Engine
  alias Kantele.Scheduler
  alias Kantele.World.Room

  @doc """
  受直接伤害（对应 LPC receive_damage/3）：气/精扣减，不为负；触发心跳
  """
  def receive_damage(character, type, amount, who \\ nil) do
    cond do
      amount < 0 ->
        {:error, "Damage cannot be negative"}

      type not in [:qi, :jing] ->
        {:error, "Damage type must be :qi or :jing"}

      true ->
        character = update_last_damage(character, who)

        # 高伤害触发 craze（PK 狂暴值）
        if who && amount > 150 do
          improve_craze(who, div(amount, 5))
        end

        # 扣减当前值（底线 0）
        vitals = Vitals.damage(character.meta.vitals, type, amount)
        character = put_vitals(character, vitals)

        # 受击启用心跳（自然回复）
        set_heart_beat(character, true)

        {:ok, character}
    end
  end

  @doc """
  受创伤（对应 LPC receive_wound/4）：削减 max_*/eff_*，夹住当前值；触发心跳
  """
  def receive_wound(character, type, amount, who \\ nil) do
    cond do
      amount < 0 ->
        {:error, "Damage cannot be negative"}

      type not in [:qi, :jing] ->
        {:error, "Damage type must be :qi or :jing"}

      true ->
        character = update_last_damage(character, who)

        if who && amount > 150 do
          improve_craze(who, div(amount, 3))
        end

        vitals = Vitals.wound(character.meta.vitals, type, amount)
        character = put_vitals(character, vitals)

        set_heart_beat(character, true)

        {:ok, character}
    end
  end

  @doc """
  治疗（对应 LPC receive_heal/4）：当前值向 max_* 回补，不超上限
  """
  def receive_heal(character, type, amount) do
    cond do
      amount < 0 ->
        {:error, "Heal cannot be negative"}

      type not in [:qi, :jing, :neili] ->
        {:error, "Heal type must be :qi, :jing, or :neili"}

      true ->
        vitals = Vitals.heal(character.meta.vitals, type, amount)
        character = put_vitals(character, vitals)
        {:ok, character}
    end
  end

  @doc """
  驱除创伤（对应 LPC receive_curing/4）：把 wound 削低的 max_* 向 base_* 回补
  """
  def receive_curing(character, type, amount) do
    cond do
      amount < 0 ->
        {:error, "Cure cannot be negative"}

      type not in [:qi, :jing, :neili] ->
        {:error, "Cure type must be :qi, :jing, or :neili"}

      true ->
        vitals = Vitals.curing(character.meta.vitals, type, amount)
        character = put_vitals(character, vitals)
        {:ok, character}
    end
  end

  # ---- DPS / 击杀追踪 ----

@doc "记录击杀（DPS/胜负追踪）"
  def record_defeat(character, victim) do
    if killing?(character, victim.id) do
      PlayerMeta.update_damage(character, fn dmg ->
        dp = dmg.defeat_player || []
        if victim.id in dp do
          dmg
        else
          Map.put(dmg, :defeat_player, [victim.id | dp])
        end
      end)
    else
      character
    end
  end

  def remove_defeat(character, victim_id) do
    PlayerMeta.update_damage(character, fn dmg ->
      Map.put(dmg, :defeat_player, List.delete(dmg.defeat_player || [], victim_id))
    end)
  end

  def clear_defeats(character) do
    PlayerMeta.update_damage(character, fn dmg -> Map.put(dmg, :defeat_player, []) end)
  end

  # ---- 昏迷/复活/死亡 ----

  @doc "昏迷处理（对应 LPC unconcious/2）"
  def unconcious(character) do
    cond do
      not living?(character) ->
        {:ok, character}

      wizard_immortal?(character) ->
        {:ok, character}

      true ->
        # 竞争处理
        character = handle_competition_unconcious(character)

        # 忙乱中断
        character = if busy?(character), do: interrupt_me(character), else: character

        # 运行 override（留钩子给特殊 NPC）
        if run_override(character, "unconcious") do
          {:ok, character}
        else
          handle_unconcious(character)
        end
    end
  end

  defp handle_unconcious(character) do
    competitor = query_competitor(character)

    character =
      character
      PlayerMeta.update_damage(fn dmg ->
        dmg
        |> Map.put(:defeated_by, competitor)
        |> Map.put(:defeated_by_who, competitor && competitor.name)
      end)

    # DPS 记录
    if competitor && is_player?(character) && killing?(character, competitor.id) do
      character = record_defeat(character, competitor)
    end

    character = clear_enemies(character)

    # 封印状态
    character =
      character
      PlayerMeta.update_damage(fn dmg -> Map.put(dmg, :block_msg_all, 1) end)
      |> disable_player()
      |> put_vitals(%{character.meta.vitals | qi: 0, jing: 0})
      |> PlayerMeta.put_temp("block_msg/all", 1)

    # 自动复活延迟：30 + random(100 - con) 秒
    delay = 30 + :rand.uniform(100 - character.meta.stats.con)
    schedule_revive(character.id, delay * 1000)

    # 广播昏迷
    announce(character, "unconcious")

    # 玩家逃跑检查（保护机制）
    check_player_escape(character)

    {:ok, character}
  end

  @doc "复活处理（对应 LPC revive/3）"
  def revive(character, quiet \\ false) do
    # 取消复活定时
    remove_call_out(character, "revive")

    # 找有效房间（若在尸体链中）
    env = environment(character)
    if env do
      env = find_valid_room(env)
      if env != environment(character) do
        character = move_character(character, env)
      end
    end

    character =
      character
      |> PlayerMeta.delete("disable_type")
      |> PlayerMeta.put_temp("block_msg/all", 0)
      |> enable_player()
      |> write_prompt()

    # 清除 DPS
    character
    |> PlayerMeta.damage_state()
    |> Map.get(:defeated_by)
    |> (fn defeated_by ->
      if defeated_by do
        remove_defeat(defeated_by, character.id)
        character
      else
        character
      end
    end).()

    unless quiet do
      character =
        character
        PlayerMeta.update_damage(fn dmg ->
          dmg
          |> Map.put(:defeated_by, nil)
          |> Map.put(:defeated_by_who, nil)
        end)

      announce(character, "revive")
      send_message(character, "Slowly you regain consciousness...")
    end

    # 清除上次伤害记录
    character =
      character
      PlayerMeta.update_damage(fn dmg ->
        dmg
        |> Map.put(:last_damage_from, nil)
        |> Map.put(:last_damage_name, nil)
      end)

    {:ok, character}
  end

  @doc "死亡处理（对应 LPC die/3）"
  def die(character, killer \\ nil) do
    character = delete_sleep_flags(character)

    # 竞争处理
    competitor = query_competitor(character)
    if competitor do
      # 胜负结算留给 Combat.announce
    end

    character = if busy?(character), do: interrupt_me(character), else: character

    if run_override(character, "die") do
      {:ok, character}
    else
      handle_die(character, killer)
    end
  end

  defp handle_die(character, killer) do
    character = delete_sleep_flags(character)

    # 竞争结算
    if competitor = query_competitor(character) do
      # win/lost 留给 Combat.announce
    end

    character = if busy?(character), do: interrupt_me(character), else: character

    if run_override(character, "die") do
      {:ok, character}
    else
      process_death(character, killer)
    end
  end

  defp process_death(character, killer) do
    character = delete_sleep_flags(character)

    # 确定击杀者/名称
    {killer, killer_name} = determine_killer(character, killer)

    # 直接死亡标记（已昏迷再死）
    direct_die = ghost?(character) || killing?(character, killer && killer.id)

    # 胜负/奖励
    if direct_die && killer do
      Combat.winner_reward(killer, character)
    end

    # 坐骑下马（留钩子）
    dismount_if_riding(character)

    # 死亡原因（按伤害类型）
    die_reason = determine_die_reason(character)

    # 玩家逃跑检查
    check_player_escape(character)

    # 广播死亡
    announce(character, "dead")

    # 标记击杀者
    character = PlayerMeta.put_temp(character, "my_killer", killer)

    # 击杀者奖励
    if killer do
      Combat.killer_reward(killer, character)
    end

    # 统计/尸体/死亡房间
    character = increment_death_times(character)
    corpse = make_corpse(character)
    character = move_to_death_room(character)

    # 清理
    character = clear_die_flags(character)
    character = PlayerMeta.put_temp(character, "die_reason", nil)

    if is_player?(character) do
      character = if busy?(character), do: interrupt_me(character), else: character
      # 玩家死亡：气精置 1，进入幽灵态，移至死亡房间
      character =
        character
        |> put_vitals(%{character.meta.vitals | qi: 1, jing: 1})
        PlayerMeta.update_damage(fn dmg -> Map.put(dmg, :ghost, true) end)
    else
      # NPC 直接析构（留钩子给 World）
      destruct_npc(character)
    end

    {:ok, character}
  end

  @doc "复活/重生（对应 LPC reincarnate/2）"
  def reincarnate(character) do
    character =
      character
      PlayerMeta.update_damage(fn dmg -> Map.put(dmg, :ghost, false) end)
      |> put_vitals(%{
        character.meta.vitals
        | eff_jing: character.meta.vitals.max_jing,
          eff_qi: character.meta.vitals.max_qi
      })
    {:ok, character}
  end

  # ---- 心跳回复（heal_up）----

  @doc "心跳回复（对应 LPC heal_up/1，对应 feature_damage.ex heal_up/2）"
  def heal_up(character) do
    # 清除 nopoison
    character = PlayerMeta.delete_temp(character, "nopoison")

    # 监狱处理（占位）
    if in_prison?(character) do
      update_in_prison(character)
      return {:ok, character}
    end

    scale = if living?(character), do: 1, else: (if is_player?(character), do: 4, else: 8)

    # 非玩家/非聊天室/非 scheme 时才回复
    unless not is_player?(character) or
           (environment(character) and not chat_room?(environment(character)) and
            (not is_binary(character.meta.temp.doing) and interactive?(character) or
             character.meta.temp.doing == "scheme")) do
      return {:ok, character}
    end

    vitals = character.meta.vitals
    stats = character.meta.stats

    # 食物/水消耗
    vitals = if vitals.water > 0, do: %{vitals | water: vitals.water - 1}, else: vitals
    vitals = if vitals.food > 0, do: %{vitals | food: vitals.food - 1}, else: vitals

    if vitals.water < 1 and is_player?(character) do
      return {:ok, character}
    end

    # 守卫职责消耗精力
    guard = PlayerMeta.get_temp(character, "guardfor")
    if guard && (not is_map(guard) or not is_character(guard)) do
      if div(vitals.jing * 100, vitals.max_jing) < 50 do
        send_message(character, "You feel too tired, need to relax.")
        return {:ok, character}
      end

      vitals = %{vitals | jing: vitals.jing - 30 - :rand.uniform(20)}
      character = put_vitals(character, vitals)
      return {:ok, character}
    end

    # 精力回复：(con + max_jingli/10) / scale
    jing_gain = div(stats.con + div(vitals.max_jingli, 10), scale)
    vitals = %{vitals | jing: min(vitals.jing + jing_gain, vitals.eff_jing)}

    if vitals.jing >= vitals.eff_jing && vitals.eff_jing < vitals.max_jing do
      vitals = %{vitals | eff_jing: vitals.eff_jing + 1}
    end

    # 气血回复：(con*2 + max_neili/20) / scale，忙乱时不回
    unless busy?(character) do
      qi_gain = div(stats.con * 2 + div(vitals.max_neili, 20), scale)
      vitals = %{vitals | qi: min(vitals.qi + qi_gain, vitals.eff_qi)}

      if vitals.qi >= vitals.eff_qi && vitals.eff_qi < vitals.max_qi do
        vitals = %{vitals | eff_qi: vitals.eff_qi + 1}
      end
    end

    if vitals.food < 1 && is_player?(character) do
      return {:ok, character}
    end

    # 精力修为
    if vitals.max_jingli > 0 && vitals.jingli < vitals.max_jingli do
      jingli_gain = stats.con + div(Stats.skill(stats, "force"), 6)
      vitals = %{vitals | jingli: min(vitals.jingli + jingli_gain, vitals.max_jingli)}
    end

    # 内力
    if vitals.max_neili > 0 && vitals.neili < vitals.max_neili do
      neili_gain = stats.con * 2 + div(Stats.skill(stats, "force"), 3)
      vitals = %{vitals | neili: min(vitals.neili + neili_gain, vitals.max_neili)}
    end

    character = put_vitals(character, vitals)
    {:ok, character}
  end

  # ---- 容量计算 ----

  @doc "最大食物容量（str*10+100 + 奖励）"
  def max_food_capacity(character) do
    f = character.meta.stats.str * 10 + 100
    f = if has_item?(character, "skybook/item/tianshu2"), do: f + 300, else: f
    f = if has_item?(character, "special_skill/greedy"), do: f + 500, else: f
    f
  end

  @doc "最大水容量（str*10+100 + 奖励）"
  def max_water_capacity(character) do
    w = character.meta.stats.str * 10 + 100
    w = if has_item?(character, "skybook/item/tianshu2"), do: w + 300, else: w
    w = if has_item?(character, "special_skill/greedy"), do: w + 500, else: w
    w
  end

  # ---- 内部辅助 ----

  defp update_last_damage(character, who) do
    if who && who != Map.get(PlayerMeta.damage_state(character), :last_damage_from) do
      character
      PlayerMeta.update_damage(fn dmg ->
        dmg
        |> Map.put(:last_damage_from, who)
        |> Map.put(:last_damage_name, character.name(who))
      end)
    else
      character
    end
  end

  defp put_vitals(character, vitals) do
    %{character | meta: Map.put(character.meta, :vitals, vitals)}
  end

  defp set_heart_beat(character, enabled) do
    # 实际应调度 heal_up 心跳，此处占位
    character
  end

  defp improve_craze(_who, _amount), do: :ok

  defp handle_competition_unconcious(character) do
    competitor = query_competitor(character)
    if competitor && not killing?(competitor, character.id) do
      # win/lost 留给 Combat.announce
    end
    character
  end

  defp run_override(_character, _fname), do: false

  defp clear_enemies(character), do: character

  defp disable_player(character), do: character

  defp enable_player(character), do: character

  defp write_prompt(character), do: character

  defp schedule_revive(_player_id, _ms), do: :ok

  defp announce(_character, _event), do: :ok

  defp check_player_escape(_character), do: :ok

  defp find_valid_room(env), do: env

  defp move_character(_character, _env), do: _character

  defp delete_sleep_flags(character), do: character

  defp determine_killer(character, killer) do
    {killer, killer && killer.name}
  end

  defp dismount_if_riding(character), do: character

  defp determine_die_reason(_character), do: "unknown"

  defp increment_death_times(character), do: character

  defp make_corpse(_character), do: nil

  defp move_to_death_room(character), do: character

  defp clear_die_flags(character), do: character

  defp destruct_npc(_character), do: :ok

  defp living?(%{meta: %{vitals: vitals}}), do: vitals.qi > 0 || vitals.jing > 0

  defp wizard_immortal?(_character), do: false

  defp busy?(%{meta: %{combat: combat}}), do: Combat.busy?(combat)

  defp interrupt_me(character) do
    %{character | meta: Map.put(character.meta, :combat, Combat.interrupt(character.meta.combat))}
  end

  defp killing?(%{meta: %{temp: temp}} = character, target_id) do
    Map.get(temp, "want_kill") == target_id || Map.get(temp, "killing") == target_id
  end

  defp is_player?(%{id: id}), do: is_binary(id) && String.starts_with?(id, "player:")
  defp is_character(%{id: id}), do: is_binary(id)

  defp environment(character), do: character.meta.zone_id

  defp chat_room?(_env), do: false

  defp interactive?(_character), do: true

  defp in_prison?(_character), do: false

  defp update_in_prison(_character), do: :ok

  defp has_item?(_character, _item_id), do: false

  defp remove_call_out(_character, _name), do: :ok

  defp query_competitor(_character), do: nil

  defp send_message(_character, _msg), do: :ok

  defp winner_reward(_killer, _victim), do: :ok
  defp killer_reward(_killer, _victim), do: :ok
  defp announce(_character, _event), do: :ok

  defp schedule_revive(_player_id, _ms), do: :ok

  defp ghost?(%{meta: %{damage: dmg}}), do: dmg.ghost || false
  defp return(_v), do: :ok
end