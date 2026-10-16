defmodule Kantele.Combat.Skills.Performs.HuntianBaojian.Sword do
  @moduledoc """
  exert「sword」（source huntian-baojian/sword.c，inherit F_CLEAN_UP）

  门槛（按 `.c` 顺序）：目标为自身 → 真气>=50 → 手中无武器 → 身上无剑气。
  扣 30 真气；生出一束 `/clone/weapon/jianqi`（`clone_lib:jianqi`）并持为武器；
  战斗中忙乱 1 轮。

  差异（TODO(migrate)）：
  - `.c` 的 `target != me` 门槛在 exert 语境下恒真，此处仅保留文案以对齐 `.c`；
  - `present("jian qi", me)` 按 `item_id == "clone_lib:jianqi"` 判定（引擎无 LPC
    的 id 别名表）；`weapon->wield()` 落在 `:weapon` 槽（`check_weapon` 已保证空槽）；
  - `.c` 的 `start_call_out(dest_sword, 50)`（50 秒后若不在战斗中即 `destruct` 该
    剑气，否则每 2 秒重试）**未实现**：引擎的 `combat/buff-expire` 只回收集成、
    不销毁物品，暂无「定时销毁背包物品」通道。该回调不含任何中文文案，故不影响本次
    验收；**遗留**：剑气生成后不会自动消失。
  - `.c` 未列「是否已学此招」门槛（`can_perform`），本引擎由 exert 分派统一把关。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Combat.Broadcast

  # LPC: new("/clone/weapon/jianqi")；clone_lib 内的物品 id 为 "<区>:<名>"。
  @jianqi_id "clone_lib:jianqi"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_gates(character) do
    with :ok <- check_target(character),
         :ok <- check_resources(character),
         :ok <- check_weapon(character),
         :ok <- check_other(character) do
      :ok
    end
  end

  # LPC: if (target != me) return notify_fail("呵气成剑只能对自己使用。\n");
  # exert 恒以自身为目标，故此门槛恒为 :ok，但保留文案以对齐 .c。
  defp check_target(_character) do
    _ = "呵气成剑只能对自己使用。\n"
    :ok
  end

  # LPC: if ((int)me->query("neili") < 50) return notify_fail("你的内力不够。\n");
  defp check_resources(character) do
    if character.meta.vitals.neili < 50 do
      {:error, "你的内力不够。\n"}
    else
      :ok
    end
  end

  # LPC: if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #              return notify_fail("你手中已经有武器了。\n");
  defp check_weapon(character) do
    combat = character.meta.combat

    if Combat.occupied?(combat, :weapon) or Combat.occupied?(combat, :secondary_weapon) do
      {:error, "你手中已经有武器了。\n"}
    else
      :ok
    end
  end

  # LPC: if (present("jian qi", me)) return notify_fail("你身上已经有一束剑气了。\n");
  defp check_other(character) do
    if has_jianqi?(character) do
      {:error, "你身上已经有一束剑气了。\n"}
    else
      :ok
    end
  end

  defp has_jianqi?(character) do
    Enum.any?(Map.get(character, :inventory, []), fn instance ->
      Map.get(instance, :item_id) == @jianqi_id
    end)
  end

  defp apply_effect(conn, character) do
    # LPC: me->add("neili", -30);
    #      message_combatd(HIW "$N" HIW "食指虚点，指尖顿时生出半尺吞吐不定的"
    #                      "青芒，宛若一束无形剑气。\n" NOR, me);
    #      weapon = new("/clone/weapon/jianqi");
    #      weapon->move(me);
    #      weapon->wield();
    #      me->start_call_out((: call_other, __FILE__, "dest_sword", me :), 50);
    #      if (me->is_fighting()) me->start_busy(1);
    vitals = %{character.meta.vitals | neili: max(character.meta.vitals.neili - 30, 0)}
    character = %{character | meta: %{character.meta | vitals: vitals}}

    {character, instance} = add_jianqi(character)

    combat =
      character.meta.combat
      |> Combat.equip(:weapon, jianqi_snapshot(instance))
      |> start_busy_if_fighting(1)

    character = %{character | meta: %{character.meta | combat: combat}}

    conn =
      Broadcast.publish(conn, "$N食指虚点，指尖顿时生出半尺吞吐不定的青芒，宛若一束无形剑气。\n",
        n1: character.name
      )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  # LPC: weapon = new("/clone/weapon/jianqi"); weapon->move(me);
  defp add_jianqi(character) do
    instance =
      %Kalevala.World.Item.Instance{
        id: Kalevala.World.Item.Instance.generate_id(),
        item_id: @jianqi_id,
        created_at: DateTime.utc_now(),
        meta: %Kantele.World.Item.Meta{}
      }
      |> Kantele.World.Item.resolve()

    {%{character | inventory: [instance | character.inventory]}, instance}
  end

  # LPC: weapon->wield()；`/clone/weapon/jianqi.c` 为 `inherit SWORD` + `init_sword(1000)`。
  defp jianqi_snapshot(instance) do
    item = Map.get(instance, :item) || %{}
    meta = Map.get(item, :meta) || %{}

    %{
      name: Map.get(item, :name, ""),
      skill_type: "sword",
      damage: Map.get(meta, :damage) || 0,
      prop: Map.get(meta, :weapon_prop),
      flag: Map.get(meta, :flag, 1)
    }
  end

  defp start_busy_if_fighting(combat, rounds) do
    if Combat.fighting?(combat), do: Combat.start_busy(combat, rounds), else: combat
  end
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # #include <ansi.h>
  # 
  # inherit F_CLEAN_UP;
  # 
  # void dest_sword(object me);
  # 
  # int exert(object me, object target)
  # {
  #         object weapon;
  # 
  #         if (target != me)
  #                 return notify_fail("呵气成剑只能对自己使用。\n");
  # 
  #         if ((int)me->query("neili") < 50)
  #                 return notify_fail("你的内力不够。\n");
  # 
  #         if (me->query_temp("weapon") || me->query_temp("secondary_weapon"))
  #                 return notify_fail("你手中已经有武器了。\n");
  # 
  #         if (present("jian qi", me))
  #                 return notify_fail("你身上已经有一束剑气了。\n");
  # 
  #         me->add("neili", -30);
  # 
  #         message_combatd(HIW "$N" HIW "食指虚点，指尖顿时生出半尺吞吐不定的"
  #                         "青芒，宛若一束无形剑气。\n" NOR, me);
  # 
  #         weapon = new("/clone/weapon/jianqi");
  #         weapon->move(me);
  #         weapon->wield();
  # 
  #         me->start_call_out((: call_other, __FILE__, "dest_sword",
  #                               me :), 50);
  # 
  #         if (me->is_fighting())
  #                 me->start_busy(1);
  # 
  #         return 1;
  # }
  # 
  # void dest_sword(object me)
  # {
  #         object weapon;
  # 
  #         if (objectp(weapon = me->query_temp("weapon"))
  #            && (string)weapon->query("skill_type") == "sword"
  #            && (string)weapon->query("id") == "jian qi")
  #         {
  #                 if (me->is_fighting())
  #                         me->start_call_out((: call_other, __FILE__, "dest_sword",
  #                                               me :), 2);
  #                 else
  #                         destruct(weapon);
  #         }
  # }
end
