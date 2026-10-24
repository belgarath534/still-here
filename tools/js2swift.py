#!/usr/bin/env python3
"""Converts the story part of the web version (index.html) to Swift.

It handles the regular patterns (scenes, sound option objects, choices, arrow functions,
loops, string joining). Data tables and engine code are written by hand and skipped here.
Anything it can't convert is left with a /*FIX*/ marker so the compiler points at it.
"""
import re, sys

SRC, OUT = sys.argv[1], sys.argv[2]
START, STOP = 'let frontVisitor', 'scene("credits"'

SKIP_FUNCS = set("""noise tone drip heartbeat heartStop buzz whoosh boom chime birds steps len ramp rain engine carDoor skid
silenceAll pick shuffle scream after cancelTimers wait say clearScene show uiClick listening go scene die radio wipers hum
shopChime gravel thunderSoon bells fob pound crash siren squelch buzzer conc crawl wind fire ring owl say2 tapeClick tape
monitor playReversed holdStill drips city unplug emergencyAlert recordVoice settingsPanel start boot checkAnswer menuMusic
markEnding findTape hardOr saveStory markDone saveOpts loadOne loadSounds loadChapter chapterKey makePanner setPos play
stopAll music musicCut unlockAudio wakeAudio openPause closePause chapterOf epilogue""".split())
SKIP_VARS = set("""opts done endings tapesFound ENDINGS TAPES SFX MUSIC CH_SFX chLoaded BED SCENE_MUSIC QUIET SCENES MENUS to
CHAPTERS act4Open offCar offCh4 offCh5 offAct2 offAct4 DIRS CREDITS rainNodes engineNodes radioNodes wiperTimer humNodes
bellTimer poundTimer windNodes fireNodes popTimer ringTimer beepTimer heartTimer birdTimer noiseBuf musicNow dripTimer
cityNodes dannyKept alertNoted toldTruth closeness Q PLEAS STATIONS ROOMS ROOMS4 BURN DELETE SPELL""".split())

# parameter types for story functions: name -> Swift parameter list
PARAMS = {
    "dodge": "_ side: Double", "lockPress": "_ side: Double", "unlockSide": "_ side: Double",
    "sneakShow": "_ text: String", "breatheLoop": "_ firstWait: Double? = nil", "junctionPick": "_ side: Double",
    "c5doorChoices": "_ v: String, _ text: String, _ asked: Bool = false", "c5ask": "_ v: String",
    "c6menu": "_ text: String", "tuneTo": "_ v: Double", "climbShow": "_ text: String", "gustLoop": "_ first: Double? = nil",
    "stairPick": "_ dir: Double", "woodsPick": "_ d: Double", "c10act": "_ n: Double", "c13dance": "_ kind: String",
    "huntPick": "_ i: Double",
}
RETURNS = {"playReturn": " -> Double", "returnChoices": " -> [Choice]", "tuneChoices": " -> [Choice]"}
OPTKEYS = set("x y z gain rate delay lowpass phone loop keep to toSec type f f2 dur attack from gap".split())

# ---------- tokenizer ----------
TOK = re.compile(r'''
 (?P<ws>[ \t]+) | (?P<nl>\n) |
 (?P<com>//[^\n]*|/\*.*?\*/) |
 (?P<str>"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*') |
 (?P<num>\d+\.\d+|\d+|\.\d+) |
 (?P<id>[A-Za-z_$][A-Za-z0-9_$]*) |
 (?P<op>===|!==|=>|\+\+|--|\+=|-=|\*=|/=|&&|\|\||<=|>=|==|!=|\.\.\.|[{}()\[\];,.:?=<>+\-*/%!&|@])
''', re.S | re.X)

def tokenize(s):
    out, i = [], 0
    while i < len(s):
        m = TOK.match(s, i)
        if not m: raise SystemExit("tokenize error at: " + s[i:i+60])
        kind = m.lastgroup; text = m.group()
        if kind == 'str' and text.startswith("'"):
            text = '"' + text[1:-1].replace('"', '\\"') + '"'
        out.append([kind, text])
        i = m.end()
    return out

