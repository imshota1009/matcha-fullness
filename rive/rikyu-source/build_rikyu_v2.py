# りきゅうさん v2 の RML を生成する。実行: v2 フォルダで python3 work/build_rikyu_v2.py
# 子の並びは「手前 → 奥」(先に書いたものが手前に描かれる)。
from pathlib import Path
import xml.etree.ElementTree as E
import math, json

P = Path('outputs/rikyu-source'); P.mkdir(parents=True, exist_ok=True)
R = E.Element('Rive', version='1', kind='fragment'); counter = 10; ids = {}

def el(parent, tag, **a):
    global counter
    a = {k: str(v).lower() if isinstance(v, bool) else str(v) for k, v in a.items()}
    counter += 1; a['id'] = f'0:{counter}'
    return E.SubElement(parent, tag, a)

def node(p, name, **a):
    e = el(p, 'Node', name=name, **a); ids[name] = e.attrib['id']; return e

def paints(s, fill=None, stroke=None, w=0):
    if fill:
        f = el(s, 'Fill'); el(f, 'SolidColor', colorValue=fill)
    if stroke:
        st = el(s, 'Stroke', thickness=w, cap='round', join='round'); el(st, 'SolidColor', colorValue=stroke)

def shape(p, name, x=0, y=0, **a):
    e = el(p, 'Shape', name=name, x=x, y=y, **a); ids[name] = e.attrib['id']; return e

def ellipse(p, name, x, y, w, h, fill=None, stroke=None, sw=0):
    s = shape(p, name, x, y); el(s, 'Ellipse', width=w, height=h, originX=.5, originY=.5); paints(s, fill, stroke, sw); return s

def path(p, name, pts, fill=None, stroke=None, sw=0, closed=True):
    """pts: (点, 入ってくる制御点, 出ていく制御点)。制御点が両方 None なら角"""
    s = shape(p, name); v = el(s, 'PointsPath', isClosed=closed)
    for pt, inc, out in pts:
        if inc is None and out is None:
            el(v, 'StraightVertex', x=pt[0], y=pt[1], radius=0)
        else:
            def polar(q):
                if q is None: return (0, 0)
                dx = q[0] - pt[0]; dy = q[1] - pt[1]; return math.atan2(dy, dx), math.hypot(dx, dy)
            ia, il = polar(inc); oa, ol = polar(out)
            el(v, 'CubicDetachedVertex', x=pt[0], y=pt[1], inRotation=ia, inDistance=il, outRotation=oa, outDistance=ol)
    paints(s, fill, stroke, sw); return s

def line(p, name, a, b, c, d, col, w):
    return path(p, name, [(a, None, b), (d, c, None)], stroke=col, sw=w, closed=False)

def smooth(pts, k=0.32):
    """閉じた点列を、なめらかな曲線(Catmull-Rom 風)の (点, 入, 出) に変える"""
    n = len(pts); out = []
    for i, p in enumerate(pts):
        a = pts[i - 1]; b = pts[(i + 1) % n]
        tx, ty = (b[0] - a[0]) * k, (b[1] - a[1]) * k
        out.append((p, (p[0] - tx, p[1] - ty), (p[0] + tx, p[1] + ty)))
    return out

B = '2B1F17'; W = 'FAF9F5'; G = '78736E'; S = 'F5E3CC'; M = '5C7838'
LW = 5  # 輪郭の太さ

a = el(R, 'Artboard', name='Rikyu', width=500, height=500)
style = el(a, 'LayoutComponentStyle', name='Artboard Style'); a.set('styleId', style.attrib['id'])

root = node(a, 'Breathing', x=250, y=420)
squat = node(root, 'Seated')
talk = node(squat, 'Talking sway')
upper = node(talk, 'Bow torso')

