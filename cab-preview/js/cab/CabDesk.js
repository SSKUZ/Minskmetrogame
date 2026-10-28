// Layout follows the supplied design, including its separate service panels.
export function buildCabDesk(kit,cab,controls,instruments){
 const {THREE,materials:m,box,rounded,panel,label}=kit;
 const base=new THREE.Group();base.name='CabConsole';cab.add(base);
 // Bent sheet pedestal is open beneath the controller, with two side supports.
 for(const x of [-.89,.86]){
  rounded(base,.15,.45,.64,x,.34,1.47,m.casing,.018);
  rounded(base,.10,.36,.48,x,.34,1.50,m.blue,.012);
 }
 box(base,1.84,.09,.10,0,.65,.96,m.casing);
 const desk=new THREE.Group();desk.name='SlopingControlDeck';desk.position.set(0,.877,1.49);desk.rotation.x=-1.085;base.add(desk);
 // Bent steel L-shaped deck: the left footwell is actually open, not painted on.
 const outline=new THREE.Shape();outline.moveTo(-1.12,.44);outline.lineTo(1.17,.44);outline.quadraticCurveTo(1.19,.44,1.19,.42);outline.lineTo(1.19,.076);outline.lineTo(.98,.076);outline.lineTo(.98,-.42);outline.quadraticCurveTo(.98,-.44,.96,-.44);outline.lineTo(-.30,-.44);outline.lineTo(-.30,-.10);outline.lineTo(-1.12,-.10);outline.quadraticCurveTo(-1.14,-.10,-1.14,-.08);outline.lineTo(-1.14,.42);outline.quadraticCurveTo(-1.14,.44,-1.12,.44);
 const deckGeometry=new THREE.ExtrudeGeometry(outline,{depth:.060,bevelEnabled:true,bevelSize:.005,bevelThickness:.004,bevelSegments:2});deckGeometry.translate(0,0,-.074);kit.mesh(desk,deckGeometry,m.casing);
 rounded(desk,1.28,.023,.067,.34,-.439,-.046,m.edge,.01);
 rounded(desk,.82,.023,.065,-.72,-.098,-.045,m.edge,.01);
 const lighting=panel(desk,.42,.50,-.91,.166);
 label(lighting,'ОСВЕЩЕНИЕ',0,.213,.22,.021);
 controls.rotary(lighting,'cabLight',-.089,.05,'КАБИНА',{title:'Освещение кабины · L'});
 controls.rotary(lighting,'headlights',.089,.05,'ТОННЕЛЬ',{title:'Фары · F'});
 controls.button(lighting,'sandLeft',-.082,-.17,'ПЕСОК ЛЕВ',m.black,{enabled:false,title:'Песок слева · система не моделируется'});
 controls.button(lighting,'sandRight',.082,-.17,'ПРАВ',m.black,{enabled:false,title:'Песок справа · система не моделируется'});
 const wipers=panel(desk,.40,.50,-.50,.166);
 label(wipers,'СТЕКЛООЧИСТИТЕЛИ',0,.213,.35,.020);
 controls.rotary(wipers,'wiperLeft',-.078,.05,'ЛЕВЫЙ',{title:'Левый стеклоочиститель · анимация'});
 controls.rotary(wipers,'wiperRight',.078,.05,'ПРАВЫЙ',{title:'Правый стеклоочиститель · анимация'});
 const check=panel(desk,.47,.34,-.07,.246);
 controls.button(check,'lampTest',-.160,.032,'ПРОВЕРКА',m.white,{title:'Проверка ламп · удерживайте'});
 controls.button(check,'reset',-.020,.032,'СБРОС',m.red,{title:'Сброс проверки приборов'});
 controls.button(check,'ars',.120,.032,'КОНТРОЛЬ',m.black,{enabled:false,title:'АРС · система не моделируется'});
 const doors=panel(desk,.45,.34,.635,.246);
 label(doors,'ДВЕРИ',-.11,.145,.13,.017);
 controls.button(doors,'open',-.16,.018,'ОТКР',m.green,{title:'Открыть двери · O · штатная проверка остановки'});
 controls.button(doors,'close',-.04,.018,'ЗАКР',m.red,{title:'Закрыть двери · P'});
 controls.button(doors,'doorBlock',.08,.018,'БЛОКИРОВКА',m.black,{enabled:false,title:'Обход блокировки дверей не реализован'});
 const mode=panel(desk,.324,.34,1.025,.246);
 controls.rotary(mode,'mode',0,.012,'АВТОМАТ | РУЧНОЙ',{enabled:false,title:'Автоведение не реализовано',labelWidth:.28});
 label(mode,'РЕЗЕРВНОЕ УПРАВЛЕНИЕ',0,-.088,.30,.017);
 controls.rotary(mode,'reserve',0,-.149,'ВКЛ',{enabled:false,title:'Резервное управление не моделируется'});
 const vent=panel(desk,.23,.34,.281,.246);
 for(let i=0;i<8;i++)rounded(vent,.13,.004,.003,0,.06-i*.015,.014,m.black,.001);
 controls.controller(desk);
 const brake=panel(desk,.493,.47,.460,-.16);
 label(brake,'ТОРМОЗА',0,.197,.25,.022);
 controls.rotary(brake,'brake1',-.148,.035,'КРАН 1',{enabled:false,title:'Пневматическая магистраль не моделируется'});
 controls.rotary(brake,'brake2',0,.035,'КРАН 2',{enabled:false,title:'Пневматическая магистраль не моделируется'});
 controls.rotary(brake,'ept',.148,.035,'ЭПТ',{enabled:false,title:'Отдельная модель ЭПТ отсутствует'});
 controls.button(brake,'release',-.148,-.125,'ОТПУСК',m.black,{title:'Отпуск тормоза · N'});
 controls.button(brake,'service',0,-.125,'ПЕРЕКРЫША',m.black,{title:'Служебный тормоз 50% · B'});
 controls.button(brake,'emergency',.148,-.125,'ЭКСТРЕННОЕ',m.red,{title:'Полный игровой тормоз · Пробел',labelWidth:.13});
 const horn=panel(desk,.27,.47,.844,-.16);
 controls.button(horn,'horn',0,-.045,'СИГНАЛ',m.black,{title:'Звуковой сигнал · игровой тон · удерживайте H'});
 label(horn,'◁',0,-.078,.05,.035);
 controls.brakeValve(base);
 // Elevated steel instrument binnacle: independent face, lip and fixing points.
 const upper=new THREE.Group();upper.name='InstrumentBinnacle';upper.position.set(.18,1.285,.917);upper.scale.setScalar(1.14);upper.rotation.x=-.10;base.add(upper);
 rounded(upper,1.72,.374,.10,0,0,-.031,m.panel,.026);
 const left=panel(upper,.813,.304,-.414,0,.025,m.black);
 const right=panel(upper,.813,.304,.414,0,.025,m.black);
 const speed=instruments.speedDisplay(left,-.072,.007);
 const indicators=[];
 for(let row=0;row<3;row++)for(let col=0;col<2;col++)indicators.push(instruments.pilot(left,-.334+col*.048,.082-row*.051,col===0?0x46a449:0xdfb919));
 rounded(left,.266,.155,.011,.221,.002,.015,m.casing,.006);label(left,'ДВЕРИ',.221,.108,.15,.02,'#d0c9b2',.023);
 const doorLamps=[['ОТКР',0xd7bb15],['ХОД',0xd7bb15],['ЗАКР',0x22ac4c],['БЛОК',0xba1712]].map(([text,color],i)=>instruments.pilot(left,.131+i*.061,.017,color,text));
 const gauges=[instruments.gauge(right,-.174,0,'кВ',1.5),instruments.gauge(right,.174,0,'кА',1)];
 return {base,desk,upper,speed,indicators,doorLamps,gauges};
}
