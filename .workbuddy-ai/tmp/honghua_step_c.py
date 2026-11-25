from pathlib import Path

p = Path(r"C:\files\git\wuxia_mud_ex\data\world\kaifeng.ucl")
text = p.read_bytes().decode("utf-8")

start = text.index('    characters "wuchen" {')
end = text.index('\n    characters "zaohongma" {', start)
seg = text[start:end]

old_inq_start = seg.index('      # LPC: kungfu/class/honghua/wuchen.c ask_skill1..3')
old_inq_end = seg.index('      # LPC: kungfu/class/honghua/wuchen.c\n', old_inq_start)
new_inq = '''      # LPC: kungfu/class/honghua/wuchen.c ask_skill1..3 —— 内联 ask_skill*
      # 原序：已会 → 同门 → 本招技能存在 → gongxian → shen → 前置绝招 →
      # force / dodge / max_neili / 本招技能（各有逐字文案）。
      inquiries = {
        夺命连环 = {
          kind = "sect_master_grant"
          gate_order = "lpc_honghua"
          perform_id = "lianhuan-mizongtui/lian"
          skill = "lianhuan-mizongtui"
          min_levels = {
            force = 150
            dodge = 150
            max_neili = 1800
            lianhuan_mizongtui = 120
          }
          level_order = ["force", "dodge", "max_neili", "lianhuan_mizongtui"]
          level_deny = {
            force = "你的内功火候不足，学不成这招。"
            dodge = "你的轻功火候不足，学不成这招。"
            max_neili = "你的内力修为不够，学不成这招。"
            lianhuan_mizongtui = "你的连环迷踪腿还练得不到家，自己下去练练再来吧！"
          }
          min_gongxian = 600
          min_shen = 50000
          cost_gongxian = 600
          family = "红花会"
          maxed = "这招俺不是已经教给你了吗？"
          family_deny = "和本会素无瓜葛，何出此言？"
          skill_deny = "你连连环迷踪腿都没学，还谈什么绝招可言？"
          gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
          shen_deny = "你侠义正事做得不够，这招我不能传你。"
          msg_one = "$n大笑数声，对$N说道：“想不到你的腿法居然能有如此造诣，今日我传你这招又何妨？”说罢，$n随即摆开架势，慢慢的演示招数。"
          learned = "你学会了「夺命连环」。"
          improve_skills = ["unarmed", "lianhuan_mizongtui", "martial_cognize"]
        }

        追魂夺命 = {
          kind = "sect_master_grant"
          gate_order = "lpc_honghua"
          perform_id = "zhuihun-jian/zhui"
          skill = "zhuihun-jian"
          min_levels = {
            force = 120
            max_neili = 800
            zhuihun_jian = 100
          }
          level_order = ["force", "max_neili", "zhuihun_jian"]
          level_deny = {
            force = "你的内功火候不足，学不成这招。"
            max_neili = "你的内力修为不够，学不成这招。"
            zhuihun_jian = "你的追魂夺命剑还练得不到家，自己下去练练再来吧！"
          }
          min_gongxian = 300
          min_shen = 35000
          cost_gongxian = 300
          family = "红花会"
          maxed = "自己下去练，别跟我纠缠个没完！"
          family_deny = "和本会素无瓜葛，何出此言？"
          skill_deny = "你连追魂夺命剑都没学，还谈什么绝招可言？"
          gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
          shen_deny = "你侠义正事做得不够，这招我不能传你。"
          msg_one = "$n点了点头，从怀中轻轻取出了一本剑谱，指着其中一段对$N细说良久，$N一边听一边点头。"
          learned = "你学会了「追魂夺命」。"
          improve_skills = ["sword", "zhuihun_jian", "martial_cognize"]
        }

        诛天刹神 = {
          kind = "sect_master_grant"
          gate_order = "lpc_honghua"
          perform_id = "zhuihun-jian/zhu"
          skill = "zhuihun-jian"
          min_levels = {
            force = 200
            max_neili = 1800
            zhuihun_jian = 160
          }
          level_order = ["force", "max_neili", "zhuihun_jian"]
          level_deny = {
            force = "你的内功火候不足，学不成这招。"
            max_neili = "你的内力修为不够，学不成这招。"
            zhuihun_jian = "你的追魂夺命剑还练得不到家，自己下去练练再来吧！"
          }
          requires_performs = ["zhuihun-jian/zhui"]
          requires_perform_deny = "这招是由「追魂夺命」演化而来，等你通晓那招后再来吧。"
          min_gongxian = 1200
          min_shen = 80000
          cost_gongxian = 1200
          family = "红花会"
          maxed = "多说无益，赶快去练功，以后行侠仗义就靠你们了。"
          family_deny = "和本会素无瓜葛，何出此言？"
          skill_deny = "你连追魂夺命剑都没学，还谈什么绝招可言？"
          gongxian_deny = "你在会中所作的贡献还不够，这招我不忙传你。"
          shen_deny = "你侠义正事做得不够，这招我不能传你。"
          msg_one = "$n凝视了$N好一会儿，随即大笑数声，赞道：“不错，不错。今日我传你这招，可要看好了！”$n话音刚落，随即便一声清啸，手中长剑龙吟不止，迸出万道光华疾闪而过。顿时只见石屑飞溅，只听“嗤”的一声，$N对面的青石桌案竟已被$n手中长剑激荡出的剑芒贯穿，砖地尚留下碗口粗的大洞，直看得$N目瞪口呆，半天说不出一句话。"
          learned = "你学会了「诛天刹神」。"
          improve_skills = ["sword", "zhuihun_jian", "martial_cognize"]
        }
      }

'''
seg = seg[:old_inq_start] + new_inq + seg[old_inq_end:]

marker = '      # LPC: kungfu/class/honghua/wuchen.c\n      #   create_family'
assert seg.count(marker) == 1
apprentice = '''      # LPC kungfu/class/honghua/honghua.h permit_recruit 三问 +
      # kungfu/class/honghua/wuchen.c attempt_apprentice:
      # permit → shen 20000 → combat_exp 350000 → 红花心法 80 → sword 80。
      apprentice = {
        family = "红花会"
        permit_recruit = true
        betray_sect_deny = "我们红花会四大戒条你还记得吗？亏你还有脸回来！"
        betray_times_deny = "哼，阁下不忠不信，我们红花会可不会收留。"
        other_family_deny = "阁下既有了师承，还来我们红花会做什么？"
        min_shen = 20000
        min_shen_deny = "你非我侠义中人，我不能收你。"
        min_exp = 350000
        min_exp_deny = "你的江湖经验太浅，就算收了你，恐怕也难有作为。"
        min_skills = {
          honghua_xinfa = 80
          sword = 80
        }
        recruit_skill_order = ["honghua_xinfa", "sword"]
        min_skills_deny = {
          honghua_xinfa = "你内功修炼得太差，下去把本门的心法练好了再来。"
          sword = "你的剑法练成这样，叫我如何传你精深的剑技？"
        }
        accept_msg = "既然如此，那你以后就跟着我好了。"
      }

      chat_chance_combat = 100
      chat_msg_combat = ["sword.zhu", "sword.zhui", "unarmed.lian", "powerup", "recover"]

'''
seg = seg.replace(marker, apprentice + marker)

text = text[:start] + seg + text[end:]
p.write_bytes(text.replace("\r\n", "\n").encode("utf-8"))
print("step C ok:", len(text), "chars")
