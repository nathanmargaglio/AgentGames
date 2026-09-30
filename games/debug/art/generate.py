"""Run with blender --background --python games/debug/art/generate.py."""
import bpy, math, pathlib
from mathutils import Vector
ROOT=pathlib.Path(__file__).resolve().parents[1]
OUT=ROOT/'assets/models';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,emission=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.5
 if emission:p.inputs['Emission Color'].default_value=(*color,1);p.inputs['Emission Strength'].default_value=emission
 return m
ink=mat('Graphite',(.025,.042,.056),.4);steel=mat('Steel',(.13,.2,.23),.65)
lime=mat('Signal lime',(.64,.94,.18),.1,1.2);cyan=mat('Cold cyan',(.15,.75,.8),.15,1.5)
orange=mat('Bug amber',(.98,.36,.08),.2);orange2=mat('Bug shell',(.64,.16,.035),.15)
white=mat('Ivory',(.8,.86,.79),.1);black=mat('Rubber',(.012,.021,.021))
def cube(name,loc,scale,material,bevel=0):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(material)
 if bevel:
  m=o.modifiers.new('Soft edges','BEVEL');m.width=bevel;m.segments=2;bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=m.name)
 return o
def sphere(name,loc,scale,material):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=12,ring_count=6,location=loc);o=bpy.context.object;o.name=name;o.scale=scale;o.data.materials.append(material);return o
def rod(name,a,b,r,material):
 d=Vector(b)-Vector(a);bpy.ops.mesh.primitive_cylinder_add(vertices=8,radius=r,depth=d.length,location=(Vector(a)+Vector(b))/2);o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(material);return o

def export(name,objects):
 # Merge per material to keep the web renderer's draw calls low.
 groups={}
 for o in objects:groups.setdefault(o.data.materials[0].name,[]).append(o)
 merged=[]
 for group in groups.values():
  bpy.ops.object.select_all(action='DESELECT')
  for o in group:o.select_set(True)
  bpy.context.view_layer.objects.active=group[0];bpy.ops.object.join();o=group[0];bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR');merged.append(o)
 bpy.ops.object.select_all(action='DESELECT')
 for o in merged:o.select_set(True)
 bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
 collection=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(collection)
 for o in merged:
  for c in list(o.users_collection):c.objects.unlink(o)
  collection.objects.link(o)
 return collection

def objects_since(before):return [o for o in bpy.context.scene.objects if o.name not in before]
before=set(bpy.context.scene.objects.keys())
cube('Cabinet',(0,0,1.4),(1.5,1.15,2.8),ink,.055)
for x in [-.7,.7]:cube('Frame',(x,-.595,1.4),(.08,.08,2.68),steel,.015)
for z in [.25+i*.29 for i in range(9)]:
 cube('Server unit',(0,-.59,z),(1.23,.055,.235),steel,.014)
 for x in [-.45,-.27,-.09]:cube('Status LED',(x,-.627,z),(.055,.016,.035),lime)
 cube('Vent',(0.32,-.626,z),(.38,.012,.065),ink)
for x in [-.6,.6]:cube('Feet',(x,0,.04),(.2,1.25,.08),black)
rack=export('rack',objects_since(before))
before=set(bpy.context.scene.objects.keys())
sphere('Abdomen',(0,.13,0),(.36,.45,.27),orange2)
sphere('Shell left',(-.14,.08,.07),(.22,.39,.23),orange)
sphere('Shell right',(.14,.08,.07),(.22,.39,.23),orange)
sphere('Head',(0,-.31,.035),(.25,.22,.22),ink)
for x in [-.14,.14]:
 sphere('Eyes',(x,-.48,.12),(.075,.05,.085),lime)
 rod('Antenna',(x,-.4,.18),(x*1.6,-.7,.35),.02,ink);sphere('Antenna tip',(x*1.6,-.7,.35),(.035,)*3,lime)
for side in [-1,1]:
 for y in [-.24,0,.25]:
  rod('Leg',(side*.22,y,-.06),(side*.53,y+.12,-.19),.036,ink)
  rod('Foot',(side*.53,y+.12,-.19),(side*.65,y-.03,-.33),.025,steel)
bug=export('bug',objects_since(before))
before=set(bpy.context.scene.objects.keys())
rod('Handle',(0,0,0),(0,0,.65),.035,steel)
cube('Grip',(0,0,.04),(.12,.12,.27),ink,.028)
# Open grid swatter, with a neon perimeter.
for x in [-.22,.22]:cube('Rim',(x,0,.88),(.035,.045,.44),lime,.01)
for z in [.66,1.1]:cube('Rim',(0,0,z),(.46,.045,.035),lime,.01)
for x in [-.15,-.075,0,.075,.15]:cube('Mesh',(x,0,.88),(.011,.018,.42),steel)
for z in [.73,.8,.87,.94,1.01]:cube('Mesh',(0,0,z),(.42,.018,.011),steel)
cube('Agent palm',(.035,.015,.03),(.24,.18,.18),white,.03)
cube('Agent forearm',(.03,.06,-.25),(.21,.2,.4),ink,.03)
for z in [-.06,.01,.08]:cube('Agent fingers',(-.07,-.07,z),(.16,.1,.045),white,.018)
cube('Agent status',(.03,-.05,-.25),(.13,.015,.07),cyan,.008)
swatter=export('swatter',objects_since(before))
# Save a native, editable source library.
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/models.blend'))
# Compose an illustration using the actual game assets.
for c in [rack,bug,swatter]:
 for o in c.objects:o.hide_render=True
for x in [-2.5,2.5]:
 for y in [1,3,5]:
  for src in rack.objects:
   o=src.copy();o.data=src.data;bpy.context.scene.collection.objects.link(o);o.hide_render=False;o.location+=(Vector((x,y,0)))
for src in bug.objects:
 o=src.copy();o.data=src.data;bpy.context.scene.collection.objects.link(o);o.hide_render=False;o.location=Vector((0,-.3,1.25));o.scale*=1.65;o.rotation_euler.z=-.35
cube('Floor',(0,2,-.11),(10,12,.2),ink)
for x in [-1.3,1.3]:cube('Floor guide',(x,2,.005),(.028,12,.01),lime)
world=bpy.data.worlds.new('Server atmosphere');bpy.context.scene.world=world;world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.055,.1,.1,1);world.node_tree.nodes['Background'].inputs[1].default_value=.5
for loc,power,color,size in [((1,-3,6),1700,(.65,.85,1),7),((-3,2,4),1400,(.6,1,.35),5),((4,5,5),1600,(.2,.7,1),4)]:
 bpy.ops.object.light_add(type='AREA',location=loc);bpy.context.object.data.energy=power;bpy.context.object.data.color=color;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=size
bpy.ops.object.camera_add(location=(6.8,-8.5,6));cam=bpy.context.object;cam.rotation_euler=(Vector((0,1.7,1.1))-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO';cam.data.ortho_scale=11;bpy.context.scene.camera=cam
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=1200;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(ROOT/'cover.png');bpy.ops.render.render(write_still=True)
print('AgentGames: exported rack, bug, swatter, native source, and cover.')
