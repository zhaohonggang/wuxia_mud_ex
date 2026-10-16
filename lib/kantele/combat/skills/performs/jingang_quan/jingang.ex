defmodule Kantele.Combat.Skills.Performs.JingangQuan.Jingang do
  @moduledoc """
  大金刚神通「jingang」（对照 `kungfu/skill/jingang-quan/jingang.c`，inherit F_SSERVER）

  金刚拳自我增益：门槛（按 .c 顺序）已学此招 → 未在运功中 → 目标战斗中 →
  激发少林内功（hunyuan-yiqi/yijinjing/luohan-fumogong）→ 真气>=500 →
  force>=150 → cuff>=150 → 激发金刚拳 → 目标存活。

  气血 > 上限 40%：广播起手、`str +count*2 / dex -d_count`、扣 150 内力，
  定时 `remove_effect` 回收；否则拼死一击（`str +count*10`、真气清零、
  内力上限 -10、`unconcious`）。

  差异（TODO(migrate)）：
  - `call_out remove_effect` 由 `combat/buff-expire` + `expire_message/0` 承担；
  - 低气血分支的 `COMBAT_D->do_attack` 与 `unconcious` 未建模（TODO(migrate)）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats

  @perform_id "jingang-quan/jingang"
  @move_name "「大金刚神通」"
  @buff_key "jingang"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         :ok <- check_not_running(combat),
         {:ok, target} <- check_target(combat),
         :ok <- check_force_mapped(stats),
         :ok <- check_neili(character),
         :ok <- check_force(stats),
         :ok <- check_cuff(stats),
         :ok <- check_cuff_mapped(stats),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  defp check_not_running(combat) do
    if Combat.buff_active?(combat, @buff_key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp check_target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "「大金刚神通」只能对战斗中的对手使用。\n"}
    end
  end

  defp check_force_mapped(stats) do
    if Stats.mapped(stats, "force") in ["hunyuan-yiqi", "yijinjing", "luohan-fumogong"] do
      :ok
    else
      {:error, "你现在没有激发少林内功为内功，难以施展#{@move_name}。\n"}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的真气不够，无法施展#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_force(stats) do
    if Stats.skill(stats, "force") < 150 do
      {:error, "你的内功修为不够，不能使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_cuff(stats) do
    if Stats.skill(stats, "cuff") < 150 do
      {:error, "你的拳法还不到家，无法使用#{@move_name}！\n"}
    else
      :ok
    end
  end

  defp check_cuff_mapped(stats) do
    if Stats.mapped(stats, "cuff") == "jingang-quan" do
      :ok
    else
      {:error, "你没有激发金刚拳，无法使用#{@move_name}！\n"}
    end
  end

  defp check_target_alive(target) do
    if not dead?(target) do
      :ok
    else
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp apply_perform(conn, character, target, stats) do
    vitals = character.meta.vitals
    qi = vitals.qi
    maxqi = vitals.max_qi
    skill = div(Stats.skill(stats, "jingang-quan"), 3)
    count = div(skill, 2)
    d_count = div(stats.dex || 0, 10)

    if qi * 5 > maxqi * 2 do
      # LPC: msg = HIY "$N" HIY "使出大金刚拳的绝技「大金刚神通」，臂力陡然增加！\n" NOR;
      msg = "$N使出大金刚拳的绝技#{@move_name}，臂力陡然增加！\n"

      vitals = %{vitals | neili: vitals.neili - 150}
      character = %{character | meta: %{character.meta | vitals: vitals}}

      buff = %Buff{key: @buff_key, applies: %{}}

      combat =
        character.meta.combat
        |> Combat.apply_temp(%{str: count * 2, dex: -d_count})
        |> Combat.add_buff(buff)

      character = %{character | meta: %{character.meta | combat: combat}}

      conn = Broadcast.publish(conn, msg, n1: character.name, n2: target.name)
      schedule_expire(buff, skill)

      conn
      |> put_character(character)
      |> assign(:prompt, false)
    else
      # LPC: msg = HIR "$N" HIR "拼尽毕生功力使出了大金刚拳的终"
      #           "极绝技, 全身骨骼一阵爆响, 欲与$n" HIR "同归于尽！\n" NOR;
      msg = "$N拼尽毕生功力使出了大金刚拳的终极绝技, 全身骨骼一阵爆响, 欲与$n同归于尽！\n"

      vitals = %{vitals | neili: 0, max_neili: vitals.max_neili - 10}
      character = %{character | meta: %{character.meta | vitals: vitals}}

      buff = %Buff{key: @buff_key, applies: %{}}

      combat =
        character.meta.combat
        |> Combat.apply_temp(%{str: count * 10})
        |> Combat.add_buff(buff)

      character = %{character | meta: %{character.meta | combat: combat}}

      conn = Broadcast.publish(conn, msg, n1: character.name, n2: target.name)

      # LPC: msg = HIR "$N" HIR "用尽了最后一点气力, 喷出一口鲜血, 一头栽倒在地！\n" NOR;
      end_msg = "$N用尽了最后一点气力, 喷出一口鲜血, 一头栽倒在地！\n"
      conn = Broadcast.publish(conn, end_msg, n1: character.name, n2: target.name)
      schedule_expire(buff, 2)

      conn
      |> put_character(character)
      |> assign(:prompt, false)
    end
  end

  defp schedule_expire(buff, seconds) do
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(seconds, 1) * 1000
    )
  end

  # LPC remove_effect：tell_object(me, "你的「大金刚神通」运行完毕，将内力收回丹田。\n");
  @doc false
  def expire_message, do: "你的#{@move_name}运行完毕，将内力收回丹田。\n"
end
