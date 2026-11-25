alias Kantele.World.Loader

world = Loader.load()

apprentice_keys = [
  :family,
  :gate_order,
  :permit_recruit,
  :deny_all,
  :min_shen,
  :min_shen_deny,
  :min_exp,
  :min_exp_deny,
  :min_skills,
  :recruit_skill_order,
  :min_max_neili,
  :max_neili_deny,
  :accept_msg,
  :deny_msg,
  :betray_sect_deny,
  :betray_times_deny,
  :other_family_deny
]

inquiry_keys = [
  "kind",
  "gate_order",
  "perform_id",
  "skill",
  "family",
  "allowed_families",
  "family_denies",
  "min_gongxian",
  "min_shen",
  "max_shen",
  "min_levels",
  "level_order",
  "level_deny",
  "improve_skills",
  "requires_performs",
  "requires_perform_deny",
  "msg_one",
  "item",
  "master_id",
  "allowed_master_ids",
  "master_before_gates",
  "skill_before_shen",
  "min_skill_levels",
  "count",
  "unique",
  "success",
  "master_deny",
  "min_shen_deny",
  "min_skill_deny",
  "accept_msg"
]

chosen =
  Enum.filter(world.characters, fn c ->
    Enum.any?(c.meta.aliases || [], &String.starts_with?(&1, "honghua_")) or
      (c.meta.zone_id == "kaifeng" and c.name == "无尘道长")
  end)

chunks =
  Enum.map(chosen, fn c ->
    key =
      Enum.find(c.meta.aliases || [], &String.starts_with?(&1, "honghua_")) ||
        "kaifeng:wuchen"

    inquiries =
      Map.new(c.meta.inquiries || %{}, fn {k, v} ->
        {k, Map.take(v, inquiry_keys)}
      end)

    """
    === #{key} / #{c.name} ===
    apprentice: #{inspect(Map.take(c.meta.apprentice || %{}, apprentice_keys), pretty: true, limit: :infinity)}
    inquiry_state: #{inspect(c.meta.inquiry_state, pretty: true, limit: :infinity)}
    chat: #{inspect({c.meta.chat_chance_combat, c.meta.chat_msg_combat}, pretty: true, limit: :infinity)}
    inquiries: #{inspect(inquiries, pretty: true, limit: :infinity)}
    """
  end)

File.write!(".workbuddy-ai/tmp/honghua_compact.txt", Enum.join(chunks, "\n"))
