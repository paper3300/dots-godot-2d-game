"""Original tiny raster art for Briar & Bone. No external image inputs."""
from PIL import Image, ImageDraw
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets'/'sprites'; out.mkdir(parents=True,exist_ok=True)
P={'ink':'#17252a','steel':'#b6c8c4','light':'#e3e8d0','shade':'#637b80','skin':'#c59772','skinlight':'#e4b68e','hair':'#584234','cloth':'#426f78','clothlight':'#60939a','leather':'#73533b','gold':'#d5ac59','red':'#934950','wood':'#815b3b'}
def sprite(name,w,h,fn):
 im=Image.new('RGBA',(w,h));d=ImageDraw.Draw(im); fn(d);im.save(out/(name+'.png'))
def hero(d,kind='hero'):
 c=P['cloth']; l=P['clothlight']; hair=P['hair']
 if kind=='raider': c='#85525a';l='#b37568';hair='#443947'
 if kind=='archer': c='#6b7355';l='#969a6d';hair='#4a4436'
 if kind=='warden': c='#5e5a78';l='#9791a4';hair='#a7b8b6'
 d.rectangle((4,21,12,22),fill='#101d25');d.rectangle((5,18,7,22),fill='#403f3b');d.rectangle((10,18,12,22),fill='#403f3b')
 d.rectangle((3,11,13,18),fill=P['ink']);d.rectangle((5,10,11,19),fill=c);d.rectangle((6,11,8,17),fill=l)
 d.rectangle((4,17,12,18),fill=P['leather']);d.rectangle((8,17,9,18),fill=P['gold'])
 d.rectangle((5,3,11,9),fill=P['ink']);d.rectangle((6,4,11,8),fill=P['skin']);d.rectangle((6,4,10,5),fill=P['skinlight'])
 d.rectangle((5,2,11,4),fill=hair);d.rectangle((4,4,6,6),fill=hair);d.point((10,6),fill=P['ink']);d.rectangle((8,9,10,10),fill=P['skin'])
 if kind=='hero':
  d.rectangle((4,1,11,3),fill=P['shade']);d.rectangle((5,1,10,1),fill=P['steel']);d.rectangle((3,3,12,3),fill=P['steel']);d.rectangle((10,0,10,2),fill=P['red'])
  d.rectangle((1,11,5,17),fill=P['ink']);d.rectangle((1,12,4,16),fill=P['wood']);d.rectangle((2,12,3,15),fill=P['gold']);d.point((2,14),fill=P['light'])
  d.rectangle((14,6,14,14),fill=P['steel']);d.rectangle((13,13,15,13),fill=P['gold']);d.rectangle((14,14,14,17),fill=P['leather'])
 elif kind=='archer':
  d.arc((11,6,17,18),-100,100,fill=P['gold'],width=1);d.line((14,6,14,18),fill=P['light']);d.rectangle((1,8,2,17),fill=P['wood'])
 elif kind=='warden':
  d.rectangle((4,1,12,5),fill=P['shade']);d.rectangle((3,3,13,5),fill=P['steel']);d.rectangle((5,5,11,8),fill='#303b48');d.rectangle((6,6,7,6),fill='#e6ac65');d.rectangle((10,6,11,6),fill='#e6ac65')
  d.rectangle((2,10,14,12),fill=P['shade']);d.rectangle((6,12,11,16),fill=P['shade']);d.rectangle((14,5,15,20),fill=P['wood']);d.rectangle((12,5,15,8),fill=P['steel'])
 else:
  d.rectangle((14,10,14,18),fill=P['wood']);d.rectangle((13,6,15,12),fill=P['shade']);d.rectangle((14,6,15,10),fill=P['steel'])
for s in ['hero','raider','archer','warden']: sprite(s,16,24,lambda d,s=s:hero(d,s))
def wolf(d):
 d.rectangle((3,7,11,12),fill='#39454c');d.rectangle((4,6,10,10),fill='#6e7b7c');d.rectangle((5,6,9,8),fill='#94a09c')
 d.rectangle((9,4,14,9),fill='#647275');d.rectangle((10,3,11,6),fill='#46555f');d.rectangle((13,3,14,6),fill='#46555f');d.rectangle((12,7,15,9),fill='#8b9590');d.point((14,6),fill='#dab674');d.rectangle((2,12,4,14),fill='#36434b');d.rectangle((10,12,12,14),fill='#36434b');d.line((0,6,3,8),fill='#71817e',width=2)
