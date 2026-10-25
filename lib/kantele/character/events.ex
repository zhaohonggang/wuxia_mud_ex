defmodule Kantele.Character.Events do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.ItemDrop
  alias Kalevala.Event.ItemPickUp
  alias Kalevala.Event.Message
  alias Kalevala.Event.Movement
  alias Kantele.Character.ChannelEvent
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.DetachEvent
  alias Kantele.Character.EmoteEvent
  alias Kantele.Character.SayEvent
  alias Kantele.Character.TellEvent
  alias Kantele.Character.TrapEvent
  alias Kantele.Character.VisionEvent
  alias Kantele.Character.WhisperEvent

  scope(Kantele.Character) do
    module(DelayedEvent) do
      event("commands/delayed", :run)
    end

    module(ExerciseEvent) do
      event("exercise/tick", :tick)
    end

    module(ConditionEvent) do
      event("poison/apply", :apply)
      event("condition/tick", :tick)
    end

    module(RespirateEvent) do
      event("respirate/tick", :tick)
    end

    module(JingzuoEvent) do
      event("jingzuo/wakeup", :wakeup)
    end

    module(EffectEvent) do
      # 通用角色副作用（房间进程判定 -> 角色进程执行，见 Kantele.Character.EffectEvent）
      event("character/effects", :run)
    end

    module(TrapEvent) do
      # 出口陷阱副作用（房间进程判定 -> 角色进程执行，见 Kantele.Character.TrapEvent）
      event("trap/effect", :run)
    end

    module(ShopEvent) do
      event("shop/list-result", :list_result)
      event("shop/buy-result", :buy_result)
    end

    module(QuestEvent) do
      event("quest/turnin-request", :turnin_request)
      event("quest/report", :report)
      event("quest/ask-result", :ask_result)
      event("quest/cancel-result", :cancel_result)
    end

    module(FamilyEvent) do
      event("family/result", :result)
    end

    module(DetachEvent) do
      event("family/detach-result", :detach_result)
    end

    module(GiveEvent) do
      event("characters/give", :receive)
      event("give/result", :result)
      event("xiaoer/process_give", :xiaoer_process_give)
    end

    module(MirrorEvent) do
      event("mirror/give", :give_result)
    end

    module(NpcScriptEvent) do
      event("npc/give", :give_result)
      event("npc/learn", :learn_result)
      event("npc/faction", :faction_result)
      event("npc/perform", :perform_result)
      event("npc/register_summon", :register_result)
      event("npc/inquiry", :inquiry_result)
    end

    module(AssistEvent) do
      event("assist/request", :request)
    end

    module(StealEvent) do
      event("steal/result", :result)
    end

    module(SleepEvent) do
      event("sleep/wakeup", :wakeup)
    end

    module(SwearEvent) do
      event("swear/request", :request)
      event("swear/pending", :pending)
      event("swear/joined", :joined)
      event("swear/cancelled", :cancelled)
    end

    module(EngageEvent) do
      event("engage/propose", :propose)
      event("engage/pending", :pending)
      event("engage/joined", :joined)
      event("engage/cancelled", :cancelled)
      event("engage/divorced", :divorced)
    end

    module(LeagueEvent) do
      event("league/joined", :joined)
      event("league/removed", :removed)
      event("league/dismissed", :dismissed)
      event("league/grant", :grant)
    end

    module(CutEvent) do
      event("cut/result", :result)
    end

    module(FollowEvent) do
      event("follow/set-leader", :set_leader)
      event("follow/register", :register)
      event("follow/unregister", :unregister)
      event("follow/move", :move)
    end

    module(TeamEvent) do
      event("team/invite-request", :invite_request)
      event("team/accept", :accept)
      event("team/refuse", :refuse)
      event("team/declined", :declined)
      event("team/set", :set_team)
      event("team/disband", :disband)
      event("team/kicked", :kicked)
      event("team/member-left", :member_left)
      event("team/talk", :talk)
      event("team/formation", :formation)
      event("team/swear", :swear)
      event("team/xp-share", :xp_share)
    end

    module(CombatEvent) do
      event("combat/start", :start)
      event("combat/tick", :tick)
      event("combat/incoming", :incoming)
      event("combat/perform-incoming", :perform_incoming)
      event("combat/perform-feedback", :perform_feedback)
      event("combat/enemy-died", :enemy_died)
      event("combat/enemy-left", :enemy_left)
      event("combat/halt", :halt)
      event("combat/yield", :yield)
      event("combat/reject-dead", :reject_dead)
      event("combat/buff-expire", :buff_expire)
      event("combat/respawn", :respawn)
      event("vitals/regen", :regen)

      event(Message, :echo, interested?: &CombatEvent.interested?/1)
    end

    module(FanliangyiEvent) do
      event("array/fanliangyi-dao", :array)
    end

    module(EmoteEvent) do
      event(Message, :echo, interested?: &EmoteEvent.interested?/1)
    end

    module(InventoryEvent) do
      event("inventory/list", :list)
    end

    module(ItemEvent) do
      event(ItemDrop.Abort, :drop_abort)
      event(ItemDrop.Commit, :drop_commit)

      event(ItemPickUp.Abort, :pickup_abort)
      event(ItemPickUp.Commit, :pickup_commit)

      event("item/hide", :hide_commit)
    end

    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
      event(Movement.Notice, :notice)
    end

    module(SayEvent) do
      event("say/send", :broadcast)
      event(Message, :echo, interested?: &SayEvent.interested?/1)
    end

    module(VisionEvent) do
      event(Message, :echo, interested?: &VisionEvent.interested?/1)
    end

    module(SkillsEvent) do
      event("skills/learn-result", :learn_result)
    end

    module(TellEvent) do
      event("tell/send", :broadcast)
      event(Message, :echo, interested?: &TellEvent.interested?/1)
    end

    module(WhisperEvent) do
      event("whisper/send", :broadcast)
      event(Message, :echo, interested?: &WhisperEvent.interested?/1)
    end

    module(ChannelEvent) do
      event(Message, :echo, interested?: &ChannelEvent.interested?/1)
    end

    module(BiEvent) do
      event("bi/result", :result)
    end

    # 拱猪座位同步：动作 handler 判定，角色进程落地 `temp["pigging_seat"]`
    # （meta 只有本进程能安全修改；见 Kantele.Character.PigEvent）。
    module(PigEvent) do
      event("pig/seat", :seat)
    end

    # 赌场赢钱落地：房间进程结算后发 `casino/payout`，角色进程加扁平铜钱
    # （meta 只有本进程能安全修改；见 Kantele.Character.CasinoPayoutEvent）。
    module(CasinoPayoutEvent) do
      event("casino/payout", :credit)
    end

    module(YitianEvent) do
      event("yitian/result", :result)
    end
  end
