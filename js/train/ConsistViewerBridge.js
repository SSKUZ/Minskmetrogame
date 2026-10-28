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
 function show(){
  frame.src=viewer;
  panel.hidden=false;
  panel.style.display='block';
  open.hidden=true;
  open.style.display='none';
  close.focus();
 }
 function hide(){
  frame.src='about:blank';
  panel.hidden=true;
  panel.style.display='none';
  open.hidden=false;
  open.style.display='';
  open.focus();
 }
 open.addEventListener('click',show);
 close.addEventListener('click',hide);
 document.addEventListener('keydown',e=>{if(e.key==='Escape'&&!panel.hidden)hide()});
 panel.style.display='none';
 window.metroConsistViewer={open:show,close:hide,get active(){return !panel.hidden},version:106};
})();
