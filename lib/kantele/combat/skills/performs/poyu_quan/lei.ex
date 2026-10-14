defmodule Kantele.Combat.Skills.Performs.PoyuQuan.Lei do
  @moduledoc """
  perform「雷动九天」（对照 `kungfu/skill/poyu-quan/lei.c`，自身增益）

  门槛（按 .c 顺序）：已学此招 → 未在运功中（`query_temp("lei")`）→
  真气>=500 → 劈石破玉拳>=120。
  通过后无条件扣 400 真气，广播状态文案，按等级折算
  `count = 劈石破玉拳/6`，给 `str`/`dex` 各 +`count` 临时加成，
  战斗中忙乱 2，并置 `lei` 标记；`劈石破玉拳/3` 秒后回收加成并提示
  「你的雷动九天运行完毕，将内力收回丹田。」

  差异（TODO(migrate)）：
  - `.c` 为单参数 perform（无 target），框架侧同样只在自身生效；
  - `me->add_temp("str", count)` / `add_temp("dex", count)` 与回收：
    str/dex 为天赋属性，不在 `Combat` 的 `@applies_keys` 白名单
    （同 `luohan_gun/shibaluohan.ex` 取舍）→ buff `applies: %{}`，
    仅以 buff 记录标记与到期时长，`count` 计算过程保留在注释中；
  - `set_temp("lei")` + `start_call_out(remove_effect, skill/3)` 折算为
    `Combat.Buff{key: @key, applies: %{}, duration: skill/3}` +
    `Combat.add_buff` + `combat/buff-expire` 定时回收
    （`Combat.buff_active?/2` 判「已在运功中」门槛），
    `remove_effect` 的 `tell_object` 文案作为到期提示（同
    `miaojia_neigong/powerup.ex` 先例）；
  - `.c` 的门槛文案 `"你的劈石破玉拳修为不够，无法施展" LEI "\n"` 在绝招名后
    无句号（原文如此，逐字保留）。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Combat.Broadcast

  @key "lei"
  @perform_id "poyu-quan/lei"
  @move_name "「雷动九天」"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_perform_known(character),
         :ok <- check_state(character),
         :ok <- check_resources(character),
         :ok <- check_levels(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (userp(me) && ! me->query("can_perform/poyu-quan/lei"))
  defp check_perform_known(character) do
    if Stats.perform_known?(character.meta.stats, @perform_id) do
      :ok
    else
      {:error, "你所使用的外功中没有这种功能。\n"}
    end
  end

  # LPC: if ((int)me->query_temp("lei")) return notify_fail("你已经在运功中了。\n");
  defp check_state(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  # LPC: if ((int)me->query("neili") < 500) return notify_fail("你现在的真气不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你现在的真气不够。\n"}
    else
      :ok
    end
  end

  # LPC: skill = (int)me->query_skill("poyu-quan",1);
  #      if (skill < 120)
  #      return notify_fail("你的劈石破玉拳修为不够，无法施展" LEI "\n");
  defp check_levels(character) do
    if Stats.skill(character.meta.stats, "poyu-quan") < 120 do
      {:error, "你的劈石破玉拳修为不够，无法施展#{@move_name}\n"}
    else
      :ok
    end
  end

  # LPC: me->add("neili", -400);
  #      message_combatd(HIM "$N" HIM "深深吸了一口气，脸上顿时"
  #                      "紫气大盛，出手越来越重！\n" NOR, me);
  #      count = skill / 6;
  #      if (me->is_fighting()) me->start_busy(2);
  #      me->add_temp("str", count);
  #      me->add_temp("dex", count);
  #      me->set_temp("lei", 1);
  #      me->start_call_out((: call_other, __FILE__, "remove_effect", me, count :), skill / 3);
  defp apply_effect(conn, character) do
    # LPC: skill = (int)me->query_skill("poyu-quan", 1);  count = skill / 6;
    #      count 给 str/dex 各 +count 临时加成（未建模，见 moduledoc；不落代码）。
    skill = Stats.skill(character.meta.stats, "poyu-quan")

    conn =
      Broadcast.publish(
        conn,
        "$N深深吸了一口气，脸上顿时紫气大盛，出手越来越重！\n",
        n1: character.name
      )

    # LPC: me->add("neili", -400);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 400, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    # LPC: me->add_temp("str", count); me->add_temp("dex", count);
    #      me->set_temp("lei", 1);
    #      me->start_call_out(..., skill / 3);
    # str/dex 未建模（不在 @applies_keys），applies 记 %{}，count 仅保留在注释：
    buff = %Buff{
      key: @key,
      applies: %{},
      duration: div(skill, 3)
    }

    combat =
      character.meta.combat
      |> Combat.add_buff(buff)

    # LPC: if (me->is_fighting()) me->start_busy(2);
    combat =
      if Combat.fighting?(combat) do
        Combat.start_busy(combat, 2)
      else
        combat
      end

    character = %{character | meta: %{character.meta | combat: combat}}

    # LPC: remove_effect() 的 tell_object(me, "你的雷动九天运行完毕，将内力收回丹田。\n");
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(buff.duration, 1) * 1000
    )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp expire_message, do: "你的雷动九天运行完毕，将内力收回丹田。\n"
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // leidong 雷动九天
  # // by winder 98.12
  # // modify by rcwiz 2003
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # #define LEI "「" HIM "雷动九天" NOR "」"
  # 
  # void remove_effect(object me, int amount);
  # 
  # int perform(object me)
  # {
  #     int skill, count/*, count1*/;
  # 
  # 
  #         if (userp(me) && ! me->query("can_perform/poyu-quan/lei"))
  #                 return notify_fail("你所使用的外功中没有这种功能。\n");
  # 
  #     if ((int)me->query_temp("lei"))
  #         return notify_fail("你已经在运功中了。\n");
  # 
  #     if ((int)me->query("neili") < 500)
  #         return notify_fail("你现在的真气不够。\n");
  # 
  #     //skill = me->query_skill("cuff");
  #     skill = (int)me->query_skill("poyu-quan",1);
  # 
  #     if (skill < 120)
  #         return notify_fail("你的劈石破玉拳修为不够，无法施展" LEI "\n");
  # 
  #     me->add("neili", -400);
  #     message_combatd(HIM "$N" HIM "深深吸了一口气，脸上顿时"
  #                         "紫气大盛，出手越来越重！\n" NOR, me);
  # 
  #     //count = skill / 10;
  #     count = skill / 6;
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(2);
  # 
  #     me->add_temp("str", count);
  #     me->add_temp("dex", count);
  #     me->set_temp("lei", 1);
  #     me->start_call_out((: call_other,  __FILE__, "remove_effect", me, count :), skill / 3);
  # 
  #     return 1;
  # }
  # 
  # void remove_effect(object me, int amount)
  # {
  #     if ((int)me->query_temp("lei"))
  #     {
  #         me->add_temp("str", -amount);
  #         me->add_temp("dex", -amount);
  #         me->delete_temp("lei");
  #         tell_object(me, CYN "你的雷动九天运行完毕，将内力收回丹田。\n" NOR);
  #     }
  # }
end
