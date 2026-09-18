defmodule Kantele.Combat.Skills.ZixiaShengong do
  @moduledoc """
  紫霞神功（对照 `kungfu/skill/zixia-shengong.c`）

  内功载体：`valid_enable("force")`；仅可学不可练。
  `valid_force` 接受 混元一气/太极神功/武当心法/少林心法 共存。

  差异（TODO(migrate)）：
  - `ziqi`（紫气东来）需持剑、qi>40%max_qi、skill>=150、neili>=200；
  - `hit_ob` 被动未接入。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "zixia-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["hunyuan-yiqi", "taiji-shengong", "wudang-xinfa", "shaolin-xinfa"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的基本内功火候不够，无法学习紫霞神功！\n"}
    else
      :ok
    end
  end

  @doc "只能学(learn)不能练（LPC practice_skill 返回失败）"
  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{
      "powerup" => Kantele.Combat.Skills.ZixiaShengong.Powerup,
      "ziqi" => Kantele.Combat.Skills.ZixiaShengong.Ziqi
    }
  end
end

defmodule Kantele.Combat.Skills.ZixiaShengong.Powerup do
  @moduledoc """
  运功「powerup」（对照 `kungfu/skill/zixia-shengong/powerup.c`）

  耗 100 内力，临时提升 attack=defense=紫霞/3，持续 紫霞 秒；
  战斗中 busy 1..3 轮。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "zixia-shengong/powerup",
      gates: [
        {:neili_min, 100, "你的内力不够。\n"},
        {:no_buff, "powerup", "你已经在运功中了。\n"}
      ],
      costs: %{neili: 100},
      effects: [
        {:buff, "powerup",
         %{
           attack: {:div, {:skill, "zixia-shengong"}, 3},
           defense: {:div, {:skill, "zixia-shengong"}, 3}
         }}
      ],
      busy: {:if_fighting, {:random, 1, 3}},
      duration: {:skill, "zixia-shengong"},
      expire_message: "你的紫霞神功运行完毕，将内力收回丹田。\n",
      message: "$N微一凝神，默默运转体内所蓄的紫霞神功，霎时面部竟呈出一层薄霜。\n"
    }
end

