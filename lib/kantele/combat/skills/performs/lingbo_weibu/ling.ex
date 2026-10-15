defmodule Kantele.Combat.Skills.Performs.LingboWeibu.Ling do
  @moduledoc """
  洛神凌波「ling」（对照 `kungfu/skill/lingbo-weibu/ling.c`）

  自我增益：运起轻功身法，持续 `lingbo-weibu/2` 秒，战斗中忙乱 2、
  扣 400 内力；到期由 `combat/buff-expire` 回收。

  差异（TODO(migrate)）：
  - LPC 文案按性别分档（`me->query("gender") == "女性"`）；引擎角色模型无
    gender 字段，本版按 meta 的 `:gender` 取档、缺省走非女性档（两档文案均保留）；
  - LPC `add_temp("dex", 15)` 的身法加成本版只记 buff 状态、不参与数值
    （引擎 @applies_keys 无 dex，且无随机 dodging 建模）。
  """

  use Kantele.Combat.Performs.Simple,
    spec: %Kantele.Combat.Performs.Spec{
      id: "lingbo-weibu/ling",
      kind: :perform,
      gates: [
        {:perform_known, "lingbo-weibu/ling", "你所使用的外功中没有这种功能。\n"},
        {:skill_min, "lingbo-weibu", 120, "你的凌波微步还不够熟练，难以施展「洛神凌波」。\n"},
        {:neili_min, 600, "你现在真气不足，难以施展「洛神凌波」。\n"},
        {:no_buff, "lingbo", "你已经运起「洛神凌波」了。\n"}
      ],
      costs: %{neili: 400},
      effects: [{:buff, "lingbo", %{}}],
      busy: {:if_fighting, 2},
      duration: {:div, {:skill, "lingbo-weibu"}, 2},
      expire_message: "你的「洛神凌波」运功完毕，将内力收回丹田。\n",
      message: &ling_message/1
    }

  defp ling_message(%{character: character}) do
    female =
      "\n$N提起真气，依照先天伏羲六十四卦，将凌波微步由头到尾迅速无比的走了一次。$N仿如洛神再生，身形顿时轻盈无比，微步凌波，真个将逍遥二字发挥得淋漓尽至。\n"

    other =
      "\n$N提起真气，依照先天伏羲六十四卦，将凌波微步由头到尾迅速无比的走了一次。只见$N意态飘逸，影子乱飞，身形顿时轻盈无比，真个将逍遥二字发挥得淋漓尽至。\n"

    if Map.get(character.meta, :gender) == "女性", do: female, else: other
  end
end
