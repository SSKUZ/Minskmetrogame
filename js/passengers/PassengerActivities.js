// Short, infrequent actions; each choice belongs to the persistent passenger.
export function updateCarriageActivity(a,time,rng,agents){
 if(a.space!=='train'||!['riding','seated'].includes(a.state)||a.velocity>.055)return;
 if(a.activityUntil&&time<a.activityUntil){
  const target=agents.find(p=>p.id===a.attentionId);
  if(target)a.attentionAngle=Math.atan2(target.x-a.x,target.z-a.z)-(a.heading??0);
  return;
 }
 if(a.activityUntil){a.activityUntil=0;a.activity=a.railGrip?'rail':'wait';a.attentionId=null;a.nextDecision=time+9+rng()*19;return;}
 if(time<a.nextDecision)return;
 const relatives=agents.filter(p=>p!==a&&p.space==='train'&&p.groupId!==null&&p.groupId===a.groupId);
 const child=relatives.find(p=>p.child),partner=relatives[0];
 const n=rng();let action;
 if(child&&n<.35){action='child';a.attentionId=child.id;}
 else if(partner&&n<.42){action='talk';a.attentionId=partner.id;}
 else action=n<.20?'phone':n<.42?'window':n<.57?'display':n<.72?'look':n<.85&&a.accessory?'bag':'weight';
 // A supported passenger keeps the support hand; phone uses the other hand.
 a.activityStart=time;a.activity=action;a.activityUntil=time+2+rng()*3.5;a.nextDecision=time+18+rng()*19;
}
