import 'dart:convert';
import 'package:flutter/services.dart';

/// [신통방통 사운드 배치 개발 기획서 v1.0 — 2026-10-21] §9.2 "사운드 설정은
/// 코드에 하드코딩하지 않는다. 이 JSON을 설정 파일로 만들면 기획 변경 시
/// 코드 수정 없이 교체된다." 원칙에 따라, `assets/config/sound_routes.json`
/// 하나를 유일한 소스로 두고 이 파일이 파싱만 담당한다.
///
/// 화면(메뉴) 하나의 BGM·앰비언스 배치 1건.
class SoundRoute {
  const SoundRoute({required this.bgm, this.amb, this.ambGainDb});

  /// bgm 파일명(확장자 없음, `assets/audio/bgm/{bgm}.mp3`로 조립).
  final String bgm;

  /// 앰비언스 파일명(확장자 없음). null이면 이 화면은 앰비언스를 쓰지 않는다
  /// (기획서 §5.1 — 8개 메뉴 중 3개 화면에만 앰비언스가 붙는다).
  final String? amb;

  /// 앰비언스 게인(dB). BGM 대비 상대값(기획서 §9.2 기준 -20dB).
  final double? ambGainDb;

  factory SoundRoute.fromJson(Map<String, dynamic> json) {
    return SoundRoute(
      bgm: json['bgm'] as String,
      amb: json['amb'] as String?,
      ambGainDb: (json['ambGain'] as num?)?.toDouble(),
    );
  }
}

/// 덕킹(ducking) 1건 — 어떤 이벤트가 발생했을 때 BGM/앰비언스를 얼마나,
/// 얼마나 빠르게 줄였다가 되돌리는지(기획서 §7.1).
class DuckProfile {
  const DuckProfile({
    required this.bgmDb,
    required this.ambDb,
    required this.attackMs,
    required this.releaseMs,
  });

  final double bgmDb;
  final double ambDb;
  final int attackMs;
  final int releaseMs;

  factory DuckProfile.fromJson(Map<String, dynamic> json) {
    return DuckProfile(
      bgmDb: (json['bgmDb'] as num).toDouble(),
      ambDb: (json['ambDb'] as num).toDouble(),
      attackMs: (json['attackMs'] as num).toInt(),
      releaseMs: (json['releaseMs'] as num).toInt(),
    );
  }
}

/// 전환 표식음 설정(기획서 §6.2) — 메뉴 전환 시 터치 +0.3초에 삽입되는
/// 범종+양금 혼합음.
class TransitionMarker {
  const TransitionMarker({
    required this.file,
    required this.atSeconds,
    required this.gainDb,
  });

  final String file;
  final double atSeconds;
  final double gainDb;

  factory TransitionMarker.fromJson(Map<String, dynamic> json) {
    return TransitionMarker(
      file: json['file'] as String,
      atSeconds: (json['atSeconds'] as num).toDouble(),
      gainDb: (json['gainDb'] as num).toDouble(),
    );
  }
}

/// 동시 재생 제한(기획서 §7.3).
class SoundLimits {
  const SoundLimits({
    required this.minRetriggerMs,
    required this.maxVoices,
    required this.channelPoolSize,
  });

  final int minRetriggerMs;
  final int maxVoices;
  final int channelPoolSize;

  factory SoundLimits.fromJson(Map<String, dynamic> json) {
    return SoundLimits(
      minRetriggerMs: (json['minRetriggerMs'] as num).toInt(),
      maxVoices: (json['maxVoices'] as num).toInt(),
      channelPoolSize: (json['channelPoolSize'] as num).toInt(),
    );
  }
}

/// `assets/config/sound_routes.json` 전체를 담는 불변 설정 객체.
class SoundConfig {
  const SoundConfig({
    required this.routes,
    required this.crossfadeSeconds,
    required this.marker,
    required this.duck,
    required this.limits,
  });

  final Map<String, SoundRoute> routes;
  final double crossfadeSeconds;
  final TransitionMarker marker;
  final Map<String, DuckProfile> duck;
  final SoundLimits limits;

  factory SoundConfig.fromJson(Map<String, dynamic> json) {
    final routesJson = json['routes'] as Map<String, dynamic>;
    final duckJson = json['duck'] as Map<String, dynamic>;
    return SoundConfig(
      routes: routesJson.map(
        (key, value) => MapEntry(
          key,
          SoundRoute.fromJson(value as Map<String, dynamic>),
        ),
      ),
      crossfadeSeconds: (json['crossfadeSeconds'] as num).toDouble(),
      marker: TransitionMarker.fromJson(
        json['marker'] as Map<String, dynamic>,
      ),
      duck: duckJson.map(
        (key, value) => MapEntry(
          key,
          DuckProfile.fromJson(value as Map<String, dynamic>),
        ),
      ),
      limits: SoundLimits.fromJson(json['limits'] as Map<String, dynamic>),
    );
  }

  /// 설정 파일을 asset에서 로드한다. 파일이 없거나 파싱 실패 시 null을
  /// 반환한다 — [저사양 degrade 원칙]에 따라 사운드 설정 로드 실패가 앱
  /// 구동 자체를 막아서는 안 된다(호출부에서 null이면 사운드 기능 전체를
  /// 조용히 비활성화한다).
  static Future<SoundConfig?> load() async {
    try {
      final raw = await rootBundle.loadString(
        'assets/config/sound_routes.json',
      );
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return SoundConfig.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
