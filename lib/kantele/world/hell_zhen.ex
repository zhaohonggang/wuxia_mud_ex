defmodule Kantele.World.HellZhen do
  @moduledoc """
  十八层地狱试炼（LPC `d/death/npc/yanluo.c` 的 `ask_zhuan` / `round_1..18` /
  `check_status` / `winning` / `failed` / `remove_all` 的 Ex 等价）。

  ## LPC 时序（本模块以 `Process.send_after` 复刻 `call_out`）

  | 时刻 | LPC | 本模块 phase |
  |---|---|---|
  | t=0 | `ask_zhuan`：设 `SomeonePassing`、move `/d/death/emptyroom` | `Yanluo.execute/3` 起链 |
  | t=2 | `message_ob` | `"opening"` |
  | t=3 | `round_1` | `"round"`, round=1 |
  | 每层 +1s | `check_status` | `"check"` |
  | 每层 +2s（1-10）/ +4s（11-18） | `message_ob` | `"interlude"` |
  | 每层 +3s（1-10）/ +6s（11-17） | `round_N+1` | `"round"`, round=N+1 |
  | 第 18 层 +3s | `winning` | `"winning"` |
  | `check_status` 失败 +1s | `failed` | `"failed"` |
  | win/fail +3s | `remove_all` | `"remove_all"` |

  `check_status` 失败时 LPC 用 `remove_call_out` 撤掉所有后续 `round_*` /
  `message_ob` / `winning`，只留 `failed`。Ex 没有可撤销的命名定时器，改用
  `meta.temp["hell_zhen_cancelled"]` 作为「令牌已作废」标记：除 `"failed"` /
  `"remove_all"` 外的所有 phase 都先校验令牌，作废即静默丢弃（等价
  `remove_call_out`）。

  ## LPC → Ex 字段映射

  - `combat_exp >= 20000000` → `stats.combat_exp`
  - `ultrap(who)` = `query("opinion/ultra")` → `Kantele.Character.Reborn.ultrap?/1`
    （本仓已拍板用 `combat_exp >= 800_000_000` 建模大宗师，与 `Reborn.trigger/1`
    的第四前置共用同一判据）
  - `animaout` → `meta.env[:animaout]`（`AnimaoutCommand` 写出）
  - `couple` → `meta.spouse` / `env[:couple]`
  - `bunch` → `env[:bunch]`（帮派；`meta.family` 是门派，语义不同，不能混用）
  - `brothers` → `meta.brothers` / `env[:brothers]`
  - `league` → `meta.league` / `env[:league]`
  - `HellZhenPass` → `meta.env[:HellZhenPass]`
  - `SomeonePassing`（NPC temp）→ 阎罗殿房间 state（房间进程长驻，等价于 NPC
    所在房间的全局锁；`Room.set_timer/3` 不可用，故不用来复刻 `call_out`）
  - `qi < 500 || eff_qi < 500` → `vitals.qi < 500 || vitals.max_qi < 500`
    （Ex `Vitals` 没有 `eff_qi`；`wound/3` 削减的是 `max_qi`，故以 `max_qi`
    作为有效气血上限的等价物）
  - `/clone/misc/void` → 本仓无 void 房；`failed` 直接落到 `city:wumiao`
    （即 LPC 3 秒后 `remove_all` 的最终落点）

  ## 尚未移植的 LPC 前置

  `over_quest/hell_quest/锁阳丹`（四味药引任务，LPC `ask_quest` +
  `accept_object`）在 Ex 尚无任务链，故 `gate_error/1` **不把它当硬门**：
  否则十八层地狱会变成永远进不去的死内容。UCL 里已有四味药引的物品定义
  与 `hell_quest/锁阳丹` 的 `valid_leave` 条件，待任务子系统移植后再补这道门。
  """

  alias Kalevala.Event
  alias Kantele.Character.Reborn
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.Room

  @step_topic "character/hell_zhen_step"

  @emptyroom "death:emptyroom"
  @yanluodian "death:yanluodian"
  @wumiao "city:wumiao"

  @combat_exp_min 20_000_000
  @qi_min 500

  # LPC `d/death/HellZhen/1.c`：`set_skill("unarmed", 600)` +
  # `set_skill("martial-cognize", 600)`；18 个鬼全部同档。
  @ghost_unarmed 600
  @ghost_martial_cognize 600

  @lock_key "SomeonePassing"
  @temp_token "hell_zhen_token"
  @temp_cancelled "hell_zhen_cancelled"

  # {狱名, 本层鬼的 LPC 文件序号}。1-10 层一只鬼，11-18 层两只
  # （顺序按 yanluo.c 中 `new("/d/death/HellZhen/N")` 的出现次序；18 个鬼的
  #  skill 档位完全一致，故次序只影响文案不影响判定）。
  @layers [
    {"吊筋狱", [1]},
    {"幽枉狱", [2]},
    {"火坊狱", [3]},
    {"酆都狱", [4]},
    {"拔舌狱", [5]},
    {"剥皮狱", [6]},
    {"磨涯狱", [7]},
    {"锥捣狱", [8]},
    {"车崩狱", [9]},
    {"寒冰狱", [10]},
    {"脱壳狱", [15, 11]},
    {"抽肠狱", [11, 12]},
    {"油锅狱", [16, 13]},
    {"黑暗狱", [18, 14]},
    {"刀山狱", [15, 14]},
    {"血池狱", [15, 16]},
    {"阿鼻狱", [16, 17]},
    {"秤杆狱", [18, 17]}
  ]

  # LPC `message_ob()` 的 `switch(random(5))`
  @interludes [
    "\n你觉得自己不断下降，周围景物如彩蝶翻飞，不可注目。\n",
    "\n你觉得自己不断下降。\n",
    "\n你觉得自己不断下降，天地似乎没了界限。。。\n",
    "\n你觉得自己不断下降，周围一切都在旋转。。。\n",
    "\n你觉得自己不断下降，下降，似乎落向了无尽的深渊。\n"
  ]

  # ---------------------------------------------------------------------------
  # 房间 / 会话键
  # ---------------------------------------------------------------------------

  def empty_room_id, do: @emptyroom
  def yanluodian_id, do: @yanluodian
  def wumiao_id, do: @wumiao
  def lock_key, do: @lock_key
  def temp_token, do: @temp_token
  def temp_cancelled, do: @temp_cancelled

  # ---------------------------------------------------------------------------
  # 试炼数据
  # ---------------------------------------------------------------------------

  @doc "十八层狱名与鬼序号表（按 `yanluo.c` round_1..18 顺序）"
  def layers, do: @layers

  def layer_count, do: length(@layers)

  @doc "第 `round` 层的狱名（1-based）"
  def layer_name(round) when is_integer(round) and round >= 1 and round <= 18 do
    @layers |> Enum.at(round - 1) |> elem(0)
  end

  def layer_name(_round), do: nil

  @doc "第 `round` 层 `invocation` 的鬼序号列表（1-10 一只，11-18 两只）"
  def ghost_ids(round) when is_integer(round) and round >= 1 and round <= 18 do
    @layers |> Enum.at(round - 1) |> elem(1)
  end

  def ghost_ids(_round), do: []

  @doc "LPC `tell_room` 的黑牌横幅（去掉 LPC ANSI 颜色宏）"
  def banner(round) do
    name = layer_name(round)
    line = "                **************************************\n"

    "\n突然间一道黑牌闪过：\n\n" <>
      line <>
      "                **               #{name}             **\n" <>
      line
  end

  @doc "LPC `message_ob()` 五选一"
  def interlude, do: Enum.random(@interludes)

  def combat_exp_min, do: @combat_exp_min
  def qi_min, do: @qi_min

  @doc """
  第 `round` 层的 `call_out` 秒数。11-18 层节奏放慢（message_ob 4s、
  下一层 6s），第 18 层改为 `winning` 3s。
  """
  def timings(round) when is_integer(round) and round >= 1 and round <= 18 do
    slow? = round >= 11

    %{
      check_s: 1,
      interlude_s: if(slow?, do: 4, else: 2),
      next_s: if(slow?, do: 6, else: 3),
      winning_s: 3,
      failed_s: 1,
      remove_all_s: 3
    }
  end

  @doc "`ask_zhuan` 起链的两跳秒数（message_ob 2s、round_1 3s）"
  def opening_timings, do: %{message_ob_s: 2, round_1_s: 3}

  @doc """
  秒 → 毫秒。`scale` 供定向测试压到 0（不改 LPC 默认时序）。
  """
  def delay_ms(seconds, scale \\ 1) when is_number(seconds) and is_number(scale) do
    max(0, trunc(seconds * 1000 * scale))
  end

  @doc """
  LPC `call_out(phase, seconds, who)` 的等价：把下一拍事件投给玩家进程，
  由 `Kantele.Character.HellZhenEvent` 路由执行（玩家进程内可安全改 meta）。

  `data` 需含 `:token`；`:scale` 只影响延时，不改变 LPC 时序本身。
  返回 timer ref，便于需要时 `:erlang.cancel_timer/1`。
  """
  def schedule_step(pid, data, seconds, scale \\ 1) when is_pid(pid) do
    event = %Event{
      from_pid: self(),
      topic: @step_topic,
      data: Map.put(data, :scale, scale)
    }

    Process.send_after(pid, event, delay_ms(seconds, scale))
  end

  def step_topic, do: @step_topic

  # ---------------------------------------------------------------------------
  # ask_zhuan 门控
  # ---------------------------------------------------------------------------

  @doc """
  LPC `ask_zhuan` 的前置门；返回 `nil`（放行）或阎罗的拒绝语（含换行）。

  顺序与 `yanluo.c:532-605` 一致（除未移植的锁阳丹任务门，见 moduledoc）：
  exp/ultrap → animaout → couple → bunch → brothers → league →
  HellZhenPass → SomeonePassing。
  """
  def gate_error(character) do
    meta = Map.get(character, :meta) || %{}
    env = Map.get(meta, :env) || %{}
    stats = Map.get(meta, :stats) || %{}

    cond do
      (Map.get(stats, :combat_exp) || 0) < @combat_exp_min ->
        "十殿阎罗对你一拱手，道：经验不够，技能不熟，强求亦是枉然。\n"

      not ultrap?(character) ->
        "十殿阎罗对你一拱手，道：经验不够，技能不熟，强求亦是枉然。\n"

      not present?(Map.get(env, :animaout)) ->
        "十殿阎罗对你一拱手，道：你还没有修炼成元婴出世呢。\n"

      present?(Map.get(meta, :spouse)) or present?(Map.get(env, :couple)) ->
        "十殿阎罗对你一拱手，道：你还是先和你的家庭做个交代再转世吧。\n"

      present?(Map.get(env, :bunch)) ->
        "十殿阎罗对你一拱手，道：你还是先和你的帮派做个交代再转世吧。\n"

      present?(Map.get(meta, :brothers)) or present?(Map.get(env, :brothers)) ->
        "十殿阎罗对你一拱手，道：你还是先和你的结义兄弟做个交代再转世吧。\n"

      present?(Map.get(meta, :league)) or present?(Map.get(env, :league)) ->
        "十殿阎罗对你一拱手，道：你还是先和你的同盟做个交代再转世吧。\n"

      Map.get(env, :HellZhenPass) == true ->
        "十殿阎罗对你一拱手，道：既是武功高强，我等佩服便是，这。。。便是免了吧！\n"

      someone_passing?() ->
        "十殿阎罗对你一拱手，道：真时机缘不巧，改日再来吧。\n"

      true ->
        nil
    end
  end

  defp ultrap?(character) do
    try do
      Reborn.ultrap?(character)
    rescue
      _ -> false
    end
  end

  # LPC `query(...)` 的真值：0 / "" / nil / false / 空容器为假
  defp present?(nil), do: false
  defp present?(false), do: false
  defp present?(0), do: false
  defp present?(""), do: false
  defp present?(value) when is_list(value), do: value != []
  defp present?(value) when is_map(value), do: map_size(value) > 0
  defp present?(_value), do: true

  # ---------------------------------------------------------------------------
  # 全局 SomeonePassing 锁（阎罗殿房间 state）
  # ---------------------------------------------------------------------------

  def someone_passing? do
    Room.get_state_by_id(@yanluodian, @lock_key) != nil
  end

  def set_someone_passing(character_id, token) do
    Room.put_state_by_id(@yanluodian, @lock_key, %{
      character_id: character_id,
      token: token,
      at: System.system_time(:millisecond)
    })
  end

  def clear_someone_passing do
    Room.delete_state_by_id(@yanluodian, @lock_key)
  end

  # ---------------------------------------------------------------------------
  # 玩家 temp 令牌（撤销 call_out 用）
  # ---------------------------------------------------------------------------

  @doc "生成本轮试炼令牌（`Yanluo.execute/3` 起链时调用）"
  def new_token do
    "hz-#{System.unique_integer([:positive])}-#{:erlang.phash2(self())}"
  end

  @doc "构造一拍事件数据；`:token` / `:phase` 恒为权威字段"
  def step_data(token, phase, extra \\ %{}) do
    Map.merge(extra, %{token: token, phase: phase})
  end

  def token(character) do
    Map.get(temp(character), @temp_token)
  end

  def cancelled_key(token), do: "#{@temp_cancelled}:#{token}"

  @doc """
  作废标记。双写两处，避免「角色 meta 尚未 flush」的竞态：

  - 角色 `meta.temp`（玩家进程内可见）
  - `death:emptyroom` 房间 state（`:sys.replace_state` 同步生效，跨进程立即可见）
  """
  def cancelled?(token) when is_binary(token) do
    Room.get_state_by_id(@emptyroom, cancelled_key(token)) == true
  end

  def cancelled?(character) do
    Map.get(temp(character), @temp_cancelled) == true or
      case token(character) do
        token when is_binary(token) -> cancelled?(token)
        _ -> false
      end
  end

  @doc """
  令牌是否属于当前这一轮试炼。角色还没 flush 出 `temp` 时（`nil`）放行，
  避免 `Yanluo.execute/3` 起链与首拍事件之间的竞态误杀。
  """
  def token_matches?(character, token) do
    case token(character) do
      nil -> true
      ^token -> true
      _ -> false
    end
  end

  @doc "普通 phase 的有效条件：未作废 + 令牌匹配"
  def valid_step?(character, %{token: token}) do
    token_matches?(character, token) and
      not cancelled?(character) and
      not cancelled?(token)
  end

  def valid_step?(_character, _data), do: false

  @doc "写入试炼令牌并清掉上一轮的作废标记（含房间 state）"
  def put_token(character, token) do
    Room.delete_state_by_id(@emptyroom, cancelled_key(token))

    new_temp =
      temp(character)
      |> Map.put(@temp_token, token)
      |> Map.delete(@temp_cancelled)

    %{character | meta: %{character.meta | temp: new_temp}}
  end

  @doc """
  LPC `remove_call_out(...)` 的等价：后续 phase 全部静默丢弃。
  房间 state 同步写入，因此紧接着到达的定时器也一定被拦下。
  """
  def cancel(character) do
    case token(character) do
      token when is_binary(token) ->
        Room.put_state_by_id(@emptyroom, cancelled_key(token), true)

      _ ->
        :ok
    end

    %{character | meta: %{character.meta | temp: Map.put(temp(character), @temp_cancelled, true)}}
  end

  @doc "winning/failed 清场（清角色 temp + 清房间作废标记）"
  def clear_trial(character) do
    case token(character) do
      token when is_binary(token) ->
        Room.delete_state_by_id(@emptyroom, cancelled_key(token))

      _ ->
        :ok
    end

    new_temp =
      temp(character)
      |> Map.delete(@temp_token)
      |> Map.delete(@temp_cancelled)

    %{character | meta: %{character.meta | temp: new_temp}}
  end

  defp temp(%{meta: %{temp: temp}}) when is_map(temp), do: temp
  defp temp(_), do: %{}

  # ---------------------------------------------------------------------------
  # 鬼 invocation / check_status
  # ---------------------------------------------------------------------------

  @doc """
  LPC `HellZhen/*.c` `invocation(target)` 的攻击/防御判定：

      ap = ghost.unarmed * 3/2 + ghost."martial-cognize"   // 600*3/2+600 = 1500
      dp = player."force" + player."martial-cognize"
      if (ap + random(ap) > dp) damage = ap + random(ap)

  `rand` 可注入（`fn n -> n end` 取上界，便于测试定值）。
  """
  def invocation(character, rand \\ &:rand.uniform/1) do
    stats = Map.get(Map.get(character, :meta) || %{}, :stats)
    dp = Stats.skill(stats, "force") + Stats.skill(stats, "martial-cognize")
    ap = div(@ghost_unarmed * 3, 2) + @ghost_martial_cognize
    hit? = ap + rand.(ap) > dp
    damage = if hit?, do: ap + rand.(ap), else: 0

    %{ap: ap, dp: dp, hit?: hit?, damage: damage}
  end

  @doc "把一次 invocation 的伤害落到 `vitals.qi`（LPC `COMBAT_D->do_damage`）"
  def apply_damage(character, %{damage: damage}) when is_integer(damage) and damage > 0 do
    meta = character.meta
    vitals = Map.get(meta, :vitals)

    case vitals do
      %Vitals{} ->
        %{character | meta: %{meta | vitals: Vitals.damage(vitals, :qi, damage)}}

      _ ->
        character
    end
  end

  def apply_damage(character, _result), do: character

  @doc """
  LPC `check_status()`：`qi < 500 || eff_qi < 500` → `:failed`。
  `eff_qi` 在 Ex 映射到 `max_qi`（见 moduledoc）。
  """
  def check_status(character) do
    vitals = Map.get(Map.get(character, :meta) || %{}, :vitals) || %{}
    qi = Map.get(vitals, :qi) || 0
    eff_qi = Map.get(vitals, :max_qi) || 0

    if qi < @qi_min or eff_qi < @qi_min, do: :failed, else: :ok
  end

  @doc "鬼命中的播报文案（LPC `message_combatd`）"
  def hit_text(%{hit?: true, damage: damage}) do
    "狱中鬼影运转龙象般若功，双拳携着十龙十象之力朝你崩击而出，你不及闪避，" <>
      "被击个正中，气血 -#{damage}。\n"
  end

  def hit_text(%{hit?: false}) do
    "可是你识破了狱中鬼影的拳路，轻轻一侧身便避了开去。\n"
  end
end
