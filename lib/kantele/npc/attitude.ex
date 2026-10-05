defmodule Kantele.Npc.Attitude do
  @moduledoc """
  NPC 态度（对应 LPC `inherit/char/npc.c` 的 `accept_fight` / `accept_hit` /
  `accept_kill` 里的 `switch(att = query("attitude"))`）。

  ## ⚠️ 纠正一个此前的错误理解

  之前文档里把 `attitude` 写成「是否主动攻击」。**这是错的。**
  LPC 里 `attitude` **完全不决定主动攻击**（那是 `attack()` / 心跳 /
  `chat_msg` 的事），它决定的是：

  > **被人挑战 / 攻击 / 杀你的时候，接不接、说什么话。**

  三个函数里 attitude 的分支（`npc.c`）：

      accept_fight:  already fighting -> heroism 说「哼！出招吧！」
                                     其他   说「想倚多为胜」并**拒战**
                      气血>=75%     -> friendly  「怎么可能是…的对手？」**拒战**
                                      aggressive/killer 「出招吧！」
                                      其他          「只好奉陪」**接受**
                      气血<75%     -> 一律「今天有些疲惫」**拒战**

      accept_hit:    气血>=50%     -> friendly  「且慢！」
                                      aggressive 多数概率直接 **kill_ob**
                                      killer     多数概率直接 **kill_ob**
                                      其他        小概率 **kill_ob**，否则「且慢！」
                      气血<50%     -> 一律说完就 **kill_ob**（被彻底激怒）

      accept_kill:   **一律接受**（return 1），只是台词不同：
                                      friendly 「莫怪在下不留情！」
                                      aggressive/killer 「明年的今天就是你的忌日！」
                                      其他 「咱们就一决生死！」

  也就是说 `friendly` 偏向**避战**（fight 拒、hit 怒而杀、kill 接受），
  `peaceful` 偏**被动奉陪**，`aggressive`/`killer` 主动接甚至反击，
  `heroism` 是「你不许以多欺少」的江湖规矩。

  ## 血/气门槛

  LPC 用 `perqi = qi*100/max_qi`、`perjing` 两个百分比门槛决定接不接。
  我们的 `Vitals` 是 qi/jing/neili，这里沿用同样的百分比口径。

  ## 纯函数

  决策全部返回给宿主执行：

    - `{:engage, msg}`   接受并说这句
    - `{:refuse, msg}`   拒战并说这句
    - `{:kill, msg}`    说完直接反杀

  宿主（`room.ex` 的 combat 事件）负责真正开打 / 反杀。
  """

  @type verdict :: {:engage, String.t()} | {:refuse, String.t()} | {:kill, String.t()}

  @qi_fight 75
  @jing_fight 75
  @qi_hit 50
  @jing_hit 50
  @qi_heroism 50

  @doc """
  `accept_fight/4`：被人挑战切磋。

  返回 `{:engage | :refuse, msg}`。
  """
  @spec decide_fight(String.t() | nil, non_neg_integer(), non_neg_integer(), boolean()) ::
          {atom(), String.t()}
  def decide_fight(att, qi_pct, jing_pct, already_fighting \\ false)

  def decide_fight(att, _qi, _jing, true) do
    # 已经在打：只有 heroism 会应战，其余一律拒绝以多欺少
    if att == "heroism" do
      {:engage, "哼！出招吧！\n"}
    else
      {:refuse, "想倚多为胜，这不是欺人太甚吗！\n"}
    end
  end

  def decide_fight(att, qi_pct, jing_pct, false) do
    if qi_pct >= @qi_fight and jing_pct >= @jing_fight do
      case att do
        "friendly" ->
          {:refuse, "怎么可能是你的对手？\n"}

        a when a in ["aggressive", "killer"] ->
          {:engage, "哼！出招吧！\n"}

        _ ->
          {:engage, "既然你赐教，只好奉陪。\n"}
      end
    else
      {:refuse, "今天有些疲惫，改日再战也不迟啊。\n"}
    end
  end

