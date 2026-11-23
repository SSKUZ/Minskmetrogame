"""Join preserved per-file evidence; never modify the runtime sound bank.

Confidence is an editorial low/medium assessment, not a calibrated probability.
Machine-derived content always requires review before use in game events.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2] / 'data/identification_tz54_1'
LABELS = {
    'speech.announcement': 'речевое объявление по громкой связи',
    'speech.noisy': 'речь на фоне шума',
    'speech.conversation': 'разговоры людей',
    'speech.radio': 'речь с окраской радиосвязи',
    'speech.warning': 'речевое предупреждение пассажирам',
    'train.motor': 'вой тягового двигателя с изменением тона',
    'train.running': 'гул движения, дребезг и шум колёс',
    'train.coasting': 'ровный гул качения и дребезг',
    'train.brake_electric': 'снижение тона двигателя при замедлении',
    'train.brake_squeal': 'высокий металлический скрип колёс или тормозов',
    'train.rail_joints': 'ритмичный стук колёс по рельсовым стыкам',
    'train.switch': 'нерегулярные удары при проходе стрелки',
    'train.passby': 'нарастающий и затихающий шум проезжающего поезда',
    'train.compressor': 'механическое жужжание компрессора',
    'train.ventilation': 'ровный шум вентилятора или электрооборудования',
    'pneumatic.release': 'короткий сброс сжатого воздуха',
    'pneumatic.continuous': 'продолжительное шипение воздуха',
    'doors.sliding_open': 'движение раздвижных дверей с шипением',
    'doors.sliding_close': 'движение раздвижных дверей с конечным ударом',
    'doors.pneumatic': 'шипение, трение и удар дверного механизма',
    'doors.hinged': 'скрип или хлопок тяжёлой распашной двери',
    'doors.latch': 'металлический щелчок дверной защёлки или ручки',
    'cab.controller': 'последовательные щелчки механического рычага',
    'cab.switch': 'щелчок переключателя',
    'cab.button': 'короткий щелчок кнопки',
    'cab.relay': 'щелчки электрического реле',
    'cab.horn': 'гудок или свисток',
    'cab.bell': 'металлический звонок',
    'cab.alarm': 'повторяющиеся сигналы тревоги',
    'cab.buzzer': 'протяжный электрический зуммер',
    'cab.motor': 'жужжание небольшого электромотора',
    'environment.station': 'гул станции с дальними звуками людей',
    'environment.crowd': 'голоса и шаги в людном помещении',
    'environment.tunnel': 'гул и эхо подземного пространства',
    'environment.depot': 'производственный гул и металлические звуки',
    'other.footsteps': 'шаги по твёрдой поверхности',
    'other.knock': 'короткие удары или металлический стук',
    'other.scrape': 'трение или скрип металла',
    'other.whoosh': 'короткий воздушный свист или взмах',
    'other.music': 'музыкальная мелодия или ритм',
    'other.ui': 'короткий искусственный интерфейсный эффект',
    'other.static': 'треск, помехи или искажённое жужжание',
    'other.silence': 'очень тихая запись или тишина',
    'other.low_hum': 'ровный низкий гул',
    'other.water': 'плеск или капли воды',
    'other.car_engine': 'изменяющий обороты двигатель',
    'other.breath': 'дыхание или кашель',
    'other.electronic_tone': 'короткий электронный тон',
}


def evidence(name):
    path = ROOT / name
    if not path.exists():
        return {}
    return {r['source_file']: dict(r, evidence_file=name) for r in map(json.loads, path.read_text().splitlines())}


def main():
    path = ROOT / 'individual_catalog.json'
    catalog = json.loads(path.read_text())
    clap, asr = evidence('clap_evidence.jsonl'), evidence('asr_small.jsonl')
    asr.update(evidence('asr_refinements.jsonl'))
    notes_path = ROOT / 'content_notes.json'
    notes = json.loads(notes_path.read_text()) if notes_path.exists() else {}
    for row in catalog['files']:
        key = row['source_file']
        c, a, note = clap.get(key), asr.get(key), notes.get(key, {})
        if not c:
            continue
        top = c['top']
        first, second = top[0], top[1]
        label, score = first['label'], first['cosine']
        margin = score - second['cosine']
        speech_score = max(v for k, v in c['all_mean_cosines'].items() if k.startswith('speech.'))
        text = a.get('text', '') if a else ''
        segments = a.get('segments', []) if a else []
        segment_quality = any(s['avg_logprob'] > -1.0 and s['no_speech_prob'] < .9 and s['compression_ratio'] < 3 for s in segments)
        suspect_segments = any(s['no_speech_prob'] >= .6 or s['compression_ratio'] >= 2.4 or s['end'] > row['duration_seconds'] + .5 for s in segments)
        coherent_announcement = any(v in text.lower() for v in ['станц', 'пассаж', 'посажи', 'station', 'stanzia', 'stacja'])
        speech_supported = speech_score >= .25 or (speech_score >= .12 and coherent_announcement and len(text) >= 25)
        accepted = bool(text and row['duration_seconds'] >= 2 and speech_supported and segment_quality)
        if note.get('reject_transcript'):
            accepted = False
        row['content_analysis_completed'] = bool(a)
        row['manual_review_required'] = True
        row['station_id'] = row['direction'] = row['event_id'] = None
        row['transcript_original'] = text if accepted else None
        row['transcript_status'] = (('machine_low_confidence' if suspect_segments else 'machine_unverified') if accepted else 'rejected_model_output' if text else 'no_text_detected' if a else 'pending')
        row['rejected_asr_text'] = text if text and not accepted else None
        row['alternative_hypotheses'] = [dict(x, description_ru=LABELS[x['label']]) for x in top[1:4]]
        row['evidence'] = {
            'clap': {'file': 'clap_evidence.jsonl', 'source_file': key, 'top_cosine': score, 'top_margin': round(margin, 5)},
            'asr': {'file': a['evidence_file'], 'source_file': key, 'model': a.get('model'), 'language': a.get('language'), 'requested_language': a.get('requested_language'), 'language_probability': a.get('language_probability'), 'quality_warning': suspect_segments} if a else None,
            'rms': c['rms'], 'peak': c['peak'],
        }
        if accepted:
            low = text.lower()
            phase = 'next_station' if any(v in low for v in ['наступн', 'следующ', 'next station']) else 'arrival' if any(v in low for v in ['станц', 'stanzia', 'station', 'stacja']) and not any(v in low for v in ['пассаж', 'посажи', 'вакцин']) else 'warning'
            row['identified_category'] = 'announcer'
            row['identified_subcategory'] = note.get('subcategory', phase)
            row['content_description_ru'] = note.get('description_ru', 'Речевое объявление. Машинная расшифровка с возможными ошибками: ' + text)
            row['identification_status'] = 'machine_provisional'
            row['confidence'] = 'medium' if speech_score >= .25 and not suspect_segments else 'low'
            row['confidence_basis'] = 'ASR дал связное объявление; точность слов и названий требует прослушивания. Уверенность относится к смысловой категории, не к каждому слову.' + (' CLAP поддерживает речь.' if speech_score >= .25 else ' Сходство CLAP с речью слабое, достоверность снижена.')
            if suspect_segments:
                row['confidence_basis'] += ' Есть предупреждение качества ASR: высокая вероятность отсутствия речи, повторяемость текста или выход временных меток за длительность.'
        elif score >= .32 and not label.startswith('speech.'):
            row['identified_category'], row['identified_subcategory'] = label.split('.', 1)
            row['content_description_ru'] = f"Запись {row['duration_seconds']:.2f} с. Предварительная гипотеза: {LABELS[label]}. Альтернатива: {LABELS[second['label']]}. Точный механизм и назначение не подтверждены."
            row['identification_status'] = 'machine_provisional'
            row['confidence'] = 'medium' if score >= .45 and margin >= .06 else 'low'
            row['confidence_basis'] = 'Сходство CLAP с описаниями звуков; cosine не является вероятностью. ASR не дал подтверждаемой расшифровки. Модель не подтверждает принадлежность к конкретному оборудованию.'
        else:
            row['identified_category'] = 'unidentified'
            row['identified_subcategory'] = 'possible_speech' if label.startswith('speech.') else 'ambiguous_effect'
            row['content_description_ru'] = f"Запись {row['duration_seconds']:.2f} с. Содержание не установлено. Ведущие гипотезы: {LABELS[label]}; {LABELS[second['label']]}."
            row['identification_status'] = 'unresolved'
            row['confidence'] = 'low'
            row['confidence_basis'] = 'Нет согласованного подтверждения содержания; требуется индивидуальное прослушивание.'
        row['station_name_candidate'] = note.get('station_name')
        row['station_candidate_id'] = note.get('station_candidate_id')
        row['semantic_notes'] = note.get('notes')
    catalog['stage'] = 'individual_machine_analysis_requires_review'
    catalog['confidence_definition'] = 'low/medium are qualitative editorial assessments, not calibrated model probabilities; no record is human-listening verified'
    catalog['runtime_assignment_status'] = 'No event, direction or station bindings activated; runtime audio_catalog.json unchanged.'
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    fields = ['source_file', 'duration_seconds', 'identified_category', 'identified_subcategory', 'content_description_ru', 'transcript_original', 'transcript_status', 'rejected_asr_text', 'station_name_candidate', 'station_candidate_id', 'confidence', 'confidence_basis', 'identification_status', 'manual_review_required', 'content_analysis_completed', 'source_sha256', 'ogg_resource', 'ogg_sha256']
    with path.with_suffix('.csv').open('w', encoding='utf-8-sig', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fields, extrasaction='ignore')
        writer.writeheader()
        writer.writerows(catalog['files'])
    print(json.dumps({'records': len(catalog['files']), 'clap': len(clap), 'asr': len(asr)}, ensure_ascii=False))


if __name__ == '__main__':
    main()
