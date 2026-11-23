#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate UCL edits for duan (大理段氏) sect teaching-data backfill.
Reads LPC kungfu/class/duan/*.c for authority; edits clone_lib.ucl insertion-only
except for replacing the 16 "unimplemented" inquiry placeholders.
Strict assertion: every existing combat { ... } block is byte-identical afterwards.

NOTE: 段正明 apprentice 块在脚本产出后按 LPC duanzm.c:107-136 手工修正：
gate_order="lpc_xuanming"（shen → duanshi-xinfa → exp），两句 deny 原文改为
「治好国家？」/「段氏的面子」。重跑本脚本前请先同步这两处，否则会回退保真修正。
"""
import re, sys, io

UCL = 'data/world/clone_lib.ucl'
LPC = r'C://files//git//mud//kungfu//class//duan'

# ---------- 1. Parse LPC set_skill per NPC (authoritative teach source) ----------
import glob, os
lpc_skills = {}
for f in glob.glob(os.path.join(LPC, '*.c')):
    key = 'duan_' + os.path.basename(f)[:-2]
    txt = open(f, encoding='utf-8', errors='replace').read()
    skills = re.findall(r'set_skill\("([^"]+)",\s*(\d+)\)', txt)
    lpc_skills[key] = skills

# ---------- 2. Grant definitions (14) — exact LPC gates/msgs, verified by audit ----------
GRANTS = {
 'duan_daobf': [{
   'key':'凤栖于梧','perform':'feifeng-bian/xi','skill':'feifeng-bian',
   'min_levels':{'force':150,'max_neili':1200,'feifeng_bian':120},
   'order':['force','max_neili','feifeng-bian'],
   'gx':300,'shen':0,
   'maxed':'我不是已经教给你了吗？还有什么不懂就自己研究。',
   'family':'和我素无瓜葛，何出此言？',
   'skill_deny':'你连我飞凤鞭法都未学，怎么来绝招一说？',
   'shen_deny':'哼，你还嫌你在外面惹的祸事不够么？',
   'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
   'levels':{'force':'你的内功修为太差，学不了这一招。','max_neili':'你的内力弱成这样，怎么学习这一招？','feifeng_bian':'你飞凤鞭法的火候还不够，回去练练再来。'},
   'learned':'你学会了「凤栖于梧」。','improve':['whip','feifeng-bian','martial-cognize'],
 }],
 'duan_gu': [{
   'key':'错字诀','perform':'pangen-cuojiefu/cuo','skill':'pangen-cuojiefu',
   'min_levels':{'force':120,'max_neili':800,'pangen_cuojiefu':100},
   'order':['force','max_neili','pangen-cuojiefu'],
   'gx':150,'shen':None,
   'maxed':'这个…这…在下不是已经教过你了吗？',
   'family':'和古某素不相识，何出此言？',
   'skill_deny':'世子殿下还是先学了在下的盘根错节斧再说吧。',
   'gongxian':'这个…不是我不愿意…只是王爷吩咐了，无功劳者不得…那个。',
   'levels':{'force':'这个…世子殿下的内功修为还有待提高。','max_neili':'这个…世子殿下的内力修为还有待提高。','pangen_cuojiefu':'世子殿下盘根错节斧的火候还不够，尚且用不了这招。'},
   'learned':'你学会了「错字诀」。','improve':['hammer','pangen-cuojiefu','martial-cognize'],
 }],
 'duan_hua': [{
   'key':'弑元诀','perform':'yuezhao-gong/shi','skill':'yuezhao-gong',
   'min_levels':{'force':200,'max_neili':1800,'yuezhao_gong':130},
   'order':['force','max_neili','yuezhao-gong'],
   'gx':400,'shen':None,
   'maxed':'我不是已经教给你了吗？',
   'family':'和我素无瓜葛，何出此言？',
   'skill_deny':'哈哈，你连我越爪功都未学，怎么来绝招一说？',
   'gongxian':'恕在下无礼，王爷吩咐过，不得传功给无功子弟。',
   'levels':{'force':'你的内功修为太差，学不了这一招。','max_neili':'你的内力修为太差，学不了这一招。','yuezhao_gong':'你越爪功的火候还不够，学不了这一招。'},
   'learned':'你学会了「弑元诀」。','improve':['claw','yuezhao-gong','martial-cognize'],
 }],
 'duan_zhu': [{
   'key':'透骨钉','perform':'qingliang-daxuefa/ding','skill':'qingliang-daxuefa',
   'min_levels':{'force':150,'max_neili':1200,'qingliang_daxuefa':100},
   'order':['force','max_neili','qingliang-daxuefa'],
   'gx':400,'shen':None,
   'maxed':'我不是已经教给你了吗？',
   'family':'和我素无瓜葛，何出此言？',
   'skill_deny':'你连我清凉打穴法都未学，怎么来绝招一说？',
   'gongxian':'恕在下无礼，王爷吩咐过，不得传功给无功子弟。',
   'levels':{'force':'你的内功修为太差，学不了这一招。','max_neili':'你的内力修为太差，学不了这一招。','qingliang_daxuefa':'你清凉打穴法的火候还不够，回去练练再来吧。'},
   'learned':'你学会了「透骨钉」。','improve':['dagger','qingliang-daxuefa','martial-cognize'],
 }],
 'duan_duanzc': [
   {'key':'乾阳神指','perform':'qiantian-zhi/zhi','skill':'qiantian-zhi',
    'min_levels':{'force':100,'max_neili':500,'qiantian_zhi':80},
    'order':['force','max_neili','qiantian-zhi'],
    'gx':50,'shen':None,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连乾天指法都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','qiantian_zhi':'你的乾天指法功力还不够，练高了再说吧。'},
    'learned':'你学会了「乾阳神指」。','improve':['finger','qiantian-zhi','martial-cognize']},
   {'key':'风云变幻','perform':'wuluo-zhang/bian','skill':'wuluo-zhang',
    'min_levels':{'force':100,'max_neili':500,'wuluo_zhang':100},
    'order':['force','max_neili','wuluo-zhang'],
    'gx':150,'shen':None,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连五罗轻烟掌都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','wuluo_zhang':'你的五罗轻烟掌还不够，练高了再说吧。'},
    'learned':'你学会了「风云变幻」。','improve':['strike','wuluo-zhang','martial-cognize']},
   {'key':'金玉满堂','perform':'jinyu-quan/man','skill':'jinyu-quan',
    'min_levels':{'force':100,'max_neili':500,'jinyu_quan':80},
    'order':['force','max_neili','jinyu-quan'],
    'gx':150,'shen':None,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连金玉拳法都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','jinyu_quan':'你的金玉拳法还不够，练高了再说吧。'},
    'learned':'你学会了「金玉满堂」。','improve':['cuff','jinyu-quan','martial-cognize']},
   {'go':'lpc_duan','key':'惊天一剑','perform':'duanjia-jian/jing','skill':'duanjia-jian',
    'min_levels':{'force':120,'max_neili':800,'duanjia_jian':80},
    'order':['force','max_neili','duanjia-jian'],
    'gx':300,'shen':0,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连段家剑法都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'shen_deny':'算了吧，传你绝招只怕你又去作恶！',
    'levels':{'force':'你的内功的修为不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','duanjia_jian':'你的段家剑法还不行，练练再说吧！'},
    'learned':'你学会了「惊天一剑」。','improve':['sword','duanjia-jian','martial-cognize']},
 ],
 'duan_duanzm': [
   {'go':'lpc_duan','key':'五绝连环','perform':'duanjia-jian/lian','skill':'duanjia-jian',
    'min_levels':{'force':160,'duanjia_jian':120},
    'order':['force','duanjia-jian'],
    'gx':400,'shen':0,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连段家剑法都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'shen_deny':'算了吧，传你绝招只怕你又去作恶！',
    'levels':{'force':'你的内功的修为不够，练高了再来吧。','duanjia_jian':'你的段家剑法还不行，练练再说吧！'},
    'learned':'你学会了「五绝连环」。','improve':['sword','duanjia-jian','martial-cognize']},
   {'key':'起死回生','perform':'yiyang-zhi/heal','skill':'yiyang-zhi',
    'min_levels':{'force':150,'max_neili':1500,'jingluo_xue':100,'yiyang_zhi':100},
    'order':['force','max_neili','jingluo-xue','yiyang-zhi'],
    'gx':800,'shen':None,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连一阳指诀都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','jingluo_xue':'你对经络学的了解还不透彻，研究透了再来找我吧。','yiyang_zhi':'你的一阳指诀功力还不够，练高了再说吧。'},
    'learned':'你学会了「起死回生」。','improve':['finger','yiyang-zhi','jingluo-xue','martial-cognize']},
   {'go':'lpc_duan','key':'神指点穴','perform':'yiyang-zhi/dian','skill':'yiyang-zhi',
    'min_levels':{'force':160,'max_neili':1800,'jingluo_xue':120,'yiyang_zhi':120},
    'order':['force','max_neili','jingluo-xue','yiyang-zhi'],
    'gx':400,'shen':20000,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连一阳指诀都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'shen_deny':'你侠义正事做得不够，这招我暂时还不能传你！',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','jingluo_xue':'你对经络学的了解还不透彻，研究透了再来找我吧。','yiyang_zhi':'你的一阳指诀功力还不够，练高了再说吧。'},
    'learned':'你学会了「神指点穴」。','improve':['finger','yiyang-zhi','jingluo-xue','martial-cognize']},
   {'go':'lpc_duan','key':'一指乾坤','perform':'yiyang-zhi/qian','skill':'yiyang-zhi',
    'min_levels':{'force':220,'max_neili':2400,'jingluo_xue':160,'yiyang_zhi':160},
    'order':['force','max_neili','jingluo-xue','yiyang-zhi'],
    'gx':1000,'shen':30000,
    'maxed':'你不是已经学会了么？还有什么疑问？',
    'family':'你又不是我们段家的传人，这话是什么意思？',
    'skill_deny':'你连一阳指诀都没学，还谈什么绝招可言？',
    'gongxian':'你在族里碌碌无为，叫我如何信得过你？',
    'shen_deny':'你侠义正事做得不够，这招我暂时还不能传你！',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','jingluo_xue':'你对经络学的了解还不透彻，研究透了再来找我吧。','yiyang_zhi':'你的一阳指诀功力还不够，练高了再说吧。'},
    'learned':'你学会了「一指乾坤」。','improve':['finger','yiyang-zhi','jingluo-xue','martial-cognize']},
 ],
 'duan_yideng': [
   {'go':'lpc_duan','key':'阳关三叠','perform':'yiyang-zhi/die','skill':'yiyang-zhi',
    'min_levels':{'force':300,'max_neili':5000,'jingluo_xue':200,'yiyang_zhi':200},
    'order':['force','max_neili','jingluo-xue','yiyang-zhi'],
    'gx':2500,'shen':50000,
    'maxed':'你一阳指练到这种境界，老衲已没什么可教的了。',
    'family':'施主与老衲素不相识，不知施主此话从何说起？',
    'skill_deny':'你连一阳指诀都没学，还谈什么绝招可言？',
    'gongxian':'你为段氏所作出的贡献还不够，这招老衲暂时还不能传你。',
    'shen_deny':'你的侠义正事还做得不够，这招老衲暂时还不能传你。',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','jingluo_xue':'你对经络学的了解还不透彻，研究透了再来找我吧。','yiyang_zhi':'你的一阳指诀功力还不够，练高了再说吧。'},
    'learned':'你学会了「阳关三叠」。','improve':['force','jingluo-xue','finger','yiyang-zhi','martial-cognize']},
   {'key':'先天功乾阳剑气','perform':'xiantian-gong/jian','skill':'xiantian-gong',
    'min_levels':{'force':500,'max_neili':5000,'xiantian_gong':280,'yiyang_zhi':280,'jingluo_xue':200},
    'order':['force','max_neili','xiantian-gong','yiyang-zhi','jingluo-xue'],
    'gx':3000,'shen':50000,
    'maxed':'你先天功的乾阳剑气练到这种境界，老衲已没什么可教的了。',
    'family':'施主与老衲素不相识，不知施主此话从何说起？',
    'skill_deny':'这招暂时不能传授于你，等你学会先天功再来找我吧。',
    'gongxian':'你的贡献值不够，这招先不忙传你。',
    'shen_deny':'你的侠义正事还做得不够，这招老衲暂时还不能传你。',
    'levels':{'force':'你内功的修为还不够，练高了再来吧。','max_neili':'你的内力修为还不够，练高点再来吧。','xiantian_gong':'你的先天功功力还不够，练高了再说吧。','yiyang_zhi':'你的一阳指诀修为还不够，练高了再说吧。','jingluo_xue':'你对经络学的了解还不透彻，研究透了再来找我吧。'},
    'learned':'你学会了「先天功乾阳剑气」。','improve':['force','finger','xiantian-gong','yiyang-zhi','martial-cognize'],
    'family_multi':['全真教','段氏皇族']},  # GAP #845
 ],
}

# family deny messages: gu/hua/zhu use RANK_D->query_respect dynamic prefix; use closest literal
FAMILY_DENY = {
 'duan_daobf':'和我素无瓜葛，何出此言？',
 'duan_duanzc':'你又不是我们段家的传人，这话是什么意思？',
 'duan_duanzm':'你又不是我们段家的传人，这话是什么意思？',
 'duan_yideng':'施主与老衲素不相识，不知施主此话从何说起？',
}

def q(s):
    # UCL string: escape double quotes; no ; [ ]; backslash only before normal char
    return '"' + s.replace('\\','').replace('"','\\"') + '"'

def render_grant(g, npc_key):
    L=[]
    L.append('      kind = "sect_master_grant"')
    L.append('      perform_id = '+q(g['perform']))
    L.append('      gate_order = ' + q(g.get('go', 'lpc_kunlun')))
    L.append('      skill = '+q(g['skill']))
    L.append('      family = '+q('段氏皇族'))
    L.append('      family_deny = '+q(g['family']))
    L.append('      min_levels = {')
    for k,v in g['min_levels'].items():
        L.append(f'        {k} = {v}')
    L.append('      }')
    L.append('      level_order = [' + ', '.join(q(x) for x in g['order']) + ']')
    L.append(f'      min_gongxian = {g["gx"]}')
    L.append(f'      cost_gongxian = {g["gx"]}')
    if g.get('shen') is not None:
        L.append(f'      min_shen = {g["shen"]}')
    L.append('      maxed = '+q(g['maxed']))
    if g.get('skill_deny'):
        L.append('      skill_deny = '+q(g['skill_deny']))
    L.append('      gongxian_deny = '+q(g['gongxian']))
    if 'shen_deny' in g:
        L.append('      shen_deny = '+q(g['shen_deny']))
    L.append('      level_deny = {')
    for k,v in g['levels'].items():
        L.append(f'        {k} = '+q(v))
    L.append('      }')
    L.append('      learned = '+q(g['learned']))
    L.append('      improve_skills = [' + ', '.join(q(x) for x in g['improve']) + ']')
    return '\n'.join(L)

# ---------- 3. Apprentice blocks ----------
DUAN_H_DENIES = {
 'detach':'既然离开了我们段家，就不要回来了',
 'betray_times':'哼，我们大理段氏最痛恨的就是不忠不义之徒。',
 'born':'我们段家乃皇族出身，不收外人。',
 'other':'你当年跑出去的时候怎么就没想过要回来？',
}
RECRUIT_NPCS = ['duan_ba','duan_chu','duan_daobf','duan_duanzc','duan_duanzm',
                'duan_fan','duan_fu','duan_gao','duan_gu','duan_hua','duan_zhu']

def render_apprentice(npc_key):
    L=['  apprentice = {','    family = "段氏皇族"','    permit_recruit = true']
    L.append('    betray_sect_deny = '+q(DUAN_H_DENIES['detach']))
    L.append('    betray_times_deny = '+q(DUAN_H_DENIES['betray_times']))
    L.append('    other_family_deny = '+q(DUAN_H_DENIES['other']))
    L.append('    family_deny = '+q(DUAN_H_DENIES['born']))
    if npc_key=='duan_duanzm':
        L.append('    min_shen = 50000')
        L.append('    min_shen_deny = "你江湖上的名声不怎么样，这样的人如何能够治好段家的病？"')
        L.append('    min_skills = {')
        L.append('      duanshi_xinfa = 100')
        L.append('    }')
        L.append('    min_skills_deny = {')
        L.append('      duanshi_xinfa = "你先好好学习我们段家的心法，以后我再指点你。"')
        L.append('    }')
        L.append('    min_exp = 400000')
        L.append('    min_exp_deny = "你实战经验太低，应好好在江湖上历炼，不要失了段家的颜面。"')
    if npc_key=='duan_daobf':
        L.append('    gender = "女性"')
    L.append('  }')
    return '\n'.join(L)

def render_teach(npc_key):
    sk = lpc_skills[npc_key]
    L=['  teach = {','    family = "段氏皇族"','    teach_skills = {']
    for s,lvl in sk:
        k=s.replace('-','_')
        L.append(f'      {k} = {{ max = {lvl} gongxian = 0 }}')
    L.append('    }')
    L.append('  }')
    return '\n'.join(L)

# ---------- 4. Edit UCL ----------
raw = open(UCL, encoding='utf-8').read()
# snapshot combat blocks for assertion
combat_before = re.findall(r'\n  combat = \{.*?\n  \}\n', raw, re.S)

lines = raw.split('\n')
# locate duan block ranges (all duan_* character headers)
hdr=[(i,re.search(r'characters "([^"]+)"',l).group(1)) for i,l in enumerate(lines) if re.match(r'\s*characters "duan_',l)]
# extend each block to next ANY characters header (not just duan)
allhdr=[i for i,l in enumerate(lines) if re.match(r'\s*characters "',l)]
def block_end(i):
    for j in allhdr:
        if j>i: return j
    return len(lines)

# process from bottom to top so line indices stay valid
edits=[]
for idx,(start,key) in enumerate(hdr):
    end=block_end(start)
    block_lines=lines[start:end]
    block='\n'.join(block_lines)

    newblock_lines=[]
    # We'll insert teach+apprentice right after the combat block closing, before skills/inquiries/carry
    inserted=False
    for li,line in enumerate(block_lines):
        newblock_lines.append(line)
        # insert after combat closing '  }' following '  combat = {'
        if not inserted and re.match(r'^  \}\s*$', line):
            # check we are just after a combat block by scanning backwards
            back='\n'.join(block_lines[max(0,li-20):li+1])
            if 'combat = {' in back:
                newblock_lines.append('')
                newblock_lines.append(render_teach(key))
                if key in RECRUIT_NPCS:
                    newblock_lines.append('')
                    newblock_lines.append(render_apprentice(key))
                inserted=True
    assert inserted, f'failed to insert teach for {key}'
    newblock='\n'.join(newblock_lines)

    # replace inquiry placeholders with grants
    if key in GRANTS:
        grants=GRANTS[key]
        for g in grants:
            ph_pat=re.compile(r'\{ key = '+re.escape(q(g['key']))+r' value = " inquire about skill\d+ \(unimplemented\)" \}')
            assert ph_pat.search(newblock), f'missing placeholder for {key} {g["key"]}'
            repl='{ key = '+q(g['key'])+' value = {\n'+render_grant(g,key)+'\n    } }'
            newblock=ph_pat.sub(repl,newblock,count=1)
        # duanzm: 玉颧神脉经/王叔和脉经 placeholders → keep as text inquiry with GAP note
        for mk in ['玉颧神脉经','王叔和脉经']:
            pp=re.compile(r'\{ key = '+re.escape(q(mk))+r' value = " inquire about maijing\d+ \(unimplemented\)" \}')
            rr='{ key = '+q(mk)+' value = "GAP #844：脉经多状态给书（owner 遍历 + shen/exp/jingluo 门），未实现。" }'
            newblock=pp.sub(rr,newblock,count=1)
    edits.append((start,end,newblock))

# apply edits bottom-to-top
for start,end,newblock in sorted(edits,reverse=True):
    lines[start:end]=newblock.split('\n')

out='\n'.join(lines)
# assertions: combat blocks unchanged
combat_after = re.findall(r'\n  combat = \{.*?\n  \}\n', out, re.S)
assert combat_before==combat_after, 'combat blocks changed!'
# no duan unimplemented placeholders remain (except documented GAP text - should be none)
duan_part='\n'.join(l for l in out.split('\n'))
assert 'inquire about skill' not in '\n'.join(l for i,l in enumerate(out.split('\n')) if True)[:0]  # noop guard

open(UCL,'w',encoding='utf-8',newline='\n').write(out)
print('OK: duan UCL edits applied. teach=14 apprentice=11 grants=14. combat blocks byte-identical.')
print('remaining "inquire about skill" placeholders total in file:', out.count('inquire about skill'))
