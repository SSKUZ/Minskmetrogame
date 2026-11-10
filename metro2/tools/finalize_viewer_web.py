#!/usr/bin/env python3
"""Add a native user-gesture fullscreen control to the viewer HTML only."""
from pathlib import Path
import sys

path = Path(sys.argv[1])
html = path.read_text()
assert 'id="viewer-fullscreen"' not in html
html = html.replace('initial-scale=1.0', 'initial-scale=1.0, viewport-fit=cover')
addition = '''
<style>
html,body {width:100%;height:100%;height:100dvh;overscroll-behavior:none;}
#viewer-fullscreen {position:fixed;z-index:10000;right:max(10px,env(safe-area-inset-right));top:max(8px,env(safe-area-inset-top));min-height:40px;padding:8px 16px;border:1px solid #687688;border-radius:12px;background:#172131e8;color:white;font:600 14px system-ui;touch-action:manipulation;}
#viewer-fullscreen-note {position:fixed;z-index:10001;right:10px;top:56px;max-width:85vw;color:white;background:#172131;padding:6px 10px;font:13px system-ui;display:none;}
</style>
<button id="viewer-fullscreen" type="button">На весь экран</button>
<div id="viewer-fullscreen-note" role="status"></div>
<script>
(() => {
 const button=document.getElementById('viewer-fullscreen');
 const note=document.getElementById('viewer-fullscreen-note');
 button.addEventListener('click',async () => {
  try {
   if(document.fullscreenElement) await document.exitFullscreen();
   else if(document.documentElement.requestFullscreen) await document.documentElement.requestFullscreen({navigationUI:'hide'});
   else throw new Error('unsupported');
   note.style.display='none';
  } catch(error) {note.textContent='Полноэкранный режим недоступен в этом браузере';note.style.display='block';}
 });
 document.addEventListener('fullscreenchange',() => {
  button.textContent=document.fullscreenElement?'Выйти из полного экрана':'На весь экран';
  window.dispatchEvent(new Event('resize'));
 });
})();
</script>
'''
assert '</body>' in html
path.write_text(html.replace('</body>',addition+'\n</body>'))
