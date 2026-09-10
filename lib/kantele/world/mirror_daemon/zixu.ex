defmodule Kantele.World.MirrorDaemon.Zixu do
  @moduledoc """
  子虚道人 NPC（宝镜任务发布者）：
  - 固定驻守 liuxi:zixu_guan (子虚观)
  - 玩家 ask mirror/宝镜/乾坤宝镜 → 给乾坤宝镜（每人限 1 个，记 mirror_count）
  - 玩家 ask 心魔幻境 → 暂未开放
  """

  require Logger

  alias Kantele.Character.{NPCConfig, NonPlayerMeta, Stats, Vitals}
  alias Kantele.Character.Combat
  alias Kalevala.World.Item.Instance
  alias Kantele.World.Items

  @liuxi_zone "liuxi"
  @mirror_item "liuxi:item/mirror"  # 待定义

  @doc "构建子虚道人 NPC 角色结构（zone_id 可注入，测试用独立 zone 避免抢占 liuxi 监督树）"
  def build_zixu(zone_id \\ @liuxi_zone) do
    room_id = "#{zone_id}:zixu_guan"

    meta =
      %NonPlayerMeta{
        zone_id: zone_id,
        initial_events: [],
        vitals: %Vitals{
          qi: 50_000,
          max_qi: 50_000,
          base_qi: 50_000,
          jing: 50_000,
          max_jing: 50_000,
          base_jing: 50_000,
          jingli: 50_000,
          max_jingli: 50_000,
          neili: 100_000,
          max_neili: 100_000,
          base_neili: 100_000
        },
        stats: %Stats{
          str: 50,
          dex: 50,
          con: 50,
          int: 50,
          combat_exp: 12_000_000,
          potential: 0,
          learned_points: 0,
          score: 0,
          weiwang: 0,
          gongxian: 0,
          shen: 0,
          skills: %{
            "force" => 500,
            "huntian-baojian" => 500,
            "parry" => 500,
            "dodge" => 500,
            "unarmed" => 500,
            "sword" => 500,
            "lunhui-jian" => 500,
            "poison" => 500,
            "medical" => 500,
            "lingbo-weibu" => 500,
            "qiankun-danuoyi" => 500,
            "buddhism" => 500,
            "taoism" => 500,
            "literate" => 500,
            "martial-cognize" => 500
          },
          mapped: %{
            "force" => :huntian_baojian,
            "parry" => :qiankun_danuoyi,
            "unarmed" => :huntian_baojian,
            "dodge" => :lingbo_weibu,
            "sword" => :lunhui_jian
          },
          performs: MapSet.new(),
          tattoo: nil,
          reborn: 0
        },
        combat_config: %NPCConfig{
          attitude: "friendly",
          spawn_room_id: room_id,
          respawn_delay: 0,
          no_kill: true,
          apply: %{}
        },
        combat: Combat.new(),
        loot: [],
        goods: nil,
        inquiries: %{
          "mirror" => :ask_mirror,
          "宝镜" => :ask_mirror,
          "乾坤宝镜" => :ask_mirror,
          "心魔幻境" => :ask_maze
        },
        teach: nil,
        turn_in: nil,
        quest: nil,
        coagents: [],
        parts: %{},
        no_cut: %{},
        default_clone: nil,
        been_cut: 0,
        defeated_by: nil
      }
      # 子虚道人标记
      |> Map.put(:kind, "zixu")

    %Kalevala.Character{
      id: "zixu_daoren",
      name: "子虚道人",
      description: "此人身着道袍，须发皆白，一副仙风道骨的气派，这便是武林中号称「子虚乌有」二道仙中的子虚道人，传说此人早已得道成仙，可通神界。",
      brain: %Kalevala.Brain{root: %Kalevala.Brain.NullNode{}},
      room_id: room_id,
      meta: meta
    }
  end

  def start_zixu(zone_id \\ @liuxi_zone) do
    invader = build_zixu(zone_id)

    config = [
      supervisor_name: Kalevala.World.CharacterSupervisor.global_name(zone_id),
      communication_module: Kantele.Communication,
      initial_controller: Kantele.Character.SpawnController,
      quit_view: {Kantele.Character.QuitView, "disconnected"}
    ]

    Kalevala.World.start_character(invader, config)
  end

  @doc """
  NPC 侧问询应答（Q5-T3，NpcAskEvent 对 atom 问询的分发目标）：

  - `:ask_mirror` → 发 `mirror/give` 事件给 asker（限 1 判定在玩家侧 MirrorEvent）
  - `:ask_maze` → 返回占位文本
  """
  def respond_to_ask(conn, %{reply_to: reply_to, asker_id: asker_id}, answer) do
    case answer do
      :ask_mirror ->
        send(reply_to, %Kalevala.Event{
          topic: "mirror/give",
          data: %{
            npc_name: conn.character.name,
            item_id: @mirror_item,
            asker_id: asker_id
          }
        })

        conn

      :ask_maze ->
        publish_tell(
          conn,
          asker_id,
          "子虚道人微微颔首：心魔幻境尚在祭炼之中，且先持宝镜寻回那三十件江湖失物。\n"
        )

      _ ->
        conn
    end
  end

  defp publish_tell(conn, asker_id, text) do
    Kalevala.Character.Conn.publish_message(
      conn,
      "characters:#{asker_id}",
      text,
      [],
      &publish_error/2
    )
  end

  defp publish_error(conn, _error), do: conn
end