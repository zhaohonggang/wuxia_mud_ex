defmodule Kantele.Combat.Skills.TaijiQuan do
  @moduledoc """
  太极拳（对应 ExKantele.Combat.Skills.TaijiQuan）

  招式表为纯数据（@actions），选择公式在 `Kantele.Combat.Skill`
  """
  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @actions [
    %{
      "action" => "$N使一招「揽雀尾」，双手划了个半圈，按向$n的$l",
      "force" => 20,
      "dodge" => 50,
      "parry" => 38,
      "skill_name" => "揽雀尾",
      "lvl" => 0,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一招「单鞭」，右手收置肋下，左手向外挥出，劈向$n的$l",
      "force" => 25,
      "dodge" => 48,
      "parry" => 57,
      "skill_name" => "单鞭",
      "lvl" => 5,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手回收，右手由钩变掌，由右向左，使一招「提手上式」，向$n的$l打去",
      "force" => 25,
      "dodge" => 46,
      "parry" => 49,
      "skill_name" => "提手上式",
      "lvl" => 10,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手划弧，右手向上，左手向下，使一招「白鹤亮翅」，分击$n的面门和$l",
      "force" => 25,
      "dodge" => 44,
      "parry" => 71,
      "skill_name" => "白鹤亮翅",
      "lvl" => 15,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手由胸前向下，身体微转，划了一个大圈，使一招「搂膝拗步」，击向$n的$l",
      "force" => 25,
      "dodge" => 44,
      "parry" => 58,
      "skill_name" => "搂膝拗步",
      "lvl" => 20,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手由下上挑，右手内合，使一招「手挥琵琶」，向$n的$l打去",
      "force" => 30,
      "dodge" => 48,
      "parry" => 62,
      "skill_name" => "手挥琵琶",
      "lvl" => 25,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手变掌横于胸前，右拳由肘下穿出，一招「肘底看锤」，锤向$n的$l",
      "force" => 30,
      "dodge" => 54,
      "parry" => 71,
      "skill_name" => "肘底看锤",
      "lvl" => 30,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左脚前踏半步，右手使一招「海底针」，指由下向$n的$l戳去",
      "force" => 30,
      "dodge" => 76,
      "parry" => 65,
      "skill_name" => "海底针",
      "lvl" => 35,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N招「闪通臂」，左脚一个弓箭步，右手上举向外撇出，向$n的$l挥去",
      "force" => 30,
      "dodge" => 79,
      "parry" => 76,
      "skill_name" => "闪通臂",
      "lvl" => 40,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N两手由相对，转而向左上右下分别挥出，右手使一招「斜飞式」，挥向$n的$l",
      "force" => 35,
      "dodge" => 82,
      "parry" => 52,
      "skill_name" => "斜飞式",
      "lvl" => 45,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手虚按，右手使一招「白蛇吐信」，向$n的$l插去",
      "force" => 35,
      "dodge" => 70,
      "parry" => 82,
      "skill_name" => "白蛇吐信",
      "lvl" => 50,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手握拳，向前向后划弧，一招「双峰贯耳」打向$n的$l",
      "force" => 35,
      "dodge" => 88,
      "parry" => 51,
      "skill_name" => "双风贯耳",
      "lvl" => 55,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手虚划，右手一记「指裆锤」击向$n的裆部",
      "force" => 40,
      "dodge" => 86,
      "parry" => 71,
      "skill_name" => "指裆锤",
      "lvl" => 60,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N施出「伏虎式」，右手击向$n的$l，左手攻向$n的裆部",
      "force" => 40,
      "dodge" => 84,
      "parry" => 81,
      "skill_name" => "伏虎式",
      "lvl" => 65,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N由臂带手，在面前缓缓划过，使一招「云手」，挥向$n的$l",
      "force" => 45,
      "dodge" => 82,
      "parry" => 87,
      "skill_name" => "云手",
      "lvl" => 70,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左腿收起，右手使一招「金鸡独立」，向$n的$l击去",
      "force" => 50,
      "dodge" => 90,
      "parry" => 51,
      "skill_name" => "金鸡独立",
      "lvl" => 75,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N右手由钩变掌，双手掌心向上，右掌向前推出一招「高探马」",
      "force" => 55,
      "dodge" => 68,
      "parry" => 90,
      "skill_name" => "高探马",
      "lvl" => 80,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N右手使一式招「玉女穿梭」，扑身向$n的$l插去",
      "force" => 60,
      "dodge" => 76,
      "parry" => 92,
      "skill_name" => "玉女穿梭",
      "lvl" => 85,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N右手经腹前经左肋向前撇出，使一招「反身撇锤」，向$n的$l锤去",
      "force" => 65,
      "dodge" => 84,
      "parry" => 95,
      "skill_name" => "反身撇锤",
      "lvl" => 90,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手虚按，右腿使一招「转身蹬腿」，向$n的$l踢去",
      "force" => 70,
      "dodge" => 42,
      "parry" => 99,
      "skill_name" => "反身蹬腿",
      "lvl" => 100,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手向上划弧拦出，右手使一招「搬拦锤」，向$n的$l锤去",
      "force" => 75,
      "dodge" => 81,
      "parry" => 102,
      "skill_name" => "白蛇吐信",
      "lvl" => 120,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N使一招「栽锤」，左手搂左膝，右手向下锤向$n的$l",
      "force" => 80,
      "dodge" => 88,
      "parry" => 115,
      "skill_name" => "栽锤",
      "lvl" => 140,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手先抱成球状，忽地分开右手上左手下，一招「野马分鬃」，向$n的$l和面门打去",
      "force" => 85,
      "dodge" => 86,
      "parry" => 119,
      "skill_name" => "野马分鬃",
      "lvl" => 160,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左手由胸前向下，右臂微曲，使一招「抱虎归山」，向$n的$l推去",
      "force" => 90,
      "dodge" => 94,
      "parry" => 115,
      "skill_name" => "抱虎归山",
      "lvl" => 180,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手经下腹划弧交于胸前，成十字状，一式「十字手」，向$n的$l打去",
      "force" => 95,
      "dodge" => 102,
      "parry" => 122,
      "skill_name" => "十字手",
      "lvl" => 200,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N左脚踏一个虚步，双手交叉成十字拳，一招「进步七星」，向$n的$l锤去",
      "force" => 100,
      "dodge" => 110,
      "parry" => 133,
      "skill_name" => "进步七星",
      "lvl" => 210,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N身体向后腾出，左手略直，右臂微曲，使一招「倒撵猴」，向$n的$l和面门打去",
      "force" => 115,
      "dodge" => 132,
      "parry" => 121,
      "skill_name" => "倒撵猴",
      "lvl" => 220,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手伸开，以腰为轴，整个上身划出一个大圆弧，一招「转身摆莲」，将$n浑身上下都笼罩在重重掌影之中",
      "force" => 120,
      "dodge" => 154,
      "parry" => 145,
      "skill_name" => "转身摆莲",
      "lvl" => 230,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手握拳，右手缓缓收至耳际，左手缓缓向前推出，拳意如箭，一招「弯弓射虎」，直奔$n心窝而去",
      "force" => 115,
      "dodge" => 166,
      "parry" => 175,
      "skill_name" => "弯弓射虎",
      "lvl" => 240,
      "damage_type" => "瘀伤"
    },
    %{
      "action" => "$N双手在胸前翻掌，由腹部向前向上推出，一招「如封似闭」，一股劲风直逼$n",
      "force" => 120,
      "dodge" => 178,
      "parry" => 185,
      "skill_name" => "如封似闭",
      "lvl" => 250,
      "damage_type" => "瘀伤"
    }
  ]

  # 极招（等级 350，动态 force/attack）
  @ultimate %{
    "action" => "$N凝神静气，使出极招 太极拳之极意 ",
    "lvl" => 350,
    "skill_name" => "极意",
    "damage_type" => "瘀伤"
  }

  @impl true
  def id(), do: "taiji-quan"

  @impl true
  def valid_enable(usage), do: usage == "unarmed" or usage == "parry"

  @impl true
  def valid_learn(stats) do
    cond do
      stats.int < 26 ->
        {:error, "你先天悟性太差，难以领会太极拳的要诣。\n"}

      Stats.skill(stats, "force") < 180 ->
        {:error, "你的内功火候不够，无法学太极拳。\n"}

      Stats.skill(stats, "unarmed") < 100 ->
        {:error, "你的基本拳脚火候不够，无法学太极拳。\n"}

      Stats.skill(stats, "unarmed") < Stats.skill(stats, id()) ->
        {:error, "你的基本拳脚水平有限，无法领会更高深的太极拳。\n"}

      true ->
        :ok
    end
  end

  @impl true
  def practice_cost(), do: %{qi: 35, neili: 59}

  @impl true
  def query_action(level, rng \\ &:rand.uniform/1) do
    if level >= 350, do: @ultimate, else: Kantele.Combat.Skill.pick_action(@actions, level, rng)
  end

  @doc "可组合的技能"
  def valid_combine(combo), do: combo in ["wudang-zhang", "paiyun-shou"]

  @doc "借力打力（valid_damage）：太极拳核心反制"
  def valid_damage(attacker, victim, damage, _action) do
    taiji_lvl = Map.get(victim.skills, "taiji-quan", 0)
    victim_weapon = victim.weapon_name

    if taiji_lvl >= 100 and victim_weapon == nil do
      mp = Map.get(attacker.skills, "count", 0)
      ap = Map.get(attacker.skills, "force", 0) + mp
      dp = div(Map.get(victim.skills, "parry", 0), 2) + taiji_lvl

      if div(ap, 2) + :rand.uniform(ap) < dp do
        msg = case :rand.uniform(3) do
          1 -> "$n面含微笑，双手齐出，划出了一个圆圈，竟然让$N的攻击全不着力。\n"
          2 -> "$n左右格档，使出四两拨千斤的手法，化解$N的攻势于无形。\n"
          _ -> "$n慢慢出拳，动作虽然缓慢，却让$N感到浑身粘滞，甚不舒畅。\n"
        end
        {0, msg}
      else
        {damage, nil}
      end
    else
      {damage, nil}
    end
  end

  @impl true
  def query_effect_parry(%{skills: skills} = stats) when map_size(skills) > 0 do
    level = Map.get(stats.skills, "taiji-quan", 0)

    cond do
      level < 80 -> 0
      level < 200 -> 50
      level < 280 -> 80
      level < 350 -> 100
      true -> 120
    end
  end

  def query_effect_parry(_), do: 0

  @doc "蓄力连击（hit_ob）"
  def hit_ob(_attacker, _victim, _action), do: :unchanged

  @doc "练习 60 级自动领悟绝招「极意」"
  def perform_unlock_level(), do: 350

  @impl true
  def perform_list() do
    %{"extreme" => Kantele.Combat.Skills.TaijiQuan.Extreme}
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

