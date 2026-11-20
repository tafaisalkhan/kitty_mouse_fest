const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
function write(p, text) { fs.mkdirSync(path.dirname(path.join(root,p)),{recursive:true}); fs.writeFileSync(path.join(root,p),text); }
function scene(p, name, type, script) { write(p,`[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://${script}" id="1"]\n\n[node name="${name}" type="${type}"]\nscript = ExtResource("1")\n`); }
for (const name of ['MainMenu','Settings','LevelSelect']) scene(`scenes/menus/${name}.tscn`,name,'Control','scripts/menus/Menu.gd');
scene('scenes/gameplay/Gameplay.tscn','Gameplay','Node2D','scripts/gameplay/Gameplay.gd');
scene('scenes/gameplay/Kitten.tscn','Kitten','RigidBody2D','scripts/gameplay/Kitten.gd');
scene('scenes/gameplay/SandTerrain.tscn','SandTerrain','Node2D','scripts/gameplay/SandTerrain.gd');
scene('scenes/gameplay/MotherCat.tscn','MotherCat','Node2D','scripts/gameplay/CatVisual.gd');
for(const name of ['RotatingWheel','FallingRock','Bee','Spikes','DangerousPlant','PressureSwitch','Gate','Fan','Portal','Water','MovingPlatform']) scene(`scenes/obstacles/${name}.tscn`,name,'Node2D','scripts/obstacles/Obstacle.gd');
const tutorials = [
 {name:'First Rescue',help:'Drag down through the sand to reach Mom.',spawn:210,mom:440,count:1,route:[[210,310],[270,560],[350,810],[440,1060]],obstacles:[]},
 {name:'Better Together',help:'Dig a wide path. Bring both kittens home.',spawn:485,mom:290,count:2,route:[[485,310],[420,560],[345,810],[290,1060]],obstacles:[]},
 {name:'Rocky Road',help:'Leave sand under the rock. Dig to the right.',spawn:470,mom:400,count:2,route:[[470,310],[500,540],[460,790],[400,1060]],obstacles:[{id:'rock',type:'falling_rock',position:[230,430],radius:38}]},
 {name:'A Helping Turn',help:'Tap the wheel hub to reverse its rotation.',spawn:245,mom:430,count:2,route:[[245,310],[310,550],[370,800],[430,1060]],obstacles:[{id:'wheel',type:'rotating_wheel',position:[310,590],radius:72,speed:0.55,interactive:true}]},
 {name:'Mind the Buzz',help:'Bees patrol the left cave. Choose a safe tunnel.',spawn:490,mom:420,count:3,route:[[490,310],[505,540],[470,800],[420,1060]],obstacles:[{id:'bee',type:'bee',position:[210,620],radius:24,patrol_width:50}]}
];
tutorials.forEach((t,i)=>{
 const chambers=[[t.spawn,265,100],[t.mom,1070,100]];
 if(i===2) chambers.push([230,420,45]);
 if(i===3) chambers.push([310,590,100]);
 if(i===4) chambers.push([210,620,85]);
 const kittens=Array.from({length:t.count},(_,j)=>({id:`kitten_${j+1}`,variant:(i+j)%6,position:[t.spawn+(j-(t.count-1)/2)*46,260],radius:21,mass:1}));
 write(`levels/easy/level_${String(i+1).padStart(3,'0')}.json`,JSON.stringify({schema_version:1,id:`level_${String(i+1).padStart(3,'0')}`,name:t.name,tutorial:t.help,seed:100+i,number:i+1,verified:false,difficulty:'easy',world:{width:720,height:1280,gravity:980},terrain:{grid_size:10,brush_radius:i===4?70:45,chambers,rock_rects:[]},kittens,mother:{id:'mom',position:[t.mom,1070],rescue_radius:85},obstacles:t.obstacles,solution:t.route,objectives:{rescue_all:true,target_time_seconds:45,target_dig_distance:1400}},null,2));
});
write('data/characters.json',JSON.stringify({variants:['gray_tabby','orange_bow','white_green_cap','black_white','cream','brown_tabby'],mother:'white_pink_bow',physics:{radius:21,mass:1,bounce:0.12,friction:0.65,maximum_speed:620}},null,2));
write('data/difficulty.json',JSON.stringify({easy:{kittens:[1,2],hazards:[0,1]},medium:{kittens:[2,3],hazards:[1,3]},hard:{kittens:[3,4],hazards:[3,5]},expert:{kittens:[4,5],hazards:[4,7]}},null,2));
console.log('Created scenes, character data and five tutorial levels.');