# --- 手前: 葉(レベルアップ) ---
leaves = node(upper, 'Leaves', opacity=0)
for i, (x, y) in enumerate([(-112, -200), (0, -262), (112, -212)]):
    n = node(leaves, f'Leaf {i+1}', x=x, y=y)
    path(n, f'Leaf shape {i+1}', [((0, -17), (-15, -6), (15, -6)), ((0, 17), (15, 6), (-15, 6))], fill=M, stroke=B, sw=3)
    line(n, f'Leaf vein {i+1}', (0, -12), (1, -4), (1, 4), (0, 12), W, 2)

# --- 右腕(画面の右): 茶せん・扇子を持つ。肩を支点に回る ---
arm = node(upper, 'Greeting arm', x=52, y=-150)
hand = node(arm, 'Arm hand', x=-24, y=78)
# 扇子(手に持つ)
fan = node(hand, 'Fan', x=0, y=-8, opacity=0, scaleX=.1)
for i, ang in enumerate([-1.0, -.66, -.33, 0, .33, .66, 1.0]):
    line(fan, f'Fan rib {i}', (0, 0), (math.sin(ang) * 22, -math.cos(ang) * 22), (math.sin(ang) * 48, -math.cos(ang) * 48), (math.sin(ang) * 68, -math.cos(ang) * 68), M, 3)
fan_pts = [((0, 0), None, None)]
for i in range(9):
    t = -1.05 + 2.1 * i / 8
    fan_pts.append(((math.sin(t) * 74, -math.cos(t) * 74), None, None))
path(fan, 'Fan paper', fan_pts, fill=W, stroke=B, sw=4)
# 手(袖口から出る)。親指を小さく
ellipse(hand, 'Right thumb', -12, -6, 13, 15, fill=S, stroke=B, sw=4)
ellipse(hand, 'Right hand', 0, 0, 36, 31, fill=S, stroke=B, sw=LW)
# 茶せん(手の中。穂先を下にして茶碗へ)
whisk = node(hand, 'Whisk prop', x=-6, y=2, opacity=0)
for j in range(7):
    x = (j - 3) * 4.2
    line(whisk, f'Whisk tine {j}', (x * .3, 4), (x * .9, 14), (x * 1.25, 26), (x * 1.1, 34), B, 2.5)
path(whisk, 'Whisk handle', [((-6, -30), None, None), ((6, -30), None, None), ((5, 2), None, None), ((-5, 2), None, None)], fill=S, stroke=B, sw=4)
line(whisk, 'Whisk binding', (-6, 0), (-2, 1), (2, 1), (6, 0), B, 4)
# 右の袖: 肩から下へ大きく垂れる袖(袖口は手のほう)
swing = node(arm, 'Sleeve swing')  # 袖は腕より遅れ、腕を上げると重さで垂れる
path(swing, 'Right sleeve', smooth([(-6, -10), (34, 4), (52, 52), (40, 92), (6, 96), (-22, 92), (-34, 70), (-26, 30)]), fill=G, stroke=B, sw=LW)

# --- 茶碗と左手 ---
bowl = node(upper, 'Bowl', x=-4, y=-70)
ellipse(bowl, 'Left hand', -22, 14, 40, 24, fill=S, stroke=B, sw=LW)  # 茶碗を下から支える手(手前)
ellipse(bowl, 'Matcha surface', 0, -10, 52, 11, fill=M)
path(bowl, 'Tea bowl', [((-32, -10), None, (-31, 14)), ((0, 18), (-18, 19), (18, 19)), ((32, -10), (31, 14), None)], fill=W, stroke=B, sw=LW)
line(bowl, 'Bowl rim', (-32, -10), (-12, -16), (12, -16), (32, -10), B, 4)
path(upper, 'Left sleeve', smooth([(-52, -150), (-88, -126), (-100, -84), (-92, -46), (-60, -40), (-36, -48), (-44, -92)]), fill=G, stroke=B, sw=LW)

