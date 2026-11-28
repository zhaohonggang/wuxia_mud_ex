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
    "hire_helper" => Kantele.World.InquiryHandlers.HireHelper,
    "message_sort" => Kantele.World.InquiryHandlers.MessageSort,
    "counter_perform" => Kantele.World.InquiryHandlers.CounterPerform,
    "teleport_service" => Kantele.World.InquiryHandlers.TeleportService,
    # #831 天地会 ask_tuihui：party/party_name 门控 + 退会清理 party/rank/level。
    "tiandihui_quit" => Kantele.World.InquiryHandlers.TiandihuiQuit,
    "smith_job" => Kantele.World.InquiryHandlers.SmithJob,
    # d/city/npc/smith.c ask_back()：血刀弟子「血海无边」密道回中原。
    "city_smith_back" => Kantele.World.InquiryHandlers.CitySmithBack,
    # d/beijing/npc/*.c ask_weiwang()：8 名北京 NPC 查询「威望/江湖威望」。
    "weiwang" => Kantele.World.InquiryHandlers.Weiwang,
    "yelvqi_job" => Kantele.World.InquiryHandlers.YelvqiJob,
    "wuxiuwen_tools" => Kantele.World.InquiryHandlers.WuxiuwenTools,
    "hostile" => Kantele.World.InquiryHandlers.Hostile,
    "jobs_job" => Kantele.World.InquiryHandlers.JobsJob,
    # A-5-c C4：北京领赏（康熙 ask_reward 殿试链；御前侍卫传送链为 C5 并入）。
    "beijing_reward" => Kantele.World.InquiryHandlers.BeijingReward,
    # A-5-b：平一指/书童/厨娘的 ask_job() 领活链（按 profile 分流）。
    "job_ask" => Kantele.World.InquiryHandlers.JobAsk,
    "sect_master_grant" => Kantele.World.InquiryHandlers.SectMasterGrant,
    "sect_master_teach_skill" => Kantele.World.InquiryHandlers.SectMasterTeachSkill,
    "sect_master_unlock_perform" => Kantele.World.InquiryHandlers.SectMasterUnlockPerform,
    "meizhuang_riyue" => Kantele.World.InquiryHandlers.MeizhuangRiyue,
    "tonsure" => Kantele.World.InquiryHandlers.Tonsure,
    # #853 峨嵋九名师太共用 tobebonze.h ask_for_join：同门/class/性别三门 + pending。
    "emei_tonsure" => Kantele.World.InquiryHandlers.EmeiTonsure,
    # #857 灭绝师太「还俗」ask_for_quit：同门/未出家门 + pending/quit_bonze。
    "emei_quit_bonze" => Kantele.World.InquiryHandlers.EmeiQuitBonze,
    # #855 李明霞「上山/back」带人传送 + 回程定时器。
    "emei_li_back" => Kantele.World.InquiryHandlers.EmeiLiBack,
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
    # #813 QUEST_D->accept_ask("历练"/"历炼"/"锻炼") 通用门派历练流程；
    # 与 #955 张无忌任务 spec 登记的 "quest" 是两套机制，不可合并。
    "quest_lilian" => Kantele.World.InquiryHandlers.QuestLilian,
    "quest" => Kantele.World.InquiryHandlers.Quest
  }

  @doc "按 `kind` 查处理模块；未知 kind 返回 nil（静默忽略）"
  def lookup(kind) when is_binary(kind), do: Map.get(@handlers, kind)
  def lookup(_), do: nil
end
