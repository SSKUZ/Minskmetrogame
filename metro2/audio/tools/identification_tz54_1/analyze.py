"""Offline per-file content evidence. Never runs Godot or converts game audio.

Dependencies: faster-whisper 1.2.1, transformers 4.57.6, onnxruntime, scipy,
soundfile. Models are supplied as local paths; weights are never committed.
"""
import argparse, json, math, pathlib, hashlib, time, os

def deny_network():
    """Fail closed: inference and native dependencies cannot open sockets.

    Model libraries may send native telemetry despite their offline settings.
    Install this Linux seccomp filter before importing any model dependency;
    subsequently created worker threads inherit it. Requires libseccomp.so.2.
    """
    import ctypes
    import errno
    import sys
    if not sys.platform.startswith('linux'):
        raise RuntimeError('Offline analysis requires Linux with libseccomp')
    lib = ctypes.CDLL('libseccomp.so.2', use_errno=True)
    lib.seccomp_init.argtypes = [ctypes.c_uint32]
    lib.seccomp_init.restype = ctypes.c_void_p
    lib.seccomp_syscall_resolve_name.argtypes = [ctypes.c_char_p]
    lib.seccomp_syscall_resolve_name.restype = ctypes.c_int
    lib.seccomp_rule_add.argtypes = [ctypes.c_void_p, ctypes.c_uint32, ctypes.c_int, ctypes.c_uint]
    lib.seccomp_load.argtypes = [ctypes.c_void_p]
    lib.seccomp_release.argtypes = [ctypes.c_void_p]
    ctx = lib.seccomp_init(0x7fff0000)  # SCMP_ACT_ALLOW
    if not ctx:
        raise RuntimeError('Cannot create offline seccomp filter')
    try:
        for name in (b'socket', b'socketpair', b'connect', b'sendto', b'sendmsg', b'sendmmsg'):
            number = lib.seccomp_syscall_resolve_name(name)
            if number < 0 or lib.seccomp_rule_add(ctx, 0x00050000 | errno.EACCES, number, 0) != 0:
                raise RuntimeError('Cannot block network syscall: ' + name.decode())
        if lib.seccomp_load(ctx) != 0:
            raise RuntimeError('Cannot enforce offline analysis')
    finally:
        lib.seccomp_release(ctx)

deny_network()
# All weights are provisioned separately. Inference must not make network calls.
os.environ['HF_HUB_OFFLINE']='1'
os.environ['TRANSFORMERS_OFFLINE']='1'
os.environ['HF_HUB_DISABLE_TELEMETRY']='1'
import onnxruntime as ort
ort.disable_telemetry_events()
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