# --- 頭(首の位置で傾く) ---
head = node(upper, 'Head', x=0, y=-222)
face = node(head, 'Face')
# 口(表情ごと)。会話中は Talking mouth に入れ替わる
mouth = node(face, 'Mouth', x=0, y=42)
m_normal = node(mouth, 'Mouth normal'); line(m_normal, 'Smile', (-9, 0), (-4, 6), (4, 6), (9, 0), B, 4.5)
m_happy = node(mouth, 'Mouth happy', opacity=0)
path(m_happy, 'Big smile', [((-14, -2), None, None), ((14, -2), None, (12, 14)), ((0, 14), (8, 15), (-8, 15)), ((-14, -2), (-12, 14), None)], fill=B, stroke=B, sw=3)
m_cheer = node(mouth, 'Mouth encourage', opacity=0)
path(m_cheer, 'Open smile', [((-9, -2), None, None), ((9, -2), None, (8, 9)), ((0, 10), (5, 10), (-5, 10)), ((-9, -2), (-8, 9), None)], fill=B, stroke=B, sw=3)
m_focus = node(mouth, 'Mouth focus', opacity=0); line(m_focus, 'Calm line', (-6, 2), (-2, 3), (2, 3), (6, 2), B, 4)
openmouth = node(face, 'Talking mouth', x=0, y=44, scaleY=.1, opacity=0); ellipse(openmouth, 'Mouth opening', 0, 0, 13, 14, fill=B)
# 目(表情ごと)。まばたきは Blink の縦の縮み
blink = node(face, 'Blink', y=16)
e_normal = node(blink, 'Smile eyes')
for x in (-34, 34): line(e_normal, f'Smiling eye {x}', (x - 11, 4), (x - 6, -4), (x + 6, -4), (x + 11, 4), B, 5)
e_happy = node(blink, 'Happy eyes', opacity=0)
for x in (-34, 34): line(e_happy, f'Happy eye {x}', (x - 12, 5), (x - 7, -8), (x + 7, -8), (x + 12, 5), B, 6)
e_cheer = node(blink, 'Bright eyes', opacity=0)
for x in (-34, 34): ellipse(e_cheer, f'Bright eye {x}', x, 0, 12, 14, fill=B)
closed = node(blink, 'Quiet eyes', opacity=0)
for x in (-34, 34): line(closed, f'Closed eye {x}', (x - 11, -1), (x - 5, 5), (x + 5, 5), (x + 11, -1), B, 4.5)
# まゆ(灰色。年を重ねた、下がりぎみのやさしい形)。表情で上下する
brows = node(face, 'Brows', y=-6)
for x in (-36, 36):
    o = -1 if x < 0 else 1  # 外側の向き
    # 外側の端が下がる、やさしい弧
    line(brows, f'Brow {x}', (x + 13 * o, 3), (x + 5 * o, -6), (x - 5 * o, -7), (x - 13 * o, -3), G, 6)
# 白ひげ: あごの下に小さく(輪郭線で肌と区別する)
path(face, 'Small white beard', [((-9, 70), None, (-8, 82)), ((0, 90), (-5, 90), (5, 90)), ((9, 70), (8, 82), None)], fill=W, stroke=B, sw=3.5)
# 帽子(利休帽): 頭の上にふっくら乗る丸い頭巾。下のふちは少しだけ顔にかかる。灰色の線で布のたるみ
cap = node(head, 'Cap')
# 頭巾のふちの縫い目と、上のたたみじわ(灰色の線)。おでこが見えるので髪型に見えない
line(cap, 'Cap band', (-70, -58), (-30, -52), (30, -52), (70, -58), G, 4)
line(cap, 'Cap crease', (-4, -106), (-2, -96), (2, -88), (6, -80), G, 4)
path(cap, 'Rikyu cap', [((-72, -46), None, (-80, -78)), ((-46, -106), (-70, -100), (-26, -112)), ((0, -104), (-12, -108), (12, -108)),
                        ((46, -106), (26, -112), (70, -100)), ((72, -46), (80, -78), (40, -38)), ((0, -40), (26, -38), (-26, -38))], fill=B, stroke=B, sw=LW)
