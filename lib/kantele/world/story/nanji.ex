defmodule Kantele.World.Story.Nanji do
  @moduledoc "story:nanji 赤脚大仙藏铸骨丹于西瓜（LPC nanji.c）"
  @behaviour Kantele.World.Story.Behaviour

  alias Kantele.World.Story.Gift
  alias Kantele.World.Story.Lines

  defp messages(), do: [
    "赤脚大仙馋性大发溜到王母娘娘的蟠桃园偷了一颗蟠桃。",
    "赤脚大仙一路狂奔，眼看快到南天门了，却被斗战胜佛孙悟空撞了个正着。",
    "赤脚大仙：大圣，你放我一马，改日必有重谢。",
    "孙悟空：赤脚大仙，你这是怎么回事？",
    "赤脚大仙：我……我……",
    "孙悟空好声好气地道：大仙你有话好好说，别吞吞吐吐的。",
    "赤脚大仙只好把偷桃之事一五一十说了，并道：大圣，你我哥们儿一场，你可千万别说出去。",
    "孙悟空眼珠一转：这好办，你先把这桃给我尝尝。",
    "赤脚大仙：你……",
    "孙悟空：怎么？不够意思了？",
    "赤脚大仙无奈，把蟠桃递过去。孙悟空咬了两口，道：还你，好，我去玩了。",
    "赤脚大仙拿着被咬了两口的蟠桃，哭笑不得。",
    "赤脚大仙走到南天门，被守门的四大金刚挡住了去路。",
    "金刚甲：何人如此大胆，敢在上班时间偷吃蟠桃？",
    "赤脚大仙赶紧把两只手放到背后，说：我，我没有。",
    "金刚乙的眼睛望向赤脚大仙拿在身后的蟠桃。",
    "赤脚大仙：吃桃是不对，你看我一不偷二不抢，这桃是……大圣送我的。",
    "金刚甲：好呀，又是你，上回你偷炼丹炉里的补丹的时候，就被我们撞见过。",
    "赤脚大仙：胡说，我几时偷过孙悟空的丹了，那都是他自己蹦出来的。",
    "金刚乙：既然这样，跟你去给太上回话。",
    "赤脚大仙心里念了句：当初奉父亲遗命，凡来捏泥人若都用模子，则既未见手，亦未见心，便没了人间烟火气。",
    "南极大仙见赤脚大仙迟疑，忙道：你这家伙还想逃？",
    "赤脚大仙急道：我怕你们吃了那铸骨丹！",
    "赤脚大仙情急之下将铸骨丹塞进墙角刚长出来的西瓜肚子里，转身就溜。",
    {:action, fn ->
      case Gift.drop_to_random_room("gift/con2", "\n“啪”的一声一颗仙丹掉到你面前。\n\n") do
        :none -> nil
        {:ok, _player} -> "据说铸骨丹就藏在刚长出来的西瓜肚子里，你听见“咚”的一声。"
        {:error, _reason, _player} -> nil
      end
    end},
    "南极仙翁：好了好了，我不要了。",
    "赤脚大仙：那还差不多。"
  ]

  @impl true
  def init_state(), do: %{}

  @impl true
  def prompt(), do: "{color foreground=\"green\"}【故事传闻】{/color}"

  @impl true
  def step(index, inner), do: Lines.step_lines(messages(), index, inner)
end