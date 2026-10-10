#!/usr/bin/env python3
"""
Enhanced Python port of scripts/translate_perform.exs

Extracts perform/exert data from LPC .c files and generates Elixir skeleton modules
with detailed logic extraction (AP/DP formulas, damage calc, messages, callbacks, etc.).
"""

import os
import re
import sys
from pathlib import Path
from typing import Optional, List, Tuple, Dict, Any, Set


class TranslatePerform:
    def __init__(self):
        # Relative paths (skill_dir/move.ex) that must never be overwritten.
        # These were hand-written BEFORE translate_perform.py existed (the
        # commit-488139fb baseline), so the extractor only generates them if
        # missing; existing content is preserved verbatim.
        self.protected: Set[str] = self.load_protected()
        # Regex patterns ported from Elixir version
        self.perform_re = re.compile(r'^\s*int\s+perform\s*\(', re.MULTILINE)
        self.exert_re = re.compile(r'^\s*int\s+exert\s*\(', re.MULTILINE)
        self.inherit_re = re.compile(r'\binherit\s+(F_\w+)\b')
        self.sense_re = re.compile(r'#define\s+\w+\s*"「"\s*\w*\s*"([^"「」]+)')
        self.level_gate_re = re.compile(r'query_skill\("([a-z0-9-]+)"[^)]*\)+\s*<\s*(\d+)')
        self.assign_re = re.compile(r'(\w+)\s*=\s*[^;\n]*?query_skill\("([a-z0-9-]+)"')
        self.var_gate_re = re.compile(r'\b(\w+)\s*<\s*(\d+)')
        self.map_gate_re = re.compile(r'query_skill_mapped\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"')
        self.prepared_gate_re = re.compile(r'query_skill_prepared\("(\w+)"\)\s*!=\s*"([a-z0-9-]+)"')
        self.resource_gate_re = re.compile(r'query\("(\w+)"[^)]*\)+\s*<\s*(\d+)')
        self.add_re = re.compile(r'\badd\("(\w+)",\s*(-?\d+)\)')
        self.set_re = re.compile(r'\bset\("(\w+)",\s*(\d+)\)')
        self.set_temp_re = re.compile(r'\bset_temp\("(\w+)"')
        self.add_temp_re = re.compile(r'\badd_temp\("apply\/(\w+)"')
        self.affect_re = re.compile(r'\baffect_by\("([a-z_]+)"')
        self.damage_re = re.compile(r'\bdo_damage\(')
        self.busy_re = re.compile(r'^\s*(?:\/\/)?\s*.*\b(?:start_busy|is_busy)\(', re.MULTILINE)
        self.notify_re = re.compile(r'notify_fail\(\s*"([^"\n]+)', re.MULTILINE)
        
        # Enhanced patterns for detailed logic extraction
        self.weapon_check_re = re.compile(r'query_temp\("weapon"\)[^)]*\)\s*\|\|\s*\(string\).*?query\("skill_type"\)\s*!=\s*"(\w+)"')
        self.offensive_target_re = re.compile(r'offensive_target\((\w+)\)')
        self.ap_calc_re = re.compile(r'(\w+)\s*=\s*([^;]+query_skill[^;]+);')
        self.dp_calc_re = re.compile(r'(\w+)\s*=\s*([^;]+query_skill[^;]+);')
        self.hit_formula_re = re.compile(r'if\s*\(\s*([^)]+)\s*>\s*([^)]+)\s*\)')
        self.damage_formula_re = re.compile(r'damage\s*=\s*([^;]+);')
        self.do_damage_detail_re = re.compile(r'do_damage\([^)]+,\s*([^,]+),\s*([^,]+),\s*([^)]+)\)')
        self.affect_by_detail_re = re.compile(r'affect_by\("([^"]+)",\s*\(\[\s*"level"\s*:\s*([^,]+),\s*"id"\s*:\s*([^,]+),\s*"duration"\s*:\s*([^\]]+)\s*\]\)')
        self.msg_construction_re = re.compile(r'msg\s*[+=]\s*([^;]+);')
        self.color_codes_re = re.compile(r'(HIM|HIR|HIC|HIY|HIG|HIB|HIW|NOR|CYN|RED|GRN|YEL|BLU|MAG|WHT)')

        # New patterns for resource / damage / buff / throwing logic (gap analysis)
        self.receive_damage_re = re.compile(
            r'->receive_(damage|wound|heal)\("(\w+)",\s*((?:[^(),\n]|\([^)]*\))+)\s*,\s*(\w+)\)')
        self.receive_damage_2arg_re = re.compile(
            r'->receive_(damage|wound|heal)\("(\w+)",\s*((?:[^(),\n]|\([^)]*\))+)\)')
        self.resource_add_re = re.compile(
            r'\badd\("(neili|qi|jing|max_neili|max_qi|max_jing|combat_exp|shen|food|water|potential|ep|score|gongxian|weiwang|seniority|tianmo|lingtong|liangong)",\s*((?:[^()\n]|\([^)]*\))+)\)')
        self.resource_set_re = re.compile(
            r'\bset\("(neili|qi|jing|max_neili|max_qi|max_jing|combat_exp|shen|food|water|potential|ep|score|gongxian|weiwang|seniority|tianmo|lingtong|liangong)",\s*((?:[^()\n]|\([^)]*\))+)\)')
        self.delete_temp_re = re.compile(r'\bdelete_temp\("([a-z_/]+)"')
        self.start_call_out_re = re.compile(
            r'->start_call_out\(\(:\s*call_other,\s*__FILE__,\s*"(\w+)",\s*((?:[^)]|\n)*?)\s*:\),\s*((?:[^()\n]|\([^)]*\))+)\)')
        self.hit_ob_re = re.compile(r'->hit_ob\((\w+),\s*(\w+),\s*((?:[^(),\n]|\([^)]*\))+)\)')
        self.amount_re = re.compile(r'->(query_amount|set_amount)\(([^)]*)\)')
        self.exp_gate_re = re.compile(r'if\s*\(\s*random\((\w+)\)\s*>\s*(\w+)\)')
        self.ahinfo_re = re.compile(r'COMBAT_D->(clear_ahinfo|query_ahinfo)\(')
        self.neili_query_re = re.compile(r'query\("(neili|max_neili|qi|max_qi|jing|max_jing)"')
        self.query_amount_gate_re = re.compile(r'query_amount\(\)\s*<\s*(\d+)')

        # Patterns for misc gates/formulas lost by the first gap pass (audit)
        self.skill_type_eq_re = re.compile(r'query\("skill_type"\)\s*==\s*"(\w+)"')
        self.combat_exp_formula_re = re.compile(
            r'\b(\w+)\s*=\s*(to_int\(pow\([^;]*?query\("combat_exp"[^;]*?\));')
        self.combat_exp_inline_re = re.compile(
            r'random\((\w+)\)\s*>\s*[^;]*query\("combat_exp"\)')
        self.reset_action_re = re.compile(r'->reset_action\(')
        self.wield_re = re.compile(r'->(wield|unwield|equip|unequip)\(')
        self.improve_skill_re = re.compile(r'improve_skill\(')
        self.misc_gate_re = re.compile(r'query\("(gender|age|family|class)"')
        
    def classify(self, src: Path) -> Tuple[str, Optional[str]]:
        text = src.read_text(encoding='utf-8')

        if self.perform_re.search(text):
            kind = 'perform'
        elif self.exert_re.search(text):
            kind = 'exert'
        else:
            kind = 'skip'

        inherit_match = self.inherit_re.search(text)
        inherit = inherit_match.group(1) if inherit_match else None

        return kind, inherit

    def extract(self, src: Path) -> Optional[Dict[str, Any]]:
        kind, inherit = self.classify(src)

        if kind == 'skip':
            return None

        text = src.read_text(encoding='utf-8')
        # Use correct skill name (grandparent for exert/perform subdirs)
        skill = skill_from_path(src)
        move = src.stem

        # Extract all enhanced data
        weapon_type = self.extract_weapon_type(text)
        target_logic = self.extract_target_logic(text)
        all_fails = self.extract_all_fails(text)
        ap_dp = self.extract_ap_dp(text)
        hit_logic = self.extract_hit_logic(text)
        damage_logic = self.extract_damage_logic(text)
        do_damage_details = self.extract_do_damage_details(text)
        affect_by_details = self.extract_affect_by_details(text)
        messages = self.extract_messages(text)
        color_codes = self.extract_color_codes(text)
        callbacks = self.extract_callbacks(text)

        return {
            'skill': skill,
            'move': move,
            'kind': kind,
            'inherit': inherit,
            'title': self.title_of(text, move),
            # Original gates
            'level_gates': self.pairs(self.level_gate_re.findall(text)),
            'assign_refs': self.pairs(self.assign_re.findall(text)),
            'var_gates': self.pairs(self.var_gate_re.findall(text)),
            'map_gates': self.pairs(self.map_gate_re.findall(text)),
            'prepared_gates': self.pairs(self.prepared_gate_re.findall(text)),
            'resource_gates': self.pairs(self.resource_gate_re.findall(text)),
            # Original effects
            'add_costs': self.pairs(self.dedup(self.add_re.findall(text))),
            'set_flags': self.pairs(self.dedup(self.set_re.findall(text))),
            'temp_set': self.dedup(self.set_temp_re.findall(text)),
            'apply_adds': self.dedup(self.add_temp_re.findall(text)),
            'affect_by': self.dedup(self.affect_re.findall(text)),
            'remote_damage': self.damage_re.search(text) is not None,
            'busy_lines': self.busy_lines(text),
            'first_fail': self.first_fail(text),
            # Enhanced extraction
            'weapon_type': weapon_type,
            'target_logic': target_logic,
            'all_fails': all_fails,
            'ap_dp': ap_dp,
            'hit_logic': hit_logic,
            'damage_logic': damage_logic,
            'do_damage_details': do_damage_details,
            'affect_by_details': affect_by_details,
            'messages': messages,
            'color_codes': color_codes,
            'callbacks': callbacks,
            # Gap-analysis additions: resource / damage / buff / throwing
            'receive_damages': self.extract_receive_damages(text),
            'resource_adds': self.extract_resource_calls(text, 'add'),
            'resource_sets': self.extract_resource_calls(text, 'set'),
            'buff_delete': self.dedup(self.delete_temp_re.findall(text)),
            'call_outs': self.extract_call_outs(text),
            'hit_obs': self.pairs(self.dedup(self.hit_ob_re.findall(text))),
            'amounts': self.dedup(self.amount_re.findall(text)),
            'exp_gates': self.pairs(self.dedup(self.exp_gate_re.findall(text))),
            'ahinfo': self.extract_ahinfo(text),
            'resource_queries': self.dedup(self.neili_query_re.findall(text)),
            'amount_gates': self.dedup(self.query_amount_gate_re.findall(text)),
            # Audit additions: misc gates / formulas
            'weapon_forbidden': self.dedup(self.skill_type_eq_re.findall(text)),
            'combat_exp_formulas': self.pairs(self.dedup(self.combat_exp_formula_re.findall(text))),
            'combat_exp_inline': self.dedup(self.combat_exp_inline_re.findall(text)),
            'reset_actions': self.reset_action_re.search(text) is not None,
            'wield_actions': self.dedup(self.wield_re.findall(text)),
            'improve_skills': self.dedup(self.improve_skill_re.findall(text)),
            'misc_gates': self.dedup(self.misc_gate_re.findall(text)),
        }

    def extract_weapon_type(self, text: str) -> Optional[str]:
        """Extract required weapon skill_type from weapon check."""
        match = self.weapon_check_re.search(text)
        if match:
            return match.group(1)
        # Alternative pattern
        alt = re.search(r'query\("skill_type"\)\s*!=\s*"(\w+)"', text)
        if alt:
            return alt.group(1)
        return None

    def extract_target_logic(self, text: str) -> Dict[str, Any]:
        """Extract target selection logic."""
        return {
            'uses_offensive_target': bool(self.offensive_target_re.search(text)),
            'requires_fighting': 'is_fighting' in text,
            'requires_living': 'living(target)' in text or 'living (target)' in text,
        }

    def extract_all_fails(self, text: str) -> List[str]:
        """Extract all notify_fail messages."""
        return self.notify_re.findall(text)

    def extract_ap_dp(self, text: str) -> Dict[str, Any]:
        """Extract AP/DP calculation formulas."""
        ap_dp = {}
        
        # Find AP calculation (usually: ap = me->query_skill("sword") + me->query_skill("force"))
        ap_matches = re.findall(r'(ap|AP)\s*=\s*([^;]+);', text)
        for var, expr in ap_matches:
            ap_dp[f'{var}_formula'] = expr.strip()
            
        # Find DP calculation (usually: dp = target->query_skill("force") * 2)
        dp_matches = re.findall(r'(dp|DP)\s*=\s*([^;]+);', text)
        for var, expr in dp_matches:
            ap_dp[f'{var}_formula'] = expr.strip()
            
        return ap_dp

    def extract_hit_logic(self, text: str) -> Dict[str, Any]:
        """Extract hit probability formula using proper paren matching."""
        # Find all if conditions with balanced parentheses
        if_matches = list(re.finditer(r'if\s*\(', text))
        
        for match in if_matches:
            start = match.end()
            paren_count = 1
            pos = start
            
            while pos < len(text) and paren_count > 0:
                if text[pos] == '(':
                    paren_count += 1
                elif text[pos] == ')':
                    paren_count -= 1
                pos += 1
            
            if paren_count == 0:
                condition = text[start:pos-1].strip()
                
                # Skip if operator is part of !=, >=, <=
                # Check for comparison operators in order of precedence
                for op in ['>=', '<=', '>', '<']:
                    # Make sure it's not part of !=
                    if op in condition and not (op == '>' and '!=' in condition):
                        left, right = condition.split(op, 1)
                        left = left.strip()
                        right = right.strip()
                        
                        # Check if it's a combat formula: ap/dp in arithmetic context
                        # Must have ap or dp on both sides, with arithmetic operators
                        if (re.search(r'\b(ap|AP|dp|DP)\b', left) and 
                            re.search(r'\b(ap|AP|dp|DP)\b', right) and
                            re.search(r'[+\-*/]', left)):
                            return {
                                'left_side': left,
                                'right_side': right,
                                'operator': op
                            }
        return {}

    def extract_damage_logic(self, text: str) -> Dict[str, Any]:
        """Extract damage calculation formula."""
        dmg_match = re.search(r'damage\s*=\s*([^;]+);', text)
        if dmg_match:
            return {'formula': dmg_match.group(1).strip()}
        return {}

    def extract_do_damage_details(self, text: str) -> List[Dict[str, Any]]:
        """Extract do_damage call details: attack_type, damage_factor, callback."""
        details = []
        # Pattern: do_damage(me, target, WEAPON_ATTACK, damage, 70, (: final, ... :))
        matches = re.finditer(
            r'do_damage\([^,]+,\s*[^,]+,\s*(\w+),\s*([^,]+),\s*(\d+),\s*\(:\s*(\w+)',
            text
        )
        for m in matches:
            details.append({
                'attack_type': m.group(1),
                'damage_var': m.group(2).strip(),
                'damage_factor': int(m.group(3)),
                'callback': m.group(4)
            })
        return details

    def extract_affect_by_details(self, text: str) -> List[Dict[str, Any]]:
        """Extract affect_by callback details: buff name, level formula, id, duration formula."""
        details = []
        # Pattern: target->affect_by("damo_luanqi", ([ "level" : lvl + random(lvl), "id" : me->query("id"), "duration" : 5 + random(lvl / 20) ]))
        matches = re.finditer(
            r'affect_by\("([^"]+)",\s*\(\[\s*"level"\s*:\s*([^,]+),\s*"id"\s*:\s*([^,]+),\s*"duration"\s*:\s*([^\]]+)\s*\]\)',
            text
        )
        for m in matches:
            details.append({
                'buff_name': m.group(1),
                'level_formula': m.group(2).strip(),
                'id_formula': m.group(3).strip(),
                'duration_formula': m.group(4).strip()
            })
        return details

    def extract_messages(self, text: str) -> Dict[str, List[str]]:
        """Extract combat messages (success, fail, etc.)."""
        messages = {'success': [], 'fail': [], 'other': []}
        
        # Extract message_combatd calls and msg += patterns
        msg_lines = re.findall(r'msg\s*[+=]\s*([^;]+);', text)
        for line in msg_lines:
            line = line.strip()
            if 'HIR' in line or '$n' in line and 'HIR' in line:
                messages['success'].append(line)
            elif 'CYN' in line and ('内力深厚' in line or '化解' in line or '没有起到任何作用' in line):
                messages['fail'].append(line)
            else:
                messages['other'].append(line)
                
        return messages

    def extract_color_codes(self, text: str) -> List[str]:
        """Extract ANSI color codes used."""
        return self.dedup(self.color_codes_re.findall(text))

    def extract_callbacks(self, text: str) -> List[Dict[str, Any]]:
        """Extract callback functions (like `final` in luan.c)."""
        callbacks = []
        # Look for function definitions after the main perform function
        func_matches = re.finditer(
            r'(string|int|void)\s+(\w+)\s*\(([^)]*)\)\s*\{([^}]+)\}',
            text,
            re.DOTALL
        )
        for m in func_matches:
            if m.group(2) not in ['perform', 'exert']:
                callbacks.append({
                    'name': m.group(2),
                    'return_type': m.group(1),
                    'params': m.group(3).strip(),
                    'body': m.group(4).strip()[:200]  # truncate for readability
                })
        return callbacks

    def _scan_balanced(self, text: str, start: int, end_char: str = ')') -> int:
        """Return index just past the matching close paren, starting after an
        opening '(' at position `start` (text[start-1] == '('). Handles nesting.
        """
        depth = 1
        i = start
        n = len(text)
        while i < n:
            c = text[i]
            if c == '(':
                depth += 1
            elif c == end_char:
                depth -= 1
                if depth == 0:
                    return i + 1
            i += 1
        return -1

    def _call_args(self, text: str, callee: str) -> List[List[str]]:
        """Extract argument lists of every `->callee(...)` call, splitting on
        top-level commas (parens/strings preserved). Returns list of arg lists.
        """
        results = []
        rx = re.compile(re.escape(callee) + r'\s*\(')
        for m in rx.finditer(text):
            end = self._scan_balanced(text, m.end(), ')')
            if end < 0:
                continue
            inner = text[m.end():end - 1]
            args = []
            depth = 0
            cur = []
            in_str = False
            for ch in inner:
                if ch == '"':
                    in_str = not in_str
                    cur.append(ch)
                elif ch == '(' and not in_str:
                    depth += 1
                    cur.append(ch)
                elif ch == ')' and not in_str:
                    depth -= 1
                    cur.append(ch)
                elif ch == ',' and depth == 0 and not in_str:
                    args.append(''.join(cur).strip())
                    cur = []
                else:
                    cur.append(ch)
            if cur:
                args.append(''.join(cur).strip())
            results.append(args)
        return results

    def extract_resource_calls(self, text: str, verb: str) -> List[Tuple[str, str]]:
        """Extract add("neili", V) / set("neili", V) with V possibly a nested
        expression like -(300 + random(200)). Balanced-paren aware.
        """
        RESOURCES = (
            'neili', 'qi', 'jing', 'max_neili', 'max_qi', 'max_jing',
            'combat_exp', 'shen', 'food', 'water', 'potential', 'ep', 'score',
            'gongxian', 'weiwang', 'seniority', 'tianmo', 'lingtong', 'liangong',
        )
        out = []
        for args in self._call_args(text, f'->{verb}'):
            if len(args) >= 2:
                name = args[0].strip('"').strip()
                if name in RESOURCES:
                    out.append((name, args[1]))
        return self.pairs(self.dedup(out))

    def extract_receive_damages(self, text: str) -> List[Dict[str, Any]]:
        """Extract direct damage/wound/heal calls:
        me->receive_damage("qi", skill * 3 / 2 + random(skill * 3 / 2), me)   (3-arg)
        me->receive_damage("qi", 0)                                          (2-arg, source=None)
        """
        details = []
        for m in self.receive_damage_re.finditer(text):
            kind, part, formula, source = m.groups()
            details.append({
                'kind': kind,
                'part': part,
                'formula': formula.strip(),
                'source': source,
            })
        # 2-arg variant: source is implicit (environment / caller)
        for m in self.receive_damage_2arg_re.finditer(text):
            kind, part, formula = m.groups()
            details.append({
                'kind': kind,
                'part': part,
                'formula': formula.strip(),
                'source': None,
            })
        return details

    def extract_call_outs(self, text: str) -> List[Dict[str, Any]]:
        """Extract delayed callbacks:
        me->start_call_out((: call_other, __FILE__, "remove_effect", me, skill :), skill)
        """
        details = []
        for m in self.start_call_out_re.finditer(text):
            fn, args, delay = m.groups()
            details.append({
                'fn': fn,
                'args': args.strip(),
                'delay': delay.strip(),
            })
        return details

    def extract_ahinfo(self, text: str) -> Dict[str, bool]:
        """COMBAT_D aggregate hit info usage."""
        return {
            'clear': 'clear_ahinfo' in text,
            'query': 'query_ahinfo' in text,
        }

    def title_of(self, text: str, move: str) -> str:
        match = self.sense_re.search(text)
        if match:
            return match.group(1).strip()
        return move

    def first_fail(self, text: str) -> Optional[str]:
        match = self.notify_re.search(text)
        if match:
            return match.group(1)
        return None

    def busy_lines(self, text: str) -> List[str]:
        lines = text.split('\n')
        return [line.strip() for line in lines if self.busy_re.match(line)]

    def dedup(self, items: List) -> List:
        return sorted(list(set(items)))

    def pairs(self, items: List[Tuple]) -> List[Tuple]:
        return sorted(list(set(items)))

    def skill_dir(self, skill: str) -> str:
        return skill.replace('-', '_')

    def camel(self, id_str: str) -> str:
        return ''.join(part.capitalize() for part in id_str.split('-'))

    def module_name(self, skill: str, move: str) -> str:
        return f"Kantele.Combat.Skills.Performs.{self.camel(skill)}.{self.camel(move)}"

    def comment_block(self, text: str, indent: str = "      #   ") -> str:
        return '\n'.join(indent + line for line in text.split('\n'))

    def render_skeleton(self, data: Dict[str, Any]) -> str:
        mod = self.module_name(data['skill'], data['move'])

        gates = {
            'level_gates': data['level_gates'],
            'assign_refs': data['assign_refs'],
            'var_gates': data['var_gates'],
            'map_gates': data['map_gates'],
            'prepared_gates': data['prepared_gates'],
            'resource_gates': data['resource_gates']
        }

        effects = {
            'add_costs': data['add_costs'],
            'set_flags': data['set_flags'],
            'temp_set': data['temp_set'],
            'apply_adds': data['apply_adds'],
            'affect_by': data['affect_by'],
            'remote_damage': data['remote_damage'],
            'busy_lines': data['busy_lines']
        }

        def elixir_fmt(obj):
            """Format Python dict/list/tuple as Elixir map/keyword/list (compact)."""
            if isinstance(obj, dict):
                if not obj:
                    return '%{}'
                items = [f'{elixir_fmt(k)}: {elixir_fmt(v)}' for k, v in sorted(obj.items())]
                return '%{' + ', '.join(items) + '}'
            elif isinstance(obj, list):
                if not obj:
                    return '[]'
                items = [elixir_fmt(v) for v in obj]
                return '[' + ', '.join(items) + ']'
            elif isinstance(obj, tuple):
                return '{' + ', '.join(elixir_fmt(v) for v in obj) + '}'
            elif isinstance(obj, str):
                return f'"{obj}"'
            elif isinstance(obj, bool):
                return 'true' if obj else 'false'
            else:
                return str(obj)

        gates_str = self.comment_block(elixir_fmt(gates))
        effects_str = self.comment_block(elixir_fmt(effects))

        # Enhanced comment blocks
        enhanced = {}
        if data.get('weapon_type'):
            enhanced['weapon_type'] = data['weapon_type']
        if data.get('target_logic'):
            enhanced['target_logic'] = data['target_logic']
        if data.get('all_fails'):
            enhanced['all_fail_messages'] = data['all_fails']
        if data.get('ap_dp'):
            enhanced['ap_dp_formulas'] = data['ap_dp']
        if data.get('hit_logic'):
            enhanced['hit_formula'] = data['hit_logic']
        if data.get('damage_logic'):
            enhanced['damage_formula'] = data['damage_logic']
        if data.get('do_damage_details'):
            enhanced['do_damage_calls'] = data['do_damage_details']
        if data.get('affect_by_details'):
            enhanced['affect_by_callbacks'] = data['affect_by_details']
        if data.get('messages'):
            enhanced['combat_messages'] = data['messages']
        if data.get('color_codes'):
            enhanced['color_codes'] = data['color_codes']
        if data.get('callbacks'):
            enhanced['callback_functions'] = data['callbacks']
        # Gap-analysis additions
        if data.get('receive_damages'):
            enhanced['receive_damage_calls'] = data['receive_damages']
        if data.get('resource_adds'):
            enhanced['resource_adds'] = data['resource_adds']
        if data.get('resource_sets'):
            enhanced['resource_sets'] = data['resource_sets']
        if data.get('buff_delete'):
            enhanced['buff_delete'] = data['buff_delete']
        if data.get('call_outs'):
            enhanced['call_outs'] = data['call_outs']
        if data.get('hit_obs'):
            enhanced['hit_ob_calls'] = data['hit_obs']
        if data.get('amounts'):
            enhanced['amount_calls'] = data['amounts']
        if data.get('exp_gates'):
            enhanced['exp_compare'] = data['exp_gates']
        if data.get('ahinfo') and (data['ahinfo']['clear'] or data['ahinfo']['query']):
            enhanced['combat_d_ahinfo'] = data['ahinfo']
        if data.get('resource_queries'):
            enhanced['resource_queries'] = data['resource_queries']
        if data.get('amount_gates'):
            enhanced['amount_gates'] = data['amount_gates']
        # Audit additions
        if data.get('weapon_forbidden'):
            enhanced['weapon_forbidden'] = data['weapon_forbidden']
        if data.get('combat_exp_formulas'):
            enhanced['combat_exp_formulas'] = data['combat_exp_formulas']
        if data.get('combat_exp_inline'):
            enhanced['combat_exp_inline'] = data['combat_exp_inline']
        if data.get('reset_actions'):
            enhanced['reset_action'] = True
        if data.get('wield_actions'):
            enhanced['wield_actions'] = data['wield_actions']
        if data.get('improve_skills'):
            enhanced['improve_skill'] = data['improve_skills']
        if data.get('misc_gates'):
            enhanced['misc_gates'] = data['misc_gates']

        enhanced_str = self.comment_block(elixir_fmt(enhanced)) if enhanced else ''

        stanzas = '\n'.join(f"      #   - {line}" for line in data['busy_lines'])

        return f'''defmodule {mod} do
  @moduledoc """
  {data['kind']}「{data['title']}」（source {data['skill']}/{data['move']}.c，由 translate_perform.py 骨架生成，inherit {data['inherit'] or "?"}）

  TODO(migrate): 样本人工校对后，把以下门槛/语义写进 check_* 与 apply_effect。
  以上注释行（TODO(migrate)）校对完成后删除。
  """

  import Kalevala.Character.Conn

  alias Kantele.Combat.Broadcast
  alias Kantele.Character.CommandView

  @spec run(Kalevala.Character.Conn.t()) :: Kalevala.Character.Conn.t()
  def run(conn) do
    character = conn.character

    with :ok <- check_gates(character) do
      apply_effect(conn, character)
    else
      {{:error, message}} ->
        conn
        |> render(CommandView, "text", %{{text: message}})
        |> assign(:prompt, false)
    end
  end

  # TODO(migrate) 提取器门槛事实（核对后替换为真实查法）：
{gates_str}
  # TODO(migrate) 增强提取逻辑：
{enhanced_str}
  defp check_gates(_character), do: :ok

  defp apply_effect(conn, character) do
    # TODO(migrate) 提取器效果事实（含目标侧 busy/remote damage，移植后落库）：
{effects_str}
{stanzas}
    conn
    |> Broadcast.publish("-= TODO(migrate) 未移植文案。\\n", n1: character.name)
    |> put_character(character)
    |> assign(:prompt, false)
  end
end
'''

    def load_protected(self) -> Set[str]:
        """Load the set of hand-written perform files that must never be overwritten.

        Reads a newline-separated list of relative paths (e.g. 'bagua_biao/zhi.ex')
        from the PROTECTED_PERFORMS env var file, or from the default location
        next to this script: scripts/protected_performs.txt.
        Returns an empty set when the file is missing (no protection).
        """
        env_file = os.getenv('PROTECTED_PERFORMS')
        candidates = []
        if env_file:
            candidates.append(Path(env_file))
        candidates.append(Path(__file__).resolve().parent / 'protected_performs.txt')

        for path in candidates:
            if path.exists():
                items = {
                    line.strip()
                    for line in path.read_text(encoding='utf-8').splitlines()
                    if line.strip() and not line.strip().startswith('#')
                }
                print(f"translate_perform: protected {len(items)} hand-written files from {path}")
                return items
        print("translate_perform: WARNING no protected list found, will overwrite existing files")
        return set()

    def write_skeleton(self, out_root: Path, skill: str, data: Dict[str, Any]) -> Optional[str]:
        dir_path = out_root / self.skill_dir(skill)
        dir_path.mkdir(parents=True, exist_ok=True)
        file_path = dir_path / f"{data['move']}.ex"
        rel_path = f"{self.skill_dir(skill)}/{data['move']}.ex"
        rendered = self.render_skeleton(data)

        # Never touch hand-written performs: the baseline 155 files were
        # converted before this extractor existed, so skip them entirely.
        if rel_path in self.protected:
            if file_path.exists():
                return None
            print(f"translate_perform: protected file MISSING, generating: {rel_path}")
            file_path.write_text(rendered, encoding='utf-8')
            return str(file_path.relative_to(out_root))

        if file_path.exists() and file_path.read_text(encoding='utf-8') == rendered:
            return None

        file_path.write_text(rendered, encoding='utf-8')
        return str(file_path.relative_to(out_root))

    def run(self, src_root: Path, out_root: Path) -> Dict[str, List[str]]:
        written = []
        skipped = []
        protected_hits = []

        for skill_dir in sorted(src_root.iterdir()):
            if not skill_dir.is_dir():
                continue

            # Use Python's rglob for cross-platform .c file discovery
            c_files = sorted(skill_dir.rglob('*.c'))

            for c_file in c_files:
                src_path = c_file
                data = self.extract(src_path)

                if data is None:
                    rel = src_path.relative_to(src_root)
                    skipped.append(str(rel))
                    continue

                rel_path = f"{self.skill_dir(data['skill'])}/{data['move']}.ex"
                if rel_path in self.protected:
                    protected_hits.append(rel_path)
                    continue

                written_path = self.write_skeleton(out_root, skill_from_path(src_path), data)
                if written_path:
                    written.append(written_path)

        return {
            'written': sorted(written),
            'skipped': sorted(skipped),
            'protected_skipped': sorted(protected_hits)
        }


def skill_from_path(c_file: Path) -> str:
    parent = c_file.parent.name
    # If file is in exert/ or perform/ subdirectory, use grandparent as skill name
    if parent in ('exert', 'perform'):
        return c_file.parent.parent.name
    return parent


def main():
    import os

    src = Path(os.getenv('KUNGFU_SRC', '/app/kungfu_source/kungfu/skill'))
    out = Path(os.getenv('KUNGFU_OUT', '/tmp/perf_out'))

    if not src.exists():
        print(f"Source directory not found: {src}")
        sys.exit(1)

    translator = TranslatePerform()
    result = translator.run(src, out)

    print(f"translate_perform: {result}")


if __name__ == '__main__':
    main()