@doc """
`accept_hit/5`：被非致命打了一下。

LPC 里对 `aggressive` / `killer` / 默认 分支有一层**概率翻脸**：

    case "aggressive":  if (random(t) > 8)  { say; kill_ob; return 1; }  say "接招！"
    case "killer":     if (random(t) > 2)  { say; kill_ob; return 1; }  say "接招吧！"
    default:           if (random(t) > 7)  { say; kill_ob; return 1; }  say "且慢！"

`random(t) > N` 在 t=1（第一次被打）时几乎总是成立，所以**第一次挨打就翻脸杀人**
是常态；t 越大（挨得越多）越难触发。

我们没有 LPC 的 `attempt_hit` 计数，参数 `attempt` 由宿主传入，默认 1
（即"第一次挨打"这个 LPC 常态）。`random(t)` 用确定性伪随机代替，
保证可测 —— 生产环境换成真随机也不影响语义。

返回 `{:engage | :kill, msg}`（accept_hit 不会拒战 —— 挨了打一定还手）。
"""
  @spec decide_hit(String.t() | nil, non_neg_integer(), non_neg_integer(), pos_integer(), String.t()) ::
          {atom(), String.t()}
  def decide_hit(att, qi_pct, jing_pct, attempt \\ 1, who \\ "你")

  def decide_hit(att, qi_pct, jing_pct, attempt, who) do
    if qi_pct >= @qi_hit and jing_pct >= @jing_hit do
      case att do
        "friendly" ->
          {:engage, "这位#{who}，且慢！\n"}

        a when a in ["aggressive", "killer"] ->
          # LPC: aggressive random(t)>8 / killer random(t)>2 -> 翻脸杀人
          if snap_random(attempt) > kill_threshold(a) do
            {:kill, "#{kill_line(a)}！手正痒呢！\n"}
          else
            {:engage, "接招吧！\n"}
          end

        _ ->
          # LPC: default random(t)>7 -> 翻脸杀人
          if snap_random(attempt) > 7 do
            {:kill, "你要找死啊！\n"}
          else
            {:engage, "这位#{who}，且慢！\n"}
          end
      end
    else
      # 气血过半被打 —— 彻底激怒，一律反杀（LPC:191 无条件 kill_ob）
      case att do
        "friendly" -> {:kill, "既然#{who}如此无礼，我只有不容情了！\n"}
        a when a in ["aggressive", "killer"] -> {:kill, "#{who}！你找死。\n"}
        _ -> {:kill, "你不仁，我不义！#{who}，可不要怪我。\n"}
      end
    end
  end

  defp kill_threshold("aggressive"), do: 8
  defp kill_threshold(_killer), do: 2

  defp kill_line("aggressive"), do: "他奶奶的，怎么这么烦"
  defp kill_line(_), do: "哼，找死找到这里来了"

  # LPC: `random(t) > N` 判翻脸，`random(t)` 是 1..t 的随机数，t 越大越容易翻脸。
  # 这里用确定性序列代替真随机以便测试；attempt=1 时 random(1)=1，
  # `1 > 8` 不成立 -> 接招（这与 LPC 第一次挨打通常不杀人的实际表现一致）。
  defp snap_random(attempt), do: rem(attempt * 7, 10)

  @doc """
  `accept_kill/2`：被人下杀手。

  LPC 里三个分支**一律 return 1**（接受），只有台词不同 ——
  被打到要杀人命了，谁都不会躲。
  返回 `{:engage, msg}`。
  """
  @spec decide_kill(String.t() | nil) :: {atom(), String.t()}
  def decide_kill(att) do
    case att do
      "friendly" -> {:engage, "既然你如此逼迫，莫怪在下不留情！\n"}
      a when a in ["aggressive", "killer"] -> {:engage, "！明年的今天，就是你的忌日！。\n"}
      _ -> {:engage, "好！咱们就一决生死！\n"}
    end
  end

  @doc """
  气血百分比（LPC: `qi * 100 / max_qi`）。max 为 0 时返回 100（视为满状态，
  与 LPC 的整数除法行为一致，不会除零）。
  """
  @spec pct(non_neg_integer(), non_neg_integer()) :: non_neg_integer()
  def pct(_cur, 0), do: 100
  def pct(cur, max), do: div(cur * 100, max)

  @doc """
  是否是「会主动杀人」的态度。

  仅供 UI / 文档参考 —— **attitude 本身不驱动主动攻击**，
  LPC 里主动攻击来自 `attack()` / 心跳 / `chat_msg`。
  """
  @spec proactive?(String.t() | nil) :: boolean()
  def proactive?(att), do: att in ["aggressive", "killer"]
end