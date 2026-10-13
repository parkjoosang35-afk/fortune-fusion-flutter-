import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/util/image_gallery_saver_io.dart'
    if (dart.library.html) '../../../core/util/image_gallery_saver_web.dart';
import '../../../core/util/safe_share.dart';
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
  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      if (widget.originalPng == null) {
        throw StateError('원래 결과 페이지에서 저장해주세요.');
      }
      final ok = await saveImageBytesToGallery(
        widget.originalPng!,
        name: 'sintong_original_${DateTime.now().millisecondsSinceEpoch}',
      );
      if (!ok) throw StateError('원본 결과 저장 실패');
      if (mounted) {
        AppToast.show(
          context,
          kIsWeb ? '원본 결과 파일 다운로드를 요청했어요.' : '원본 결과를 갤러리에 저장했어요.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(context, '전체 결과를 저장하지 못했어요. $e', isError: true);
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
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('전송하면 링크를 가진 사람이 아래 결과를 볼 수 있어요.'),
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
                  child: OutlinedButton(
                    onPressed: _saving || widget.originalPng == null
                        ? null
                        : _save,
                    child: Text(_saving ? '저장 중' : '전체 저장'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () => safeShareText(
                      context,
                      '${widget.title}\n${widget.shareUrl}',
                      subject: '신통방통 전체 결과',
                    ),
                    child: const Text('링크 전송'),
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
