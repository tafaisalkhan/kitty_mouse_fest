const fs=require('fs'),path=require('path');
const level={
 schema_version:1,id:'level_006',number:6,name:'The Sunken Garden',difficulty:'medium',seed:6021,verified:false,
 tutorial:'Dig a safe tunnel. Tap the wheel hub to reverse it.',
 world:{width:720,height:1280,gravity:980},
 terrain:{grid_size:8,brush_radius:90,
  chambers:[[235,305,122],[530,1030,125],[350,660,154],[563,335,67],[592,604,65],[153,966,52]],
  tunnels:[
   {points:[[150,490],[116,556],[144,634],[120,725],[155,805],[122,870],[153,966]],radius:45},
   {points:[[563,335],[582,402],[565,470]],radius:37},
   {points:[[592,604],[558,694],[592,754]],radius:43},
   {points:[[590,844],[551,885],[504,907]],radius:41},
   {points:[[270,1007],[220,1074],[130,1085]],radius:39}
  ],rock_rects:[]},
 kittens:[{id:'kitten_1',variant:0,position:[175,290],radius:29},{id:'kitten_2',variant:1,position:[235,290],radius:29},{id:'kitten_3',variant:2,position:[295,290],radius:29}],
 mother:{id:'mom',position:[530,1030],rescue_radius:97},
 obstacles:[
  {id:'wheel',type:'rotating_wheel',position:[350,660],radius:119,speed:0.5,interactive:true},
  {id:'rock',type:'falling_rock',position:[563,335],radius:49},
  {id:'bee_1',type:'bee',position:[136,600],radius:24,patrol_width:21},
  {id:'bee_2',type:'bee',position:[142,787],radius:24,patrol_width:18},
  {id:'plant',type:'dangerous_plant',position:[592,604],radius:38},
  {id:'spikes',type:'spikes',position:[574,870],radius:32},
  {id:'wheel_stop',type:'pressure_switch',position:[153,966],radius:27,target:'wheel'},
  {id:'plant_switch',type:'pressure_switch',position:[565,470],radius:21,target:'plant'}
 ],
 solution:[[235,345],[289,490],[350,660],[416,827],[530,1030]],
 objectives:{rescue_all:true,target_time_seconds:65,target_dig_distance:1550},
 decorations:[{sprite:1,x:372,y:307,size:35},{sprite:1,x:641,y:940,size:48},{sprite:1,x:295,y:1103,size:40},{sprite:2,x:651,y:216,size:65},{sprite:1,x:258,y:740,size:30}]
};
fs.writeFileSync(path.join(__dirname,'../levels/easy/level_006.json'),JSON.stringify(level,null,2));
console.log('Created authored showcase level 6; requires simulation verification.');
