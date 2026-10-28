defmodule Kantele.World.RoomActions.Wuguan.Work do
  @moduledoc """
  郭府打工动词（P5 打工闭环中段）：`sao`/`chu`/`jiao`/`pi`/`ju` 五个干活动词，
  由 `wuguan.ucl` 各工作房的 `actions` 绑定到本模块（按 room_id 查配置）。

  LPC 源：`guofu_mafang.c`(do_sao) / `guofu_caidi1.c`(do_chu) / `guofu_caidi2.c`
  (do_jiao) / `guofu_chaifang.c`(do_pi) / `guofu_mufang.c`(do_pi)。五个 `do_*`
  逻辑完全一致，仅「活计名 / 参数词 / 进度 mark / 完成 mark / 管事 NPC / 文案」
  不同，故抽成一份配置驱动模块。

  ## 判定链（LPC do_* 原序）

  1. `query_temp("mark/X完了")` 已完工 → 「X管事嚷嚷道：喂喂喂，让你去覆命，还留
     在这里干嘛？」（督促去覆命，不再干活）。
  2. `query_temp("job_name") != 本职活计` → 「X管事对你喝道：没事你瞎折腾什么？」
  3. 无工具（`mark/工具` 未置，由武修文 `give_tools` 下发）→
     「X管事讥笑道：你是想用什么来<干活>呀，用手吗？」
  4. 参数词不对（`sao mafang` / `chu cao` / `jiao shui` / `pi chai` / `ju mutou`）→
     「你要<目标>什么？」
  5. 扣精力/气血（随机 `con/3`、`str/3`）；不足则滑倒/受伤 → `unconcious()`；
     否则 `receive_damage` 后：
     - 若 `wuguan_job` 计时 condition 已过期 **且** 进度 `mark/X > 10+random(10)`
       **且** 本房管事在场 → 写 `mark/X完了` + 广播「可以去向耶律大爷覆命(task ok)」。
     - 否则广播干活动作 + `add_temp("mark/X", 1)` 推进进度。

  ## 与 LPC 的差异 / 范围

  - 工具校验：LPC 检**已装备武器** id，本端口按仓库既定约定改用 `mark/工具` 会话
    temp（武修文 `give_tools` 下发工具时置位），与 `mark/*` 体系一致；因 `job_name`
    已先于房间动词校验，工具归属不会串房。
  - `wuguan_job` 时限：读 `conn.session["conditions"]["wuguan_job"]`（与
    `Kantele.World.NpcActions.Task` 覆命分支 4 同一落点），过期即视为工期已到。
  - 管事在场：管事经 `room_characters` 静态常驻本房；读 `Room.characters_for_conn`
    的房间快照，匹配 `wuguan:guanjiaN` 之 id 或别名 `guanshi`。房间快照缺失时
    默认「在场」（管事恒在，不阻断闭环）。
  - `start_busy` / `is_busy` / `is_fighting` 守卫与 `improve_skill` 技能成长：LPC
    为防御性与副作用，本端口暂不移植（与其他房间动词移植同口径，属 out-of-scope）。
  - 摔倒时的 `add("food",100)`（马房）/ `set("water",600)`（菜地2）：微调字段在
    Kantele 的 `Vitals` 结构上无对应键，跳过，仅保留 `unconcious` 主线。
  """

  use Kantele.World.RoomAction

  import Kalevala.Character.Conn, only: [get_session: 2, put_character: 2]

  alias Kantele.Character.PlayerMeta
  alias Kantele.Feature.Damage
  alias Kantele.World.Room
  alias Kantele.World.RoomActions.Break
  alias Kantele.World.RoomActions.Helpers
  alias Kantele.World.NpcActions.Helpers, as: NpcHelpers

  # 每房一份配置：活计名 / 参数词 / 进度 mark / 完成 mark / 管事 short id /
  # 管事名（文案用）/ 各守卫与广播文案。
  @rooms %{
    "wuguan:guofu_mafang" => %{
      job: "打扫马房",
      arg: "mafang",
      progress: "mark/扫",
      done: "mark/扫完了",
      guanjia: "guanjia3",
      guanshi_name: "马房管事",
      no_job: "马房管事对你喝道：没事你瞎折腾什么？\n",
      no_tool: "马房管事讥笑道：你是想用什么来打扫呀，用手吗？\n",
      no_arg: "你要打扫什么？\n",
      low_vision: "\n$N脚一滑，结果不小心滑倒在粪堆里，吃了一大口马粪。\n",
      progress_vision: "$N开始打扫马房，臭味使你不由闭紧了呼吸。\n",
      done_vision:
        "\n马房管事对$N说：干的不错，好了，你可以去向耶律大爷覆命(task ok)了。\n"
    },
    "wuguan:guofu_caidi1" => %{
      job: "锄草",
      arg: "cao",
      progress: "mark/锄",
      done: "mark/锄完了",
      guanjia: "guanjia5",
      guanshi_name: "菜园管事",
      no_job: "菜园管事对你喝道：没事你瞎折腾什么？\n",
      no_tool: "菜园管事讥笑道：你是想用什么来锄草呀，用手吗？\n",
      no_arg: "你要锄什么？\n",
      low_vision: "\n$N锄着锄着，结果不小心手一滑，锄在了自己的脚上。\n",
      progress_vision: "$N挥起锄头，对着地上的杂草锄了起来。\n",
      done_vision:
        "\n菜园管事对$N说：干的不错，好了，你可以去向耶律大爷覆命(task ok)了。\n"
    },
    "wuguan:guofu_caidi2" => %{
      job: "浇菜地",
      arg: "shui",
      progress: "mark/浇",
      done: "mark/浇完了",
      guanjia: "guanjia6",
      guanshi_name: "菜园管事",
      no_job: "菜园管事对你喝道：没事你瞎折腾什么？\n",
      no_tool: "菜园管事讥笑道：你想用什么来舀水浇呀，用手吗？\n",
      no_arg: "你要浇什么？\n",
      low_vision: "\n$N弯腰到大缸里舀水，结果一失足栽进了缸里。\n",
      progress_vision: "$N用瓢从缸里舀起水，在菜地里浇起水来。\n",
      done_vision:
        "\n菜园管事对$N说：干的不错，好了，你可以去向耶律大爷覆命(task ok)了。\n"
    },
    "wuguan:guofu_chaifang" => %{
      job: "劈柴",
      arg: "chai",
      progress: "mark/劈",
      done: "mark/劈完了",
      guanjia: "guanjia1",
      guanshi_name: "柴房管事",
      no_job: "柴房管事对你喝道：没事你瞎折腾什么？\n",
      no_tool: "柴房管事讥笑道：你准备用什么来劈柴呀，用手吗？\n",
      no_arg: "你要劈什么？\n",
      low_vision: "\n$N手一歪，一不小心柴刀竟然劈在自己的腿上。\n",
      progress_vision: "$N摆正一块木头，一刀劈去，将木头劈为两片。\n",
      done_vision:
        "\n柴房管事对$N说：干的不错，好了，你可以去向耶律大爷覆命(task ok)了。\n"
    },
    "wuguan:guofu_mufang" => %{
      job: "锯木头",
      arg: "mutou",
      progress: "mark/锯",
      done: "mark/锯完了",
      guanjia: "guanjia2",
      guanshi_name: "木房管事",
      no_job: "木房管事对你喝道：没事你瞎折腾什么？\n",
      no_tool: "木房管事讥笑道：你想用什么来锯木头，用手掰吗？\n",
      no_arg: "你要锯什么？\n",
      low_vision: "\n突然间木头竟然断了，弹起的半截木头正砸在$N头上。\n",
      progress_vision: "$N摆正一根木头，慢慢锯了起来。\n",
      done_vision:
        "\n木房管事对$N说：干的不错，好了，你可以去向耶律大爷覆命(task ok)了。\n"
    }
  }

  @impl true
  def run(conn, %{room_id: room_id, trailing: trailing}) do
    case Map.get(@rooms, room_id) do
      nil -> :not_handled
      cfg -> do_work(conn, cfg, String.trim(trailing))
    end
  end

  def run(_conn, _params), do: :not_handled

  defp do_work(conn, cfg, arg) do
    character = current(conn)
    meta = character.meta || %PlayerMeta{}
    temp = meta.temp || %{}
    stats = meta.stats
    vitals = meta.vitals

    cond do
      # 1. 已完工：督促去覆命
      present_temp?(conn, cfg.done) ->
        Helpers.render_to_player(conn, cfg.guanshi_name <> "嚷嚷道：喂喂喂，让你去覆命，还留在这里干嘛？\n")

      # 2. 活计不对
      Map.get(temp, "job_name") != cfg.job ->
        Helpers.render_to_player(conn, cfg.no_job)

      # 3. 没领工具
      not present_temp?(conn, "mark/工具") ->
        Helpers.render_to_player(conn, cfg.no_tool)

      # 4. 参数词不对
      arg != cfg.arg ->
        Helpers.render_to_player(conn, cfg.no_arg)

      # 5. 干活（扣体力，可能摔倒昏厥；否则推进进度 / 完工）
      true ->
        handle_work(conn, character, stats, vitals, cfg)
    end
  end

  defp handle_work(conn, character, stats, vitals, cfg) do
    con = (stats && Map.get(stats, :con)) || 10
    str = (stats && Map.get(stats, :str)) || 10
    costj = :rand.uniform(max(div(con, 3), 1))
    costq = :rand.uniform(max(div(str, 3), 1))

    jing = (vitals && Map.get(vitals, :jing)) || 0
    qi = (vitals && Map.get(vitals, :qi)) || 0

    if jing < costj or qi < costq do
      # 体力不支：滑倒/受伤 → 昏厥（LPC 的 message_vision + unconcious）
      conn
      |> Helpers.broadcast_vision(character.room_id, cfg.low_vision)
      |> Break.unconcious()
    else
      {:ok, character} = Damage.receive_damage(character, :jing, costj)
      {:ok, character} = Damage.receive_damage(character, :qi, costq)
      conn = put_character(conn, character)
      progress_or_complete(conn, character, cfg)
    end
  end

  # 推进进度或完工：LPC `!query_condition("wuguan_job") && mark/X > 10+random(10)
  # && present("<room> guanshi", env)`
  defp progress_or_complete(conn, character, cfg) do
    progress =
      case NpcHelpers.temp(conn, cfg.progress) do
        v when is_integer(v) -> v
        _ -> 0
      end

    threshold = 10 + (:rand.uniform(10) - 1)

    if not condition_active?(conn, "wuguan_job") and
         progress > threshold and
         guanjia_present?(conn, cfg.guanjia) do
      conn
      |> Helpers.broadcast_vision(character.room_id, cfg.done_vision)
      |> NpcHelpers.put_temp(cfg.done, 1)
    else
      conn
      |> Helpers.broadcast_vision(character.room_id, cfg.progress_vision)
      |> NpcHelpers.add_mark(cfg.progress, 1)
    end
  end

  # LPC 真值：query_temp 未设置返回 0（假）
  defp present_temp?(conn, key) do
    case NpcHelpers.temp(conn, key) do
      nil -> false
      false -> false
      0 -> false
      "" -> false
      _ -> true
    end
  end

  # 当前生效的 character（与 NpcActions/RoomActions Helpers 同一约定）
  defp current(%{private: %{update_character: character}}) when not is_nil(character),
    do: character

  defp current(%{character: character}), do: character

  # session conditions（bi.ex 惯用法）：Kantele 条件存 session 的 "conditions" map，
  # 与 NpcActions.Task 覆命分支 4 同一落点。
  defp condition_active?(conn, name) do
    case get_session(conn, "conditions") do
      %{} = conds ->
        case Map.get(conds, name) do
          nil -> false
          false -> false
          0 -> false
          _ -> true
        end

      _ ->
        false
    end
  end

  # 管事在场：房间快照（conn.private.room.characters）含 `wuguan:guanjiaN` 或别名
  # "guanshi"。快照缺失（未注入）时默认在场 —— 管事静态常驻，不应阻断闭环。
  defp guanjia_present?(conn, short_id) do
    chars = Room.characters_for_conn(conn)

    if chars == [] do
      true
    else
      Enum.any?(chars, fn c ->
        id = to_string(Map.get(c, :id) || "")
        String.ends_with?(id, short_id) or
          (Map.get(c, :aliases) |> List.wrap() |> Enum.any?(&(&1 == "guanshi")))
      end)
    end
  end
end
