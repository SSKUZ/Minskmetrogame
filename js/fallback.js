// Keep the WebGL canvas untouched while the module downloads. A separate 2D
// surface can be removed safely if a slow 3D startup eventually succeeds.
(function(){
 const $=id=>document.getElementById(id),scene=$('scene');
 if(!scene)return;
 const names=['Малиновка','Петровщина','Михалово','Грушевка','Институт культуры','Площадь Ленина','Октябрьская','Площадь Победы','Площадь Якуба Коласа','Академия наук','Парк Челюскинцев','Московская','Восток','Борисовский тракт','Уручье'];
 let active=false,available=false,surface=null,context=null,frameId=0;
 let speed=0,lever=0,dist=850,people=0,index=0,doors=false,yaw=0,pitch=0,last=0;
 const ready=()=>Boolean(window.metro3DReady);
 const status=text=>{if($('status'))$('status').textContent=text;};
 function syncLever(){
  if($('masterHandle'))$('masterHandle').style.top=50-lever*43+'%';
  if($('masterValue'))$('masterValue').textContent=(lever>.04?'ТЯГА':lever<-.04?'ТОРМОЗ':'НЕЙТРАЛЬ')+' · '+Math.round(Math.abs(lever)*100)+'%';
 }
 function toggleDoors(){
  if(!active||ready())return;
  if(speed>1){status('Сначала останови поезд');return;}
  if(Math.abs(dist)>32){status('До платформы ещё далеко');return;}
  doors=!doors;
  const button=$('screenDoorToggle');
  button?.classList.toggle('open',doors);button?.setAttribute('aria-pressed',String(doors));button?.setAttribute('aria-label',doors?'Закрыть двери':'Открыть двери');
  if(doors){people+=20;lever=0;syncLever();status('Двери открыты');}
  else{index=Math.min(index+1,names.length-1);dist=850;status('Следующая станция — '+names[index]);}
 }
 const master=$('masterTrack');
 function drive(e){
  if(!active||ready()||!master)return;
  const r=master.getBoundingClientRect();lever=Math.max(-1,Math.min(1,(.5-(e.clientY-r.top)/r.height)*2));syncLever();
 }
 master?.addEventListener('pointerdown',e=>{if(!active||ready())return;master.setPointerCapture(e.pointerId);drive(e);});
 master?.addEventListener('pointermove',e=>{if(master.hasPointerCapture(e.pointerId))drive(e);});
 $('screenDoorToggle')?.addEventListener('click',toggleDoors);
 let pointer=null,x=0,y=0;
 function attachLook(canvas){
  canvas.addEventListener('pointerdown',e=>{if(!active||ready())return;pointer=e.pointerId;x=e.clientX;y=e.clientY;canvas.setPointerCapture(pointer);});
  canvas.addEventListener('pointermove',e=>{
   if(!active||ready()||e.pointerId!==pointer)return;
   yaw=Math.max(-1.04,Math.min(1.04,yaw-(e.clientX-x)*.008));pitch=Math.max(-.42,Math.min(.54,pitch-(e.clientY-y)*.006));x=e.clientX;y=e.clientY;
  });
  for(const type of ['pointerup','pointercancel'])canvas.addEventListener(type,()=>{pointer=null;});
 }
 function stop(){
  const wasActive=active;
  active=false;available=false;cancelAnimationFrame(frameId);surface?.remove();surface=null;context=null;
  document.body.classList.remove('metro-fallback');
  if(wasActive&&ready()){lever=0;syncLever();status('Рычаг вверх — тяга, вниз — тормоз');}
 }
 function start(){
  if(!available||active||ready()||!window.metroStarted)return;
  surface=document.createElement('canvas');surface.id='fallbackScene';surface.setAttribute('aria-label','Резервный вид пути');
  surface.style.cssText='position:fixed;inset:0;width:100%;height:100%;z-index:0;touch-action:none';scene.after(surface);
  context=surface.getContext('2d');if(!context){surface.remove();surface=null;return;}
  attachLook(surface);active=true;last=performance.now();document.body.classList.add('metro-fallback');
  status('Режим совместимости · 3D недоступен');frameId=requestAnimationFrame(frame);
 }
 function frame(now){
  if(!active||ready()){stop();return;}
  const dt=Math.min(.05,(now-last)/1000);last=now;
  if(!doors){
   speed=Math.max(0,Math.min(75,speed+((lever>0?lever*18:-3)+(lever<0?lever*40:0))*dt));dist-=speed/3.6*dt;
   if(dist< -80){index=Math.min(index+1,names.length-1);dist=850;speed=0;lever=0;syncLever();status('Следующая станция — '+names[index]);}
  }
  const w=innerWidth,h=innerHeight;if(surface.width!==w||surface.height!==h){surface.width=w;surface.height=h;}
  const ctx=context;ctx.setTransform(w/1000,0,0,h/700,0,0);ctx.fillStyle='#0b1018';ctx.fillRect(0,0,1000,700);
  const cx=500-yaw*220,cy=280+pitch*120;
  for(let i=15;i>=0;i--){const z=((i*100-now*speed*.003)%1600+1600)%1600,k=1-z/1600;ctx.strokeStyle='rgba(140,160,175,'+(.12+.6*k)+')';ctx.lineWidth=2+5*k;ctx.strokeRect(cx-(65+520*k),cy-(55+360*k),130+1040*k,110+720*k);}
  ctx.strokeStyle='#9b9da0';ctx.lineWidth=5;
  for(const side of [-1,1]){ctx.beginPath();ctx.moveTo(cx+side*30,cy+30);ctx.lineTo(cx+side*160,700);ctx.stroke();}
  ctx.fillStyle='#d9eaff';ctx.fillRect(cx-20,cy-130,40,8);
  if($('speed'))$('speed').textContent=Math.round(speed);
  if($('station'))$('station').textContent=names[index]+' · '+Math.max(0,Math.round(dist))+' м';
  if($('people'))$('people').textContent='Пассажиры: '+people;
  frameId=requestAnimationFrame(frame);
 }
 // Slow downloads are allowed to finish; no 2D context is acquired on #scene.
 const timer=setTimeout(()=>{if(!ready()){available=true;start();}},10000);
 window.addEventListener('metro-start',start);
 window.addEventListener('metro-3d-ready',()=>{clearTimeout(timer);stop();});
 function unavailable(){clearTimeout(timer);available=true;if(active)status('Режим совместимости · 3D недоступен');else start();}
 window.addEventListener('metro-3d-unavailable',unavailable);
 window.addEventListener('metro-render-error',unavailable);
})();
