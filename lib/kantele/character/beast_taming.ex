defmodule Kantele.Character.BeastTaming do
  @moduledoc """
  `train` / `come` / `stay` / `stop` / `release` 五个驯兽命令的共享 helper。

  对应 LPC：

  - `cmds/std/train.c` —— 驯化野兽
  - `cmds/std/come.c` —— 让已驯服野兽跟随
  - `cmds/std/stay.c` —— 停止跟随
  - `cmds/std/stop.c` —— 让野兽停止攻击
  - `cmds/std/release.c` —— 放生

  ## LPC 门控到 Ex 的映射

  | LPC | Ex |
  | --- | --- |
  | `query_skill("training", 1) < 10` | `Stats.skill(meta.stats, "training") < 10` |
  | `present(arg, environment(me))` | `BeastTaming.find/2`（房间快照 + id/短 id/名字/别名） |
  | `userp(ob)` | `meta` 是 `%PlayerMeta{}` |
  | `query("race") == "野兽"` | `beast?/1`，见下 |
  | `query_temp("owner")` | `BeastState` 按 NPC id 存的 `owner_id` |
  | `set_leader(me)` / `set_leader(0)` | `BeastState.leader_id` |
  | `remove_all_enemy(1)` | `BeastState.enemies = []` |
  | `me->remove_all_enemy()` | `meta.combat.enemies = []` |
  | `set("attitude","peace")` / `set("ridable",1)` | `BeastState.attitude` / `ridable` |
  | `set_temp("comedby", id)` / `delete_temp` | `PlayerMeta.temp["comedby"]` |
  | `query("max_jing")/(skill/10)-10` | `jing_cost/1` + `Vitals.damage(:jing, cost)` |
  | `random(sp) < random(dp)/2` | `roll_failure?/3`（可用 `conn.private[:beast_roll]` 注入） |
  | `can_improve_skill` + `improve_skill` | `LearnGate.can_improve?/2` + `Stats.improve_skill/2` |
  | `message_vision` | `emit/2`（自己 render + 房间广播，排除自己） |
  | `notify_fail` | `reject/2`（只 render 给自己） |
  | `ob->kill_ob(me)` | `NpcAttack.kill_ob/2`（发 `combat/start`） |

  ## `race` 尚未进入 UCL 数据的处理

  LPC 的 `race` 由 `inherit/char/quarry.c` / `snake.c` 的 `setup()` 里
  `set("race","野兽")` 给出；Ex 的转换器和 `Loader.parse_character/4` **从未
  输出/读取该字段**，46 个含「野兽」字样的 UCL 文件里 `race` 只出现在注释中。
  为不把整批数据回填塞进本命令批次，`beast?/1` 采用两层判定：

  1. 若 `character.attributes["race"]` / `meta.race` 已建模（将来回填后）→
     以它为准，`== "野兽"` 才算野兽；
  2. 否则按本模块的**静态野兽登记表**识别（LPC 中所有 `set("race","野兽")`
     的 NPC 文件名 / 中文名 / 别名）。登记表是 LPC 源码的逐条抄录，可用
     `beast_keys/0`、`beast_names/0` 检视。

  ## LPC 源码里的 owner 类型不一致（本端口按 id 归一）

  `train.c` 写 `set_temp("owner", me)`（对象），却在第 30 行与
  `me->query("id")`（字符串）比较；`stay.c` 又拿它与 id 字符串比较，
  `stop.c` / `release.c` 则与 `me` 对象比较 —— 同一字段混用两种类型，
  `stay` 对刚驯服的野兽会恒判成「被人家驯服了」并反咬主人，属 LPC 遗留
  bug。Ex 无对象指针，统一存 `owner_id`，所有比较都按 id 进行，取的是
  **设计意图**而非该 bug 的行为。

  ## 与 LPC 的其余差异

  - NPC 的 temp/leader/enemy 无法写回 NPC 进程（房间只持有 Trim 快照），
    统一进 `Kantele.Character.BeastState` 的受监督 ETS 表，语义同为不落盘；
  - LPC `improve_skill("training", random(int))` 加的是「学习点数」，Ex 的
    `Stats.improve_skill/2` 是等级 +1，故在 `LearnGate.can_improve?/2` 通过且
    `int > 0` 时升 1 级；
  - `train_level` 变量在 LPC 里取了却没用，本端口不复刻；
  - LPC 的 ANSI 颜色宏（`HIY`/`NOR` 等）在文案中省略。

  ## 单测注入点（都挂在 `conn.private`）

  - `:beast_characters` —— 房间 NPC 列表（跳过房间快照）；
  - `:room` —— 房间快照 `%{private: %{characters: [...]}}`；
  - `:beast_roll` —— `(sp, dp) -> failed?`，固定驯服成败；
  - `:beast_retaliate` —— `(npc, me) -> any`，拦截 `kill_ob`；
  - `:beast_broadcast` —— `(room_id, text) -> any`，拦截房间广播。
  """

  import Kalevala.Character.Conn

  alias Kantele.Character.BeastState
  alias Kantele.Character.Combat
  alias Kantele.Character.CommandView
  alias Kantele.Character.LearnGate
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.World.NpcActions.NpcAttack
  alias Kantele.World.Room

  @skill "training"
  @min_skill 10

  # train.c:76-88：名字里带这些字才可骑
  @ridable_markers ~w(马 驴 骡 驼 牛 象 狮 虎 豹 鹿 鲨 雕 獸)

  # LPC 中所有 set("race","野兽") 的 NPC：clone/horse、clone/insect、
  # clone/worm、clone/beast（inherit SNAKE）、d/*/npc 下自设 race 的散件。
  @beast_keys ~w(
    huangbiaoma zaohongma ziliuma
    bihuochan bingcan chanchu ciwugong duzhu heiguafu huoxie jinwugong
    wucaizhu wugong xiezi xuexie zhizhu
    baizuwugong changaoxie changtuizhu datouwugong huabanzhu huibeixie
    jinxianwugong jiuweixie qianjiewugong renmianzhu shishixie tianwu
    tieguxie xixuezhu
    caihuashe dushe fushe jinshe jinshewang mangshe qingshe wangshe
    wubushe xuanmang yanjingshe
    lingshe douji baihu qinglong xuanwu zhuque monkey sheep heihu yezhu shachong
  )

  # 同上，中文名（已去掉 LPC 的 ANSI 颜色宏）
  @beast_names ~w(
    黄骠马 枣红马 紫骝马
    碧火蟾蜍 冰蚕 蟾蜍 赤斑蜈蚣 毒蜘蛛 黑寡妇 火蝎子 金蜈蚣
    五彩蛛 蜈蚣 蝎子 雪蝎子 蜘蛛
    百足蜈蚣 长螯蝎 长腿蛛 大头蜈蚣 花斑蛛 灰背蝎
    金线蜈蚣 九尾蝎 千节蜈蚣 人面蛛 食尸蝎 阴山天蜈
    铁骨蝎 吸血蛛
    菜花蛇 毒蛇 腹蛇 金环蛇 金蛇 蟒蛇 竹叶青蛇 眼镜王蛇
    五步蛇 玄冰赤蟒 眼镜蛇
    灵蛇 斗鸡 白虎 青龙 玄武 朱雀 猴子 野羊 黑虎 野猪 沙虫
  )

  def skill_name, do: @skill
  def min_skill, do: @min_skill
  def ridable_markers, do: @ridable_markers
  def beast_keys, do: @beast_keys
  def beast_names, do: @beast_names

  # ---- 房间内目标查找（LPC present(arg, environment(me))）----

  @doc "当前房间的角色列表；单测可注入 `:beast_characters` 或 `:room`"
  def characters(conn) do
    case Map.get(conn.private || %{}, :beast_characters) do
      list when is_list(list) ->
        list

      _ ->
        snapshot =
          case Map.get(conn.private || %{}, :room) do
            room when is_map(room) -> room
            _ -> safe_snapshot(room_id_of(conn))
          end

        case snapshot do
          %{private: %{characters: list}} when is_list(list) -> list
          %{characters: list} when is_list(list) -> list
          _ -> []
        end
    end
  end

  # 纯函数测试里可能只给一个 `%{private: %{...}}` 而没有任何 character；
  # 此时按「空房间」处理，别让 `conn.character.room_id` 抛 KeyError。
  defp room_id_of(conn) do
    case Map.get(conn, :character) do
      nil -> nil
      character -> Map.get(character, :room_id)
    end
  end

  defp safe_snapshot(nil), do: %{private: %{characters: []}}

  defp safe_snapshot(room_id) do
    Room.snapshot(room_id)
  rescue
    _ -> %{private: %{characters: []}}
  end

  @doc "LPC `present(arg, environment(me))`：按 id / 短 id / 名字 / 前缀 / 别名匹配"
  def find(conn, arg) do
    key = arg |> to_string() |> String.trim()
    characters(conn) |> Enum.find(&matches?(&1, key))
  end

  @doc "LPC `present()` 的 id 表匹配（Ex 的 character.id 形如 `zone:key`）"
  def matches?(npc, arg) do
    arg = arg |> to_string() |> String.trim()
    key = String.downcase(arg)

    id = npc |> Map.get(:id) |> to_string()
    short_id = id |> String.split(":") |> List.last()
    name = npc |> Map.get(:name) |> to_string() |> String.downcase()
    aliases = aliases_of(npc) |> Enum.map(&String.downcase(to_string(&1)))

    id == arg or String.downcase(id) == key or short_id == key or
      name == key or String.starts_with?(name, "#{key} ") or key in aliases
  end

  defp aliases_of(npc) do
    meta = Map.get(npc, :meta) || %{}
    attrs = Map.get(npc, :attributes) || %{}

    case Map.get(meta, :aliases) || Map.get(attrs, "aliases") || Map.get(attrs, :aliases) do
      list when is_list(list) -> list
      _ -> []
    end
  end

  # ---- LPC 判定 ----

  @doc "LPC `query(\"race\") == \"野兽\"`；race 未建模时回落静态登记表"
  def beast?(npc) do
    case explicit_race(npc) do
      nil -> registry_beast?(npc)
      race -> race == "野兽"
    end
  end

  defp explicit_race(npc) do
    attrs = Map.get(npc, :attributes) || %{}
    meta = Map.get(npc, :meta) || %{}

    Map.get(attrs, "race") || Map.get(attrs, :race) || Map.get(meta, :race) ||
      Map.get(meta, "race")
  end

  defp registry_beast?(npc) do
    id = npc |> Map.get(:id) |> to_string()
    short_id = id |> String.split(":") |> List.last()
    name = npc |> Map.get(:name) |> to_string()
    aliases = aliases_of(npc) |> Enum.map(&to_string/1)

    short_id in @beast_keys or name in @beast_names or
      Enum.any?(aliases, &(&1 in @beast_keys))
  end

  @doc "LPC `userp(ob)`：目标是玩家"
  def player?(%{meta: %PlayerMeta{}}), do: true
  def player?(%{attributes: %{"player" => true}}), do: true
  def player?(%{attributes: %{player: true}}), do: true
  def player?(_), do: false

  @doc "LPC `living(ob)`"
  def living?(npc) do
    meta = Map.get(npc, :meta) || %{}
    attrs = Map.get(npc, :attributes) || %{}
    status = Map.get(npc, :status)
    combat = Map.get(meta, :combat)
    vitals = Map.get(meta, :vitals)

    not (
      (is_map(combat) and Map.get(combat, :dead) == true) or
        Map.get(meta, :dead) == true or
        Map.get(attrs, "ghost") == true or
        Map.get(attrs, "not_living") == true or
        (is_binary(status) and String.contains?(status, "尸体")) or
        (is_map(vitals) and is_integer(Map.get(vitals, :qi)) and Map.get(vitals, :qi) <= 0)
    )
  end

  @doc "LPC `ob->is_fighting()`（BeastState 的敌人表 + 快照里的 combat）"
  def fighting?(npc) do
    state = BeastState.get(Map.get(npc, :id)) || %{}
    combat = Map.get(Map.get(npc, :meta) || %{}, :combat)

    not Enum.empty?(Map.get(state, :enemies, [])) or
      (is_map(combat) and not Enum.empty?(Map.get(combat, :enemies, [])))
  end

  @doc "LPC `ob->is_busy()`"
  def busy?(npc) do
    state = BeastState.get(Map.get(npc, :id)) || %{}
    combat = Map.get(Map.get(npc, :meta) || %{}, :combat)

    Map.get(state, :busy, 0) > 0 or (is_map(combat) and Map.get(combat, :busy, 0) > 0)
  end

  @doc "LPC `ob->query(\"combat_exp\")`（驯服失败率 dp = combat_exp / 100）"
  def combat_exp(npc) do
    meta = Map.get(npc, :meta) || %{}
    attrs = Map.get(npc, :attributes) || %{}

    case Map.get(meta, :stats) do
      %Stats{combat_exp: exp} when is_integer(exp) -> exp
      %{} = stats -> Map.get(stats, :combat_exp) || 0
      _ -> Map.get(attrs, "combat_exp") || 0
    end
  end

  @doc "LPC `me->query_skill(\"training\", 1)`"
  def training_level(character) do
    Stats.skill(Map.get(character.meta || %{}, :stats), @skill)
  end

  @doc "LPC `me->query(\"int\")`"
  def int(character) do
    case Map.get(character.meta || %{}, :stats) do
      %Stats{int: value} when is_integer(value) -> value
      %{} = stats -> Map.get(stats, :int) || 0
      _ -> 0
    end
  end

  @doc "LPC `cost = query(\"max_jing\") / (skill/10) - 10`"
  def jing_cost(character) do
    divisor = max(div(training_level(character), 10), 1)
    div(max_jing(character), divisor) - 10
  end

  defp max_jing(character) do
    vitals = Map.get(character.meta || %{}, :vitals)

    case vitals do
      nil -> 0
      _ -> Map.get(vitals, :max_jing) || Map.get(vitals, :jing) || 0
    end
  end

  defp jing(character) do
    vitals = Map.get(character.meta || %{}, :vitals)

    case vitals do
      nil -> 0
      _ -> Map.get(vitals, :jing) || 0
    end
  end

  @doc "LPC `query(\"jing\") <= cost`（注意是 `<=`，必须严格大于 cost 才行）"
  def tired?(character), do: jing(character) <= jing_cost(character)

  @doc "LPC `ob == me`"
  def self_target?(me, npc), do: Map.get(npc, :id) == Map.get(me, :id)

  @doc "LPC `me->is_fighting()`（`come.c:14` / `stay.c:15`）"
  def player_fighting?(character) do
    combat = Map.get(character.meta || %{}, :combat)
    is_map(combat) and not Enum.empty?(Map.get(combat, :enemies, []))
  end

  @doc "train.c:76-88：名字里出现这些字 → `set(\"ridable\", 1)`"
  def ridable?(name), do: String.contains?(to_string(name), @ridable_markers)

  # ---- 驯兽态（NPC 侧）----

  @doc "LPC `query_temp(\"owner\")` 的 id"
  def owner(npc) do
    case BeastState.get(Map.get(npc, :id)) do
      nil -> nil
      state -> Map.get(state, :owner_id) || Map.get(state, :owner)
    end
  end

  @doc "LPC `!query_temp(\"owner\")`"
  def no_owner?(npc), do: is_nil(owner(npc))

  @doc "LPC `query_temp(\"owner\") == me`"
  def owned_by?(npc, me), do: owner(npc) == Map.get(me, :id)

  @doc "LPC `query_temp(\"owner\") != me`"
  def foreign_owner?(npc, me) do
    case owner(npc) do
      nil -> false
      owner_id -> owner_id != Map.get(me, :id)
    end
  end

  @doc """
  LPC `train.c:71-89` 的成功收尾：attitude=peace、remove_all_enemy(1)、
  set_temp owner/owner_name/owner_id、按名字设 ridable。
  """
  def claim(npc, me) do
    BeastState.update(Map.get(npc, :id), fn state ->
      Map.merge(state || BeastState.empty(), %{
        owner_id: Map.get(me, :id),
        owner_name: Map.get(me, :name),
        attitude: "peace",
        enemies: [],
        ridable: ridable?(Map.get(npc, :name))
      })
    end)
  end

  @doc "LPC `set_leader(me)`"
  def follow(npc, me), do: set_leader(npc, Map.get(me, :id))

  @doc "LPC `set_leader(0)`"
  def unfollow(npc), do: set_leader(npc, nil)

  defp set_leader(npc, leader_id) do
    BeastState.update(Map.get(npc, :id), fn state ->
      Map.merge(state || BeastState.empty(), %{leader_id: leader_id})
    end)
  end

  @doc "LPC `ob->remove_all_enemy(1)`"
  def halt(npc) do
    BeastState.update(Map.get(npc, :id), fn state ->
      Map.merge(state || BeastState.empty(), %{enemies: []})
    end)
  end

  @doc """
  LPC `release.c`：找出本房间里由我驯服的所有野兽并清掉 owner 三键。

  返回被放生的 `[npc]`，供命令逐条播报。LPC 遍历的是 `all_inventory(environment(me))`，
  且只 `delete_temp` 三键（`attitude` / `ridable` 是 `set()`，放生后仍保留），
  这里同样只清 owner/leader，不删整条状态。
  """
  def release_owned(conn, me) do
    owned_ids =
      BeastState.owned_by(Map.get(me, :id))
      |> Enum.map(&elem(&1, 0))
      |> MapSet.new()

    characters(conn)
    |> Enum.filter(fn npc -> MapSet.member?(owned_ids, Map.get(npc, :id)) end)
    |> Enum.map(fn npc ->
      BeastState.update(Map.get(npc, :id), fn state ->
        Map.merge(state || %{}, %{owner_id: nil, owner_name: nil, leader_id: nil})
      end)

      npc
    end)
  end

  # ---- 玩家侧 temp：comedby ----

  @doc "LPC `me->query_temp(\"comedby\")`（存的是野兽 id）"
  def comedby(character) do
    temp = Map.get(character.meta || %{}, :temp) || %{}
    Map.get(temp, "comedby") || Map.get(temp, :comedby)
  end

  @doc "LPC `me->set_temp(\"comedby\", ob->query(\"id\"))`"
  def set_comedby(conn, npc) do
    character = current(conn)
    temp = Map.get(character.meta || %{}, :temp) || %{}

    put_character(conn, %{
      character
      | meta: Map.put(character.meta, :temp, Map.put(temp, "comedby", Map.get(npc, :id)))
    })
  end

  @doc "LPC `me->delete_temp(\"comedby\")`"
  def clear_comedby(conn) do
    character = current(conn)
    temp = Map.get(character.meta || %{}, :temp) || %{}

    put_character(conn, %{
      character
      | meta:
          Map.put(
            character.meta,
            :temp,
            temp |> Map.delete("comedby") |> Map.delete(:comedby)
          )
    })
  end

  # ---- 结算 ----

  @doc """
  LPC `sp = skill + int; dp = combat_exp/100; random(sp) < random(dp)/2`。

  返回 `true` 表示驯服失败（野兽反扑）。`random(0)` 在 LPC 返回 0，
  这里对 `sp <= 0` / `dp <= 0` 做同样处理，避免 `:rand.uniform(0)` 抛异常。
  """
  def roll_failure?(conn, me, npc) do
    sp = training_level(me) + int(me)
    dp = div(combat_exp(npc), 100)

    case Map.get(conn.private || %{}, :beast_roll) do
      fun when is_function(fun, 2) -> fun.(sp, dp)
      _ -> default_roll(sp, dp)
    end
  end

  defp default_roll(sp, dp) do
    sp_roll = if sp > 0, do: :rand.uniform(sp) - 1, else: 0
    dp_roll = if dp > 0, do: :rand.uniform(dp) - 1, else: 0
    sp_roll < div(dp_roll, 2)
  end

  @doc "LPC `me->receive_damage(\"jing\", cost)`"
  def pay_jing(conn, cost) do
    character = current(conn)
    meta = character.meta
    amount = max(cost, 0)

    vitals =
      case Map.get(meta, :vitals) do
        %Vitals{} = v -> Vitals.damage(v, :jing, amount)
        %{} = v -> Map.put(v, :jing, max((Map.get(v, :jing) || 0) - amount, 0))
        _ -> Vitals.damage(Vitals.new(), :jing, amount)
      end

    put_character(conn, %{character | meta: Map.put(meta, :vitals, vitals)})
  end

  @doc "LPC `me->start_busy(1)`"
  def busy_player(conn, rounds) do
    character = current(conn)
    meta = character.meta

    combat =
      case Map.get(meta, :combat) do
        %Combat{} = c -> Combat.start_busy(c, rounds)
        _ -> Combat.start_busy(Combat.new(), rounds)
      end

    put_character(conn, %{character | meta: Map.put(meta, :combat, combat)})
  end

  @doc "LPC `me->remove_all_enemy()`"
  def clear_player_enemies(conn) do
    character = current(conn)
    meta = character.meta

    combat =
      case Map.get(meta, :combat) do
        %Combat{} = c -> %{c | enemies: []}
        %{} = c -> Map.put(c, :enemies, [])
        _ -> Combat.new()
      end

    put_character(conn, %{character | meta: Map.put(meta, :combat, combat)})
  end

  @doc """
  LPC `if (me->can_improve_skill("training")) me->improve_skill("training", random(int))`。

  Ex 的 `Stats.improve_skill/2` 是等级 +1（无学习点数），故通过
  `LearnGate.can_improve?/2`（`(lvl+1)³/10 <= combat_exp`）且 `int > 0` 时升 1 级。
  """
  def improve_training(conn) do
    character = current(conn)

    case Map.get(character.meta || %{}, :stats) do
      %Stats{} = stats ->
        if int(character) > 0 and LearnGate.can_improve?(stats, @skill) do
          {new_stats, _} = Stats.improve_skill(stats, @skill)
          put_character(conn, %{character | meta: Map.put(character.meta, :stats, new_stats)})
        else
          conn
        end

      _ ->
        conn
    end
  end

  @doc "LPC `ob->kill_ob(me)`：让野兽扑向冒犯者"
  def retaliate(conn, npc, me) do
    case Map.get(conn.private || %{}, :beast_retaliate) do
      fun when is_function(fun, 2) -> fun.(npc, me)
      _ -> safe_kill_ob(npc, me)
    end
  end

  defp safe_kill_ob(npc, me) do
    NpcAttack.kill_ob(npc, me)
  rescue
    _ -> :ok
  end

  # ---- 输出 ----

  @doc "LPC `notify_fail`：只给自己"
  def reject(conn, text) do
    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  @doc "LPC `message_vision`：自己看到 + 房间其他人看到"
  def emit(conn, text) do
    broadcast(conn, text)

    conn
    |> render(CommandView, "text", %{text: text})
    |> prompt(CommandView, "prompt", %{})
  end

  @doc "只广播给房间（排除自己），常用于失败分支的 `message_vision`"
  def broadcast(conn, text) do
    room_id = conn.character.room_id

    case Map.get(conn.private || %{}, :beast_broadcast) do
      fun when is_function(fun, 2) -> fun.(room_id, text)
      _ -> safe_tell_room(room_id, text, conn.character.pid)
    end

    :ok
  end

  defp safe_tell_room(room_id, text, except_pid) do
    Room.tell_room(%Room{id: room_id}, text, except_pid)
  rescue
    _ -> :ok
  end

  # `put_character/2` 只写 `conn.private.update_character`，多次改动必须串联读它。
  def current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  def current(%{character: character}), do: character
end
