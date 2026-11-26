defmodule Kantele.World.InquiryHandlers do
  @moduledoc """
  数据驱动问询（inquiry）的**玩家侧**效果分发。

  与 `Kantele.World.NpcActionHandlers`（NPC 私有动词）同构：UCL 的 inquiry
  值写成 map 时，`kind` 指定玩家侧处理模块；NPC 侧 `NpcAskEvent` 只负责把
  `kind` / 配置 / 当前库存回执给玩家进程，真正落库与渲染在玩家进程完成。

  新增 kind 时在 `@handlers` 注册即可，无需改 `NpcAskEvent`。
  """

  @handlers %{
    "give_item" => Kantele.World.InquiryHandlers.GiveItem,
    "counter_perform" => Kantele.World.InquiryHandlers.CounterPerform,
    "teleport_service" => Kantele.World.InquiryHandlers.TeleportService,
    "smith_job" => Kantele.World.InquiryHandlers.SmithJob,
    "yelvqi_job" => Kantele.World.InquiryHandlers.YelvqiJob,
    "wuxiuwen_tools" => Kantele.World.InquiryHandlers.WuxiuwenTools,
    "hostile" => Kantele.World.InquiryHandlers.Hostile,
    "jobs_job" => Kantele.World.InquiryHandlers.JobsJob,
    "sect_master_grant" => Kantele.World.InquiryHandlers.SectMasterGrant,
    "sect_master_teach_skill" => Kantele.World.InquiryHandlers.SectMasterTeachSkill,
    "sect_master_unlock_perform" => Kantele.World.InquiryHandlers.SectMasterUnlockPerform,
    "meizhuang_riyue" => Kantele.World.InquiryHandlers.MeizhuangRiyue,
    "tonsure" => Kantele.World.InquiryHandlers.Tonsure,
    "born_family_reply" => Kantele.World.InquiryHandlers.BornFamilyReply,
    "wudang_jiuyang" => Kantele.World.InquiryHandlers.WudangJiuyang,
    "luohan_zhen" => Kantele.World.InquiryHandlers.LuohanZhen,
    "npc_item_grant" => Kantele.World.InquiryHandlers.NpcItemGrant,
    "npc_reply" => Kantele.World.InquiryHandlers.NpcReply,
    "xiaoyao_zhihuan" => Kantele.World.InquiryHandlers.XiaoyaoZhihuan,
    "xueshan_tonsure" => Kantele.World.InquiryHandlers.XueshanTonsure,
    "xueshan_midao" => Kantele.World.InquiryHandlers.XueshanMidao,
    "xueshan_lun" => Kantele.World.InquiryHandlers.XueshanLun,
    "xuedao_midao" => Kantele.World.InquiryHandlers.XuedaoMidao,
    "xuedao_dao" => Kantele.World.InquiryHandlers.XuedaoTreasure,
    "xuedao_book" => Kantele.World.InquiryHandlers.XuedaoTreasure,
    "xuedao_tonsure" => Kantele.World.InquiryHandlers.XuedaoTonsure,
    "quest" => Kantele.World.InquiryHandlers.Quest
  }

  @doc "按 `kind` 查处理模块；未知 kind 返回 nil（静默忽略）"
  def lookup(kind) when is_binary(kind), do: Map.get(@handlers, kind)
  def lookup(_), do: nil
end
