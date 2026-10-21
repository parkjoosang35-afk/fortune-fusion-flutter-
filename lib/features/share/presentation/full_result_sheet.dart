import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../application/share_service.dart';
// [REQ-04 — 신통방통_저장기능_정상화_개발지시서_v1.0] 이 파일은 기존에
// `if (dart.library.html)` 조건부 export로 직접 플랫폼 구현 파일을
// import하고 있었다 — image_gallery_saver.dart에 이미 적용된 kIsWeb
// 런타임 분기(REQ-04)를 우회하는 별도의 P-03 위험 지점이었다(dart2wasm
// 빌드 시 이 조건이 거짓으로 평가되어 Web인데도 io 구현이 선택될 수
// 있었음). 공용 진입점(image_gallery_saver.dart)을 통하도록 교체한다.
import '../../../core/util/image_gallery_saver.dart';
import '../../../core/util/original_result_capture.dart';
import '../../../core/util/save_filename.dart';
import '../../../core/widgets/app_toast.dart';

/// 앱·공유 수신 화면이 같은 전체 결과 데이터를 사용한다. 본문 절단 없음.
List<Map<String, String>> fullResultSections(Map<String, dynamic> payload) {
  final sections = <Map<String, String>>[];
  void add(String title, dynamic body) {
    if (body is String && body.isNotEmpty) {
      sections.add({'title': title, 'body': body});
    }
  }

  add('결과 요약', payload['summary']);
  add('질문', payload['question']);
  final blocks = payload['blocks'];
  if (blocks is List) {
    for (final block in blocks.whereType<Map>()) {
      add(block['title']?.toString() ?? '', block['body']);
    }
  }
  final positions = payload['positions'];
  if (positions is List) {
    for (final position in positions.whereType<Map>()) {
      add(
        '${position['label'] ?? ''} · ${position['cardName'] ?? ''}${position['isReversed'] == true ? ' (역방향)' : ''}',
        position['interpretation'],
      );
    }
  }
  for (final key in ['features', 'lines', 'topicResults']) {
    final entries = payload[key];
    if (entries is Map) {
      for (final entry in entries.entries) {
        add(entry.key.toString(), entry.value);
      }
    }
  }
  final advice = payload['advice'];
  if (advice is Map) add(advice['label']?.toString() ?? '조언', advice['text']);
  for (final entry in {
    '행운의 색': 'luckyColor',
    '행운의 숫자': 'luckyNumber',
    '레벨': 'levelName',
    '점등일수': 'daysLit',
    '소원 빛깔': 'wishColor',
  }.entries) {
    if (payload[entry.value] != null) {
      add(entry.key, payload[entry.value].toString());
    }
  }
  if (blocks is! List &&
      positions is! List &&
      payload['features'] is! Map &&
      payload['lines'] is! Map) {
    final highlights = payload['highlights'];
    if (highlights is List) {
      for (final line in highlights) {
        add('', line);
      }
    }
  }
  return sections;
}

Future<void> showFullResultSheet(
  BuildContext context, {
  required String title,
  required String shareUrl,
  required Map<String, dynamic> payload,
  Uint8List? originalPng,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => FullResultSheet(
    title: title,
    shareUrl: shareUrl,
    payload: payload,
    originalPng: originalPng,
  ),
);

class FullResultSheet extends StatefulWidget {
  const FullResultSheet({
    super.key,
    required this.title,
    required this.shareUrl,
    required this.payload,
    this.originalPng,
  });
  final String title;
  final String shareUrl;
  final Map<String, dynamic> payload;
  final Uint8List? originalPng;
  @override
  State<FullResultSheet> createState() => _FullResultSheetState();
}

class _FullResultSheetState extends State<FullResultSheet> {
  final _capture = GlobalKey();
  bool _saving = false;
  bool _sharing = false;

  Future<void> _share() async {
    if (_sharing) return;
    if (kIsWeb) {
      await ShareService.shareWebPage(context, title: widget.title, url: widget.shareUrl);
      return;
    }
    setState(() => _sharing = true);
    try {
      final png = widget.originalPng ?? await captureOriginalResult(_capture);
      if (!mounted) return;
      await ShareService.shareImageDirectly(context, widget.title, png);
    } catch (_) {
      if (mounted) AppToast.show(context, '결과 이미지가 준비되지 않았어요. 다시 시도해주세요.', isError: true);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final png = widget.originalPng ?? await captureOriginalResult(_capture);
      // [REQ-05] 원인별 안내 — 권한 거부/공간 부족/형식 오류/기타를 구분.
      // [REQ-09] 파일명 규칙 통일: sintong_{서비스}_{결과ID}_{yyyyMMdd_HHmmss}.
      final result = await saveImageBytesToGalleryDetailed(
        png,
        name: buildSaveFileName('share', 'original'),
      );
      if (mounted) {
        if (result.isSuccess) {
          // [REQ-09] 성공 토스트 문구를 전 화면 공통 표준으로 통일.
          AppToast.show(context, gallerySaveSuccessMessage());
        } else {
          AppToast.show(
            context,
            result.failureMessage ?? '저장에 실패했어요. 잠시 후 다시 시도해주세요.',
            isError: true,
          );
        }
      }
    } catch (_) {
      if (mounted) {
        AppToast.show(context, '결과 이미지를 만들지 못했어요. 다시 시도해주세요.', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: MediaQuery.sizeOf(context).height * .9,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Expanded(
                child: Text(
                  '전체 결과 공유',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(kIsWeb ? '전송하면 링크를 가진 사람이 아래 결과를 볼 수 있어요.' : '아래 결과를 이미지로 공유합니다.'),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: widget.originalPng != null
                ? Image.memory(
                    widget.originalPng!,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                  )
                : RepaintBoundary(
                    key: _capture,
                    child: Container(
                      color: const Color(0xFF111113),
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '신통방통',
                            style: TextStyle(
                              color: Color(0xFFE9C46A),
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.title,
                            style: const TextStyle(
                              color: Color(0xFFF2F0EC),
                              fontSize: 23,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          for (final section in fullResultSections(
                            widget.payload,
                          )) ...[
                            const SizedBox(height: 20),
                            if (section['title']!.isNotEmpty)
                              Text(
                                section['title']!,
                                style: const TextStyle(
                                  color: Color(0xFFE9C46A),
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            const SizedBox(height: 8),
                            Text(
                              section['body']!,
                              style: const TextStyle(
                                color: Color(0xFFF2F0EC),
                                fontSize: 15,
                                height: 1.65,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  // [REQ-08 — 신통방통_저장기능_정상화_개발지시서_v1.0]
                  // 기기 저장 버튼 문구/아이콘을 전 화면 공통
                  // "이미지로 저장" + download_rounded로 통일.
                  child: OutlinedButton.icon(
                    onPressed: _saving || widget.originalPng == null
                        ? null
                        : _save,
                    icon: _saving
                        ? const SizedBox.shrink()
                        : const Icon(Icons.download_rounded, size: 18),
                    label: Text(_saving ? '저장 중' : '이미지로 저장'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _sharing ? null : _share,
                    child: Text(_sharing ? '이미지 준비 중' : kIsWeb ? '링크 전송' : '이미지 전송'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