def sig(toks, i, step=1):
    """index of the next significant token from i (inclusive) in direction step"""
    while 0 <= i < len(toks) and toks[i][0] in ('ws', 'nl', 'com'): i += step
    return i

def match(toks, i):
    """index of the bracket matching toks[i]"""
    o = toks[i][1]; c = {'(': ')', '[': ']', '{': '}'}[o]; d = 0
    for j in range(i, len(toks)):
        t = toks[j][1]
        if toks[j][0] != 'op': continue
        if t in '([{': d += 1
        elif t in ')]}':
            d -= 1
            if d == 0: return j
    raise SystemExit("unmatched " + o)

def text(toks): return ''.join(t[1] for t in toks)
def T(s): return tokenize(s)

def split_top(toks, sep=','):
    parts, cur, d = [], [], 0
    for t in toks:
        if t[0] == 'op' and t[1] in '([{': d += 1
        if t[0] == 'op' and t[1] in ')]}': d -= 1
        if d == 0 and t[0] == 'op' and t[1] == sep: parts.append(cur); cur = []
        else: cur.append(t)
    parts.append(cur)
    return parts

def strip(toks):
    a = sig(toks, 0); b = sig(toks, len(toks) - 1, -1)
    return toks[a:b + 1] if a <= b else []

# ---------- pass: skip engine code and data tables ----------
def skip_decls(toks):
    out, i, depth = [], 0, 0
    while i < len(toks):
        k, t = toks[i]
        if depth == 0 and k == 'id':
            j = i
            if t == 'async': j = sig(toks, i + 1)
            if toks[j][1] == 'function':
                name = toks[sig(toks, j + 1)][1]
                if name in SKIP_FUNCS:
                    b = i
                    while toks[b][1] != '{': b += 1
                    i = match(toks, b) + 1
                    continue
            if t in ('const', 'let'):
                name = toks[sig(toks, i + 1)][1]
                if name in SKIP_VARS:
                    d = 0
                    while True:
                        if toks[i][0] == 'op' and toks[i][1] in '([{': d += 1
                        if toks[i][0] == 'op' and toks[i][1] in ')]}': d -= 1
                        if d == 0 and toks[i][1] == ';': break
                        i += 1
                    i += 1
                    continue
            if t == 'try' or (t in ('window', 'document') ):
                # top-level browser statements
                d = 0
                while True:
                    if toks[i][0] == 'op' and toks[i][1] in '([{': d += 1
                    if toks[i][0] == 'op' and toks[i][1] in ')]}': d -= 1
                    if d == 0 and toks[i][1] in (';',) : break
                    if d == 0 and toks[i][1] == '}' and t == 'try': break
                    i += 1
                i += 1
                continue
        if k == 'op' and t in '([{': depth += 1
        if k == 'op' and t in ')]}': depth -= 1
        out.append(toks[i]); i += 1
    return out

# ---------- pass: object literals ----------
OBJ_PREV = {'(', ',', '[', ':', '=', '?', 'return'}

def convert_obj(inner, as_table=False):
    entries = [strip(e) for e in split_top(inner)]
    entries = [e for e in entries if e]
    keys, vals = [], []
    for e in entries:
        if len(e) == 1 and e[0][0] == 'id':
            keys.append(e[0][1]); vals.append(e)
            continue
        c = sig(e, 1)
        if e[0][0] in ('id', 'str', 'num') and c < len(e) and e[c][1] == ':':
            keys.append(e[0][1].strip('"')); vals.append(strip(e[c + 1:]))
        else:
            return None
    if not keys: return T('[]')
    if set(keys) <= {'label', 'act'} and 'label' in keys:
        d = dict(zip(keys, vals))
        return T('Choice(') + d['label'] + T(', ') + d.get('act', T('{}')) + T(')')
    if set(keys) <= OPTKEYS:
        out = T('[')
        for n, (k, v) in enumerate(zip(keys, vals)):
            if n: out += T(', ')
            if k in ('to', 'from') and v and v[0][1] == '[':
                v = v[1:match(v, 0)]
            out += T('.' + k + '(') + v + T(')')
        return out + T(']')
    if all(len(v) == 1 and v[0][0] == 'str' for v in vals) or as_table:
        out = T('[')
        for n, (k, v) in enumerate(zip(keys, vals)):
            if n: out += T(', ')
            out += T('"' + k + '": ') + v
        return out + T(']')
    return None

