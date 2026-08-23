defmodule Kantele.Combat.Skills.LiuxinJian do
  @moduledoc """
  柳心剑法（对照 minimal_world/skill/liuxin-jian.c）

  招式表为纯数据（@actions），选择公式在 `Kantele.Combat.Skill`
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N长剑斜挑，一式「杨柳依依」，剑尖轻颤，点向$n的$l",
      "force" => 80,
      "attack" => 25,
      "dodge" => 10,
      "parry" => 15,
      "damage" => 8,
      "lvl" => 0,
      "damage_type" => "刺伤",
      "skill_name" => "杨柳依依"
    },
    %{
      "action" => "$N侧身进步，一式「拂柳分花」，剑光如带，卷向$n的$l",
      "force" => 110,
      "attack" => 35,
      "dodge" => 15,
      "parry" => 20,
      "damage" => 12,
      "lvl" => 20,
      "damage_type" => "割伤",
      "skill_name" => "拂柳分花"
    },
    %{
      "action" => "$N手腕一抖，一式「飞絮无边」，漫天剑影罩向$n全身",
      "force" => 140,
      "attack" => 45,
      "dodge" => 20,
      "parry" => 25,
      "damage" => 18,
      "lvl" => 40,
      "damage_type" => "刺伤",
      "skill_name" => "飞絮无边"
    },
    %{
      "action" => "$N剑随身转，一式「柳浪闻莺」，层层剑浪涌向$n的$l",
      "force" => 170,
      "attack" => 55,
      "dodge" => 25,
      "parry" => 30,
      "damage" => 24,
      "lvl" => 60,
      "damage_type" => "割伤",
      "skill_name" => "柳浪闻莺"
    },
    %{
      "action" => "$N凝神静气，一式「万缕垂青」，剑势绵密如雨，无隙可乘",
      "force" => 200,
      "attack" => 65,
      "dodge" => 30,
      "parry" => 35,
      "damage" => 30,
      "lvl" => 90,
      "damage_type" => "刺伤",
      "skill_name" => "万缕垂青"
    }
  ]

  @impl true
  def id(), do: "liuxin-jian"

  @impl true
  def valid_enable(usage), do: usage == "sword" or usage == "parry"

  @impl true
  def valid_learn(stats) do
    cond do
      Stats.skill(stats, "force") < 20 ->
        {:error, "你的内功火候不够，无法练柳心剑法。\n"}

      Stats.skill(stats, "sword") <= Stats.skill(stats, id()) ->
        {:error, "你的基本剑法火候有限，无法领会更高深的柳心剑法。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 55, neili: 38}

  @doc "按等级加权随机选一式（招式表 + NewRandom）"
  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc """
  练到六十层自动领悟绝招「柳浪闻莺」（对应王师父 ask_liu 的授艺门槛）
  """
  def perform_unlock_level(), do: 60

  @impl true
  def perform_list() do
    %{"liu" => Kantele.Combat.Skills.LiuxinJian.Liu}
  end

  @doc "招式名 -> 招式数据（供 score/look 展示）"
  def actions(), do: @actions

  @doc "当前等级对应的最高招式名（query_skill_name）"
  def query_skill_name(level) do
    @actions
    |> Enum.reverse()
    |> Enum.find(fn action -> level >= Map.get(action, "lvl", 0) end)
    |> case do
      nil -> nil
      action -> action["skill_name"]
    end
  end
end

defmodule Kantele.Combat.Skills.LiuxinJian.Liu do
  @moduledoc """
  绝招「柳浪闻莺」（对照 minimal_world/skill/liuxin-jian/liu.c）

  消耗 80 内力，临时提升 dodge(skill/4) 与 attack(skill/5)，
  持续 (skill/6 + 10) 秒后由 `combat/buff-expire` 自动消退。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @key "liuxin-liu"
  @perform_id "liuxin-jian/liu"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats

    with :ok <- check_perform_known(stats),
         {:ok, skill} <- check_skill_level(stats),
         :ok <- check_neili(character),
         :ok <- check_not_active(character.meta.combat) do
      apply_buff(conn, skill)
    else
      {:error, message} ->
        conn
        |> render_message(message)
        |> assign(:prompt, false)
    end
  end

  defp check_perform_known(stats) do
    if Stats.perform_known?(stats, @perform_id) do
      :ok
    else
      {:error, "你还没有学过这一招，谈何施展？\n"}
    end
  end

  defp check_skill_level(stats) do
    skill = Stats.skill(stats, "liuxin-jian")

    if skill < 60 do
      {:error, "你的柳心剑法不够娴熟，使不出「柳浪闻莺」。\n"}
    else
      {:ok, skill}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的内力不够，难以施展这一招。\n"}
    else
      :ok
    end
  end

  defp check_not_active(combat) do
    if Combat.buff_active?(combat, @key) do
      {:error, "你已经竭尽全力在施展「柳浪闻莺」了。\n"}
    else
      :ok
    end
  end

  defp apply_buff(conn, skill) do
    character = conn.character
    dodge_bonus = div(skill, 4)
    attack_bonus = div(skill, 5)

    buff = %Buff{key: @key, applies: %{dodge: -dodge_bonus, attack: -attack_bonus}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(%{dodge: dodge_bonus, attack: attack_bonus})
      |> Combat.add_buff(buff)

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 80}
    character = with_vitals_and_combat(character, vitals, combat)

    duration = (div(skill, 6) + 10) * 1000

    conn = Broadcast.publish(
      conn,
      "$N长吟一声，剑势陡然一变，剑尖颤出万千朵浪花，如春风拂过万条柳枝，绵绵不绝地涌向对手！\n",
      n1: character.name
    )

    # 定时自投递（foreman 会把 delay_event 转发给房间路由，故此处直接 send）
    Process.send_after(
      self(),
      %Kalevala.Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: @key, applies: buff.applies, message: "你剑势渐缓，「柳浪闻莺」的余韵散去。\n"}
      },
      duration
    )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp with_vitals_and_combat(character, vitals, combat) do
    meta =
      character.meta
      |> Map.put(:vitals, vitals)
      |> Map.put(:combat, combat)

    %{character | meta: meta}
  end

  defp render_message(conn, message) do
    render(conn, CommandView, "text", %{text: message})
  end

  def publish_error(conn, _error), do: conn
end
