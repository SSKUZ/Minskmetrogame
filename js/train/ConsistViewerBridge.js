// First integration milestone: open the genuine v106 four-car model from the
// running game without replacing gameplay geometry or touching train physics.
// Viewer loads only on demand; closing it frees its WebGL context.
(()=>{
 const open=document.getElementById('consistInspectOpen');
 const close=document.getElementById('consistInspectClose');
 const panel=document.getElementById('consistInspect');
 const frame=document.getElementById('consistInspectFrame');
 if(!open||!close||!panel||!frame)return;
 const viewer=new URL('./preview/wagon.html?formation=train',document.baseURI).href;
 function syncDoors(){
  try{
   const w=frame.contentWindow;
   if(!w||!w.wagonReady||typeof w.wagonSetDoors!=='function')return;
   const open=latestDoorOpen;
   if(w.__metroLastDoorState!==open){
    w.wagonSetDoors(open,{instant:true});
    w.__metroLastDoorState=open;
   }
  }catch(error){console.warn('Consist preview door sync:',error)}
 }
 function show(){
  latestDoorOpen=document.getElementById('screenDoorToggle')?.getAttribute('aria-pressed')==='true';
  frame.src=viewer;
  syncTimer=setInterval(syncDoors,250);
  panel.hidden=false;
  panel.style.display='block';
  open.hidden=true;
  open.style.display='none';
  close.focus();
 }
 function hide(){
  clearInterval(syncTimer);syncTimer=null;
  frame.src='about:blank';
  panel.hidden=true;
  panel.style.display='none';
  open.hidden=false;
  open.style.display='';
  open.focus();
 }
 window.addEventListener('metro-consist-doors',event=>{
  latestDoorOpen=Boolean(event.detail?.open);
  if(!panel.hidden)syncDoors();
 });
 open.addEventListener('click',show);
 close.addEventListener('click',hide);
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!panel.hidden)hide()});
 panel.style.display='none';
 window.metroConsistViewer={open:show,close:hide,get active(){return !panel.hidden},version:106,syncDoors};
})();
