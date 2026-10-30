defmodule Kantele.World.NpcGreeting do
  @moduledoc """
  逐 NPC 条件问候派发（LPC `greeting()` 忠实移植）。

  运行时 `move_event.greet/2` 先查本注册表：命中则调用对应 handler，
  handler 可读玩家状态、返回 `{:say, [line, ...]}`（按序广播，对应 LPC 多次
  `command("say ...")`）或 `:skip`（不问候，对应 LPC `return`）。
  未注册的 NPC 返回 `:fallback`，回退到 `meta.greetings` 静态池（随机取一句）。

  约定：NPC id 形如 `"zone:name"`（如 `"wuguan:zhuziliu"`，见 loader.ex:2250）。
  注册表 `handler/1` 返回 `fun/2`（`(npc, player) -> result`）；新增时加一条子句。
  """

  @doc "按 NPC id 派发问候，返回 `{:say, lines}` | `:skip` | `:fallback`。"
  def greet(%{id: id} = npc, player) do
    case handler(id) do
      nil -> :fallback
      fun when is_function(fun, 2) -> fun.(npc, player)
    end
  end

  def greet(_npc, _player), do: :fallback

  # ---- 注册表：NPC id => fun/2 ----
  defp handler("wuguan:zhuziliu"), do: &__MODULE__.WuguanZhuziliu.greet/2
  defp handler("wuguan:wusantong"), do: &__MODULE__.WuguanWusantong.greet/2

  # 武馆各库房管事：job_name 匹配才问候；无对应工具则提示去领。
  defp handler("wuguan:guanjia1"),
    do: guanjia("劈柴", "wuguan:items.chaidao", "劈柴(pi chai)")

  defp handler("wuguan:guanjia2"),
    do: guanjia("锯木头", "wuguan:items.juzi", "锯木(ju mutou)")

  defp handler("wuguan:guanjia3"),
    do: guanjia("打扫马房", "wuguan:items.saozhou", "打扫(sao mafang)")

  defp handler("wuguan:guanjia5"),
    do: guanjia("锄草", "wuguan:items.chutou", "锄草(chu cao)")

  defp handler("wuguan:guanjia6"),
    do: guanjia("浇菜地", "wuguan:items.piao", "浇水(jiao shui)")

  defp handler("wuguan:wuxiuwen"), do: &__MODULE__.WuguanWuxiuwen.greet/2

  # 文本分支问候（按 gender / class / family 选台词）
  defp handler("changan:shuchi"), do: &__MODULE__.ChanganShuchi.greet/2
  defp handler("changan:lingfeixue"), do: &__MODULE__.ChanganLingfeixue.greet/2
  defp handler("gaochang:liwenxiu"), do: &__MODULE__.GaochangLiwenxiu.greet/2
  defp handler("xiyu:caihua"), do: &__MODULE__.XiyuCaihua.greet/2

  # 妓院老鸨（三家同构：太监被踢出门，和尚/女性另有台词）
  defp handler("luoyang:laobao"),
    do:
      brothel(
        house: "春月楼",
        room_id: "luoyang:sroad5",
        kicker: "老鸨婆",
        landing: "栽倒在地上，磕掉两颗门牙。",
        insult: "你当我们春月楼是什么地方？我的姑娘满汉蒙藏回都接，就是不伺候太监！",
        female_line: "哎呀，这年月大姑娘也逛窑子，成何体统。",
        son_line: "可惜我儿子不在，不然让他伺候你。"
      )

  defp handler("beijing:laobaopo"),
    do:
      brothel(
        house: "怡红院",
        room_id: "beijing:wang_8",
        kicker: "老鸨婆",
        landing: "栽倒在地上，磕掉两颗门牙。",
        insult: "你当老娘是烂婊子吗？辣块妈妈，老娘满汉蒙藏回都接，就是不伺候太监！",
        female_line: "哎呀，这年月大姑娘也逛窑子，成何体统。",
        son_line: "可惜我儿子不在，不然让他伺候你。"
      )

  defp handler("city:wei"),
    do:
      brothel(
        house: "丽春院",
        room_id: "city:nandajie2",
        kicker: "韦春芳",
        landing: "栽倒在地上。",
        insult: "你当老娘是烂婊子吗？辣块妈妈，老娘满汉蒙藏回都接，就是不伺太监！",
        female_line: "哎呀，这年月大姑娘也逛窑子，成何体统？",
        son_line: "可惜我家小宝不在，不然让他伺候你。"
      )

  # 见人就杀 / 见物就杀的门卫
  defp handler("gaochang:waer"), do: &__MODULE__.GaochangWaer.greet/2
  defp handler("mingjiao:miaozuwushi"), do: &__MODULE__.MingjiaoMiaozuwushi.greet/2
  defp handler("wudang:mengmian"), do: &__MODULE__.WudangMengmian.greet/2

  # 入房即抓人的官差（`init()` 里 call_out kill_ob，见下）
  defp handler("city:shisong"), do: &__MODULE__.CityShisong.greet/2

  # 按属性分支问候
  defp handler("city:yanruyu"), do: &__MODULE__.CityYanruyu.greet/2

  defp handler(_), do: nil

  defp guanjia(job, tool_id, action) do
    fn npc, player -> __MODULE__.WuguanGuanjia.greet(npc, player, job, tool_id, action) end
  end

  defp brothel(opts) do
    fn npc, player -> __MODULE__.Brothel.greet(npc, player, opts) end
  end

  # ===================================================================
  # handlers
  # ===================================================================

  defmodule WuguanZhuziliu do
    @moduledoc """
    武馆 朱子柳（`d/wuguan/npc/zhuziliu.c` `greeting()`）：
    `literate > 99` 则 `return`；否则劝学一句。LPC 另有 `command("pat")` 表情，本移植只保留台词。
    """
    alias Kantele.Character.Stats

    def greet(_npc, player) do
      if Stats.skill(player.meta.stats, "literate") > 99 do
        :skip
      else
        {:say, ["朱子柳说道：这位{respect}，过来跟我学些知识(xue zhu ziliu literate)吧。"]}
      end
    end
  end

  defmodule WuguanWusantong do
    @moduledoc """
    武馆 武三通（`d/wuguan/npc/wusantong.c` `greeting()`）：
    force/dodge/parry 三者均 > 99 则 `return`；否则劝学两句。
    """
    alias Kantele.Character.Stats

    def greet(_npc, player) do
      s = player.meta.stats

      if Stats.skill(s, "force") > 99 and Stats.skill(s, "dodge") > 99 and
           Stats.skill(s, "parry") > 99 do
        :skip
      else
        {:say,
         [
           "武三通说道：这位{respect}，我正在传授基本武功。",
           "武三通说道：有空就过来学学(xue wu santong skills)吧。"
         ]}
      end
    end
  end

  defmodule WuguanGuanjia do
    @moduledoc """
    武馆各库房管事（`d/wuguan/npc/guanjia*.c` `greeting()`）：
    仅当 `query_temp("job_name")` 等于本管事职责时才问候；若玩家背包里没有对应工具
    （`present("<tool>")`），提示去东物品房找武爷领；否则告知就在此处作业。
    LPC 的 `command("hmm"/"nod")` 表情略去，仅保留 `say` 台词。
    """
    def greet(npc, player, job, tool_id, action) do
      temp = player.meta.temp || %{}

      cond do
        temp["job_name"] != job ->
          :skip

        has_tool?(player, tool_id) ->
          {:say, ["#{npc.name}说道：是耶律大爷吩咐你来的吧？那你就在这#{action}好了。"]}

        true ->
          {:say, ["#{npc.name}说道：你还没领工具吧，去东物品房找武爷要了再来。"]}
      end
    end

    defp has_tool?(player, tool_id) do
      Enum.any?(player.inventory || [], fn inst -> Map.get(inst, :item_id) == tool_id end)
    end
  end

  defmodule WuguanWuxiuwen do
    @moduledoc """
    武馆 武修文（`d/wuguan/npc/wuxiuwen.c` `greeting()`）：
    1. 任一活计完成 mark（劈/浇/锄/锯/扫 完了）→「你的工作做完了？那现在把工具还给我吧。」
    2. 已发过工具（`mark/工具`）→ 不问候（`return 0`）
    3. `job_name` 属五种活计 →「你是来我这里领工具(ask wu xiuwen about 工具)的吧。」
    4. 其余不问候。
    """
    @done_marks ~w(mark/劈完了 mark/浇完了 mark/锄完了 mark/锯完了 mark/扫完了)
    @jobs ~w(锯木头 锄草 浇菜地 劈柴 打扫马房)

    def greet(npc, player) do
      temp = player.meta.temp || %{}

      cond do
        Enum.any?(@done_marks, fn k -> temp[k] not in [nil, false] end) ->
          {:say, ["#{npc.name}说道：你的工作做完了？那现在把工具还给我吧。"]}

        temp["mark/工具"] not in [nil, false] ->
          :skip

        temp["job_name"] in @jobs ->
          {:say, ["#{npc.name}说道：你是来我这里领工具(ask wu xiuwen about 工具)的吧。"]}

        true ->
          :skip
      end
    end
  end

  defmodule PlayerState do
    @moduledoc false
    # 玩家态访问器：LPC `query("gender")` / `query("class")` / `query("family")`。
    # gender 落 meta.env（Records.apply_to_character）；class / family_name 落 meta.family。
    def gender(player) do
      env = (player.meta && player.meta.env) || %{}
      env[:gender] || env["gender"]
    end

    def class(player) do
      family = player.meta && player.meta.family
      if is_map(family), do: Map.get(family, :class), else: nil
    end

    def family_name(player) do
      family = player.meta && player.meta.family
      if is_map(family), do: Map.get(family, :family_name) || Map.get(family, :name), else: nil
    end
  end

  defmodule ChanganShuchi do
    @moduledoc "长安 书痴（`d/changan/npc/shuchi.c` `greeting()`）：恒说「这位<respect>快请进，快请进。」"
    def greet(npc, _player), do: {:say, ["#{npc.name}说道：这位{respect}快请进，快请进。"]}
  end

  defmodule ChanganLingfeixue do
    @moduledoc """
    长安 凌飞雪（`d/changan/npc/lingfeixue.c` `greeting()`）：
    `class=="bonze"` → 两句；`gender=="女性"` → 一句；最后恒有一句「有客人来了」。
    """
    alias Kantele.World.NpcGreeting.PlayerState

    def greet(npc, player) do
      bonze = PlayerState.class(player) == "bonze"
      female = PlayerState.gender(player) == "女性"

      lines =
        (if bonze do
           [
             "#{npc.name}说道：呵！{respect}也来光顾我们群玉楼啊。",
             "#{npc.name}说道：快请上楼吧！"
           ]
         else
           []
         end) ++
          (if female do
             ["#{npc.name}说道：哎呀，这位{respect}也来逛窑子，成何体同。"]
           else
             []
           end) ++
          ["#{npc.name}说道：楼上的姑娘们，有客人来了！"]

      {:say, lines}
    end
  end

  defmodule GaochangLiwenxiu do
    @moduledoc """
    高昌 李文秀（`d/gaochang/npc/liwenxiu.c` `greeting()`）：
    男性 → `command("sigh")`（叹气）；其余 → `command("look")`（打量）。
    LPC 无 say，此处以 emote 风格台词近似（无对话）。
    """
    alias Kantele.World.NpcGreeting.PlayerState

    def greet(npc, player) do
      if PlayerState.gender(player) == "男性" do
        {:say, ["#{npc.name}叹了口气。"]}
      else
        {:say, ["#{npc.name}打量了你一眼。"]}
      end
    end
  end

  defmodule XiyuCaihua do
    @moduledoc """
    西域 采花贼（`d/xiyu/npc/caihua.c` `greeting()`）：
    仅当玩家门派为「星宿派」时 `say` 一句；否则不问候。
    LPC 另 `set_temp("marks/花",0)`（会话态重置）从略——跨进程写玩家 temp 成本高且影响极小。
    """
    alias Kantele.World.NpcGreeting.PlayerState

    def greet(npc, player) do
      if PlayerState.family_name(player) == "星宿派" do
        {:say, ["#{npc.name}说道：我昨天从山下捉了个小妞来，水灵极了，就关在逍遥洞里。"]}
      else
        :skip
      end
    end
  end

  defmodule CityShisong do
    @moduledoc """
    扬州 茅十八的仇家「石松」（`d/city/npc/shisong.c` `init()`）：
    LPC 在 `init()`（玩家进入）里判两档，命中就 `call_out("kill_ob", 1, ob)`：

    1. 进来的是 `mao shiba`（茅十八本人）→「茅十八你这个反贼，今天终于逮到你了！」
    2. 玩家 `combat_exp > 150000` 且门派为「天地会」，且所在房间无 `no_fight`
       →「你这个天地会反贼，纳命来吧！」

    `set_leader(ob)`（跟随目标）未移植：跟随是玩家主动 `follow` 的行为，
    NPC 强行 set_leader 只会让它在玩家离开时到处乱走，与「原地开打」等效。
    `call_out` 的 1 秒延迟也略去 —— 立即开战，玩家感知一致。
    """
    alias Kantele.World.NpcActions.NpcAttack
    alias Kantele.World.NpcGreeting.PlayerState
    alias Kantele.World.Room

    def greet(npc, player) do
      cond do
        player.id in ["mao shiba", "player:mao_shiba"] or player.name == "茅十八" ->
          NpcAttack.kill_ob(npc, player)
          {:say, ["#{npc.name}说道：茅十八你这个反贼，今天终于逮到你了！"]}

        wanted?(player) ->
          NpcAttack.kill_ob(npc, player)
          {:say, ["#{npc.name}说道：你这个天地会反贼，纳命来吧！"]}

        true ->
          :skip
      end
    end

    defp wanted?(player) do
      stats = player.meta.stats

      (stats.combat_exp || 0) > 150_000 and PlayerState.family_name(player) == "天地会" and
        not no_fight?(player.room_id)
    end

    defp no_fight?(room_id) do
      case Room.get_state_by_id(room_id, "no_fight") do
        nil -> false
        false -> false
        0 -> false
        _ -> true
      end
    end
  end

  defmodule CityYanruyu do
    @moduledoc """
    扬州 颜如玉（`d/city/npc/yanruyu.c` `greeting()`）：
    玩家 `per < 20` 时招揽美容养颜的生意；否则不问候。

    ⚠️ **数据模型缺口**：本引擎没有建模 LPC 的 `per`（容貌）基础属性 ——
    `Kantele.Character.Stats` 只有 str/dex/con/int，`per` 仅存在于
    `Kantele.Character.Attributes.per/2` 的派生公式里（入参由调用方给）。
    因此这里读 `character.attributes` 的 `:per`/`"per"`，**缺省按 20 处理**
    （成年中性值）—— 宁可不问候，也不要对每个玩家无条件刷这句台词。
    等 `per` 落盘后本分支自动生效。
    """
    @default_per 20

    def greet(npc, player) do
      if per(player) < 20 do
        {:say, ["#{npc.name}说道：嘻嘻，这位{respect}要学美容养颜吗？学费很便宜哦。"]}
      else
        :skip
      end
    end

    defp per(player) do
      attrs = player.attributes || %{}
      Map.get(attrs, :per) || Map.get(attrs, "per") || @default_per
    end
  end

  defmodule Brothel do
    @moduledoc """
    妓院老鸨问候（`d/luoyang/npc/laobao.c`、`d/beijing/npc/laobaopo.c`、
    `d/city/npc/wei.c` 三家 `greeting()` 同构，仅房名/台词/踢人目标不同）。

    - `gender == "无性"`（太监）：辱骂一句 → `command("kick")` → 房间视讯
      「被<kicker>一脚踢出门外」→ `me->move(<门外>)` → 门外视讯
      「被人从<house>里踢了出来…」。位移由 `{:say, lines, {:teleport, room_id}}`
      的收尾动作触发（NPC 进程没有玩家 conn，见 `Kantele.Character.TeleportEvent`）。
    - 否则：和尚（`class == "bonze"`）两句（含西藏喇嘛典故）；女性三句
      （`say` + `sigh` + 儿子一句）；最后恒有一句「楼上楼下的姑娘们，客人来了！」。

    `command("sigh")` 按本项目惯例落成一句 emote 文本（同 `GaochangLiwenxiu`）。
    """
    alias Kantele.World.NpcGreeting.PlayerState

    def greet(npc, player, opts) do
      if PlayerState.gender(player) == "无性" do
        kick(npc, player, opts)
      else
        {:say, welcome(npc, player, opts)}
      end
    end

    defp kick(npc, player, opts) do
      house = opts[:house]

      lines = [
        "#{npc.name}说道：#{opts[:insult]}",
        {:vision, "#{player.name}被#{opts[:kicker]}一脚踢出门外。", nil, player.pid},
        {:vision, "#{player.name}被人从#{house}里踢了出来，#{opts[:landing]}", opts[:room_id],
         player.pid}
      ]

      {:say, lines, {:teleport, opts[:room_id]}}
    end

    defp welcome(npc, player, opts) do
      bonze = PlayerState.class(player) == "bonze"
      female = PlayerState.gender(player) == "女性"
      house = opts[:house]

      (if bonze do
         [
           "#{npc.name}说道：呦，{respect}也来光顾我们#{house}啊。",
           "#{npc.name}说道：想当年我接过一个西藏喇嘛，他上床前一定要念经，一面念经，眼珠子就骨溜溜的瞧着我。"
         ]
       else
         []
       end) ++
        (if female do
           [
             "#{npc.name}说道：#{opts[:female_line]}",
             "#{npc.name}叹了口气。",
             "#{npc.name}说道：#{opts[:son_line]}"
           ]
         else
           []
         end) ++
        ["#{npc.name}说道：楼上楼下的姑娘们，客人来了！"]
    end
  end

  defmodule GaochangWaer do
    @moduledoc """
    高昌 瓦耳拉齐（`d/gaochang/npc/waer.c` `greeting()`）：
    玩家身上有 `map`（`present("map", me)`）→ 喝道一句 + `kill_ob(me)`；
    否则 `command("sneer")`（嗤笑）。
    """
    alias Kantele.World.NpcActions.NpcAttack
    alias Kantele.World.RoomActions.Helpers

    def greet(npc, player) do
      if Helpers.carries?(player, "map") do
        NpcAttack.kill_ob(npc, player)
        {:say, [{:vision, "瓦耳拉齐喝道：居然敢到这里来撒野，给我受死吧！"}]}
      else
        {:say, ["#{npc.name}对你嗤笑了一声。"]}
      end
    end
  end

  defmodule MingjiaoMiaozuwushi do
    @moduledoc """
    明教 苗人巫士（`d/mingjiao/npc/miaozuwushi.c` `greeting()`）：
    见人就 `command("kill " + id)`（即 `kill_ob`），无台词。
    """
    alias Kantele.World.NpcActions.NpcAttack

    def greet(npc, player) do
      NpcAttack.kill_ob(npc, player)
      :skip
    end
  end

  defmodule WudangMengmian do
    @moduledoc """
    武当 蒙面人（`d/wudang/npc/mengmian.c` `greeting()`）：
    `all_inventory(environment())` 里所有活物逐个 `kill_ob`，再 `command("kill zhike")`。
    「所有活物」用房间角色快照实现（`Room.npc_characters_by_id/1`）；
    多杀的那记 `kill zhike` 已被前一步覆盖，不再单独发。
    """
    alias Kantele.World.NpcActions.NpcAttack
    alias Kantele.World.Room

    def greet(npc, _player) do
      npc.room_id
      |> Room.npc_characters_by_id()
      |> Enum.reject(fn occupant -> Map.get(occupant, :id) == npc.id end)
      |> Enum.filter(fn occupant -> is_pid(Map.get(occupant, :pid)) end)
      |> Enum.each(fn occupant -> NpcAttack.kill_ob(npc, occupant) end)

      :skip
    end
  end
end