PROMPTS = [
 ('speech.announcement','A clear recorded public address announcement spoken by a male announcer in a subway train.'),
 ('speech.noisy','A subway station announcement spoken over loud train rumble and machinery noise.'),
 ('speech.conversation','People talking and chatting in a crowd.'),
 ('speech.radio','A person talking over a crackly walkie talkie radio.'),
 ('speech.warning','A loudspeaker voice giving a safety warning to passengers.'),
 ('train.motor','Electric train motors whining, changing pitch during acceleration.'),
 ('train.running','A train rolling with rumbling wheels, rattling, and metallic rail noise.'),
 ('train.coasting','A subway train coasting with steady wheel rumble and rattling.'),
 ('train.brake_electric','Electric train motors winding down while a train decelerates.'),
 ('train.brake_squeal','High pitched metallic squealing of train wheels and brakes.'),
 ('train.rail_joints','Rhythmic clacking and thumping as train wheels cross rail joints.'),
 ('train.switch','Multiple irregular clunks as a train rolls over a railway switch.'),
 ('train.passby','A loud rushing and rumbling subway train passing by the microphone.'),
 ('train.compressor','An air compressor motor starts, runs with a steady mechanical buzz, and stops.'),
 ('train.ventilation','A steady mechanical hum of ventilation fans and electric equipment.'),
 ('pneumatic.release','A short loud hiss of pressurized air escaping from a pneumatic mechanism.'),
 ('pneumatic.continuous','A prolonged continuous hissing of compressed air.'),
 ('doors.sliding_open','A pair of pneumatic sliding train doors opening with a hiss and metal mechanism noise.'),
 ('doors.sliding_close','A pair of pneumatic sliding train doors closing with a hiss and a final clunk.'),
 ('doors.pneumatic','A pneumatic mechanical door moves with a hiss, scrape and clunk.'),
 ('doors.hinged','A heavy hinged metal door creaks and slams shut.'),
 ('doors.latch','A short metallic door latch clack and handle click.'),
 ('cab.controller','A mechanical lever or controller clicking through several notches.'),
 ('cab.switch','A single small electrical toggle switch clicks.'),
 ('cab.button','A short button click sound.'),
 ('cab.relay','Electrical relays repeatedly clicking and clacking.'),
 ('cab.horn','A loud train horn or whistle blowing.'),
 ('cab.bell','A clear metallic bell ringing.'),
 ('cab.alarm','An electronic alarm beeping repeatedly.'),
 ('cab.buzzer','A sustained electrical buzzer tone.'),
 ('cab.motor','A small electrical motor or servo whirring.'),
 ('environment.station','An underground railway station ambience with distant people and reverberating sounds.'),
 ('environment.crowd','A crowd of people talking with footsteps and public indoor ambience.'),
 ('environment.tunnel','An echoing underground tunnel ambience with distant machinery and rumble.'),
 ('environment.depot','An industrial train workshop ambience with machinery and metal sounds.'),
 ('other.footsteps','Footsteps walking across a hard floor.'),
 ('other.knock','A few short hard knocks or metallic impacts.'),
 ('other.scrape','Metal scraping or creaking against metal.'),
 ('other.whoosh','A short rushing swoosh of air.'),
 ('other.music','Music with melody and rhythm playing.'),
 ('other.ui','A short artificial game menu interface click or notification sound effect.'),
 ('other.static','An electronic crackle, static noise or distorted buzz.'),
 ('other.silence','Silence with almost no audible sound.'),
 ('other.low_hum','A steady low humming drone.'),
 ('other.water','Running water splashing or dripping.'),
 ('other.car_engine','An internal combustion car engine revving.'),
 ('other.breath','A person breathing or coughing.'),
 ('other.electronic_tone','A short pure electronic beep or tone.'),
]

