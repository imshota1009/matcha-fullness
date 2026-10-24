# 検証: 各表情・各しぐさ・会話+しぐさ・茶せんの連打を描画する(本番の .riv には入れない検証用コピー)
import xml.etree.ElementTree as E
from pathlib import Path
import subprocess, json, sys
exe = '../work/rive-tool/versions/1.7.0/rive'
info = json.loads(Path('work/ids.json').read_text())
def case(name, mood=None, talk=False, trig=None, steps=(30,)):
    t = E.parse('outputs/rikyu-source/scene.rml'); sm = t.find('.//StateMachine'); a = t.find('.//Artboard')
    if mood is not None: sm.find('StateMachineNumber').set('value', str(mood))
    if talk: sm.find('StateMachineBool').set('value', 'true')
    if trig:
        sh = E.SubElement(a, 'Shape', id='9:1', name='QA hit', x='250', y='250')
        E.SubElement(sh, 'Rectangle', width='500', height='500', originX='.5', originY='.5')
        f = E.SubElement(sh, 'Fill'); E.SubElement(f, 'SolidColor', colorValue='00000000')
        li = E.SubElement(sm, 'StateMachineListenerSingle', targetId='9:1', listenerTypeValue='click', name='QA fire')
        E.SubElement(li, 'ListenerTriggerChange', inputId=info['inputs'][trig])
    d = Path('work/qa-' + name); d.mkdir(exist_ok=True)
    t.write(d / 'scene.rml'); (d / 'rive.yaml').write_text('name: qa\nmain: Rikyu\n')
    args = [exe, str(d), f'--screenshot=work/shots/{name}.png', '--advance=1']
    for k, s in enumerate(steps):
        if trig and (k == 0 or s < 0): args.append('--pointer=click@250,250')
        args.append(f'--advance={abs(s)}')
    r = subprocess.run(args, capture_output=True, text=True)
    print(name, 'ok' if r.returncode == 0 else r.stderr[-300:])
Path('work/shots').mkdir(exist_ok=True)
for i, n in enumerate(['normal', 'happy', 'encourage', 'focus']): case('mood-' + n, mood=i, steps=(40,))
case('talk', talk=True, steps=(9,))
for n, f in [('bow', 40), ('wave', 30), ('whisk', 6), ('cheer', 20), ('levelUp', 45)]: case(n, trig=n, steps=(f,))
case('talk-wave', talk=True, trig='wave', steps=(30,))
case('talk-bow', talk=True, trig='bow', steps=(40,))
# 茶せんを 8 フレームごとに3回呼ぶ(連打)。途中のコマを見る
case('whisk-repeat-a', trig='whisk', steps=(8, -8, 3))
case('whisk-repeat-b', trig='whisk', steps=(8, -8, -8, 14))
case('whisk-end', trig='whisk', steps=(40,))
