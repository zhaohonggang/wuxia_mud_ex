defmodule Kantele.Character.RidetoCommand do
  @moduledoc """
  骑乘传送命令：`rideto <地点>`

  对应 LPC cmds/usr/rideto.c。
  利用坐骑到达某个地点，需要骑马且满足各种状态条件。
  """

  use Kalevala.Character.Command

  alias Kantele.Character.CommandView
  alias Kantele.Character.Teleport

  @places %{
    "baituo" => "baituo:guangchang",
    "beijing" => "beijing:tiananmen",
    "changan" => "changan:bridge2",
    "chengdu" => "chengdu:guangchang",
    "dali" => "dali:center",
    "emei" => "emei:huayanding",
    "foshan" => "foshan:street3",
    "fuzhou" => "fuzhou:dongjiekou",
    "gc" => "city:guangchang",
    "guanwai" => "guanwai:jishi",
    "guiyun" => "guiyun:taihu",
    "gumu" => "gumu:mumen",
    "hangzhou" => "hangzhou:road10",
    "heimuya" => "heimuya:shimen",
    "hengyang" => "hengyang:hengyang",
    "huashan" => "huashan:shaluo",
    "jiaxing" => "quanzhou:jiaxing",
    "jingzhou" => "jingzhou:guangchang",
    "kaifeng" => "kaifeng:zhuque",
    "kunlun" => "kunlun:klshanlu",
    "kunming" => "kunming:jinrilou",
    "lanzhou" => "lanzhou:guangchang",
    "lingjiu" => "lingjiu:jian",
    "lingzhou" => "lingzhou:center",
    "luoyang" => "luoyang:center",
    "mingjiao" => "mingjiao:shanjiao",
    "murong" => "yanziwu:hupan",
    "nanhai" => "xiakedao:haibin",
    "nanyang" => "shaolin:nanyang",
    "quanzhen" => "quanzhen:damen",
    "quanzhou" => "quanzhou:zhongxin",
    "shaolin" => "shaolin:shanmen",
    "suzhou" => "suzhou:canlangting",
    "taishan" => "taishan:taishanjiao",
    "taohua" => "taohua:haitan",
    "wudang" => "wudang:jiejianyan",
    "wugong" => "quanzhen:zhongxin",
    "xiangyang" => "xiangyang:guangchang",
    "xiaoyao" => "xiaoyao:xiaodao4",
    "xingxiu" => "xiyu:xxh1",
    "xuedao" => "xuedao:wangyougu",
    "xueshan" => "xuedao:nroad4",
    "yangzhou" => "city:guangchang",
    "yanziwu" => "yanziwu:bozhou",
    "yongdeng" => "huanghe:yongdeng",
    "zhongnan" => "quanzhen:shanjiao",
    "zhongzhou" => "zhongzhou:shizhongxin",
    "hengshan" => "hengyang:nantian",
    "jueqing" => "jueqing:shanjiao",
    "tiezhang" => "tiezhang:shanjiao"
  }

  def run(conn, %{"place" => place}) do
    character = conn.character

    cond do
      is_over_encumbered?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你的负荷过重，动弹不得。\n"})
        |> prompt(CommandView, "prompt", %{})

      is_busy?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你的动作还没有完成，不能移动。\n"})
        |> prompt(CommandView, "prompt", %{})

      is_fighting?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你现在正在战斗！\n"})
        |> prompt(CommandView, "prompt", %{})

      is_ghost?(character) ->
        conn
        |> render(CommandView, "text", %{text: "等你还了阳再说吧。\n"})
        |> prompt(CommandView, "prompt", %{})

      !has_riding?(character) ->
        conn
        |> render(CommandView, "text", %{text: "你还没有坐骑！\n"})
        |> prompt(CommandView, "prompt", %{})

      true ->
        case Map.fetch(@places, place) do
          {:ok, room_id} ->
            do_rideto(conn, character, place, room_id)

          :error ->
            conn
            |> render(CommandView, "text", %{text: "这个地方无法乘坐骑去。\n"})
            |> prompt(CommandView, "prompt", %{})
        end
    end
  end

  def run(conn, %{}) do
    list_places(conn)
  end

  defp is_over_encumbered?(character) do
    carry_weight = character.attributes["carry_weight"] || 0
    max_carry = character.attributes["max_carry"] || 100
    carry_weight > max_carry
  end

  defp is_busy?(character) do
    combat = character.meta.combat
    (combat && combat.busy && combat.busy > 0) || character.attributes["doing"]
  end

  defp is_fighting?(character) do
    combat = character.meta.combat
    combat && combat.enemies != []
  end

  defp is_ghost?(character) do
    character.attributes["ghost"] == true
  end

  defp has_riding?(character) do
    Map.get(character.meta, :riding) != nil
  end

  defp do_rideto(conn, character, place, room_id) do
    conn
    |> render(CommandView, "text", %{text: "你一路马不停蹄，风尘仆仆的赶到了#{place}。\n"})
    |> Teleport.teleport(room_id)
    |> assign(:prompt, false)
  end

  defp list_places(conn) do
    places_text = """
    利用坐骑到达某个地点。目前可以利用坐骑去的地方有：
    baituo   : 白驼山        beijing  : 北  京        changan  : 长  安
    chengdu  : 成  都        dali     : 大  理        emei     : 峨眉山
    foshan   : 佛  山        fuzhou   : 福  州        guanwai  : 关  外
    guiyun   : 归云庄        gumu     : 古  墓        hangzhou : 杭  州
    heimuya  : 黑木崖        hengyang : 衡  阳        huashan  : 华  山
    jiaxing  : 嘉  兴        jingzhou : 荆  州        kaifeng  : 开  封
    kunlun   : 昆仑山        kunming  : 昆  明        lanzhou  : 兰  州
    lingjiu  : 灵鹫宫        lingzhou : 灵  州        luoyang  : 洛  阳
    mingjiao : 光明顶        murong   : 慕  容        nanhai   : 南  海
    nanyang  : 南  阳        quanzhen : 全真教        quanzhou : 泉  州
    suzhou   : 苏  州        taishan  : 泰  山        wudang   : 武当山
    wugong   : 武功镇        xiangyang: 襄  阳        xiaoyao  : 逍遥林
    xingxiu  : 星宿海        xuedao   : 血刀门        xueshan  : 雪  山
    yangzhou : 扬  州        yanziwu  : 燕子坞        yongdeng : 永  登
    zhongnan : 终南山        zhongzhou: 中  州        hengshan : 衡  山
    jueqing  : 绝情谷        tiezhang : 铁掌山        taohua   : 桃花岛
    """

    conn
    |> render(CommandView, "text", %{text: places_text})
    |> prompt(CommandView, "prompt", %{})
  end
end