def wave(path, rate):
    y, sr = sf.read(path, dtype='float32', always_2d=True)
    y = y.mean(axis=1)
    if sr != rate:
        g = math.gcd(sr, rate)
        y = resample_poly(y, rate//g, sr//g).astype(np.float32)
    return y

def main():
    p=argparse.ArgumentParser();p.add_argument('mode',choices=['clap','asr']);p.add_argument('--wav',required=True);p.add_argument('--model',required=True);p.add_argument('--out',required=True);p.add_argument('--language');p.add_argument('--selection');a=p.parse_args()
    out=pathlib.Path(a.out);out.parent.mkdir(parents=True,exist_ok=True)
    done={json.loads(l)['source_file'] for l in out.read_text().splitlines()} if out.exists() else set()
    paths=sorted(pathlib.Path(a.wav).glob('*.wav'))
    if a.selection:
        selected=set(json.loads(pathlib.Path(a.selection).read_text())); paths=[f for f in paths if f.name in selected]
    if a.mode=='clap':
        import onnxruntime as ort
        from transformers import AutoTokenizer
        from transformers.audio_utils import mel_filter_bank, spectrogram, window_function
        opts=ort.SessionOptions();opts.intra_op_num_threads=2;opts.inter_op_num_threads=1
        audio=ort.InferenceSession(str(pathlib.Path(a.model)/'onnx/audio_model_quantized.onnx'),opts,providers=['CPUExecutionProvider'])
        text=ort.InferenceSession(str(pathlib.Path(a.model)/'onnx/text_model_quantized.onnx'),opts,providers=['CPUExecutionProvider'])
        tokenizer=AutoTokenizer.from_pretrained(a.model,local_files_only=True)
        # Match ClapFeatureExtractor's NumPy rand_trunc/repeatpad path using its
        # public audio utilities. Fusion requires Torch; this unfused model does not.
        cfg=json.loads((pathlib.Path(a.model)/'preprocessor_config.json').read_text())
        filters=mel_filter_bank(num_frequency_bins=513,num_mel_filters=64,min_frequency=cfg['frequency_min'],max_frequency=cfg['frequency_max'],sampling_rate=48000,norm='slaney',mel_scale='slaney')
        def feature(chunk, **unused):
            repeats=480000//len(chunk)
            padded=np.pad(np.tile(chunk,repeats),(0,480000-len(chunk)*repeats))
            mel=spectrogram(padded,window_function(1024,'hann'),frame_length=1024,hop_length=480,power=2.0,mel_filters=filters,log_mel='dB')
            return {'input_features':mel.T[None,None,:,:].astype(np.float32)}
        toks=tokenizer([x[1] for x in PROMPTS],padding=True,truncation=True,return_tensors='np')
        te=text.run(None,{x.name:toks[x.name].astype(np.int64) for x in text.get_inputs()})[0]
        te=te/(np.linalg.norm(te,axis=-1,keepdims=True)+1e-12)
        pathlib.Path(out.parent/'clap_prompts.json').write_text(json.dumps({'model':'Xenova/clap-htsat-unfused','revision':'c28f2883575e590e04d3146ff0713c2448d691ba','precision':'ONNX int8','note':'Cosine similarities are not probabilities; relative rankings depend on this prompt set. No equipment identity is confirmed by CLAP alone.','prompts':PROMPTS},ensure_ascii=False,indent=2)+'\n')
    else:
        from faster_whisper import WhisperModel
        asr=WhisperModel(a.model,device='cpu',compute_type='int8',cpu_threads=5,num_workers=1,local_files_only=True)
    for idx,path in enumerate(paths,1):
        if path.name in done:continue
        started=time.time()
        if a.mode=='clap':
            y=wave(path,48000);rms=float(np.sqrt(np.mean(y*y)));peak=float(np.max(np.abs(y)));windows=[];scores=[]
            for start in range(0,len(y),480000):
                chunk=y[start:start+480000]
                feats=feature(chunk,sampling_rate=48000,return_tensors='np',truncation='rand_trunc',padding='repeatpad')
                feed={v.name:np.asarray(feats[v.name],dtype=np.float32 if v.type=='tensor(float)' else np.bool_) for v in audio.get_inputs()}
                ae=audio.run(None,feed)[0];ae=ae/(np.linalg.norm(ae,axis=-1,keepdims=True)+1e-12)
                sims=(ae@te.T)[0]; scores.append(sims)
                ranking=np.argsort(-sims)[:8]
                windows.append({'start':round(start/48000,4),'end':round(min(start+480000,len(y))/48000,4),'top':[{'label':PROMPTS[j][0],'cosine':round(float(sims[j]),5)} for j in ranking]})
            mean=np.mean(scores,axis=0);rank=np.argsort(-mean)
            result={'source_file':path.name,'method':'CLAP ONNX int8; all consecutive non-overlapping windows <=10s; short clips repeat-padded to model length','duration_seconds':len(y)/48000,'rms':rms,'peak':peak,'top':[{'label':PROMPTS[j][0],'cosine':round(float(mean[j]),5)} for j in rank[:8]],'all_mean_cosines':{PROMPTS[j][0]:round(float(mean[j]),5) for j in range(len(PROMPTS))},'windows':windows}
        else:
            y=wave(path,16000)
            segments,info=asr.transcribe(y,language=a.language,task='transcribe',beam_size=5,temperature=0.0,vad_filter=True,vad_parameters={'min_silence_duration_ms':250,'speech_pad_ms':150},condition_on_previous_text=False,word_timestamps=False)
            segs=[{'start':s.start,'end':s.end,'text':s.text,'avg_logprob':s.avg_logprob,'no_speech_prob':s.no_speech_prob,'compression_ratio':s.compression_ratio} for s in segments]
            result={'source_file':path.name,'model':pathlib.Path(a.model).name,'language':info.language,'language_probability':info.language_probability,'requested_language':a.language,'segments':segs,'text':''.join(s['text'] for s in segs).strip(),'duration_after_vad':info.duration_after_vad,'method':'Whisper int8, beam5, VAD, temperature0, task=transcribe; no supplied station text or decoding prompt'}
        result['elapsed_seconds']=round(time.time()-started,3)
        with out.open('a') as f:f.write(json.dumps(result,ensure_ascii=False)+'\n');f.flush()
        print(json.dumps({'mode':a.mode,'index':idx,'file':path.name,'result':result.get('text',result.get('top',[])[:2])},ensure_ascii=False),flush=True)

if __name__=='__main__':main()
