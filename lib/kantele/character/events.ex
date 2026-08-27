defmodule Kantele.Character.Events do
  @moduledoc false

  use Kalevala.Event.Router

  alias Kalevala.Event.ItemDrop
  alias Kalevala.Event.ItemPickUp
  alias Kalevala.Event.Message
  alias Kalevala.Event.Movement
  alias Kantele.Character.ChannelEvent
  alias Kantele.Character.CombatEvent
  alias Kantele.Character.EmoteEvent
  alias Kantele.Character.SayEvent
  alias Kantele.Character.TellEvent
  alias Kantele.Character.WhisperEvent

  scope(Kantele.Character) do
    module(DelayedEvent) do
      event("commands/delayed", :run)
    end

    module(ExerciseEvent) do
      event("exercise/tick", :tick)
    end

    module(RespirateEvent) do
      event("respirate/tick", :tick)
    end

    module(JingzuoEvent) do
      event("jingzuo/wakeup", :wakeup)
    end

    module(ShopEvent) do
      event("shop/list-result", :list_result)
      event("shop/buy-result", :buy_result)
    end

    module(QuestEvent) do
      event("quest/turnin-request", :turnin_request)
    end

    module(FamilyEvent) do
      event("family/result", :result)
    end

    module(GiveEvent) do
      event("characters/give", :receive)
      event("give/result", :result)
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
      event("combat/enemy-died", :enemy_died)
      event("combat/enemy-left", :enemy_left)
      event("combat/halt", :halt)
      event("combat/yield", :yield)
      event("combat/reject-dead", :reject_dead)
      event("combat/buff-expire", :buff_expire)
      event("combat/respawn", :respawn)
      event("vitals/regen", :regen)
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
    end

    module(NpcFamilyEvent) do
      event("family/apprentice", :apprentice)
    end

    module(WanderEvent) do
      event("room/wander", :run)
    end
  end
end
