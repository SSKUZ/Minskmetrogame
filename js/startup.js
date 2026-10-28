
// Startup watchdog: never leave the player on an inert splash or a blank canvas.
(function(){
 const start=document.getElementById('start'),play=document.getElementById('play');
 function launch(){
  if(start)start.style.display='none';
  window.metroStarted=true;
  window.dispatchEvent(new Event('metro-start'));
  setTimeout(()=>{if(!window.metro3DReady&&!window.metro3DError&&!document.body.classList.contains('metro-fallback')){const status=document.getElementById('status');if(status)status.textContent='Загрузка 3D…';}},2500);
 }
 if(play){play.removeAttribute('onclick');play.addEventListener('click',launch)}
 function failed(reason){
  console.error('Metro startup error:',reason);
  const status=document.getElementById('status');
  if(!window.metro3DReady){
   window.metro3DError=String(reason);if(status)status.textContent='Не удалось запустить 3D';
   window.dispatchEvent(new Event('metro-3d-unavailable'));
  }else if(status)status.textContent='Ошибка 3D: '+String(reason);
 }
 window.addEventListener('error',e=>failed(e.message));
 window.addEventListener('unhandledrejection',e=>failed(e.reason));
})();
