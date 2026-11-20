const fs=require('fs'),path=require('path');
const root=path.resolve(__dirname,'..');
for(let n=1;n<=5;n++){
 const file=path.join(root,`levels/easy/level_${String(n).padStart(3,'0')}.json`);
 const d=JSON.parse(fs.readFileSync(file));
 d.terrain.grid_size=8;
 d.terrain.brush_radius=n===5?85:65;
 d.kittens.forEach(k=>{k.radius=29;k.position[1]=285;});
 d.terrain.chambers[0]=[d.terrain.chambers[0][0],300,90];
 d.mother.position[1]=1030;
 d.mother.rescue_radius=97;
 d.terrain.chambers[1]=[d.mother.position[0],1030,124];
 d.decorations=[{sprite:1,x:365,y:370,size:36,rotation:-0.3},{sprite:1,x:600,y:910,size:44,rotation:0.15},{sprite:1,x:140,y:1040,size:39},{sprite:2,x:630,y:210,size:70}];
 d.terrain.tunnels=[];
 if(n===1){
  d.terrain.tunnels.push({points:[[560,430],[590,530],[570,620]],radius:42},{points:[[120,800],[155,855],[215,880]],radius:37});
  d.terrain.chambers.push([565,430,64]);
 }
 if(n===2){
  d.terrain.tunnels.push({points:[[125,470],[170,550],[130,650]],radius:43},{points:[[560,790],[590,845],[545,900]],radius:38});
 }
 if(n===3){
  d.terrain.tunnels.push({points:[[230,435],[210,515],[160,575],[122,650],[145,710]],radius:45},{points:[[100,850],[175,905],[230,950]],radius:41});
  d.terrain.chambers.push([145,690,66]);
 }
 if(n===4){
  d.terrain.chambers[2]=[310,590,138];
  d.obstacles[0].radius=100;
  d.terrain.tunnels.push({points:[[130,430],[110,490],[125,570],[95,690]],radius:38},{points:[[560,440],[570,535],[605,600]],radius:40},{points:[[580,780],[550,850],[580,930]],radius:38});
 }
 if(n===5){
  d.terrain.tunnels.push({points:[[210,620],[135,690],[125,790],[185,865]],radius:46},{points:[[560,440],[600,520],[570,595]],radius:36});
 }
 d.verified=false;
 fs.writeFileSync(file,JSON.stringify(d,null,2));
}
console.log('Updated five tutorial compositions; physics verification must run again.');