# 顔と耳
ellipse(head, 'Face oval', 0, 8, 172, 150, fill=S, stroke=B, sw=LW)
ellipse(head, 'Ear left', -86, 16, 22, 32, fill=S, stroke=B, sw=4)
ellipse(head, 'Ear right', 86, 16, 22, 32, fill=S, stroke=B, sw=4)

# --- 胴(十徳)とえり ---
robe = node(upper, 'Robe')
path(robe, 'White collar', [((-40, -150), None, None), ((0, -108), None, None), ((40, -150), None, None), ((28, -156), None, None), ((0, -126), None, None), ((-28, -156), None, None)], fill=W, stroke=B, sw=3.5)
line(robe, 'Robe seam', (0, -110), (-6, -80), (-12, -40), (-12, -6), B, 4)
path(robe, 'Jittoku robe', smooth([(-48, -172), (0, -178), (48, -172), (84, -128), (96, -60), (88, -12), (40, 2), (-40, 2), (-88, -12), (-96, -60), (-84, -128)], .3), fill=G, stroke=B, sw=LW)
ellipse(root, 'Left foot', -36, 0, 50, 16, fill=B)
ellipse(root, 'Right foot', 36, 0, 50, 16, fill=B)

upper.remove(head); upper.insert(1, head)  # 頭は袖より手前(葉のすぐ後ろ)
upper.remove(bowl); upper.insert(1, bowl)  # 茶碗は頭より手前(飲むとき口元にくる)

# ================= ステートマシン =================
sm = el(a, 'StateMachine', name='Main'); a.set('defaultStateMachineId', sm.attrib['id'])
inputs = {}
for name, t in [('mood', 'Number'), ('isTalking', 'Bool'), ('bow', 'Trigger'), ('wave', 'Trigger'), ('whisk', 'Trigger'), ('cheer', 'Trigger'), ('levelUp', 'Trigger')]:
    inputs[name] = el(sm, 'StateMachine' + t, name=name).attrib['id']
keys = {'x': 13, 'y': 14, 'rotation': 15, 'scaleX': 16, 'scaleY': 17, 'opacity': 18}

def anim(name, duration, tracks, loop=False):
    an = el(a, 'LinearAnimation', name=name, fps=60, duration=duration, loopValue='loop' if loop else 'oneShot')
    for ob, prop, values in tracks:
        ko = el(an, 'KeyedObject', objectId=ids[ob]); kp = el(ko, 'KeyedProperty', propertyKey=keys[prop])
        for f, val in values:
            k = el(kp, 'KeyFrameDouble', frame=f, value=val, interpolationType='cubic')
            el(k, 'CubicEaseInterpolator', x1=.42, y1=0, x2=.58, y2=1)
    return an.attrib['id']

def transition(fr, to, cond=None, exit=False, duration=250):
    tr = el(fr, 'StateTransition', stateToId=to, duration=duration,
            **({'enableExitTime': True, 'exitTimeIsPercetange': True, 'exitTime': 100} if exit else {}))
    if cond:
        name, val = cond
        t = 'Number' if name == 'mood' else 'Bool' if name == 'isTalking' else 'Trigger'
        attrs = {'inputId': inputs[name]}
        if t == 'Number': attrs.update(opValue='equal', value=val)
        if t == 'Bool': attrs.update(opValue='equal' if val else 'notEqual')
        el(tr, 'Transition' + t + 'Condition', **attrs)
    return tr

def layer(name):
    l = el(sm, 'StateMachineLayer', name=name)
    anyst = el(l, 'AnyState', x=0, y=-160); el(l, 'ExitState', x=650, y=-160); en = el(l, 'EntryState', x=0, y=0)
    return l, en, anyst