end

defmodule Kantele.Character.IncomingEvents do
  @moduledoc false

  use Kalevala.Event.Router

  scope(Kantele.Character) do
    module(ContextEvent) do
      event("Context.Lookup", :lookup)
    end
  end
end

defmodule Kantele.Character.NonPlayerEvents do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.Movement

  scope(Kantele.Character) do
    module(CombatEvent) do
      event("combat/start", :start)
      event("combat/tick", :tick)
      event("combat/incoming", :incoming)
      event("combat/perform-incoming", :perform_incoming)
      event("combat/perform-feedback", :perform_feedback)
      event("combat/enemy-died", :enemy_died)
      event("combat/enemy-left", :enemy_left)
      event("combat/halt", :halt)
      event("combat/yield", :yield)
      event("combat/reject-dead", :reject_dead)
      event("combat/buff-expire", :buff_expire)
      event("combat/respawn", :respawn)
      event("vitals/regen", :regen)
    end

    module(FanliangyiEvent) do
      event("array/fanliangyi-dao", :array)
    end

    module(ConditionEvent) do
      event("poison/apply", :apply)
      event("condition/tick", :tick)
      event("condition/apply", :apply_named)
    end

    module(ConditionDownEvent) do
      event("condition/down", :run)
    end

    module(FleeEvent) do
      event("room/flee", :run)
    end

    module(MoveEvent) do
      event(Movement.Commit, :commit)
      event(Movement.Abort, :abort)
      event(Movement.Notice, :notice)
    end

    module(SkillsEvent) do
      event("skills/teach", :teach)
    end

    module(NpcShopEvent) do
      event("shop/list", :list)
      event("shop/buy", :buy)
    end

    module(NpcAskEvent) do
      event("characters/ask", :call)
      event("quest/ask", :call)
      event("quest/cancel", :call)
      event("npc/inquiry_consume", :inquiry_consume)
    end

    module(NpcCutEvent) do
      event("characters/cut", :call)
    end

    module(NpcFamilyEvent) do
      event("family/apprentice", :apprentice)
      event("family/detach", :detach)
    end

    module(CoagentEvent) do
      event("coagent/help", :help)
      event("coagent/finish", :finish)
    end

    module(WanderEvent) do
      event("room/wander", :run)
    end

    module(InvasionEquipEvent) do
      event("invasion/equip", :call)
    end

    module(CallOutEvent) do
      event("npc/call-out", :run)
    end

    module(BiEvent) do
      event("bi/begin", :begin_event)
    end

    module(YitianEvent) do
      event("yitian/begin", :begin_event)
    end
  end
end
