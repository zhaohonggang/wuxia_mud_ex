defmodule Kantele.Character.RegistrationFieldsTest do
  @moduledoc """
  Phase 0.2.1 数据层落盘往返：per/kar/env/character/setup_done
  经 Records.save → load → apply_to_character 不丢失（对应「重启后属性/出生地不丢」验收）。

  同时覆盖胶囊环境键归一：Ecto 的 `:map`(jsonb) 从 DB 读出时键是字符串，
  apply_to_character 必须归一为原子键，否则运行态 `meta.env[:startroom]` 等读不到。
  """
  use ExVenture.DataCase, async: false

  alias ExVenture.Characters.Metadata
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @name "registr-fields-#{System.unique_integer([:positive])}"

  defp build_character(name) do
    stats = %{Stats.new() | per: 25, kar: 12}

    %Kalevala.Character{
      id: "registr-#{name}",
      name: name,
      pid: self(),
      room_id: "register:yanluodian",
      attributes: %{},
      inventory: [],
      meta: %PlayerMeta{
        vitals: Vitals.new(),
        stats: stats,
        combat: Combat.new(),
        coins: 100,
        # 运行态 env 用原子键
        env: %{gender: "女性", startroom: "register:entry", setup_done: true},
        character: "国士无双",
        setup_done: true
      }
    }
  end

  describe "save → load → apply 往返" do
    test "per/kar/env/character/setup_done 全部保留" do
      character = build_character(@name)

      assert :ok = Records.save(character)

      {:ok, metadata, _wiz} = Records.load(@name)

      # —— DB 列 ——
      assert metadata.per == 25
      assert metadata.kar == 12
      assert metadata.personality == "国士无双"
      assert metadata.setup_done == true
      assert metadata.gender == "女性"
      # env 落盘为 jsonb（字符串键）
      assert metadata.env["gender"] == "女性"
      assert metadata.env["startroom"] == "register:entry"
      assert metadata.env["setup_done"] == true

      # —— apply 恢复（键归一为原子）——
      restored = Records.apply_to_character(character, {:ok, metadata}, 0)
      assert restored.meta.stats.per == 25
      assert restored.meta.stats.kar == 12
      assert restored.meta.character == "国士无双"
      assert restored.meta.setup_done == true
      assert restored.meta.env[:gender] == "女性"
      assert restored.meta.env[:startroom] == "register:entry"
      assert restored.meta.env[:setup_done] == true
    end
  end

  describe "apply_to_character 缺省兜底（旧档/空 Metadata）" do
    test "无 per/kar/env/character/personality/setup_done 不崩溃，退化缺省" do
      metadata = %Metadata{character_id: 999_990, gender: "男性"}

      character = %Kalevala.Character{
        id: "default-fields",
        name: "default",
        meta: %PlayerMeta{
          vitals: Vitals.new(),
          stats: Stats.new(),
          combat: Combat.new()
        }
      }

      restored = Records.apply_to_character(character, {:ok, metadata}, 0)
      assert restored.meta.stats.per == 20
      assert restored.meta.stats.kar == 0
      assert restored.meta.character == nil
      # schema 默认 false（新账号需走注册问答），非 nil
      assert restored.meta.setup_done == false
      assert restored.meta.env[:gender] == "男性"
    end
  end
end
