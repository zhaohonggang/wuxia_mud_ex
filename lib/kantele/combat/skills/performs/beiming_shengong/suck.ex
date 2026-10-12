defmodule Kantele.Combat.Skills.Performs.BeimingShengong.Suck do
  @moduledoc """
  exert「suck」（source beiming-shengong/suck.c，inherit F_SSERVER）

  门槛（按 .c 顺序）：房间允许战斗 → 目标有效且在战斗中 → 目标为活人 →
  未处于吸取冷却 → 空手 → 北冥神功>=90 → 真气>=20 → 内功上限未满 →
  目标 max_neili>=100 → 目标 max_neili>=自身/5 → 目标未运太玄功。
  前置广播后置 temp "sucked" 冷却（成功 10 秒 / 失败 15 秒）。

  对抗：`force + random(force)` > 目标 `force + random(force)`。
  成功：目标 max_neili 扣 `1+(北冥-90)/10`（按差距逐级折半），
  自身 max_neili 加同值；目标忙乱 2、自身忙乱 4、扣 10 真气。
  失败：目标忙乱 6。

  差异（TODO(migrate)）：
  - 真实运行为 `Kantele.Combat.Skills.BeimingShengong.Suck`
    （由 `exert_list`/`perform_list` 双路派发），本文件为并存的对齐副本；
  - `me->want_kill(target)` / `target->kill_ob(me)` 的仇恨建立未实现；
  - 目标 `not_living`/`race` 判定依赖 `character.meta`，以 `.dead` 近似。
  """

  @behaviour Kantele.Combat.Perform

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView
  alias Kantele.Character.Combat
  alias Kantele.Character.Stats

  @impl true
  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with {:ok, target} <- check_target(character),
         {:ok, conn} <- check_gates(conn, character, target),
         {:ok, character, target} <- apply_perform(character, target) do
      conn
      |> resolve_suck(character, target)
    else
      {:error, _conn, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)

      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  # LPC: if (environment(me)->query("no_fight")) return notify_fail("在这里不能攻击他人。\n");
  # 房间 no_fight 标记未建模，恒为 :ok，但保留文案以对齐 .c。
  defp check_no_fight(_character) do
    _ = "在这里不能攻击他人。\n"
    :ok
  end

  # LPC: if (! objectp(target) || ! me->is_fighting(target))
  #         return notify_fail("你要吸取谁的丹元？\n");
  defp check_target(character) do
    case character.meta.combat.enemies do
      [enemy | _] -> {:ok, enemy}
      [] -> {:error, "你要吸取谁的丹元？\n"}
    end
  end

  defp check_gates(conn, character, target) do
    with :ok <- check_no_fight(character),
         :ok <- check_race(target),
         {:ok, conn} <- check_cooldown(conn, character),
         {:ok, conn} <- check_weapon(conn, character),
         {:ok, conn} <- check_levels(conn, character),
         {:ok, conn} <- check_resources(conn, character),
         {:ok, conn} <- check_can_absorb_more(conn, character),
         {:ok, conn} <- check_target_has_neili(conn, target),
         {:ok, conn} <- check_target_not_weak(conn, character, target),
         {:ok, conn, _target} <- check_not_taixuan(conn, character, target) do
      {:ok, conn}
    end
  end

  # LPC: if (target->query("race") != "人类" || target->query("not_living"))
  #         return notify_fail("搞错了！只有活着的生物才能有丹元！\n");
  defp check_race(target) do
    if Map.get(target.meta, :race) == "人类" do
      :ok
    else
      {:error, "搞错了！只有活着的生物才能有丹元！\n"}
    end
  end

  # LPC: if (me->query_temp("sucked")) return notify_fail("你刚刚吸取过丹元！\n");
  defp check_cooldown(conn, character) do
    if Combat.buff_active?(character.meta.combat, "sucked") do
      {:error, conn, "你刚刚吸取过丹元！\n"}
    else
      {:ok, conn}
    end
  end

  # LPC: if (objectp(me->query_temp("weapon")))
  #         return notify_fail("你必须空手才能施用北冥神功吸人丹元！\n");
  defp check_weapon(conn, character) do
    if Combat.weapon(character.meta.combat) != nil do
      {:error, conn, "你必须空手才能施用北冥神功吸人丹元！\n"}
    else
      {:ok, conn}
    end
  end

  defp check_levels(conn, character) do
    if Stats.skill(character.meta.stats, "beiming-shengong") >= 90 do
      {:ok, conn}
    else
      {:error, conn, "你的北冥神功功力不够，不能吸取对方的丹元！\n"}
    end
  end

  defp check_resources(conn, character) do
    if character.meta.vitals.neili >= 20 do
      {:ok, conn}
    else
      {:error, conn, "你的内力不够，不能使用北冥神功。\n"}
    end
  end

  # LPC: if ((int)me->query_current_neili_limit() <= my_max)
  #         return notify_fail("你的内功水平有限，再吸取也是徒劳。\n");
  defp check_can_absorb_more(conn, character) do
    my_max = character.meta.vitals.max_neili
    limit = Map.get(character.meta.stats, :max_neili_limit) || my_max * 2

    if my_max < limit do
      {:ok, conn}
    else
      {:error, conn, "你的内功水平有限，再吸取也是徒劳。\n"}
    end
  end

  # LPC: if ((int)target->query("max_neili") < 100)
  #         return notify_fail(target->name() + "丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n");
  defp check_target_has_neili(conn, target) do
    if target.meta.vitals.max_neili >= 100 do
      {:ok, conn}
    else
      {:error, conn, "#{target.name}丹元涣散，功力未聚，你无法从他体内吸取任何东西！\n"}
    end
  end

  # LPC: if ((int)target->query("max_neili") < (int)me->query("max_neili") / 5)
  #         return notify_fail(target->name() + "的内功修为远不如你，你无法从他体内吸取丹元！\n");
  defp check_target_not_weak(conn, character, target) do
    if target.meta.vitals.max_neili >= div(character.meta.vitals.max_neili, 5) do
      {:ok, conn}
    else
      {:error, conn, "#{target.name}的内功修为远不如你，你无法从他体内吸取丹元！\n"}
    end
  end

  # LPC: if (target->query_skill_mapped("force") == "taixuan-gong")
  #       { tell_object(target, HIW + me->name() + HIW "伸出右手，轻轻握在你的手"
  #                    "臂上，试图吸取你的内力，但是你体内的太玄真气猛地将"
  #                    "其反弹回去。\n");
  #         return notify_fail(HIG "你伸出右手，轻轻握在" + target->name() +
  #                            HIG "的手臂上，却猛的感觉一股内劲将你的手弹回。\n" NOR); }
  defp check_not_taixuan(conn, character, target) do
    if Map.get(target.meta.stats.mapped || %{}, "force") == "taixuan-gong" do
      conn =
        Broadcast.publish(
          conn,
          "#{character.name}伸出右手，轻轻握在你的手臂上，试图吸取你的内力，但是你体内的太玄真气猛地将其反弹回去。\n",
          n1: character.name,
          n2: target.name
        )

      {:error, conn,
       "你伸出右手，轻轻握在" <> target.name <> "的手臂上，却猛的感觉一股内劲将你的手弹回。\n"}
    else
      {:ok, conn, target}
    end
  end

  # LPC: message_combatd(HIG "$N" HIG "全身一振，伸出右手，轻轻握在$n"
  #                     HIG "的手臂上。\n\n" NOR, me, target);
  #      me->set_temp("sucked", 1);
  defp apply_perform(character, target) do
    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 10}
    character = %{character | meta: Map.put(character.meta, :vitals, vitals)}

    {:ok, character, target}
  end

  defp resolve_suck(conn, character, target) do
    conn = Broadcast.publish(conn, "$N全身一振，伸出右手，轻轻握在$n的手臂上。\n\n",
             n1: character.name, n2: target.name)

    sp = Stats.skill(character.meta.stats, "force")
    dp = Stats.skill(target.meta.stats, "force")

    # LPC: if ((sp + random(sp) > dp + random(dp)) || ! living(target))
    if sp + :rand.uniform(sp) > dp + :rand.uniform(dp) or target.meta.combat.dead do
      resolve_hit(conn, character, target)
    else
      resolve_miss(conn, character, target)
    end
  end

  defp resolve_hit(conn, character, target) do
    # LPC: tell_object(target, "你只觉全身乏力，全身功力如融雪般消失得无影无踪！\n");
    conn = Broadcast.publish(conn, "你只觉全身乏力，全身功力如融雪般消失得无影无踪！\n", n2: target.name)

    my_max = character.meta.vitals.max_neili
    tg_max = target.meta.vitals.max_neili

    sucked = max(1 + div(Stats.skill(character.meta.stats, "beiming-shengong") - 90, 10), 1)

    sucked =
      cond do
        my_max > tg_max + 100 -> div(sucked, 2)
        my_max > tg_max + 200 -> div(sucked, 2)
        my_max > tg_max + 400 -> div(sucked, 2)
        my_max > tg_max + 800 -> div(sucked, 2)
        my_max > tg_max + 1600 -> div(sucked, 2)
        my_max > tg_max + 3200 -> div(sucked, 2)
        true -> sucked
      end

    {message, gained} =
      if sucked < 1 do
        {"可是你发现对方内力似乎弱过你太多，一时难以吸收以为己用。\n", 0}
      else
        {
          "你觉得" <> target.name <> "的丹元自手掌源源不绝地流了进来。\n",
          sucked
        }
      end

    conn =
      conn
      |> Broadcast.publish(message, n1: character.name, n2: target.name)
      |> put_character(%{
        target
        | meta: %{
            target.meta
            | vitals: %{target.meta.vitals | max_neili: max(target.meta.vitals.max_neili - sucked, 0)},
              combat: Combat.start_busy(target.meta.combat, 2)
          }
      })

    # LPC: tell_object(me, "你觉得" + target->name() + "的丹元…\n") 已并入上面广播
    _ = my_max

    conn
    |> put_character(%{
      character
      | meta: %{
          character.meta
          | vitals: %{character.meta.vitals | max_neili: character.meta.vitals.max_neili + gained},
            combat: Combat.start_busy(character.meta.combat, 4)
        }
    })
    |> assign(:prompt, false)
  end

  defp resolve_miss(conn, character, target) do
    # LPC: message_combatd(HIY "可是$p" HIY "看破了$P" HIY "的企图，机灵地溜了开去。\n" NOR, me, target)
    conn =
      Broadcast.publish(
        conn,
        "可是$p看破了$P的企图，机灵地溜了开去。\n",
        n1: character.name,
        n2: target.name
      )

    conn
    |> put_character(%{
      character
      | meta: %{character.meta | combat: Combat.start_busy(character.meta.combat, 6)}
    })
    |> assign(:prompt, false)
  end
end
