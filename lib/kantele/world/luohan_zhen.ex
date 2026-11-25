defmodule Kantele.World.LuohanZhen do
  @moduledoc """
  十八罗汉大阵事件子系统（对应 LPC kungfu/class/shaolin/xuan-ku.h / xuan-nan.h / cheng.h）。

  ## LPC 机制概览

  - 玩家向 玄苦 或 玄难 打听「十八罗汉阵/罗汉大阵」，触发 ask_me。
  - 门控：长老必须少林派；玩家技能数 > 1 且任一检查技能 >= 80；未闯过阵；
    少林派玩家辈份不得高于长老 + 2；guilty == 0；无 assigned_fighter。
  - 双长老同步：xuanku-asked / xuannan-asked 临时标志，两方都被问后才进入 preparing。
  - 300秒等待超时；10秒准备；10轮 × 2秒战斗循环；beat_count >= 18 胜利。
  - 胜利奖励 +7500 combat_exp，设置 luohan_winner 持久标志。
  - 战斗中练武场出口封锁，战后僧众返回原房、出口恢复。

  ## 架构

  本模块为**纯状态机层**：所有转换为纯函数，接收 `Challenge` 结构并返回
  `{:ok, challenge, effects}` 或 `{:error, reason}`。`effects` 是待执行的副作用
  描述（广播、封锁出口、移动 NPC、定时器、战斗等），由
  `Kantele.World.LuohanZhen.Coordinator` 执行。

  这种分层使得状态机逻辑可直接单测，无需启动完整世界。
  """

  # === 房间常量（shaolin.ucl） ===

  @arena_room "shaolin:wuchang"
  @east_arena "shaolin:wuchang2"
  @west_arena "shaolin:wuchang1"
  @houdian_room "shaolin:houdian"

  # 两位长老 NPC id（clone_lib.ucl 中的 characters key）
  @xuanku_npc "shaolin_xuan_ku"
  @xuannan_npc "shaolin_xuan_nan"

  # 道觉僧（wuchang 中的常驻 NPC，preparing 时暂避后殿）
  @daojue_npc "shaolin_dao_jue"

  # 玄苦方 9 位罗汉原房 luohan1-9，召集后移到 @east_arena
  @xuanku_monk_rooms ~w(shaolin:luohan1 shaolin:luohan2 shaolin:luohan3 shaolin:luohan4
                        shaolin:luohan5 shaolin:luohan6 shaolin:luohan7 shaolin:luohan8 shaolin:luohan9)

  # 玄难方 9 位罗汉原房 banruo1-9，召集后移到 @west_arena
  @xuannan_monk_rooms ~w(shaolin:banruo1 shaolin:banruo2 shaolin:banruo3 shaolin:banruo4
                        shaolin:banruo5 shaolin:banruo6 shaolin:banruo7 shaolin:banruo8 shaolin:banruo9)

  # 每方罗汉在集结房中的出场顺序（对应 LPC names 数组索引 0..8）
  @xuanku_monk_ids ~w(shaolin_cheng_guan shaolin_cheng_zhi shaolin_cheng_ming shaolin_cheng_jing
                      shaolin_cheng_jian shaolin_cheng_xing shaolin_cheng_ji shaolin_cheng_mie shaolin_cheng_he)

  @xuannan_monk_ids ~w(shaolin_cheng_xin shaolin_cheng_yi shaolin_cheng_si shaolin_cheng_shi
                       shaolin_cheng_zhi2 shaolin_cheng_xin2 shaolin_cheng_ling shaolin_cheng_yu shaolin_cheng_shang)

  # 检查技能（LPC checks 数组）：任一达标即可
  @check_skills ~w(finger claw hand strike cuff dodge parry force)
  @min_skill_level 80

  # 定时（毫秒）
  @wait_interval 1_000
  @max_wait_seconds 300
  @prepare_delay_ms 10_000
  @fight_round_delay_ms 2_000
  @do_back_delay_ms 5_000
  @do_recruit_delay_ms 30_000

  # 战斗奖励
  @win_beat_count 18
  @win_combat_exp 7500

  # 临时标志键名（对应 LPC set_temp/query_temp）
  @t_xuanku_asked "xuanku-asked"
  @t_xuannan_asked "xuannan-asked"
  @t_beat_count "beat_count"
  @t_fighting "fighting"

  # === 挑战状态结构 ===

  defstruct ~w[
    fighter_id      :: binary | nil,
    fighter_name    :: binary | nil,
    fighter_room_id :: binary | nil,
    state           :: atom,
    master_asked    :: map,
    temp_flags      :: map,
    wait_time       :: non_neg_integer,
    beat_count      :: non_neg_integer,
    round           :: non_neg_integer,
    timer_refs      :: map,
    result          :: atom | nil,
    assigned_by     :: binary | nil
  ]a

  @initial_master_asked %{"xuanku" => false, "xuannan" => false}

  def new_challenge(fighter, master_side) when is_binary(master_side) do
    %__MODULE__{
      fighter_id: fighter.id,
      fighter_name: fighter.name,
      fighter_room_id: fighter.room_id,
      state: :summoning,
      master_asked: Map.put(@initial_master_asked, master_side, true),
      temp_flags: %{},
      wait_time: 0,
      beat_count: 0,
      round: 0,
      timer_refs: %{},
      result: nil,
      assigned_by: master_side
    }
  end

  # === 公共 API：问询入口（对应 LPC ask_me） ===

  @doc """
  玩家向长老问询“十八罗汉阵/罗汉大阵”。

  执行 LPC ask_me 的全部门控，通过后返回 `{:ok, challenge, effects}`，
  effects 包含设置临时标志、assigned_fighter、长老移动、召集罗汉僧、
  启动 waiting 定时器。

  返回 `{:error, reason}` 时不产生任何副作用。
  """
  def initiate(fighter, master_npc) when is_map(fighter) and is_map(master_npc) do
    cond do
      # 必须有 id 字段才是有效的角色/NPC
      Map.get(fighter, :id) == nil or Map.get(master_npc, :id) == nil ->
        {:error, :invalid_args}

      # 1. 长老家族必须是少林派
      not shaolin_family?(master_npc) ->
        {:error, :not_shaolin_master}

      # 2. 玩家技能门槛：技能数 > 1 且任一检查技能 >= 80
      not skills_enough?(fighter) ->
        {:error, :skills_insufficient}

      # 3. 未闯过阵
      luohan_winner?(fighter) ->
        {:error, :already_winner}

      # 4. 少林派玩家辈份不得高于长老 + 2
      not generation_ok?(fighter, master_npc) ->
        {:error, :generation_mismatch}

      # 5. 无罪
      guilty?(fighter) ->
        {:error, :guilty}

      true ->
        {:ok, new_challenge(fighter, master_side(master_npc)), summoning_effects(fighter, master_npc)}
    end
  end

  def initiate(_fighter, _master_npc), do: {:error, :invalid_args}

  @doc """
  第二位长老加入同一挑战（合并 master_asked 与对应的 temp 标志）。

  玩家先问 玄苦、再问 玄难（或反之），两次 ask_me 都会创建挑战；
  第二次应合并到已有挑战，而非覆盖。
  """
  def merge(%__MODULE__{} = challenge, master_side) when is_binary(master_side) do
    asked_key =
      cond do
        master_side == "xuanku" -> @t_xuanku_asked
        master_side == "xuannan" -> @t_xuannan_asked
        true -> nil
      end

    updates = %{
      temp_flags:
        case asked_key do
          nil -> challenge.temp_flags
          key -> Map.put(challenge.temp_flags || %{}, key, 1)
        end
    }

    updates =
      if asked_key != nil do
        Map.put(updates, :master_asked, Map.put(challenge.master_asked, master_side, true))
      else
        updates
      end

    Map.merge(challenge, updates)
  end

  # === 状态机转换（纯函数） ===

  # --- waiting：等待玩家到场 + 另一位长老被问（每 1s 刷新，300s 超时） ---

  @doc """
  waiting 状态的一次 tick（对应 LPC waiting/1）。

  返回 `{:ok, challenge, effects}`。effects 可能包含：
  - {:schedule_timer, :waiting, 1000} 继续等待
  - {:do_back, :timeout} 超时重置
  - {:prepare, :now} 双方齐备，进入 preparing
  """
  def waiting(challenge) do
    cond do
      # 超时 300秒
      challenge.wait_time >= @max_wait_seconds ->
        {:ok,
         %{challenge | state: :finished, result: :timeout, temp_flags: Map.delete(challenge.temp_flags, @t_xuanku_asked) |> Map.delete(@t_xuannan_asked)},
         do_back_effects(:timeout, challenge)}

      # 另一位长老尚未被问，或玩家未设对方临时标志：继续等
      not other_master_asked?(challenge) or not other_flag_set?(challenge) ->
        {:ok,
         %{challenge | wait_time: challenge.wait_time + 1},
         [schedule(:waiting, @wait_interval)]}

      # 双方齐备：进入 preparing
      true ->
        {:ok, %{challenge | state: :preparing, wait_time: 0}, preparing_effects(challenge)}
    end
  end

  # --- preparing：封锁出口，宣战，10s 后进入第一轮战斗 ---

  @doc """
  preparing 状态（对应 LPC preparing/2）。

  返回 `{:ok, challenge, effects}`：移走道觉僧、广播宣战、封锁练武场出口、
  重置战斗临时标志、启动 10s 后首轮战斗定时器。
  """
  def preparing(challenge) do
    {:ok,
     %{challenge | state: :fighting, round: 0, beat_count: 0},
     List.flatten([
       move_npc(@daojue_npc, @arena_room, @houdian_room),
       broadcast(@arena_room, "\n玄苦大师大声宣布：东罗汉大阵合围！\n"),
       broadcast(@arena_room, "\n只听四周响起沙沙的脚步声，东西十八位罗汉们个个神情肃杀，\n"
                              <> "或赤手空拳，或手持兵器，慢慢地围了上来，堵住了通路。\n\n"),
       say(@arena_room, "玄苦", "准备，罗汉大阵即刻发动！\n\n"),
       delete_temp(challenge.fighter_id, @t_beat_count),
       delete_temp(challenge.fighter_id, @t_fighting),
       put_temp(challenge.fighter_id, @t_fighting, 1),
       seal_arena_effects(),
       schedule(:fighting, @prepare_delay_ms)
     ])}
  end

  # --- fighting：第 round 轮战斗（2s 一轮，共 10 轮） ---

  @doc """
  fighting 状态的第 `round` 轮（对应 LPC fighting/3）。

  `round` 取值 0..9：
    - round <= 8：将 names[round] 号罗汉从集结房移入练武场
    - round >= 1 且 <= 9：将 names[round-1] 号罗汉从练武场移回集结房
    - 战斗结束（round >= 9）：beat_count >= 18 → do_recruit，否则 do_back
    - 玩家阵亡/逃跑/气血耗尽 → do_back

  返回 `{:ok, challenge, effects}`，effects 包含下一轮定时器或终结动作。
  """
  def fighting(challenge, round) when round >= 0 and round <= 9 do
    effects =
      maybe_move_monk_in(challenge, round)
      ++ maybe_move_monk_out(challenge, round)

    cond do
      # 十轮结束：判定胜负
      round >= 9 ->
        if beat_count_enough?(challenge) do
          {:ok,
           %{challenge | state: :finished, result: :won},
           effects ++ recruit_effects(challenge)}
        else
          {:ok,
           %{challenge | state: :finished, result: :lost},
           effects ++ do_back_effects(:lost, challenge)}
        end

      # 进入下一轮
      true ->
        {:ok,
         %{challenge | round: round + 1},
         effects ++ [schedule(:fighting, @fight_round_delay_ms)]}
    end
  end

  def fighting(_challenge, round) when round < 0 or round > 9 do
    {:error, :invalid_round}
  end

  # === 终结动作 ===

  @doc "do_recruit：胜利，奖励 +7500 经验，设置 luohan_winner，随后 do_back。"
  def do_recruit(challenge) do
    effects = [
      delete_temp(challenge.fighter_id, @t_beat_count),
      delete_temp(challenge.fighter_id, @t_fighting),
      add_combat_exp(challenge.fighter_id, @win_combat_exp),
      set_env(challenge.fighter_id, "luohan_winner", 1)
    ]

    result =
      if shaolin_fighter?(challenge) do
        effects ++ [
          broadcast(@arena_room, "\n玄苦大师说道：恭喜你闯过了十八罗汉大阵！ 本寺有\n"
                                 <> "此等杰出弟子，届时必当为武林放一异彩！\n"),
          schedule(:do_back, @do_recruit_delay_ms)
        ]
      else
        effects ++ [
          broadcast(@arena_room, "玄苦大师说道：此番过阵，当对本身修行大有助益，百尺竿头，更\n"
                                 <> "进一步，老衲就此别过！\n"),
          schedule(:do_back, @do_back_delay_ms)
        ]
      end

    {:ok, %{challenge | state: :finished, result: :won}, result}
  end

  @doc "do_back：失败/超时/胜利后，僧众返回原房、出口恢复、清除 assigned_fighter。"
  def do_back(challenge) do
    {:ok,
     %{challenge | state: :finished, result: challenge.result || :reset},
     do_back_effects(:reset, challenge)}
  end

  # === 私有：门控 ===

  defp shaolin_family?(npc) do
    Map.get(npc.meta.family || %{}, :name) == "少林派"
  end

  defp shaolin_fighter?(%{fighter_id: nil}), do: false
  defp shaolin_fighter?(_challenge), do: true  # 运行时由 Coordinator 从 fighter.meta 校验

  defp skills_enough?(fighter) do
    skills = Map.get(fighter.meta.stats || %{}, :skills, %{})
    map_size(skills) > 1 and
      Enum.any?(@check_skills, fn skill ->
        Map.get(skills, skill, 0) >= @min_skill_level
      end)
  end

  defp luohan_winner?(fighter) do
    Map.get(fighter.meta.env || %{}, "luohan_winner", false) in [true, 1, "1"]
  end

  defp generation_ok?(fighter, master_npc) do
    fighter_family = Map.get(fighter.meta.family || %{}, :name)
    master_family = Map.get(master_npc.meta.family || %{}, :name)

    # 非少林派玩家不受辈份限制
    cond do
      fighter_family != "少林派" -> true
      master_family != "少林派" -> true
      true ->
        fighter_gen = Map.get(fighter.meta.family || %{}, :generation, 0)
        master_gen = Map.get(master_npc.meta.family || %{}, :generation, 0)
        fighter_gen <= master_gen + 2
    end
  end

  defp guilty?(fighter) do
    Map.get(fighter.meta.env || %{}, "guilty", 0) > 0
  end

  defp master_side(npc) do
    if Map.get(npc, :id) == @xuanku_npc, do: "xuanku", else: "xuannan"
  end

  # === 私有：等待状态辅助 ===

  defp other_master_asked?(%{master_asked: asked}), do: Map.values(asked) |> Enum.all?(& &1)

  # 对方临时标志是否已由玩家设置（由 Coordinator 从 temp_flags 读取）
  defp other_flag_set?(%{fighter_id: fighter_id, temp_flags: flags}) when is_binary(fighter_id) do
    other_key =
      case assigned_side(challenge_side(flags)) do
        :xuanku -> @t_xuannan_asked
        :xuannan -> @t_xuanku_asked
        _ -> nil
      end

    other_key != nil and Map.get(flags, other_key, false) in [true, 1]
  end

  defp other_flag_set?(_), do: false

  # 从 temp_flags 推断当前是哪一方发起（已设了标志的一方）
  defp challenge_side(flags) when is_map(flags) do
    cond do
      Map.get(flags, @t_xuanku_asked, false) in [true, 1] -> :xuanku
      Map.get(flags, @t_xuannan_asked, false) in [true, 1] -> :xuannan
      true -> :unknown
    end
  end

  defp challenge_side(_), do: :unknown

  defp assigned_side(:xuanku), do: :xuanku
  defp assigned_side(:xuannan), do: :xuannan
  defp assigned_side(_), do: :xuanku

  # === 私有：战斗辅助 ===

  defp beat_count_enough?(%{beat_count: count}), do: count >= @win_beat_count

  # === 私有：效果生成 ===

  defp summoning_effects(fighter, master_npc) do
    master_room = Map.get(master_npc, :room_id, @arena_room)
    master_side = master_side(master_npc)

    List.flatten([
      put_temp(fighter.id, if(master_side == "xuanku", do: @t_xuanku_asked, else: @t_xuannan_asked), 1),
      set_env(fighter.id, "assigned_fighter", fighter.id),
      broadcast(
        master_room,
        "\n玄苦大师说道：好吧，我来召集罗汉堂长老们于东练武场集合，我稍候在中央练武场上等你。\n"
      ),
      move_npc(@xuanku_npc, master_room, @arena_room),
      summon_monks_effects(master_side),
      schedule(:waiting, @wait_interval)
    ])
  end

  defp summon_monks_effects(master_side) when is_binary(master_side) do
    {rooms, ids, arena} =
      cond do
        master_side == "xuanku" -> {@xuanku_monk_rooms, @xuanku_monk_ids, @east_arena}
        master_side == "xuannan" -> {@xuannan_monk_rooms, @xuannan_monk_ids, @west_arena}
        true -> {[], [], @arena_room}
      end

    Enum.zip(rooms, ids)
    |> Enum.flat_map(fn {room, npc_id} ->
      [
        move_npc(npc_id, room, arena),
        broadcast(arena, "罗汉点了点头，快步走了出去。\n")
      ]
    end)
  end

  defp preparing_effects(challenge) do
    List.flatten([
      move_npc(@daojue_npc, @arena_room, @houdian_room),
      broadcast(@arena_room, "\n玄苦大师大声宣布：东罗汉大阵合围！\n"),
      broadcast(@arena_room, "\n只听四周响起沙沙的脚步声，东西十八位罗汉们个个神情肃杀，\n"
                             <> "或赤手空拳，或手持兵器，慢慢地围了上来，堵住了通路。\n\n"),
      say(@arena_room, "玄苦", "准备，罗汉大阵即刻发动！\n\n"),
      delete_temp(challenge.fighter_id, @t_beat_count),
      delete_temp(challenge.fighter_id, @t_fighting),
      put_temp(challenge.fighter_id, @t_fighting, 1),
      seal_arena_effects(),
      schedule(:fighting, @prepare_delay_ms)
    ])
  end

  defp maybe_move_monk_in(challenge, round) do
    if round <= 8 do
      {_rooms, ids, _arena} = monk_lists(challenge.assigned_by)
      npc_id = Enum.at(ids, round)

      [move_npc(npc_id, monk_src_room(challenge.assigned_by, round), @arena_room)]
    else
      []
    end
  end

  defp maybe_move_monk_out(challenge, round) do
    if round >= 1 and round <= 9 do
      {_rooms, ids, _arena} = monk_lists(challenge.assigned_by)
      npc_id = Enum.at(ids, round - 1)

      [move_npc(npc_id, @arena_room, monk_dst_room(challenge.assigned_by, round - 1))]
    else
      []
    end
  end

  defp monk_lists("xuanku"), do: {@xuanku_monk_rooms, @xuanku_monk_ids, @east_arena}
  defp monk_lists("xuannan"), do: {@xuannan_monk_rooms, @xuannan_monk_ids, @west_arena}
  defp monk_lists(_), do: {[], [], @arena_room}

  defp monk_src_room("xuanku", idx), do: Enum.at(@xuanku_monk_rooms, idx)
  defp monk_src_room("xuannan", idx), do: Enum.at(@xuannan_monk_rooms, idx)
  defp monk_src_room(_, _), do: nil

  defp monk_dst_room("xuanku", idx), do: Enum.at(@xuanku_monk_rooms, idx)
  defp monk_dst_room("xuannan", idx), do: Enum.at(@xuannan_monk_rooms, idx)
  defp monk_dst_room(_, _), do: nil

  defp seal_arena_effects do
    # 封锁练武场四个方向出口（对应 LPC room->delete("exits")）
    [
      delete_exit(@arena_room, "north"),
      delete_exit(@arena_room, "south"),
      delete_exit(@arena_room, "east"),
      delete_exit(@arena_room, "west")
    ]
  end

  defp restore_arena_effects do
    # 恢复练武场出口（shaolin.ucl 中的静态 exits）
    [
      set_exit(@arena_room, "north", "shaolin:fzlou"),
      set_exit(@arena_room, "south", "shaolin:houdian"),
      set_exit(@arena_room, "east", "shaolin:wuchang2"),
      set_exit(@arena_room, "west", "shaolin:wuchang1")
    ]
  end

  defp recruit_effects(challenge) do
    [
      broadcast(@arena_room, "\n玄苦大师说道：恭喜你闯过了十八罗汉大阵！ 本寺有\n"
                             <> "此等杰出弟子，届时必当为武林放一异彩！\n"),
      schedule(:do_back, @do_recruit_delay_ms)
    ]
  end

  defp do_back_effects(reason, challenge) do
    List.flatten([
      broadcast(@arena_room, "\n玄苦大师挥了挥手， 罗汉堂长老们随即鱼贯离开练武场。\n"),
      move_npc(@daojue_npc, @houdian_room, @arena_room),
      restore_monks_effects(),
      restore_arena_effects(),
      delete_env(challenge.fighter_id, "assigned_fighter"),
      delete_temp(challenge.fighter_id, @t_beat_count),
      delete_temp(challenge.fighter_id, @t_fighting),
      move_npc(@xuanku_npc, @arena_room, "shaolin:luohan5"),
      move_npc(@xuannan_npc, @arena_room, "shaolin:banruo5"),
      cancel_all_timers(challenge)
    ])
  end

  defp restore_monks_effects do
    # 双方罗汉都返回原房
    all_rooms = @xuanku_monk_rooms ++ @xuannan_monk_rooms
    all_ids = @xuanku_monk_ids ++ @xuannan_monk_ids

    Enum.zip(all_rooms, all_ids)
    |> Enum.flat_map(fn {room, npc_id} ->
      [move_npc(npc_id, @arena_room, room)]
    end)
  end

  defp cancel_all_timers(challenge) do
    Map.values(challenge.timer_refs)
    |> Enum.map(fn ref -> {:cancel_timer, ref} end)
  end

  # === 效果构造器 ===

  defp broadcast(room_id, message), do: {:broadcast, room_id, message}
  defp say(room_id, npc_name, message), do: {:say, room_id, npc_name, message}
  defp move_npc(npc_id, from_room, to_room), do: {:move_npc, npc_id, from_room, to_room}
  defp delete_exit(room_id, dir), do: {:delete_exit, room_id, dir}
  defp set_exit(room_id, dir, target), do: {:set_exit, room_id, dir, target}
  defp schedule(ref_key, ms), do: {:schedule_timer, ref_key, ms}
  defp cancel_timer(ref), do: {:cancel_timer, ref}
  defp put_temp(fighter_id, key, value), do: {:put_temp, fighter_id, key, value}
  defp delete_temp(fighter_id, key), do: {:delete_temp, fighter_id, key}
  defp set_env(fighter_id, key, value), do: {:set_env, fighter_id, key, value}
  defp delete_env(fighter_id, key), do: {:delete_env, fighter_id, key}
  defp add_combat_exp(fighter_id, amount), do: {:add_combat_exp, fighter_id, amount}
end
