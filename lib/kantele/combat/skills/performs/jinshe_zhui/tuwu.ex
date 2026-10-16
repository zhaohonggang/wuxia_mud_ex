defmodule Kantele.Combat.Skills.Performs.JinsheZhui.Tuwu do
  @moduledoc """
  金蛇吐雾「tuwu」（对照 `kungfu/skill/jinshe-zhui/tuwu.c`，inherit F_SSERVER）

  金蛇锥法（暗器 throwing，持于 handing 槽）单体绝招：要求手持 `jinshe zhui`
  且余量 >= 1、jinshe-zhui >= 100、真气 >= 300、目标存活。
  起手消耗暗器 1 枚；命中判定 `skill / 2 + random(skill) > target->query_skill("dodge")`，
  命中则造成 qi 伤/创伤各 `skill / 3`、扣 200 真气、给目标挂 `skill / 30` 秒
  「血雾遮眼」失明 buff（对应 `set_temp("block_msg/all")` + `tuwu_target_end`）。

  差异（TODO(migrate)）：
  - `.c` 的自身冷却 `me->set_temp("jinshe/tuwu")` 仅在命中后置、`skill / 30` 秒后由
    `tuwu_me_end` 清除；本版简化为起手即置冷却 buff（命中/失手均进入冷却，同
    `jinshe-zhui/feng.ex` 先例），文案与时限保留；
  - `tuwu_target_end` 的 `message_combatd`（房间可见）与 `tell_object`（私有）
    经引擎 `combat/buff-expire` 合并为 `message` 渲染给目标（同 `cuixin-zhang/cui.ex`）；
  - `.c` 无 `can_perform`，故不设「已知此招」检查。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Combat.Broadcast
  alias Kantele.Combat.Engine
  alias Kantele.Combat.Messages
  alias Kantele.Combat.Performs
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @perform_id "jinshe-zhui/tuwu"
  @cooldown_key "jinshe/tuwu"
  @blind_key "jinshe/tuwu/blind"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_cooldown(combat),
         {:ok, target} <- target(combat),
         :ok <- check_weapon(character),
         :ok <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_target_alive(target) do
      apply_perform(conn, character, target, stats)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (me->query_temp("jinshe/tuwu"))
  #          return notify_fail("你才用的金蛇吐雾，没法接着就出招。\n");
  defp check_cooldown(combat) do
    if Combat.buff_active?(combat, @cooldown_key) do
      {:error, "你才用的金蛇吐雾，没法接着就出招。\n"}
    else
      :ok
    end
  end

  # LPC: if (! target || ! me->is_fighting(target))
  #          return notify_fail("金蛇吐雾只能在战斗中使用。\n");
  defp target(combat) do
    case combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "金蛇吐雾只能在战斗中使用。\n"}
    end
  end

  # LPC: if (! objectp(weapon = me->query_temp("handing")) ||
  #         (string)weapon->query("id") != "jinshe zhui" ||
  #         weapon->query_amount() < 1)
  #          return notify_fail("你手里没拿金蛇锥，不能使用绝招！\n");
  defp check_weapon(character) do
    item = handing(character)

    if item && Map.get(item, :id) == "jinshe zhui" and (Map.get(item.meta, :amount) || 1) >= 1 do
      :ok
    else
      {:error, "你手里没拿金蛇锥，不能使用绝招！\n"}
    end
  end

  # LPC: if ((skill = me->query_skill("jinshe-zhui", 1)) < 100)
  #          return notify_fail("你的金蛇锥法不够娴熟，不会使用金蛇吐雾。\n");
  defp check_skill_level(stats) do
    if Stats.skill(stats, "jinshe-zhui") < 100 do
      {:error, "你的金蛇锥法不够娴熟，不会使用金蛇吐雾。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 300)
  #          return notify_fail("你内力不够了。\n");
  defp check_neili(character) do
    if character.meta.vitals.neili < 300 do
      {:error, "你内力不够了。\n"}
    else
      :ok
    end
  end

  # LPC: if (! living(target)) return notify_fail("对方都已经这样了，用不着这么费力吧？\n");
  defp check_target_alive(target) do
    if dead?(target) do
      {:error, "对方都已经这样了，用不着这么费力吧？\n"}
    else
      :ok
    end
  end

  defp dead?(%{meta: %{combat: %{dead: dead}}}), do: dead == true
  defp dead?(_), do: false

  defp handing(character), do: Enum.find(character.inventory, & &1.handing)

  defp apply_perform(conn, character, target, stats) do
    skill = Stats.skill(stats, "jinshe-zhui")
    secs = cooldown_secs(skill)

    # LPC: weapon->add_amount(-1);
    character =
      case handing(character) do
        nil -> character
        item -> consume_handing(character, item)
      end

    # LPC: me->set_temp("jinshe/tuwu", 1);
    #      me->start_call_out((: call_other, __FILE__, "tuwu_me_end", me :), skill / 30);
    combat =
      character.meta.combat
      |> Combat.add_buff(%Buff{key: @cooldown_key, applies: %{}, duration: secs})

    character = %{character | meta: %{character.meta | combat: combat}}

    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: @cooldown_key, applies: %{}}
      },
      secs * 1000
    )

    # LPC: msg = HIY "$N" HIY "一声轻啸，身形微动，手中金蛇锥竟然向上飞"
    #           "起绕了个圈，随而迅速袭向$n" HIY "的面前。\n" NOR;
    start_msg = "$N一声轻啸，身形微动，手中金蛇锥竟然向上飞起绕了个圈，随而迅速袭向$n的面前。\n"
    conn = Broadcast.publish(conn, start_msg, n1: character.name, n2: target.name)

    send(target.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        skill: skill,
        rng: &:rand.uniform/1
      }
    })

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp cooldown_secs(skill), do: max(div(skill, 30), 1)

  defp consume_handing(character, item) do
    amount = (Map.get(item.meta, :amount) || 1) - 1

    inventory =
      character.inventory
      |> Enum.reject(fn i -> i == item && amount < 1 end)
      |> Enum.map(fn i ->
        if i == item, do: %{i | meta: Map.put(i.meta, :amount, amount)}, else: i
      end)

    %{character | inventory: inventory}
  end

  @impl true
  def resolve_incoming(conn, character, attacker, data) do
    if character.meta.combat.dead do
      conn
    else
      do_resolve_incoming(conn, character, attacker, data)
    end
  end

  defp do_resolve_incoming(conn, character, attacker, data) do
    skill = max(Map.get(data, :skill, 0), 1)
    rng = Map.get(data, :rng, &:rand.uniform/1)
    dodge = Stats.skill(character.meta.stats, "dodge")
    secs = cooldown_secs(skill)

    # LPC: if (skill / 2 + random(skill) > target->query_skill("dodge", 1))
    if div(skill, 2) + Engine.rand(rng, skill) > dodge do
      # LPC: target->receive_damage("qi", (int)skill / 3, me);
      #      target->receive_wound("qi", (int)skill / 3, me);
      vitals =
        character.meta.vitals
        |> Vitals.damage(:qi, div(skill, 3))
        |> Vitals.wound(:qi, div(skill, 3))

      # LPC: target->set_temp("block_msg/all", 1);
      #      target->start_call_out((: call_other, __FILE__, "tuwu_target_end", target :), skill / 30);
      combat =
        Combat.add_buff(character.meta.combat, %Buff{
          key: @blind_key,
          applies: %{},
          duration: secs
        })

      character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

      # LPC tuwu_target_end(): message_combatd("$N抹了抹满脸的" HIR "鲜血" NOR "，终于睁开了眼。\n", target);
      #                        tell_object(target, HIR "你终于抹掉了满脸的鲜血，看到了周围的情景。\n" NOR);
      Process.send_after(
        self(),
        %Event{
          from_pid: self(),
          topic: "combat/buff-expire",
          data: %{
            key: @blind_key,
            applies: %{},
            message:
              Enum.join(
                [
                  Messages.interpolate("$N抹了抹满脸的鲜血，终于睁开了眼。\n", n1: character.name),
                  "你终于抹掉了满脸的鲜血，看到了周围的情景。\n"
                ],
                ""
              )
          }
        },
        secs * 1000
      )

      # LPC: msg += HIM "只听一阵狂风扫叶般的声响中，$N" HIM "手中的"
      #                "金蛇锥闪出夺目的光芒，闪耀得$n" HIM "眼冒金花，"
      #                "\n除了眼前一重重的雾气外，$n" HIM "啥也看不见了！\n" NOR;
      hit_msg =
        "只听一阵狂风扫叶般的声响中，$N手中的金蛇锥闪出夺目的光芒，闪耀得$n眼冒金花，\n" <>
          "除了眼前一重重的雾气外，$n啥也看不见了！\n"

      conn = Broadcast.publish(conn, hit_msg, n1: attacker.name, n2: character.name)

      # LPC: me->add("neili", -200);
      Performs.feedback(attacker, 200, 0)

      put_character(conn, character)
    else
      # LPC: msg += CYN "$n" CYN "心中暗暗一惊，急忙后"
      #                "退，闪开了这枚金蛇锥。\n" NOR;
      miss_msg = "$n心中暗暗一惊，急忙后退，闪开了这枚金蛇锥。\n"
      conn = Broadcast.publish(conn, miss_msg, n1: attacker.name, n2: character.name)

      put_character(conn, character)
    end
  end

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}

  @doc "声明式规格（用于 prepare_skill 门槛校验）"
  def spec() do
    %Kantele.Combat.Performs.Spec{
      id: "jinshe-zhui/tuwu",
      kind: :perform,
      gates: [],
      costs: %{},
      effects: [],
      busy: 0
    }
  end
end
