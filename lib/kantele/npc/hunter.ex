defmodule Kantele.NPC.Hunter do
  @moduledoc """
  衡阳猎人 NPC 问询处理器（对应 LPC `d/hengyang/npc/hunter.c`）。

  ## LPC 原始链路

  1. `accept_object(me, ob)`：玩家把「捕兽夹」(`bushou jia`) 给猎人 →
     `me->set_temp("marks/hunter", 1)`，猎人说「这个我正用得着……可以教你
     一些捕猎技巧和驭兽之术」。
  2. `set("inquiry", ([ "hunting" : (: teach_hunting:), "捕猎" : ... ]))`：
     `ask hunter about hunting` 触发 `teach_hunting()`。
  3. `teach_hunting()` 四道前置门 + 结算：

  ```c
  if (!me->query_temp("marks/hunter")) return "你我素无往来，何出此言？\\n";
  if (me->is_busy() || me->is_fighting()) { write("你现在正忙着。\\n"); return 1; }
  if (jing < 20) { write("你的精神无法集中。\\n"); return 1; }
  if ((potential - learned_points) < 1) { write("你的潜能不够，无法继续学习。\\n"); return 1; }
  add = me->query_int() + random(me->query_int() / 2);
  me->add("learned_points", 1);
  me->improve_skill("hunting", add);
  me->add("jing", -(5 + random(6)));
  ```

  4. `recognize_apprentice(me, skill)`：只传授 `training` / `hunting`，同样要求
     marks/hunter。本端口把这道门落在 `Kantele.Combat.Skills.Hunting.valid_learn/2`，
     `learn hunting 猎人` 因此也需先给捕兽夹。

  ## 标记存储

  LPC 用 `query_temp("marks/hunter")`（会话级）；端口同时写
  `PlayerMeta.marks["hunter"]`（持久化，`Records` 落盘）与
  `PlayerMeta.temp[:hunter]`（会话级），检查时二者任一为真即可，兼容
  重登与旧存档。
  """

  @behaviour Kantele.NPC.AskHandler

  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Stats

  @teach_keywords ["hunting", "捕猎", "狩猎", "打猎"]

  @impl true
  def ask_specs do
    Map.new(@teach_keywords, fn keyword ->
      {keyword,
       %{
         check: fn asker, npc -> check(asker, npc, keyword) end,
         execute: fn asker, npc -> execute(asker, npc, keyword) end,
         effects: []
       }}
    end)
  end

  @impl true
  def effects(_asker, _npc, _keyword), do: []

  @impl true
  def check(asker, _npc, keyword) do
    cond do
      keyword not in @teach_keywords ->
        {:error, "猎人摇了摇头，似乎没听明白你的意思。\n"}

      not hunter_mark?(asker) ->
        {:error, "你我素无往来，何出此言？\n"}

      busy_or_fighting?(asker) ->
        {:error, "你现在正忙着。\n"}

      jing_of(asker) < 20 ->
        {:error, "你的精神无法集中。\n"}

      Stats.available_potential(stats_of(asker)) < 1 ->
        {:error, "你的潜能不够，无法继续学习。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def execute(asker, _npc, keyword) do
    cond do
      keyword not in @teach_keywords ->
        {:error, "猎人摇了摇头，似乎没听明白你的意思。\n"}

      not hunter_mark?(asker) ->
        {:error, "你我素无往来，何出此言？\n"}

      true ->
        teach(asker)
    end
  end

  defp teach(asker) do
    stats = stats_of(asker)
    int = Stats.query_int(stats)
    half = div(int, 2)
    bonus = if half > 0, do: :rand.uniform(half) - 1, else: 0
    add = int + bonus

    # 对齐 LPC：me->improve_skill("hunting", add) 的 add 是「点数」而非等级，
    # 显示等级 = floor(sqrt(累计点数))，累计点数以 等级² 估算。故单层教学收益约为
    # floor(sqrt(原等级² + add)) - 原等级（递减收益，与 LPC 一致）。
    learned_skill = Stats.skill(stats, "hunting")
    new_level = learned_skill * learned_skill + add |> :math.sqrt() |> floor()
    gain = new_level - learned_skill

    stats =
      stats
      |> Stats.spend_potential(1)
      |> Stats.set_skill("hunting", new_level)

    vitals = vitals_of(asker)
    jing_cost = 5 + :rand.uniform(6) - 1
    vitals = Map.put(vitals, :jing, max(Map.get(vitals, :jing, 0) - jing_cost, 0))

    meta =
      asker.meta
      |> Map.put(:stats, stats)
      |> Map.put(:vitals, vitals)

    character = %{asker | meta: meta}

    msg =
      "猎人给你讲解了有关捕猎的一些技巧。\n" <>
        "你听了猎人的指导，似乎有所心得。（狩猎技巧提升至 #{new_level} 级，+#{gain}）\n"

    {:ok, msg, character}
  end

  @doc "是否已给过猎人捕兽夹（兼容持久 marks 与会话 temp）"
  def hunter_mark?(%{meta: %PlayerMeta{}} = asker) do
    PlayerMeta.mark(asker.meta, "hunter") not in [nil, 0, false] or
      PlayerMeta.mark(asker.meta, :hunter) not in [nil, 0, false] or
      PlayerMeta.get_temp(asker.meta, :hunter) not in [nil, 0, false] or
      PlayerMeta.get_temp(asker.meta, "marks/hunter") not in [nil, 0, false]
  end

  def hunter_mark?(%{meta: meta}) when is_map(meta) do
    marks = Map.get(meta, :marks, %{}) || %{}
    temp = Map.get(meta, :temp, %{}) || %{}

    Map.get(marks, "hunter") not in [nil, 0, false] or
      Map.get(temp, "marks/hunter") not in [nil, 0, false]
  end

  def hunter_mark?(_), do: false

  defp busy_or_fighting?(%{meta: %{combat: %Combat{} = combat}}) do
    Combat.busy?(combat) or Combat.fighting?(combat)
  end

  defp busy_or_fighting?(%{meta: %{combat: combat}}) when is_map(combat) do
    (Map.get(combat, :busy, 0) || 0) > 0 or
      (Map.get(combat, :enemies, []) || []) != []
  end

  defp busy_or_fighting?(_), do: false

  defp jing_of(%{meta: %{vitals: vitals}}) when is_map(vitals),
    do: Map.get(vitals, :jing, 0) || 0

  defp jing_of(_), do: 0

  defp stats_of(%{meta: %{stats: stats}}), do: stats
  defp stats_of(_), do: Stats.new()

  defp vitals_of(%{meta: %{vitals: vitals}}), do: vitals
  defp vitals_of(_), do: %{}
end
