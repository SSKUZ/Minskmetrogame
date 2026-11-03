
// Startup watchdog: never leave the player on an inert splash or a blank canvas.
(function(){
 const start=document.getElementById('start'),play=document.getElementById('play');
 let started=false;
 function launch(){
  if(start)start.style.display='none';
  window.metroStarted=true;started=true;
  window.dispatchEvent(new Event('metro-start'));
  setTimeout(()=>{if(!window.metro3DReady){const status=document.getElementById('status');if(status)status.textContent='Запуск резервного режима: 3D загружается или недоступен';}},2500);
 }
 if(play){play.removeAttribute('onclick');play.addEventListener('click',launch)}
 window.addEventListener('error',e=>{console.error('Metro startup error:',e.message);const status=document.getElementById('status');if(status)status.textContent='Ошибка 3D: '+e.message});
 window.addEventListener('unhandledrejection',e=>{console.error('Metro 3D error:',e.reason);const status=document.getElementById('status');if(status)status.textContent='Ошибка загрузки 3D: '+String(e.reason)});
})();
