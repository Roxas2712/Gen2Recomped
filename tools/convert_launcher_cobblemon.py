"""Build compact, data-only launcher meshes from pinned Cobblemon Blockbench sources."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]/'assets/launcher/cobblemon'
for name in ['haunter','delibird','sudowoodo']:
 source=name+'_male' if name=='sudowoodo' else name
 raw=json.loads((ROOT/(source+'.bbmodel')).read_text())
 groups={g['uuid']:g for g in raw['groups']};elements={e['uuid']:e for e in raw['elements']};bones=[]
 def walk(rows,parent=None):
  for row in rows:
   if isinstance(row,str):continue
   group=groups[row['uuid']];index=len(bones)+1
   cubes=[]
   for child in row.get('children',[]):
    if not isinstance(child,str) or child not in elements:continue
    e=elements[child]
    if e.get('type')!='cube' or e.get('visibility') is False:continue
    cubes.append({'from':e['from'],'to':e['to'],'pivot':e.get('origin',[0,0,0]),'rotation':e.get('rotation',[0,0,0]),'inflate':e.get('inflate',0),
                  'faces':{f:v['uv'] for f,v in e['faces'].items() if v.get('texture') is not None}})
   bones.append({'name':group['name'],'parent':parent,'pivot':group['origin'],'rotation':group.get('rotation',[0,0,0]),'cubes':cubes})
   walk([c for c in row.get('children',[]) if isinstance(c,dict)],index)
 walk(raw['outliner'])
 idle=json.loads((ROOT/(name+'.animation.json')).read_text())['animations']['animation.'+name+'.ground_idle']['bones']
 doc={'schema':1,'source':'Cobblemon Assets','license':'CC-BY-NC-3.0','texture':name+'.png','width':raw['resolution']['width'],'height':raw['resolution']['height'],'bones':bones,'idle':idle}
 (ROOT/(name+'.launcher.json')).write_text(json.dumps(doc,separators=(',',':'))+'\n')
 print(name,len(bones),'bones',sum(len(b['cubes']) for b in bones),'cubes')
