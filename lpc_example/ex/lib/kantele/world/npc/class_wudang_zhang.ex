defmodule ExKantele.World.Npc.ClassWudangZhang do
  @moduledoc """
  张三丰（对照 lpc_example/class_npc/class_wudang_zhang.c，964 行）

  结论：**一半数据、一半行为**，无法单文件直落。
  - 数据半（skills/map_skill/stats/family）→ 可进 UCL `characters`（见 migrate-notes 附表）
  - 行为半（11 个带前置条件的 ask_*、收徒条件 attempt_apprentice、
    接/拒物品 accept_object、拜师 teach_skill 门槛）→ 需底层“带逻辑的问询/NPC 钩子”。

  当前 Kantele 的 UCL：
   - `inquiries` 只支持 字符串 -> 字符串（无逻辑、无副作用）
   - `teach` 支持静态 teach_skills，但不支持 attempt_apprentice 的多条件判定
   - 无 accept_object（收东西）钩子、无 chat_chance_combat 战斗动作表

  本模块把这些行为沉淀成事件处理器样式的函数签名，标注所需底层扩展。
  """

  import Kalevala.World.Room.Context
  import Kalevala.Character.Conn

  alias Kantele.Character.Stats
  alias Kantele.Character.Views.CommandView

  # ---- 问询逻辑（原 ask_skill1..11 / ask_jian / ask_jiuyang）----
  # 每项：{关键词, 前置检查回调, 授技动作}
  @inquiry_handlers [
    {"鹤嘴劲", &check_dian/1, :perform_taiji_shengong_dian},
    {"震字诀", &check_zhen/1, :perform_taiji_quan_zhen},
    {"真武剑", &check_jian/1, :grant_zhenwu_sword},
    {"九阳真经", &check_jiuyang/1, :teach_wudang_jiuyang}
  ]

  # LPC ask_skill1 的检查：family / gongxian>=800 / shen>=150000 / taiji-shengong>=100 / max_neili>=1500
  defp check_dian(req) do
    %{
      family?: req.family_name == "武当派",
      gongxian: req.gongxian >= 800,
      shen: req.shen >= 150_000,
      skill: Stats.skill(req.stats, "taiji-shengong") >= 100,
      neili: req.max_neili >= 1500
    }
  end

  # 查询事件（characters/ask 已由 Room.AskRequestEvent 转给本 NPC）
  def handle_ask(context, event) do
    case ask_handler(event.data.keyword) do
      nil -> render(context, event.data.reply_to, CommandView, "text", %{text: random_dodge()})
      handler -> run_handler(context, event, handler)
    end
  end

  defp run_handler(context, event, {_kw, check, giver}) do
    req = build_req(event.data)
    checks = check.(req)

    cond do
      not checks.family? -> render(context, event.data.reply_to, CommandView, "text", %{text: "你不是我们武当派的人，何出此言？\n"})
      not (checks.gongxian and checks.shen and checks.skill and checks.neili) -> render(context, event.data.reply_to, CommandView, "text", %{text: "你的修为/贡献还不够，这招先不忙传你。\n"})
      true ->
        # 授技：把 can_perform/<skill>/<name> 写回请求者，扣 gongxian
        grant(context, event.data.reply_to, giver)
    end
  end

  defp ask_handler(kw),
    do: Enum.find(@inquiry_handlers, fn {k, _c, _g} -> k == kw end)

  defp build_req(data), do: data
  defp grant(context, pid, giver), do: context |> event(pid, self(), "npc/grant", %{giver: giver})
  defp random_dodge(), do: "嗨，我这儿正忙着呢，你去问我别的徒弟吧。\n"

  @unsupported [
    attempt_apprentice: "收徒需多条件判定（行为，非静态 teach）",
    accept_object: "NPC 收受物品钩子（UCL 无）",
    chat_msg_combat: "战斗中的随机动作表演（perform/exert 触发表）",
    donat_sword: "真武剑唯一物品的所有权/流转跟踪"
  ]
end
