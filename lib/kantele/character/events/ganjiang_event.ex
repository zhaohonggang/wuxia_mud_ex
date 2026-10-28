defmodule Kantele.Character.GanjiangEvent do
  @moduledoc """
  干将锻造链（对应 LPC ganjiang.c `accept_object`/`start_work`/`work_step_1..6`）。

  在干将进程内执行（NonPlayerEvents，命中 `forge/handoff`；由莫邪在
  `Kantele.World.ForgingAnswer.handoff`（S1c）直接投递）。负责：
    1. 把莫邪交来的材料实例计入干将背包并落盘；
    2. 房间即时广播 6 段锻造 vision（开炉→抛入炉内→火候→锤打→淬火→出炉）；
    3. 会话置 status="inputing"，can_help=true，记 making_instance_id；
    4. 尾段 vision 提示玩家起名并展示规则（name/desc/wieldmsg/unwieldmsg/finish）。

  注内力（S2 Task #156）在 status="inputing" 且 can_help=true 时由玩家通过
  `注内力` 命令触发，干将本身不处理该命令。
  """

  use Kalevala.Character.Event

  alias Kantele.Character.Records
  alias Kantele.World.Forging
  alias Kantele.World.Items
  alias Kantele.World.Room

  # 六段锻造 vision（对应 work_step_1..6，$N=干将，$n=材料）
  @visions [
    ~s("$N说道：好，开炉锻炼！\n$N接过莫邪手中的$n，随手把它抛入炉内，霎时间，那$n已被火炉中的熊熊烈焰吞没。\n$N凝视着炉火，喃喃说道：天地之精华为其血脉，日月之光辉是其灵气……\n"),
    ~s("炉火渐渐的转成了绿色，火苗不断跳跃，你觉得屋内十分燥热，可是干将若无其事。\n$N对在场之人说道：如果你想炼得更好，需要注入自己的精气血脉，如是有此意，请「注内力」助炉火一臂之力。\n"),
    ~s("炉火淡淡的暗了下来，呈现出一片红色……\n"),
    ~s("$N左手持蛟龙剪，一扬手已经取出了$n，右手持金刚锤聚精会神地用力锤打。\n渐渐的，$n在干将手下成了$ctype的形状。\n"),
    ~s("$N锤打完毕，大喝一声，将$ctype抛入水池，只听丝丝作响，从水池腾起一股雾气，弥漫四周。\n"),
    ~s("$N缓缓的从水池抽出了炼好的$ctype，看了看，满意地说，很好，很好。\n一$unit好$ctype不能没有名字，你给它起个名字吧！\n规则：命名 `name <中文名> <英文代号>`（必须有）；描述 `desc <文字>`；装备 `wieldmsg <文字>`；收起 `unwieldmsg <文字>`；完成 `finish`。\n")
  ]

  def handoff(conn, %{data: %{material_instance: material_instance, session: session}} = _event) do
    npc = conn.character
    owner_id = session.owner_id
    room_id = npc.room_id
    ctype = session.ctype || "武器"
    unit = session.unit || "件"

    material_name =
      case Items.get(session.material_item_id) do
        {:ok, item} -> item.name
        :error -> material_instance.item_id
      end

    # 1. 材料计入干将背包并落盘
    npc = %{npc | inventory: [material_instance | npc.inventory]}
    Records.save(npc)

    # 2. 会话进入 inputing（可起名/注内力）
    new_session =
      session
      |> Map.put(:status, "inputing")
      |> Map.put(:can_help, true)
      |> Map.put(:making_instance_id, material_instance.id)

    Forging.put(owner_id, new_session)

    # 3. 即时广播 6 段 vision（$N/$n/$ctype/$unit 作字面替换，避开绑定键约定）
    Enum.each(@visions, fn template ->
      vision =
        template
        |> String.replace("$N", npc.name)
        |> String.replace("$n", material_name)
        |> String.replace("$ctype", ctype)
        |> String.replace("$unit", unit)

      Room.message_vision(%{id: room_id}, vision, %{})
    end)

    conn
    |> put_character(npc)
  end
end
