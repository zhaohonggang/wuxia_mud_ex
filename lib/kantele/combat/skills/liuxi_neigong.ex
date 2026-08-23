defmodule Kantele.Combat.Skills.LiuxiNeigong do
  @moduledoc """
  柳溪内功（对照 minimal_world/skill/liuxi-neigong.c）
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "liuxi-neigong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") <= Stats.skill(stats, id()) do
      {:error, "你的基本内功火候不足，无法领会更高深的柳溪内功。\n"}
    else
      :ok
    end
  end

  @doc "柳溪内功只能用学(learn)的来增加熟练度（practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @doc "内功无招式表"
  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"powerup" => Kantele.Combat.Skills.LiuxiNeigong.Powerup}
  end
end

defmodule Kantele.Combat.Skills.LiuxiNeigong.Powerup do
  @moduledoc """
  运功「powerup」（对照 minimal_world/skill/liuxi-neigong/powerup.c）

  消耗 100 内力，临时提升 attack/defense 各 force/3，持续 force 秒；
  战斗中运功会 busy 1..3 轮。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.Combat
  alias Kantele.Character.Combat.Buff
  alias Kantele.Character.CommandView
  alias Kantele.Character.Stats

  @key "powerup"

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character
    stats = character.meta.stats
    skill = force_level(stats)

    with :ok <- check_neili(character),
         :ok <- check_not_active(character.meta.combat) do
      apply_buff(conn, character, skill)
    else
      {:error, message} ->
        conn
        |> render(CommandView, "text", %{text: message})
        |> assign(:prompt, false)
    end
  end

  defp force_level(stats) do
    case Stats.mapped(stats, "force") do
      nil -> Stats.skill(stats, "force")
      skill_id -> Stats.skill(stats, skill_id)
    end
  end

  defp check_neili(character) do
    if character.meta.vitals.neili < 100 do
      {:error, "你的真气不够。\n"}
    else
      :ok
    end
  end

  defp check_not_active(combat) do
    if Combat.buff_active?(combat, @key) do
      {:error, "你已经在运功中了。\n"}
    else
      :ok
    end
  end

  defp apply_buff(conn, character, skill) do
    bonus = max(div(skill, 3), 1)
    buff = %Buff{key: @key, applies: %{attack: -bonus, defense: -bonus}}

    combat =
      character.meta.combat
      |> Combat.apply_temp(%{attack: bonus, defense: bonus})
      |> Combat.add_buff(buff)

    combat =
      if Combat.fighting?(combat) do
        %{combat | busy: combat.busy + 1 + :rand.uniform(3) - 1}
      else
        combat
      end

    vitals = %{character.meta.vitals | neili: character.meta.vitals.neili - 100}

    character =
      character
      |> put_meta_of(vitals, combat)

    conn
    conn = Broadcast.publish(
      conn,
      "$N微一凝神，运起柳溪内功，周身衣袂无风自动，隐隐有溪流潺潺之声。\n",
      n1: character.name
    )

    # 定时自投递（同上，绕开房间路由）
    Process.send_after(
      self(),
      %Kalevala.Event{
        from_pid: self(),
        topic: "combat/buff-expire",
        data: %{key: @key, applies: buff.applies, message: "你的柳溪内功运行完毕，将内力收回丹田。\n"}
      },
      skill * 1000
    )

    conn
    |> put_character(character)
    |> assign(:prompt, false)
  end

  defp put_meta_of(character, vitals, combat) do
    meta =
      character.meta
      |> Map.put(:vitals, vitals)
      |> Map.put(:combat, combat)

    %{character | meta: meta}
  end
end
