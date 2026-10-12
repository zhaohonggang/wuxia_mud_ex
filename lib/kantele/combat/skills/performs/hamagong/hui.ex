defmodule Kantele.Combat.Skills.Performs.Hamagong.Hui do
  @moduledoc """
  exert「hui」（source hamagong/hui.c，inherit F_CLEAN_UP）

  门槛：须先以「经脉倒转」（`reserve`）倒转经脉，否则拒绝。
  起手广播后回收 `reserve` 的临时加成（`dodge`/`parry` 各减 `蛤蟆功/3`，
  `armor`/`dispel_poison` 各减 `蛤蟆功/2`），并清空真气。

  差异（TODO(migrate)）：
  - `.c` 的 `query_temp("hmg_dzjm")` / `delete_temp("hmg_dzjm")` 折算为引擎 buff
    （`Buff{key: "hmg_dzjm"}`，由 `reserve` 安装）；回收量直接取自该 buff 的
    `applies`（即 `reserve` 时记录的负值），与 `.c` 存 `skill` 再取负等价；
  - `apply/dispel_poison` 不在 `Combat.applies_keys/0` 白名单内（引擎未建模），
    仅随 `apply_temp/2` 一并抵消，无读取方。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Combat.Broadcast

  @key "hmg_dzjm"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_other(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (! (skill = me->query_temp("hmg_dzjm")))
  #        return notify_fail("你并没有倒转经脉啊。\n");
  defp check_other(character) do
    if Combat.buff_active?(character.meta.combat, @key) do
      :ok
    else
      {:error, "你并没有倒转经脉啊。\n"}
    end
  end

  defp apply_effect(conn, character) do
    # LPC: msg = HIB "$N" HIB "缓缓吐出一口气，脸色变了变，阴阳不定。\n" NOR;
    #      message_combatd(msg, me);
    #      me->add_temp("apply/dodge", -skill / 3);
    #      me->add_temp("apply/parry", -skill / 3);
    #      me->add_temp("apply/armor", -skill / 2);
    #      me->add_temp("apply/dispel_poison", -skill / 2);
    #      me->delete_temp("hmg_dzjm");
    #      me->set("neili", 0);
    combat =
      character.meta.combat
      |> reverse_applies()
      |> Combat.remove_buff(@key)

    vitals = %{character.meta.vitals | neili: 0}
    character = %{character | meta: %{character.meta | combat: combat, vitals: vitals}}

    conn
    |> Broadcast.publish("$N缓缓吐出一口气，脸色变了变，阴阳不定。\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # reserve 存入的 `Buff.applies` 即 `.c` 中 `-skill / N` 的反值，直接叠加回 temp。
  defp reverse_applies(combat) do
    case Enum.find(combat.buffs, &(&1.key == @key)) do
      %Buff{applies: applies} -> Combat.apply_temp(combat, applies)
      nil -> combat
    end
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // hui.c 蛤蟆功回息
  # 
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void remove_effect(object me, int a_amount);
  # 
  # int exert(object me, object target)
  # {
  #         int skill;
  #         string msg;
  # 
  #         if (! (skill = me->query_temp("hmg_dzjm")))
  #                 return notify_fail("你并没有倒转经脉啊。\n");
  # 
  #         msg = HIB "$N" HIB "缓缓吐出一口气，脸色变了变，阴阳不定。\n" NOR;
  #         message_combatd(msg, me);
  # 
  #         me->add_temp("apply/dodge", -skill / 3);
  #         me->add_temp("apply/parry", -skill / 3);
  #         me->add_temp("apply/armor", -skill / 2);
  #         me->add_temp("apply/dispel_poison", -skill / 2);
  #         me->delete_temp("hmg_dzjm");
  # 
  #         me->set("neili", 0);
  #         return 1;
  # }
end