# 呼吸: 6秒。体が先に上がり、頭が少し遅れてついてくる。途中でまばたき
idle = anim('Idle breathing and blink', 360, [
    ('Breathing', 'y', [(0, 420), (150, 416), (300, 420), (360, 420)]),
    ('Robe', 'scaleY', [(0, 1), (150, 1.012), (300, 1), (360, 1)]),
    ('Head', 'rotation', [(0, 0), (40, 0), (190, .012), (330, 0), (360, 0)]),
    ('Blink', 'scaleY', [(0, 1), (200, 1), (205, .1), (211, 1), (360, 1)]),
], True)
l, en, _ = layer('Breath'); st = el(l, 'AnimationState', animationId=idle, x=220, y=0); transition(en, st.attrib['id'], duration=0)

# 表情: 目・口・まゆ・姿勢を連動させる
groups = ['Smile eyes', 'Happy eyes', 'Bright eyes', 'Quiet eyes', 'Quiet eyes']
mouths = ['Mouth normal', 'Mouth happy', 'Mouth encourage', 'Mouth focus', 'Mouth focus']
brow_y = [-6, -12, -14, -2, -4]
brow_sy = [1, 1.05, 1.1, .9, .95]
moods = []
for i, nm in enumerate(['Normal', 'Happy', 'Encourage', 'Focus', 'Drinking']):
    tr = [(g, 'opacity', [(0, 1 if groups[i] == g else 0)]) for g in dict.fromkeys(groups)]
    tr += [(g, 'opacity', [(0, 1 if mouths[i] == g else 0)]) for g in dict.fromkeys(mouths)]
    tr += [('Brows', 'y', [(0, brow_y[i])]), ('Brows', 'scaleY', [(0, brow_sy[i])]),
           ('Seated', 'y', [(0, 8 if i == 3 else 0)]),
           ('Seated', 'scaleY', [(0, .95 if i == 3 else 1)]),
           ('Face', 'y', [(0, 3 if i == 3 else (-2 if i == 2 else 0))])]
    moods.append(anim(nm, 120, tr, True))