defmodule Kantele.Combat.Skills.TaijiQuan.Extreme do
  @moduledoc """
  绝招「极意」（对应 TaijiQuan.ultimate）

  动态计算 force/attack/dodge/parry/damage。
  """
  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @key "taiji-extreme"
  @perform_id "taiji-quan/extreme"

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
    if Stats.perform_known?(stats, "taiji-quan/extreme") do
      :ok
    else
      {:error, "你还没有领悟这一招，谈何施展？\n"}
    end
  end

  defp check_skill_level(stats) do
    skill = Stats.skill(stats, "taiji-quan")

    if skill < 350 do
      {:error, "你的太极拳不够娴熟，使不出「极意」。\n"}
    else
      {:ok, skill}
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 500 do
      {:error, "你的内力不够，难以施展这一招。\n"}
    else
      :ok
    end
  end

  defp check_not_active(combat) do
    if Combat.buff_active?(combat, @key) do
      {:error, "你已经竭尽全力在施展「极意」了。\n"}
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

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 200}
    character = with_vitals_and_combat(character, vitals, combat)

    duration = (div(skill, 6) + 20) * 1000

    conn =
      Broadcast.publish(
        conn,
        "$N气沉丹田，双掌缓缓推出，气势磅礴，如太极图缓缓旋转，一股无形劲气向四周扩散！\n",
        n1: character.name
      )

    Process.send_after(
      self(),
      %Kalevala.Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: @key, applies: buff.applies, message: "你的「极意」劲气渐消，心神渐归平静。\n"}
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
