defmodule Kantele.World.ItemDescHandlers do
  @moduledoc """
  动态 `item_desc` handler 注册表（P5-4d）。

  LPC `set("item_desc", ([ "bi" : (: look_bi :) ]))` 的闭包值在 UCL 中表示为
  `bi = { kind = "..." ... }`。`kind` 到 Elixir `{module, function}` 的解析在
  本模块。handler 接收 `(context, requester, params)`，返回更新后的房间
  `context`：

      def run(context, requester, %{keyword: keyword, config: config}) do
        # ...
        render(context, requester.pid, CommandView, "text", %{text: text})
      end

  ## 安全降级（P7）
  未注册的 kind 由 `lookup/2` 返回 `{:unimplemented, kind}`，房间回落到
  「这里没有这个东西。」，与未回填的 `item_desc` 行为一致。
  """

  @registry %{
    "hengyang:inzhushendong" => %{
      "gated_text" => {Kantele.World.ItemDescHandlers.GatedText, :run}
    },
    # 剑冢 `fen` / `sec sword` / `thi sword` 按房间 state 多键分支（P5-4i）。
    "huashan:jianzhong" => %{
      "room_state_tiers" => {Kantele.World.ItemDescHandlers.RoomStateTiers, :run}
    },
    "shaolin:putiyuan" => %{
      "score_tiers" => {Kantele.World.ItemDescHandlers.ScoreTiers, :run},
      "room_state_tiers" => {Kantele.World.ItemDescHandlers.RoomStateTiers, :run}
    },
    "beijing:aofu_shufang" => %{
      "score_tiers" => {Kantele.World.ItemDescHandlers.ScoreTiers, :run}
    },
    "hengyang:furong1" => %{
      "room_temp" => {Kantele.World.ItemDescHandlers.RoomTempText, :run}
    },
    "hengyang:zigaihole" => %{
      "room_temp" => {Kantele.World.ItemDescHandlers.RoomTempText, :run}
    },
    "guanwai:jingxiu" => %{
      "room_occupancy" => {Kantele.World.ItemDescHandlers.RoomOccupancyText, :run}
    },
    # outzigai1 `look_bi`：按房间 temp `marks/破` / `marks/推` 三态选择文本（P5-4l）。
    "hengyang:outzigai1" => %{
      "room_temp_tiers" => {Kantele.World.ItemDescHandlers.RoomTempTiers, :run}
    },
    "fuzhou:mishi" => %{
      "score_tiers" => {Kantele.World.ItemDescHandlers.ScoreTiers, :run},
      "player_temp_branch" => {Kantele.World.ItemDescHandlers.PlayerTempBranch, :run}
    },
    # 石洞群 `look_bi`：按识字技能等级选择蝌蚪文 / 壁画文本（P5-4k）。
    "xiakedao:shidong2" => %{
      "player_skill" => {Kantele.World.ItemDescHandlers.PlayerSkill, :run}
    },
    "xiakedao:shidong4" => %{
      "player_skill" => {Kantele.World.ItemDescHandlers.PlayerSkill, :run}
    },
    "xiakedao:shidong7" => %{
      "player_skill" => {Kantele.World.ItemDescHandlers.PlayerSkill, :run}
    },
    "xiakedao:shidong10" => %{
      "player_skill" => {Kantele.World.ItemDescHandlers.PlayerSkill, :run}
    },
    # houdong `look_pet`：星宿派且星宿奇术 >= 160 才见五圣剧毒（P5-4m）。
    "xiyu:houdong" => %{
      "player_skill" => {Kantele.World.ItemDescHandlers.PlayerSkill, :run}
    },
    # city:leitai `look_tiaofu`：按擂台关闭状态（Arena.close_by）显示开放 / 被某人关闭（P5-4n）。
    "city:leitai" => %{
      "arena_state" => {Kantele.World.ItemDescHandlers.ArenaState, :run}
    },
    # 城门/关卡告示牌 look_gaoshi：FINGER_D 通缉名单 + 各城落款（P5-4p / FINGER_D 子系统）。
    # footer 为各城知府/提督落款，详见 adm/daemons/fingerd.c get_killer() 的拼接。
    "chengdu:eastgate" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "chengdu:northgate" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "chengdu:southgate" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "chengdu:westgate" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "city:beimen" => %{"finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}},
    "city:dongmen" => %{"finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}},
    "city:nanmen" => %{"finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}},
    "city:ximen" => %{"finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}},
    "lanzhou:beimen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "lanzhou:dongmen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "lanzhou:nanmen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "lanzhou:ximen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "suzhou:beimen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "suzhou:dongmen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "suzhou:nanmen" => %{
      "finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}
    },
    "suzhou:ximen" => %{"finger_d_killer" => {Kantele.World.ItemDescHandlers.FingerDKiller, :run}},
    # city:guangchang `look_gaoshi`：扬州府通告访客计数条幅（P5-4q）。
    # 读房间 state.visitor（UCL state 播种）转中文数字拼装定宽 ASCII 条幅。
    "city:guangchang" => %{
      "gaoshi_visitor" => {Kantele.World.ItemDescHandlers.GaoshiVisitor, :run}
    },

    # city:eproom/nproom/sproom/wproom `look_table` / `look_scoreboard`：拱猪牌桌与
    # 成绩表（P5-4r 骨架 → P5-4ad 接上 PigGame 状态机）。
    # 键是 UCL 里的 **kind**（`lookup/2` 用 `config["kind"]` 查表），不是 item_desc
    # 的关键词 —— P5-4r 曾把键写成 "table"，于是 `look table` 一直落到
    # 「这里没有这个东西。」（已修正为 kind 值 "pig_table"）。
    "city:eproom" => %{
      "pig_table" => {Kantele.World.ItemDescHandlers.PigTable, :run},
      "pig_scoreboard" => {Kantele.World.ItemDescHandlers.PigTable, :run_scoreboard}
    },
    "city:nproom" => %{
      "pig_table" => {Kantele.World.ItemDescHandlers.PigTable, :run},
      "pig_scoreboard" => {Kantele.World.ItemDescHandlers.PigTable, :run_scoreboard}
    },
    "city:sproom" => %{
      "pig_table" => {Kantele.World.ItemDescHandlers.PigTable, :run},
      "pig_scoreboard" => {Kantele.World.ItemDescHandlers.PigTable, :run_scoreboard}
    },
    "city:wproom" => %{
      "pig_table" => {Kantele.World.ItemDescHandlers.PigTable, :run},
      "pig_scoreboard" => {Kantele.World.ItemDescHandlers.PigTable, :run_scoreboard}
    }
  }

  @doc """
  解析 `(room_id, kind)` 到 Elixir `{module, function}`。

  返回 `{:ok, {module, function}}` 或 `{:unimplemented, kind}`。
  """
  def lookup(room_id, kind) when is_binary(room_id) and is_binary(kind) do
    with room_map when is_map(room_map) <- Map.get(@registry, room_id),
         {module, function} <- Map.get(room_map, kind) do
      {:ok, {module, function}}
    else
      _ -> {:unimplemented, kind}
    end
  end

  def lookup(_room_id, kind), do: {:unimplemented, kind}

  @doc "该房间的 kind 是否已有 Elixir 实现（已注册）。"
  def registered?(room_id, kind), do: match?({:ok, _}, lookup(room_id, kind))

  @doc "当前已注册的房间 id 列表，用于覆盖度统计。"
  def registered_rooms(), do: Map.keys(@registry)
end
