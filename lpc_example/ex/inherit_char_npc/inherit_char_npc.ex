defmodule ExKantele.World.Npc.Base do
  @moduledoc """
  对应原文件: lpc_example/inherit/inherit_char_npc.c (基础NPC, 15294B)

  迁移判定: C —— **框架要新增的基础行为 mixin**，非世界数据。
  这是“所有 NPC 都该有”的通用钩子，应一次并入 Kantele 的 NPC/加载层。

  本模块尽量把原文的**纯决策逻辑**落为可测试函数：
    - accept_fight / accept_hit / accept_kill / accept_ansuan / accept_touxi
    - heal_decision（按 vitals 百分比决策 -> 治疗动作）
    - chat_dispatch（随机说话）
    - check_family

  NPC 外显字段（进入 UCL characters）:
    attitude / can_speak / chat_chance / chat_msg / chat_chance_combat /
    chat_msg_combat / is_guarder / is_quester / is_waiter
  """

  # ---- 常量：命中 / 接受结果 ----
  @accept 1
  @refuse 0

  # ==================== accept_fight ====================

  @doc """
  accept_fight：是否接受对方挑战。
  vitals: %{qi, max_qi, jing, max_jing}；att: "friendly"|"aggressive"|"killer"|其他
  Returns {result, reply} 其中 result :accept|:refuse
  """
  def accept_fight(vitals, att) do
    perqi = div(vitals.qi * 100, max(vitals.max_qi, 1))
    perjing = div(vitals.jing * 100, max(vitals.max_jing, 1))

    cond do
      perqi >= 75 and perjing >= 75 ->
        case att do
          "friendly" -> {@refuse, "我怎么可能会是你的对手？"}
          a when a in ["aggressive", "killer"] -> {@accept, "哼！出招吧！"}
          _ -> {@accept, "既然你赐教，我只好奉陪。"}
        end

      true ->
        {@refuse, "今天有些疲惫，改日再战也不迟啊。"}
    end
  end

  # ==================== accept_hit（含挑衅计数升级） ====================

  @doc """
  accept_hit：被 偷袭/攻击 时的反应，随 attempt_hit 次数升级到出手。
  attempt: 已累计的 attempt_hit 计数；rng 供测试。
  """
  def accept_hit(vitals, att, attempt, rng \\ &:rand.uniform/1) do
    perqi = div(vitals.qi * 100, max(vitals.max_qi, 1))
    perjing = div(vitals.jing * 100, max(vitals.max_jing, 1))
    t = attempt
    roll = rng.(max(t, 1))

    cond do
      perqi < 50 or perjing < 50 ->
        # 状态差：直接反击
        {@accept, "你不仁，我不义！可不要怪我。"}

      att == "friendly" ->
        {@accept, "这位朋友，且慢！"}

      att == "aggressive" ->
        if roll > 8 do
          {@accept, "他奶奶的，怎么这么烦？让我开开杀戒！"}
        else
          {@accept, "好个家伙，接招！"}
        end

      att == "killer" ->
        if roll > 2 do
          {@accept, "哼，找死找到这里来了，我手正痒呢！"}
        else
          {@accept, "接招吧！"}
        end

      true ->
        if roll > 7 do
          {@accept, "你要找死啊！"}
        else
          {@accept, "这位朋友，且慢！"}
        end
    end
  end

  # ==================== accept_kill / accept_ansuan / accept_touxi ====================

  @doc "accept_kill：被下杀手 一律应战"
  def accept_kill(att) do
    msg =
      case att do
        "friendly" -> "既然你如此逼迫，莫怪在下不留情！"
        a when a in ["aggressive", "killer"] -> "明年的今天，就是你的忌日！"
        _ -> "好，咱们就一决生死！"
      end

    {@accept, msg}
  end

  @doc "accept_ansuan / accept_touxi：被暗算/偷袭的即时话语（随机二选一）"
  def accept_ansuan(rng \\ &:rand.uniform/1) do
    if rem(rng.(100), 2) == 0, do: "嗯？怎么…", else: "啊呀，不好！"
  end

  def accept_touxi(rng \\ &:rand.uniform/1) do
    if rem(rng.(100), 2) == 0, do: "嗯！怎么…是谁！", else: "啊呀…你…"
  end

  # ==================== heal_self 决策树 ====================

  @doc """
  heal_self / 治疗决策：按当前 vitals 与技能返回应执行的治疗动作。
  vitals: %{qi, eff_qi, max_qi, jing, eff_jing, max_jing, neili, max_neili, force_level}
  Returns {:none, nil} | {:exert, "recover"|"regenerate"|"heal"|"inspire"} | {:dazuo, cost}
  """
  def heal_decision(vitals) do
    cond do
      not vitals.living -> {:none, nil}
      vitals.busy or vitals.fighting -> {:none, nil}
      vitals.no_exert -> {:none, nil}
      vitals.drugged -> {:none, nil}
      vitals.neili < 50 -> {:none, nil}

      vitals.jing < div(vitals.eff_jing * 8, 10) ->
        {:exert, "regenerate"}

      vitals.qi < div(vitals.eff_qi * 8, 10) and vitals.force_level >= 150 ->
        {:exert, "recover"}

      vitals.eff_qi < vitals.max_qi ->
        {:exert, "heal"}

      vitals.eff_jing < vitals.max_jing ->
        {:exert, "inspire"}

      vitals.neili < vitals.max_neili - 10 ->
        cost = min(vitals.max_neili - vitals.neili, div(vitals.qi, 2))
        {:dazuo, cost}

      true ->
        {:none, nil}
    end
  end

  # ==================== chat 分发 ====================

  @doc """
  chat：按 chat_chance 概率从 msg 表随机说一句。
  Returns {:say, msg} | :none
  """
  def chat_dispatch(chance, msgs, rng \\ &:rand.uniform/1)

  def chat_dispatch(chance, msgs, rng) when is_list(msgs) do
    if rng.(100) < chance and msgs != [] do
      {:say, Enum.at(msgs, rng.(length(msgs)) - 1)}
    else
      :none
    end
  end

  def chat_dispatch(_chance, _msgs, _rng), do: :none

  # ==================== check_family ====================

  @doc "check_family：玩家是否属于某门派（含出生名）"
  def check_family(family_name, born_name, fam) do
    family_name == fam or (family_name == nil and born_name == fam)
  end

  # ==================== random_move ====================

  @doc "random_move：从 exits 随机挑一个方向离开（返回 dir 或 :none）"
  def random_move(dirs, rng \\ &:rand.uniform/1) do
    case dirs do
      [] -> :none
      [_ | _] -> Enum.at(dirs, rng.(length(dirs)) - 1)
    end
  end
end
