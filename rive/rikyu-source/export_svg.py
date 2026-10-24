from pathlib import Path
import xml.etree.ElementTree as E
import math,copy
root=E.parse('outputs/rikyu-source/scene.rml').getroot()
keys={13:'x',14:'y',15:'rotation',16:'scaleX',17:'scaleY',18:'opacity'}
def export(name,bow=False,anim=None,frame=35):
 r=copy.deepcopy(root);a=r.find('Artboard');objects={x.get('id'):x for x in r.iter()}
 if bow: anim='bow';frame=38
 if anim:
  an=next(x for x in a.findall('LinearAnimation') if x.get('name')==anim)
  for ko in an:
   for kp in ko:
    frames=kp.findall('KeyFrameDouble');before=max((x for x in frames if int(x.get('frame','0'))<=frame),key=lambda x:int(x.get('frame','0')))
    objects[ko.get('objectId')].set(keys[int(kp.get('propertyKey'))],before.get('value'))
 def f(e,k,d=0):return float(e.get(k,d))
 def pt(e):return (f(e,'x'),f(e,'y'))
 def handle(e,which):
  x,y=pt(e);rot=f(e,which+'Rotation');dist=f(e,which+'Distance');return x+math.cos(rot)*dist,y+math.sin(rot)*dist
 def xy(p):return ' '.join(str(round(v,5)) for v in p)
 def geom(e):
  if e.tag=='Ellipse':return f'<ellipse cx="{f(e,"width")*(.5-f(e,"originX"))}" cy="{f(e,"height")*(.5-f(e,"originY"))}" rx="{f(e,"width")/2}" ry="{f(e,"height")/2}"/>'
  if e.tag!='PointsPath':return ''
  vs=list(e);d='M'+xy(pt(vs[0]));pairs=list(zip(vs,vs[1:]));closed=e.get('isClosed')=='true'
  if closed:pairs.append((vs[-1],vs[0]))
  for u,v in pairs:
   if u.tag=='StraightVertex' and v.tag=='StraightVertex':d+=' L'+xy(pt(v))
   else:d+=' C'+xy(handle(u,'out') if u.tag!='StraightVertex' else pt(u))+' '+xy(handle(v,'in') if v.tag!='StraightVertex' else pt(v))+' '+xy(pt(v))
  if closed:d+=' Z'
  return '<path d="'+d+'"/>'
 def walk(e):
  if e.tag not in ['Node','Shape','Artboard']:return ''
  tr=f'translate({f(e,"x")} {f(e,"y")}) rotate({f(e,"rotation")*180/math.pi}) scale({f(e,"scaleX",1)} {f(e,"scaleY",1)})'
  s=f'<g transform="{tr}" opacity="{f(e,"opacity",1)}">'
  if e.tag=='Shape':
   geometry=''.join(geom(c) for c in e)
   for p in e:
    if p.tag not in ['Fill','Stroke']:continue
    color=p.find('SolidColor').get('colorValue')[-6:]
    attrs=f'fill="#{color}"' if p.tag=='Fill' else f'fill="none" stroke="#{color}" stroke-width="{p.get("thickness")}" stroke-linecap="round" stroke-linejoin="round"'
    s+=f'<g {attrs}>{geometry}</g>'
  s+=''.join(walk(c) for c in reversed(list(e)));return s+'</g>'
 svg='<svg xmlns="http://www.w3.org/2000/svg" width="500" height="500" viewBox="0 0 500 500">'+walk(a)+'</svg>'
 Path('outputs/'+name+'.svg').write_text(svg)
export('rikyu-front');export('rikyu-bow',True)
for m in ['Normal','Happy','Encourage','Focus']: export('mood-'+m.lower(),anim=m,frame=0)