sprite('wolf',16,16,wolf)
def tree(d):
 d.rectangle((10,22,13,31),fill='#5c4638');d.rectangle((12,24,14,31),fill='#382f2b');d.rectangle((5,28,19,30),fill='#172d2b')
 for box,col in [((4,12,20,24),'#1c3531'),((1,9,21,20),'#224839'),((3,4,20,17),'#2c5740'),((6,1,17,13),'#3b6547')]: d.rectangle(box,fill=col)
 d.rectangle((5,7,10,10),fill='#48724a');d.rectangle((8,3,14,5),fill='#517749');d.rectangle((2,13,6,16),fill='#3c6243');d.rectangle((13,12,18,15),fill='#355e3d');d.rectangle((14,20,19,22),fill='#172f2e')
sprite('tree',24,32,tree)
def chest(d):
 d.rectangle((1,6,14,14),fill='#1b2829');d.rectangle((2,4,13,13),fill='#664736');d.rectangle((3,3,12,5),fill='#a27b48');d.rectangle((2,7,13,8),fill='#d0aa61');d.rectangle((4,4,5,12),fill='#c4a267');d.rectangle((11,4,12,12),fill='#c4a267');d.rectangle((7,7,9,10),fill='#e0bb66');d.point((8,9),fill='#473827')
sprite('chest',16,16,chest)
def board(d):
 d.rectangle((3,14,4,22),fill='#634731');d.rectangle((12,14,13,22),fill='#634731');d.rectangle((1,3,15,15),fill='#372e28');d.rectangle((2,4,14,14),fill='#856042');d.rectangle((4,6,11,12),fill='#d6caa0');d.rectangle((5,7,9,7),fill='#866d4f');d.rectangle((5,9,10,9),fill='#866d4f');d.point((11,11),fill='#a95745');d.line((0,3,8,0,16,3),fill='#a88655',width=2)
sprite('board',17,24,board)
def npc(d,color):
 hero(d);d.rectangle((3,10,13,18),fill=color);d.rectangle((5,2,11,4),fill='#695543');d.rectangle((2,10,3,16),fill='#bc906c');d.rectangle((13,10,14,16),fill='#bc906c');d.rectangle((14,6,15,17),fill=(0,0,0,0));d.rectangle((0,10,2,18),fill=(0,0,0,0))
sprite('shop',16,24,lambda d:npc(d,'#956b40'));sprite('inn',16,24,lambda d:npc(d,'#75885e'))
def well(d):
 d.rectangle((2,11,19,20),fill='#3d5050');d.rectangle((3,9,18,17),fill='#8b9180');d.rectangle((6,11,15,15),fill='#213e47');d.rectangle((7,12,14,13),fill='#427384');d.rectangle((3,6,4,14),fill='#8e6a45');d.rectangle((17,6,18,14),fill='#8e6a45');d.rectangle((2,4,19,6),fill='#614635');d.rectangle((5,2,16,4),fill='#b09359');d.rectangle((9,5,10,12),fill='#c9b776');d.line((5,18,8,18),fill='#c3bc9d');d.line((12,16,16,16),fill='#c3bc9d')
sprite('well',22,24,well)
def loot(d):
 d.rectangle((4,7,12,13),fill='#342e27');d.rectangle((5,6,11,12),fill='#9a7952');d.rectangle((6,8,9,10),fill='#b99662');d.rectangle((7,5,9,6),fill='#d1ba7b');d.point((13,11),fill='#ddbd60')
sprite('loot',16,16,loot)
def bell(d):
 d.rectangle((7,3,8,5),fill='#e1c379');d.rectangle((5,6,11,12),fill='#a88951');d.rectangle((6,5,10,11),fill='#d5af64');d.rectangle((4,11,12,13),fill='#edd18b');d.rectangle((7,14,9,15),fill='#a28554');d.rectangle((3,15,13,16),fill='#56646b')
sprite('bell',16,18,bell)
def door(d):
 d.rectangle((1,1,14,15),fill='#302a28');d.rectangle((2,2,13,15),fill='#75563d');d.rectangle((3,3,5,14),fill='#936c42');d.rectangle((9,2,10,15),fill='#503d31');d.rectangle((2,5,13,6),fill='#515756');d.rectangle((2,12,13,13),fill='#515756');d.point((11,9),fill='#d2b067')
sprite('door',16,16,door)
print('Original sprites generated:',len(list(out.glob('*.png'))))