def objects(toks):
    i = 0
    while i < len(toks):
        if toks[i][1] == '{' and toks[i][0] == 'op':
            p = sig(toks, i - 1, -1)
            if p >= 0 and toks[p][1] in OBJ_PREV:
                j = match(toks, i)
                inner = objects(toks[i + 1:j])
                conv = convert_obj(inner)
                if conv is None: conv = T('/*FIX obj*/{') + inner + T('}')
                toks = toks[:i] + conv + toks[j + 1:]
                i += len(conv)
                continue
        i += 1
    return toks

# ---------- pass: arrow functions ----------
def has_await(toks): return any(t[1] == 'await' for t in toks)

def arrows(toks):
    i = 0
    while i < len(toks):
        if toks[i][1] == '=>':
            # parameters
            p = sig(toks, i - 1, -1)
            if toks[p][1] == ')':
                d = 0
                for q in range(p, -1, -1):
                    if toks[q][1] == ')': d += 1
                    if toks[q][1] == '(': d -= 1
                    if d == 0: break
                params = strip(toks[q + 1:p]); pstart = q
            else:
                params = [toks[p]]; pstart = p
            a = sig(toks, pstart - 1, -1)
            if toks[a][1] == 'async': pstart = a
            # destructured single param
            if params and params[0][1] == '[':
                params = T('(') + params[1:-1] + T(')')
            # body
            b = sig(toks, i + 1)
            if toks[b][1] == '{':
                e = match(toks, b)
                body = arrows(toks[b + 1:e]); end = e + 1
            else:
                d = 0; e = b
                while e < len(toks):
                    t = toks[e]
                    if t[0] == 'op' and t[1] in '([{': d += 1
                    if t[0] == 'op' and t[1] in ')]}':
                        if d == 0: break
                        d -= 1
                    if d == 0 and t[1] in (',', ';'): break
                    e += 1
                body = arrows(toks[b:e]); end = e
            head = '{ '
            if has_await(body): head += '@MainActor '
            if params: head += text(params) + ' in '
            new = T(head) + body + T(' }')
            # rename 2-parameter forEach/map
            before = sig(toks, pstart - 1, -1)
            if toks[before][1] == '(' and len(split_top(params)) == 2 and params[0][1] != '(':
                m = sig(toks, before - 1, -1)
                if toks[m][1] in ('forEach', 'map'): toks[m][1] += 'I'
            toks = toks[:pstart] + new + toks[end:]
            i = pstart + len(new)
            continue
        i += 1
    return toks

# ---------- pass: functions ----------
def functions(toks):
    i = 0
    while i < len(toks):
        if toks[i][1] == 'function':
            a = sig(toks, i - 1, -1)
            is_async = a >= 0 and toks[a][1] == 'async'
            n = sig(toks, i + 1); name = toks[n][1]
            po = sig(toks, n + 1); pc = match(toks, po)
            raw = text(strip(toks[po + 1:pc]))
            params = PARAMS.get(name)
            if params is None:
                params = ', '.join('_ ' + p.strip() + ': /*FIX type*/Any' for p in raw.split(',')) if raw else ''
            head = ('@MainActor func ' if is_async else 'func ') + name + '(' + params + ')' + (' async throws' if is_async else '') + RETURNS.get(name, '')
            start = a if is_async else i
            toks = toks[:start] + T(head) + toks[pc + 1:]
            i = start + 1
            continue
        i += 1
    return toks

