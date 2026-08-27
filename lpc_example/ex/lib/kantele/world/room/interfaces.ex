defmodule ExKantele.World.Room.Interfaces do
  @moduledoc """
  互动房间的行为端（对照 qianting / wudu_liandu / qiyuan2）

  这些房间的**静态结构**已进 lpc_samples.ucl（rooms 段），
  剩余互动逻辑属于行为，落到本模块（Room.Processor 的事件处理器）。
  当前 Room.Processor 尚未提供 自定义动词/心跳 分发，故这些都是
  “需底层新增 room_verbs / room_heart_beat” 的范例目标。
  """

  # ---- 前庭（room_qianting.c）：大门开合状态机 ----
  # gate_open? / gate 所有权；push/close 动词改写动态 exit。
  defmodule Gate do
    @moduledoc "大门状态机（对应 push/close/look 动词）"
    defstruct [:open?, owner: nil]

    def toggle(%__MODULE__{open?: open?}, %{verb: "push"}) do
      if open?, do: {:already_open, "大门早已敞开。"}, else: {:ok, %{open?: true}}
    end

    def toggle(%__MODULE__{open?: open?}, %{verb: "close"}) do
      if open?, do: {:ok, %{open?: false}}, else: {:already_closed, "大门早就关着了。"}
    end
  end

  # ---- 炼毒房（room_wudu_liandu.c）：制作毒药 ----
  defmodule PoisonWorkshop do
    @moduledoc "炼毒交互（对照 liandu.c 的 push/verify/望闻问切式多阶段炼毒）"
    # 原文：按剧本多阶段（数暗号/看时辰/下料），产出指定毒药并给“毒方”图样。
    @note "需 room_verbs + 持久化炼毒进度"
  end

  # ---- 奇缘（room_qiyuan2.c）：随机/多分支事件 ----
  defmodule Qiyuan do
    @moduledoc "奇缘随机事件（对照 qiyuan2.c 的 look/zhao 等触发分支）"
    @note "依赖 karma/score/random 推进，需 room_heart_beat + 玩家状态查询"
  end
end
