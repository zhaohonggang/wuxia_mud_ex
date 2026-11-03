defmodule Kantele.Character.SetupPersistenceTest do
  @moduledoc """
  新玩家注册「投胎(born)」数据层往返（对应 LPC yanluodian.c:155-273 + updated.c:344-445）。

  覆盖 Phase 1.5/1.6/1.7：出生地映射写入 env（born/born_family/surname/registered/
  startroom/mud_age/age）、BornPlayer 赠「与生俱来」特技、setup_done 置位，
  经 Records.save → load → apply_to_character 全部保留，且授予的特技从
  env[:special_skills] 镜像回灌进 attributes["special_skills"]（重启不丢）。
  """
  use ExVenture.DataCase, async: false

  alias Kalevala.Character
  alias Kantele.Character.BornPlayer
  alias Kantele.Character.Combat
  alias Kantele.Character.PlayerMeta
  alias Kantele.Character.Records
  alias Kantele.Character.Stats
  alias Kantele.Character.Vitals

  @name "setup-persist-#{System.unique_integer([:positive])}"

  defp build_unwashed(name) do
    stats = %{Stats.new() | str: 22, int: 20, con: 20, dex: 18, per: 20, kar: 11}

    %Character{
      id: "setup-#{name}",
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
        env: %{gender: "男性"}
      }
    }
  end

  # 复刻 SetupController.apply_born 的数据效果（不含 move/控制器切换）
  defp apply_born_data(character, spec) do
    character
    |> put_in([Access.key(:meta), Access.key(:env)],
      Map.merge(character.meta.env, %{
        born: spec.born,
        born_family: spec.born_family,
        registered: true,
        startroom: spec.startroom,
        mud_age: 0,
        age: 14
      })
      |> maybe_put(:surname, spec.surname)
    )
    |> maybe_put_surname_in_env(spec.surname)
    |> Map.put(:room_id, spec.startroom)
    |> put_in([Access.key(:meta), Access.key(:setup_done)], true)
    |> BornPlayer.grant()
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, val), do: Map.put(map, key, val)

  defp maybe_put_surname_in_env(character, nil), do: character

  defp maybe_put_surname_in_env(character, surname) do
    env = Map.put(character.meta.env, :surname, surname)
    put_in(character.meta.env, env)
  end

  describe "born 数据层往返" do
    test "扬州人氏（普通出生地）：无 surname，env/特技/setup_done 全部保留" do
      spec = %{born: "扬州人氏", born_family: "没有", surname: nil, startroom: "city:kedian"}
      character = build_unwashed(@name) |> apply_born_data(spec)

      assert :ok = Records.save(character)
      {:ok, metadata, _wiz} = Records.load(@name)
      restored = Records.apply_to_character(character, {:ok, metadata}, 0)

      # env 落盘为 jsonb（字符串键）
      assert metadata.env["born"] == "扬州人氏"
      assert metadata.env["born_family"] == "没有"
      assert metadata.env["registered"] == true
      assert metadata.env["startroom"] == "city:kedian"
      assert metadata.env["mud_age"] == 0
      assert metadata.env["age"] == 14
      assert metadata.setup_done == true

      # apply 恢复（原子键）
      env = restored.meta.env
      assert env[:born] == "扬州人氏"
      assert env[:born_family] == "没有"
      assert env[:registered] == true
      assert env[:startroom] == "city:kedian"
      assert env[:mud_age] == 0
      assert env[:age] == 14
      assert env[:surname] == nil
      assert restored.meta.setup_done == true
      assert restored.room_id == "city:kedian"

      # 与生俱来特技：attributes["special_skills"] 由 env[:special_skills] 回灌
      granted = character.meta.env[:special_skills]
      assert is_list(granted) and length(granted) in 1..3
      Enum.each(granted, fn id -> assert restored.attributes["special_skills"][id] == true end)
    end

    test "欧阳世家（世家）：附 surname=欧阳，startroom=baituo:dating" do
      spec = %{born: "西域人氏", born_family: "欧阳世家", surname: "欧阳", startroom: "baituo:dating"}
      character = build_unwashed(@name) |> apply_born_data(spec)

      assert :ok = Records.save(character)
      {:ok, metadata, _wiz} = Records.load(@name)
      restored = Records.apply_to_character(character, {:ok, metadata}, 0)

      assert metadata.env["born"] == "西域人氏"
      assert metadata.env["born_family"] == "欧阳世家"
      assert metadata.env["surname"] == "欧阳"
      assert metadata.env["startroom"] == "baituo:dating"
      assert restored.meta.env[:surname] == "欧阳"
      assert restored.room_id == "baituo:dating"
    end
  end
end