# ---------- pass: for loops and brace-less if/else/for ----------
def stmt_end(toks, i):
    d = 0
    while i < len(toks):
        t = toks[i]
        if t[0] == 'op' and t[1] in '([{': d += 1
        if t[0] == 'op' and t[1] in ')]}':
            if d == 0: return i - 1
            d -= 1
        if d == 0 and t[1] == ';': return i
        i += 1
    return i - 1

def braces(toks):
    i = 0
    while i < len(toks):
        t = toks[i][1]
        if toks[i][0] == 'id' and t in ('if', 'for', 'while'):
            po = sig(toks, i + 1); pc = match(toks, po)
            head = toks[po + 1:pc]
            if t == 'for':
                h = text(head)
                m = re.match(r'\s*(?:let|const)\s+(\w+)\s*=\s*0\s*;\s*\1\s*<\s*(.+?);\s*\1\+\+\s*$', h, re.S)
                m2 = re.match(r'\s*(?:let|const)\s+(\[.*?\]|\w+)\s+of\s+(.+)$', h, re.S)
                if m: new = T(' ' + m.group(1) + ' in upTo(' + m.group(2).strip() + ') ')
                elif m2:
                    v = m2.group(1)
                    if v.startswith('['): v = '(' + v[1:-1] + ')'
                    new = T(' ' + v + ' in ' + m2.group(2).strip() + ' ')
                else: new = T('(/*FIX for*/') + head + T(')')
                toks = toks[:po] + new + toks[pc + 1:]
                pc = po + len(new) - 1
            b = sig(toks, pc + 1)
            if toks[b][1] != '{':
                e = stmt_end(toks, b)
                toks = toks[:b] + T('{ ') + toks[b:e + 1] + T(' }') + toks[e + 1:]
        elif toks[i][0] == 'id' and t == 'else':
            b = sig(toks, i + 1)
            if toks[b][1] not in ('{', 'if'):
                e = stmt_end(toks, b)
                toks = toks[:b] + T('{ ') + toks[b:e + 1] + T(' }') + toks[e + 1:]
        i += 1
    return toks

# ---------- pass: joining text with numbers ----------
BOUND = {',', ';', '(', ')', '[', ']', '{', '}', '?', ':', '=', '&&', '||', '==', '!=', '===', '!==', 'return', '<', '>', '<=', '>=', 'in'}

def concat(toks):
    # recurse into groups first
    out, i = [], 0
    while i < len(toks):
        if toks[i][0] == 'op' and toks[i][1] in '([{':
            j = match(toks, i)
            out += [toks[i]] + concat(toks[i + 1:j]) + [toks[j]]
            i = j + 1
        else:
            out.append(toks[i]); i += 1
    toks = out
    # split into regions at depth 0 by boundaries, and process each
    res, region = [], []
    def flush():
        nonlocal region
        res.extend(fix_region(region)); region = []
    i = 0
    while i < len(toks):
        t = toks[i]
        if t[0] == 'op' and t[1] in '([{':
            j = match(toks, i); region += toks[i:j + 1]; i = j + 1; continue
        if t[1] in BOUND and t[0] in ('op', 'id'):
            flush(); res.append(t)
        else: region.append(t)
        i += 1
    flush()
    return res

def fix_region(region):
    parts = split_top(region, '+')
    if len(parts) < 2: return region
    if not any(len(strip(p)) == 1 and strip(p)[0][0] == 'str' for p in parts): return region
    out = []
    for n, p in enumerate(parts):
        if n: out.append(['op', '+'])
        s = strip(p)
        lead = p[:len(p) - len(p.lstrip()) if False else 0]
        if len(s) == 1 and s[0][0] == 'str': out += p
        elif s and s[0][1] == 'str' : out += p
        else:
            a = sig(p, 0); b = sig(p, len(p) - 1, -1)
            out += p[:a] + T('str(') + p[a:b + 1] + T(')') + p[b + 1:]
    return out