defmodule Kantele.Combat.Skills.ZixiaShengong.Ziqi do
  @moduledoc """
  紫气东来「ziqi」（对照 `kungfu/skill/zixia-shengong/ziqi.c`）

  门槛：紫霞>=150、持剑、qi>40%max_qi、neili>=200、非 ziqi 状态。
  扣 neili 200，damage=紫霞/10, sword=紫霞/10，持续 紫霞 秒；busy 3。
  若 qi <= 40% max_qi 则失败（仅消耗 busy/内力）。
  """

  use Kantele.Combat.Skill

  alias Kantele.Character.Stats

  @impl true
  def id(), do: "zixia-shengong"

  @impl true
  def valid_enable(usage), do: usage == "force"

  @impl true
  def valid_force(force), do: force in ["hunyuan-yiqi", "taiji-shengong", "wudang-xinfa", "shaolin-xinfa"]

  @impl true
  def valid_learn(stats) do
    if Stats.skill(stats, "force") < 100 do
      {:error, "你的基本内功火候不够，无法学习紫霞神功！\n"}
    else
      :ok
    end
  end

  @impl true
  def practice_cost(), do: nil

  @impl true
  def query_action(_level, _rng \\ &:rand.uniform/1), do: %{}

  @impl true
  def exert_list() do
    %{"ziqi" => __MODULE__}
  end

  def spec do
    %Kantele.Combat.Performs.Spec{
      id: "zixia-shengong/ziqi",
      kind: :exert,
      gates: [
        {:custom, &gate_sword/1, "你没有剑.怎么用紫气东来呀? \n"},
        {:skill_min, "zixia-shengong", 150, "你的紫霞神功的修为不够，不能使用紫气东来! \n"},
        {:neili_min, 200, "你的内力还不够！\n"},
        {:custom, &gate_qi_ok/1, "你拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n"},
        {:no_buff, "ziqi", "你已经在运起紫气东来了。\n"}
      ],
      costs: %{neili: 200},
      effects: [
        {:custom, &effect_ziqi/1}
      ],
      busy: {:if_fighting, 3},
      duration: {:skill, "zixia-shengong"},
      expire_message: "你的紫气东来运行完毕，紫气渐渐隐去。\n",
      message: "$N猛吸一口气，脸上紫气大盛！手中的兵器隐隐透出一层紫光。。。\n"
    }
  end

  defp gate_sword(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "sword", do: :ok, else: {:error, "你没有剑.怎么用紫气东来呀? \n"}
  end

  defp gate_qi_ok(ctx) do
    vitals = ctx.character.meta.vitals

    if vitals.qi > div(vitals.max_qi * 4, 10),
      do: :ok,
      else: {:error, "你拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n"}
  end

  defp effect_ziqi(state) do
    char = state.character
    skill = Stats.skill(char.meta.stats, "zixia-shengong")
    bonus = div(skill, 10)

    new_combat =
      char.meta.combat
      |> Combat.apply_temp(%{damage: bonus, sword: bonus})
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "ziqi",
        applies: %{damage: -bonus, sword: -bonus}
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end

  defp gate_sword(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "sword", do: :ok, else: {:error, "你没有剑.怎么用紫气东来呀? \n"}
  end

  defp gate_qi_ok(ctx) do
    vitals = ctx.character.meta.vitals

    if vitals.qi > div(vitals.max_qi * 4, 10),
      do: :ok,
      else: {:error, "你拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n"}
  end

  defp effect_ziqi(state) do
    char = state.character
    skill = Stats.skill(char.meta.stats, "zixia-shengong")
    bonus = div(skill, 10)

    new_combat =
      char.meta.combat
      |> Combat.apply_temp(%{damage: bonus, sword: bonus})
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "ziqi",
        applies: %{damage: -bonus, sword: -bonus}
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end

  defp gate_sword(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "sword", do: :ok, else: {:error, "你没有剑.怎么用紫气东来呀? \n"}
  end

  defp gate_qi_ok(ctx) do
    vitals = ctx.character.meta.vitals

    if vitals.qi > div(vitals.max_qi * 4, 10),
      do: :ok,
      else: {:error, "你拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n"}
  end

  defp effect_ziqi(state) do
    char = state.character
    skill = Stats.skill(char.meta.stats, "zixia-shengong")
    bonus = div(skill, 10)

    new_combat =
      char.meta.combat
      |> Combat.apply_temp(%{damage: bonus, sword: bonus})
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "ziqi",
        applies: %{damage: -bonus, sword: -bonus}
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end

  defp gate_sword(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "sword", do: :ok, else: {:error, "你没有剑.怎么用紫气东来呀? \n"}
  end

  defp gate_qi_ok(ctx) do
    vitals = ctx.character.meta.vitals

    if vitals.qi > div(vitals.max_qi * 4, 10),
      do: :ok,
      else: {:error, "你拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n"}
  end

  defp effect_ziqi(state) do
    char = state.character
    skill = Stats.skill(char.meta.stats, "zixia-shengong")
    bonus = div(skill, 10)

    new_combat =
      char.meta.combat
      |> Combat.apply_temp(%{damage: bonus, sword: bonus})
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "ziqi",
        applies: %{damage: -bonus, sword: -bonus}
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end

  defp gate_sword(ctx) do
    weapon = ctx.character.meta.equipped.weapon
    if weapon && weapon.meta.skill_type == "sword", do: :ok, else: {:error, "你没有剑.怎么用紫气东来呀? \n"}
  end

  defp gate_qi_ok(ctx) do
    vitals = ctx.character.meta.vitals

    if vitals.qi > div(vitals.max_qi * 4, 10),
      do: :ok,
      else: {:error, "你拼尽毕生功力想提起紫气东来，但自己受伤太重，没能成功!\n"}
  end

  defp effect_ziqi(state) do
    char = state.character
    skill = Stats.skill(char.meta.stats, "zixia-shengong")
    bonus = div(skill, 10)

    new_combat =
      char.meta.combat
      |> Combat.apply_temp(%{damage: bonus, sword: bonus})
      |> Combat.add_buff(%Kantele.Character.Combat.Buff{
        key: "ziqi",
        applies: %{damage: -bonus, sword: -bonus}
      })

    new_char = %{char | meta: %{char.meta | combat: new_combat}}
    %{state | character: new_char}
  end
end