l, en, _ = layer('Mood')
states = [el(l, 'AnimationState', animationId=an, x=220 + (i % 2) * 230, y=(i // 2) * 180) for i, an in enumerate(moods)]
transition(en, states[0].attrib['id'], duration=0)
for i, s in enumerate(states):
    for j, t in enumerate(states):
        if i != j: transition(s, t.attrib['id'], ('mood', j))

# 会話: 口がぱくぱく。体と頭が少しゆれる(頭は体より少し遅れる)
quiet = anim('Not talking', 30, [('Talking mouth', 'opacity', [(0, 0)]), ('Mouth', 'opacity', [(0, 1)]),
                                  ('Talking sway', 'rotation', [(0, 0)]), ('Face', 'x', [(0, 0)])], True)
speaking = anim('Talking', 48, [
    ('Talking mouth', 'opacity', [(0, 1)]), ('Mouth', 'opacity', [(0, 0)]),
    ('Talking mouth', 'scaleY', [(0, .25), (6, 1), (12, .3), (19, .85), (26, .25), (33, 1), (40, .35), (48, .25)]),
    ('Talking sway', 'rotation', [(0, -.01), (24, .01), (48, -.01)]),
    ('Face', 'x', [(0, -1), (30, 1.5), (48, -1)]),
], True)
l, en, _ = layer('Speech')
q = el(l, 'AnimationState', animationId=quiet, x=220, y=0); s = el(l, 'AnimationState', animationId=speaking, x=450, y=0)
transition(en, q.attrib['id'], duration=0)
transition(q, s.attrib['id'], ('isTalking', True), duration=150); transition(s, q.attrib['id'], ('isTalking', False), duration=200)

# しぐさ: 予備動作 → 動作 → 少し遅れて収まる
base = {('Bow torso', 'y'): 0, ('Bow torso', 'scaleY'): 1, ('Head', 'y'): -222, ('Head', 'scaleX'): 1, ('Head', 'scaleY'): 1,
        ('Cap', 'y'): 0, ('Greeting arm', 'rotation'): 0, ('Arm hand', 'rotation'): 0, ('Sleeve swing', 'rotation'): 0, ('Left sleeve', 'rotation'): 0,
        ('Whisk prop', 'opacity'): 0, ('Whisk prop', 'rotation'): 0, ('Fan', 'opacity'): 0, ('Fan', 'scaleX'): .1,
        ('Leaves', 'opacity'): 0, ('Bowl', 'y'): -70, ('Bowl', 'rotation'): 0, ('Head', 'rotation'): 0}
for i in range(3):
    base[(f'Leaf {i+1}', 'y')] = [-200, -262, -212][i]; base[(f'Leaf {i+1}', 'rotation')] = 0
acts = {}

def action(name, dur, changes):
    tracks = [(ob, p, changes.get((ob, p), [(0, v), (dur, v)])) for (ob, p), v in base.items()]
    acts[name] = anim(name, dur, tracks)

action('Rest', 60, {})
# おじぎ: 少し背すじをのばしてから、前に傾く。頭は少し遅れて下がり、帽子の上が多く見える(顔が下に寄る)
action('bow', 90, {
    ('Bow torso', 'y'): [(0, 0), (8, -3), (34, 12), (54, 12), (76, -1), (90, 0)],
    ('Bow torso', 'scaleY'): [(0, 1), (8, 1.01), (34, .95), (54, .95), (78, 1.004), (90, 1)],
    ('Head', 'y'): [(0, -222), (10, -226), (38, -184), (56, -184), (80, -224), (90, -222)],
    ('Head', 'scaleX'): [(0, 1), (38, .97), (56, .97), (90, 1)],
    ('Head', 'scaleY'): [(0, 1), (38, .94), (56, .94), (90, 1)],
    ('Cap', 'y'): [(0, 0), (38, 10), (56, 10), (90, 0)],
    ('Bowl', 'y'): [(0, -70), (36, -64), (56, -64), (90, -70)],
})
# 手をふる: 少し下げてから上げ、手首が腕より少し遅れて揺れる
action('wave', 96, {
    ('Greeting arm', 'rotation'): [(0, 0), (6, .08), (22, -1.75), (34, -1.6), (46, -1.8), (58, -1.6), (70, -1.75), (86, .03), (96, 0)],
    ('Sleeve swing', 'rotation'): [(0, 0), (10, 0), (28, 1.05), (40, .95), (52, 1.1), (64, .95), (78, .9), (92, -.04), (96, 0)],
    ('Arm hand', 'rotation'): [(0, 0), (26, .25), (38, -.3), (50, .3), (62, -.3), (74, .2), (90, -.04), (96, 0)],
    ('Head', 'y'): [(0, -222), (24, -225), (70, -225), (96, -222)],
})
# 茶せん: 茶碗の上で前後にシャカッ。何度呼ばれても、最初の形が同じなので飛ばない
action('whisk', 20, {
    ('Whisk prop', 'opacity'): [(0, 1), (20, 1)],
    ('Greeting arm', 'rotation'): [(0, .05), (5, -.07), (10, .07), (15, -.07), (20, .05)],
    ('Whisk prop', 'rotation'): [(0, 0), (5, .18), (10, -.18), (15, .18), (20, 0)],
    ('Arm hand', 'rotation'): [(0, 0), (7, -.08), (12, .08), (20, 0)],
})
# うなずく: 小さく沈んでから2回うなずき、ゆっくり戻る
action('cheer', 72, {
    ('Head', 'y'): [(0, -222), (8, -225), (20, -212), (32, -222), (44, -215), (58, -223), (72, -222)],
    ('Head', 'rotation'): [(0, 0), (20, .03), (32, 0), (44, .018), (72, 0)],
    ('Bow torso', 'y'): [(0, 0), (22, 3), (46, 2), (72, 0)],
})
# レベルアップ: 腕を上げて扇子をぱっと開く。葉が3枚舞う
lv = {('Greeting arm', 'rotation'): [(0, 0), (8, .1), (22, -1.55), (90, -1.55), (112, 0)],
      ('Sleeve swing', 'rotation'): [(0, 0), (12, 0), (30, 1.0), (44, .9), (90, .95), (106, -.03), (112, 0)],
      ('Fan', 'opacity'): [(0, 0), (18, 1), (92, 1), (108, 0)],
      ('Fan', 'scaleX'): [(0, .1), (20, .1), (32, 1.04), (38, 1), (92, 1), (108, .1)],
      ('Arm hand', 'rotation'): [(0, 0), (34, .15), (60, -.1), (90, .05), (112, 0)],
      ('Leaves', 'opacity'): [(0, 0), (30, 1), (86, 1), (112, 0)]}
for i in range(3):
    y = base[(f'Leaf {i+1}', 'y')]
    lv[(f'Leaf {i+1}', 'y')] = [(0, y + 30), (30 + i * 4, y + 20), (70, y - 18), (112, y + 18)]
    lv[(f'Leaf {i+1}', 'rotation')] = [(0, -.4), (60, .45), (112, -.25)]
action('levelUp', 112, lv)
drink = {
    ('Bowl', 'y'): [(0, -70), (50, -168), (160, -168), (205, -70), (300, -70)],
    ('Bowl', 'rotation'): [(0, 0), (50, -.08), (95, -.16), (160, -.08), (205, 0), (300, 0)],
    ('Greeting arm', 'rotation'): [(0, 0), (54, -.62), (160, -.62), (210, 0), (300, 0)],
    ('Arm hand', 'rotation'): [(0, 0), (60, .2), (160, .2), (215, 0), (300, 0)],
    ('Head', 'rotation'): [(0, 0), (60, 0), (95, -.035), (150, -.02), (200, 0), (300, 0)],
    ('Head', 'y'): [(0, -222), (95, -224), (200, -222), (300, -222)],
}
tracks = [(ob, p, drink.get((ob, p), [(0, v), (300, v)])) for (ob, p), v in base.items()]
acts['drink'] = anim('Drink loop', 300, tracks, True)

l, en, anyst = layer('Gestures')
rest = el(l, 'AnimationState', animationId=acts['Rest'], x=220, y=0); transition(en, rest.attrib['id'], duration=0)
for i, name in enumerate(['bow', 'wave', 'whisk', 'cheer', 'levelUp']):
    st = el(l, 'AnimationState', animationId=acts[name], reset=True, x=460 + (i % 2) * 240, y=(i // 2) * 170)
    # どの状態からでも入れる(しぐさの途中でも、次のしぐさにつなぐ)。茶せんの連打は短くつなぐ
    transition(anyst, st.attrib['id'], (name, None), duration=60 if name == 'whisk' else 220)
    transition(st, rest.attrib['id'], exit=True, duration=200)
# 表情が 4(飲む)の間は、お茶を飲むしぐさをくり返す
dr = el(l, 'AnimationState', animationId=acts['drink'], x=220, y=260)
transition(rest, dr.attrib['id'], ('mood', 4), duration=300)
t = el(dr, 'StateTransition', stateToId=rest.attrib['id'], duration=300)
el(t, 'TransitionNumberCondition', inputId=inputs['mood'], opValue='notEqual', value=4)

E.indent(R); E.ElementTree(R).write(P / 'scene.rml', encoding='unicode', xml_declaration=True)
(P / 'rive.yaml').write_text('name: rikyu\nmain: Rikyu\n')
Path('work/ids.json').write_text(json.dumps({'inputs': inputs, 'acts': acts, 'ids': ids}))
print('ok', counter)