# ---------- small rewrites ----------
def small(toks):
    out = []
    for n, t in enumerate(toks):
        k, s = t
        if k == 'op' and s == '===': t = ['op', '==']
        elif k == 'op' and s == '!==': t = ['op', '!=']
        elif k == 'id' and s == 'await': t = ['id', 'try await']
        elif k == 'id' and s in ('const', 'let'): t = ['id', 'var']
        elif k == 'id' and s == 'null': t = ['id', 'nil']
        elif k == 'op' and s in ('++', '--'):
            p = sig(toks, n - 1, -1)
            if toks[p][0] == 'id' or toks[p][1] == ']':
                t = ['op', ' += 1' if s == '++' else ' -= 1']
        out.append(t)
    s = text(out)
    s = re.sub(r'window\.(\w+)', r'\1', s)
    s = s.replace('token++; cancelTimers();', 'cancelTimers();').replace('token += 1; cancelTimers();', 'cancelTimers();')
    s = s.replace('clearTimeout(ringTimer)', 'ringStop()')
    s = re.sub(r'(\w+(?:\.\w+)?\s*%\s*2)\s*\?', r'(\1 != 0) ?', s)
    s = s.replace('.some(', '.contains(where: ')
    # integer literals in declarations and arrays -> Double
    s = re.sub(r'(\bvar\s+\w+\s*=\s*-?\d+)(?![\d.])', r'\1.0', s)
    s = re.sub(r'(,\s*\w+\s*=\s*-?\d+)(?![\d.\w])(?=\s*[,;])', r'\1.0', s)
    return s

def scenes(s):
    """scene("id", { ... }, true); -> registered inside functions, checkpoint flag first"""
    toks = tokenize(s)
    decls, regs, i, depth = [], [], 0, 0
    cur = []
    while i < len(toks):
        k, t = toks[i]
        if depth == 0 and k == 'id' and t == 'scene':
            po = sig(toks, i + 1); pc = match(toks, po)
            args = split_top(toks[po + 1:pc])
            sid = text(strip(args[0])); body = strip(args[1])
            cp = len(args) > 2 and text(strip(args[2])) == 'true'
            e = sig(toks, pc + 1)
            regs.append('    scene(' + sid + (', true' if cp else '') + ') ' + text(body).replace('\n', '\n    ') + '\n')
            i = e + 1 if toks[e][1] == ';' else pc + 1
            continue
        if k == 'op' and t in '([{': depth += 1
        if k == 'op' and t in ')]}': depth -= 1
        decls.append(toks[i]); i += 1
    return text(decls), regs

def main():
    html = open(SRC).read()
    a = html.index(START); b = html.index(STOP)
    js = html[a:b]
    toks = tokenize(js)
    toks = skip_decls(toks)
    toks = objects(toks)
    toks = arrows(toks)
    toks = functions(toks)
    toks = braces(toks)
    toks = concat(toks)
    s = small(toks)
    decls, regs = scenes(s)
    out = ['import Foundation\n\n// Converted from the web version by tools/js2swift.py, then fixed by hand.\n\n', decls, '\n']
    for n in range(0, len(regs), 12):
        out.append('func registerStory%d() {\n' % (n // 12 + 1))
        out.extend(regs[n:n + 12])
        out.append('}\n\n')
    out.append('func registerStory() {\n' + ''.join('    registerStory%d()\n' % (n // 12 + 1) for n in range(0, len(regs), 12)) + '}\n')
    s = ''.join(out)
    s = re.sub(r'\n{3,}', '\n\n', s)
    open(OUT, 'w').write(s)
    print("scenes:", len(regs), "FIX markers:", s.count('/*FIX'))

main()
