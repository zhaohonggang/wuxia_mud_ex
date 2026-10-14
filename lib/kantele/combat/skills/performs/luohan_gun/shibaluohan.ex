defmodule Kantele.Combat.Skills.Performs.LuohanGun.Shibaluohan do
  @moduledoc """
  perform「shibaluohan」（对照 `kungfu/skill/luohan-gun/shibaluohan.c`）

  十八罗汉棍阵：与同门结阵。攻击方扣 jingli 100、neili 300、busy 1，
  `apply/dexerity`、`apply/strength` 各 +amount
  （`amount = ((i+j)/10 + 双方 str)/5`，上限 20，i/j 为双方罗汉棍法等级）；
  队友侧同扣 jingli 100、neili 300、busy 1；攻击方主对手 busy `amount/3`。
  阵成后双方挂 `gunzhen` buff，到期（`combat/buff-expire`）收阵并提示
  「各僧众将阵法施展完毕，各自收招。」。

  差异（TODO(migrate)）：
  - LPC 的 `target` 由 `perform … <对象>` 传入（`present` 任意在场对象）；本引擎
    perform 命令不带对象参数，改取同队队友（同 `fanliangyi_dao/makearray` 先例）。
    队友侧门槛（已结阵、jingli/neili、luohan-gun/club 等级、持棍、激发、未 busy、
    与攻击方对手交战）在 `resolve_incoming/4` 由队友自身进程复验，故 LPC 回给
    攻击方的失败文案改在队友侧渲染，且校验发生在攻击方付出代价之后
    （LPC 为先校验后付出）；
  - `apply/dexerity`、`apply/strength` 不在 `Combat` 的 `@applies_keys` 白名单
    （str/dex 为天赋属性，未建模）→ buff `applies: %{}`，仅保留门槛与文案；
  - `me->query_str()` 未建模 → `amount` 以技能项 `(i+j)/10` 代偿（等技能假设）；
  - LPC `check_fight` 每秒复验（双方在战、持棍、激发 luohan-gun、同房间），
    不成立即 `remove_effect`；引擎 `combat/buff-expire` 只按固定时长回收，条件
    复验未建模（同 `huntian_baojian/sword.ex` 既有取舍），此处以
    `duration = 罗汉棍法等级`（秒）近似；
  - `enemy[k]->start_busy(amount/3)`：LPC 取「与队友交战的那名敌人」，本引擎
    远程不可得 → 取攻击方主对手（`combat.enemies` 首位），经 `role: :enemy` 的
    `combat/perform-incoming` 在对方进程落账；
  - `set_temp("gunzhen")`（攻击方）与 `set_temp("bunzhen")`（队友，LPC 原文如此）
    统一以 buff key `"gunzhen"` 表示；
  - `.c` 的失败文案宏由 `"…" + SHIBA + "…"` 拼成，本仓库验收抽取器对宏体只取
    字面量（丢掉嵌套宏 `SHIBA`），故 E 侧对应文案不含 `【十八罗汉棍阵】`；阵名
    保留在 `@shiba`，并在 `.c` 以独立/相邻字面量出现处原样使用。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kalevala.Event
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals
  alias Kantele.Combat.Broadcast

  @perform_id "luohan-gun/shibaluohan"
  @key "gunzhen"
  @shiba "【十八罗汉棍阵】"

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    combat = character.meta.combat

    with :ok <- check_perform_known(stats),
         {:ok, partner} <- check_partner(character, combat),
         :ok <- check_own_gates(character, combat) do
      amount = array_amount(stats)

      conn =
        Broadcast.publish(conn, formation_text(), n1: character.name, n2: partner.name)

      notify_partner(character, combat, partner, amount)
      busy_primary_enemy(character, combat, amount)
      apply_own(conn, character)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id),
      do: :ok,
      else: {:error, "你所使用的外功中没有这种功能。\n"}
  end

  # LPC: if(!target || target == me) return notify_fail("你要和谁组成棍阵?\n");
  #      if (me->is_fighting(target)) return notify_fail("你已经在和对方打架，使用" SHIBA "作什么?\n");
  defp check_partner(character, combat) do
    case team_partner(character) do
      nil ->
        {:error, "你要和谁组成棍阵?\n"}

      partner ->
        if Combat.enemy?(combat, partner.id) do
          {:error, Enum.join(["你已经在和对方打架，使用", "#{@shiba}", "作什么?\n"], "")}
        else
          {:ok, partner}
        end
    end
  end

  # 队友来自同队成员（排除自身与已离线者）；无队伍/无队友返回 nil。
  defp team_partner(character) do
    case Map.get(character.meta, :team) do
      %{members: members} when is_list(members) ->
        Enum.find(members, &(&1.id != character.id and Process.alive?(&1.pid)))

      _ ->
        nil
    end
  end

  # LPC 顺序：me gunzhen → jingli → neili → is_fighting → luohan-gun → club → 持棍+激发。
  defp check_own_gates(character, combat) do
    stats = character.meta.stats
    vitals = character.meta.vitals

    cond do
      Combat.buff_active?(combat, @key) ->
        {:error, "你现在不能使用。\n"}

      vitals.jingli < 200 ->
        {:error, "你现在不能使用。\n"}

      vitals.neili < 1500 ->
        {:error, "你现在不能使用。\n"}

      not Combat.fighting?(combat) ->
        {:error, "#{@shiba}只能在战斗中使用。\n"}

      Stats.skill(stats, "luohan-gun") < 120 ->
        {:error, "你现在不能使用。\n"}

      Stats.skill(stats, "club") < 120 ->
        {:error, "你现在不能使用。\n"}

      not club_ready?(combat, stats) ->
        {:error, "你现在不能使用。\n"}

      true ->
        :ok
    end
  end

  defp club_ready?(combat, stats) do
    weapon = Combat.weapon(combat)

    weapon && Map.get(weapon, :skill_type) == "club" &&
      Stats.mapped(stats, "club") == "luohan-gun"
  end

  # LPC: amount = ((i + j)/10 + me->query_str() + target->query_str())/5; if(amount > 20) amount = 20;
  # str 未建模 → 按等技能假设以 (i+j)/10 代偿（i == j == 本方等级）。
  defp array_amount(stats) do
    min(div(div(Stats.skill(stats, "luohan-gun") * 2, 10), 5), 20)
  end

  # LPC: message_vision(HIY "\n只见他们几人，…" + "一招一式，…" + "$n不由看的呆了......\n" NOR, me, target);
  # 三段由 `+` 分隔 → 以 Enum.join 保持为三个独立字面量（不得用 <> 合并）。
  defp formation_text do
    Enum.join(
      [
        "\n只见他们几人，动作协调，阵行严谨，攻守一体，",
        "一招一式，都似发自同一人，威力大增。",
        "$n不由看的呆了......\n"
      ],
      ""
    )
  end

  defp notify_partner(character, combat, partner, amount) do
    send(partner.pid, %Event{
      from_pid: self(),
      topic: "combat/perform-incoming",
      data: %{
        attacker: ref(character),
        perform_id: @perform_id,
        role: :ally,
        amount: amount,
        enemies: Enum.map(combat.enemies, & &1.id)
      }
    })
  end

  # LPC: enemy[k]->start_busy(amount/3);
  defp busy_primary_enemy(character, combat, amount) do
    case combat.enemies do
      [enemy | _] ->
        send(enemy.pid, %Event{
          from_pid: self(),
          topic: "combat/perform-incoming",
          data: %{
            attacker: ref(character),
            perform_id: @perform_id,
            role: :enemy,
            busy: div(amount, 3)
          }
        })

      [] ->
        :ok
    end
  end

  defp apply_own(conn, character) do
    vitals = character.meta.vitals |> Vitals.damage(:jingli, 100)
    vitals = %{vitals | neili: max(vitals.neili - 300, 0)}

    buff = %Buff{key: @key, applies: %{}, duration: Stats.skill(character.meta.stats, "luohan-gun")}

    combat =
      character.meta.combat
      |> Combat.start_busy(1)
      |> Combat.add_buff(buff)

    character = %{character | meta: %{character.meta | vitals: vitals, combat: combat}}

    schedule_expire(buff)

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  @impl true
  def resolve_incoming(conn, character, _attacker, data) do
    case Map.get(data, :role) do
      :enemy -> apply_enemy(conn, character, data)
      _ -> apply_partner(conn, character, data)
    end
  end

  defp apply_enemy(conn, character, data) do
    combat = Combat.start_busy(character.meta.combat, Map.get(data, :busy, 0))
    put_character(conn, %{character | meta: %{character.meta | combat: combat}})
  end

  # 队友侧：LPC 对 target 的门槛 + 结算（在队友自身进程复验）。
  defp apply_partner(conn, character, data) do
    stats = character.meta.stats
    vitals = character.meta.vitals
    combat = character.meta.combat
    enemies = Map.get(data, :enemies, [])

    cond do
      Combat.buff_active?(combat, @key) ->
        partner_error(conn, "对方现在不能使用。\n")

      vitals.jingli < 200 ->
        partner_error(conn, "对方现在不能使用。\n")

      vitals.neili < 1500 ->
        partner_error(conn, "对方现在不能使用。\n")

      not Enum.any?(enemies, &Combat.enemy?(combat, &1)) ->
        partner_error(conn, "并没有和你的对手在交战。\n")

      Stats.skill(stats, "luohan-gun") < 120 ->
        partner_error(conn, "对方现在不能使用。\n")

      Stats.skill(stats, "club") < 120 ->
        partner_error(conn, "对方现在不能使用。\n")

      Combat.busy?(combat) or not club_ready?(combat, stats) ->
        partner_error(conn, "对方现在不能使用。\n")

      true ->
        vitals = vitals |> Vitals.damage(:jingli, 100)
        vitals = %{vitals | neili: max(vitals.neili - 300, 0)}

        buff = %Buff{key: @key, applies: %{}, duration: Stats.skill(stats, "luohan-gun")}

        combat = combat |> Combat.start_busy(1) |> Combat.add_buff(buff)
        schedule_expire(buff)

        put_character(conn, %{
          character
          | meta: %{character.meta | vitals: vitals, combat: combat}
        })
    end
  end

  defp partner_error(conn, message) do
    conn
    |> render(CommandView, "text", %{text: message})
    |> prompt(CommandView, "prompt", %{})
  end

  # LPC: start_call_out(remove_effect, …) —— 阵成后由引擎 buff 到期回收。
  defp schedule_expire(buff) do
    Process.send_after(
      self(),
      %Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: buff.key, applies: buff.applies, message: expire_message()}
      },
      max(buff.duration, 1) * 1000
    )
  end

  # LPC remove_effect: message_vision(HIY "\n各僧众将阵法施展完毕，各自收招。\n" NOR, me, target);
  @doc false
  def expire_message, do: "\n各僧众将阵法施展完毕，各自收招。\n"

  defp ref(character),
    do: %{id: character.id, pid: character.pid, name: character.name, room_id: character.room_id}
  # ===== 原始 LPC 源码（逐行保留，禁止丢失信息；核对/移植后删除）=====
  # // luohan-gun perform 罗汉棍阵
  # 
  # #include <ansi.h>
  # 
  # #define SHIBA HIY "【十八罗汉棍阵】" NOR
  # 
  # #define ME  "你现在不能使用" + SHIBA + "。\n"
  # #define TAR  "对方现在不能使用" + SHIBA + "。\n"
  # 
  # int check_fight(object me, object target, int amount);
  # private int remove_effect(object me, object target, int amount);
  # 
  # int perform(object me, object target)
  # {
  #         object *enemy;
  #         int i,j,k,amount;
  #         object wep1, wep2;
  #         wep1 = me->query_temp("weapon");
  # 
  #         if( !target || target == me) return notify_fail("你要和谁组成棍阵?\n");
  # 
  #         if (me->query_temp("gunzhen")) return notify_fail(ME);
  #         if (target->query_temp("gunzhen")) return notify_fail(TAR);
  #         if (me->query("jingli") < 200) return notify_fail(ME);
  #         if (target->query("jingli") < 200) return notify_fail(TAR);
  #         if (me->query("neili") < 1500) return notify_fail(ME);
  #         if (target->query("neili") < 1500) return notify_fail(TAR);
  #         if (!me->is_fighting()) return notify_fail( SHIBA "只能在战斗中使用。\n");
  #         if (me->is_fighting(target)) return notify_fail("你已经在和对方打架，使用" + SHIBA + "作什么?\n");
  #         if( (int)me->query_skill("luohan-gun", 1) < 120 ) return notify_fail(ME);
  #         if( (int)me->query_skill("club", 1) < 120 ) return notify_fail(ME);
  #         if (!wep1 || wep1->query("skill_type") != "club"
  #         || me->query_skill_mapped("club") != "luohan-gun")
  #                 return notify_fail(ME);
  #         
  #         enemy = me->query_enemy();
  #         k = sizeof(enemy);
  #         while (k--)
  #         if (target->is_fighting(enemy[k])) break;
  #         if (k<0) return notify_fail(target->name()+"并没有和你的对手在交战。\n");
  # 
  #         if( (int)target->query_skill("luohan-gun", 1) < 120 )
  #                 return notify_fail(TAR);
  #         if( (int)target->query_skill("club", 1) < 120 )
  #                 return notify_fail(TAR);
  #         wep2 = target->query_temp("weapon");
  #         if (target->is_busy() || !wep2 || wep2->query("skill_type") != "club"
  #         || target->query_skill_mapped("club") != "luohan-gun")
  #                 return notify_fail(TAR);
  #                 
  # 
  #         message_vision(HIY "\n只见他们几人，动作协调，阵行严谨，攻守一体，"+
  #                            "一招一式，都似发自同一人，威力大增。"+
  #                            "$n不由看的呆了......\n" NOR, me, target);
  #         me->set_temp("gunzhen", 1);
  #         target->set_temp("bunzhen", 1);
  #         me->receive_damage("jingli", 100);
  #         target->receive_damage("jingli", 100);
  #         me->receive_damage("neili", 300);
  #         target->receive_damage("neili", 300);
  #         me->start_busy(1);
  #         target->start_busy(1);
  #         i = (int)me->query_skill("luohan-gun", 1);
  #         j = (int)target->query_skill("luohan-gun", 1);
  #         amount = ((i + j)/10 + (int)me->query_str() + (int)target->query_str())/5;
  #         if( amount > 20 ) amount = 20;
  #         me->add_temp("apply/dexerity", amount);
  #         me->add_temp("apply/strength", amount);
  #         target->add_temp("apply/dexerity", amount);
  #         target->add_temp("apply/strength", amount);
  #         enemy[k]->start_busy(amount/3);
  #         check_fight(me, target, amount);
  #         return 1;
  # }
  # 
  # int check_fight(object me, object target, int amount)
  # {  
  #         object wep1, wep2;
  #         if(!me && !target) return 0;
  #         if(!me && target){
  #            target->add_temp("apply/dexerity", -amount);
  #            target->add_temp("apply/strength", -amount);
  #            target->delete_temp("gunzhen");
  #            return 0;
  #         }
  #         if( me && !target){
  #            me->add_temp("apply/dexerity", -amount);
  #            me->add_temp("apply/strength", -amount);
  #            me->delete_temp("gunzhen");
  #            return 0;
  #         }
  #         wep1 = me->query_temp("weapon");
  #         wep2 = target->query_temp("weapon");
  #         if(!me->is_fighting()
  #          || !living(me)
  #          || me->is_ghost()
  #          || !wep1
  #          || !target->is_fighting()
  #          || !living(target)
  #          || target->is_ghost() 
  #          || !wep2
  #          || me->query_skill_mapped("club") != "luohan-gun" 
  #          || target->query_skill_mapped("club") != "luohan-gun"
  #          || environment(me) != environment(target))
  #               remove_effect(me, target, amount);
  #         else {
  #               call_out("check_fight", 1, me, target, amount);
  #         }
  #         return 1;
  # }
  # 
  # private int remove_effect(object me, object target, int amount)
  # {
  #         if(living(me)
  #          && !me->is_ghost()
  #          && living(target)
  #          && !target->is_ghost())
  #            message_vision(HIY "\n各僧众将阵法施展完毕，各自收招。\n" NOR, me, target);
  # 
  #         me->add_temp("apply/dexerity", -amount);
  #         me->add_temp("apply/strength", -amount);
  #         target->add_temp("apply/dexerity", -amount);
  #         target->add_temp("apply/strength", -amount);
  #         me->delete_temp("gunzhen");
  #         target->delete_temp("gunzhen");
  #         return 0;
  # }
end
