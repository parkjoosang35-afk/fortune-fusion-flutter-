import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/features/shrine/state/shrine_session_provider.dart';

void main() {
  test('ShrineState.fromJson via jsonEncode/jsonDecode round-trip (matches real code path)', () {
    final now = DateTime.now().millisecondsSinceEpoch;
    const day = 86400000;
    Map spec(String key) => {
      "key": key, "type": "fate", "flavor": "observe", "story": null, "ending": null, "element": null,
      "sig": "命", "name": "명운부", "head": "命運符", "base": "星", "paper": "gold",
      "phrase": "照身", "phraseMeaning": "몸을 비추다", "motif": "目",
      "border": "single", "seal": "square", "designId": "d1"
    };
    Map source() => {"story": "red-bell", "ending": "e1", "flags": [], "path": []};

    final box = [
      {"key": "k_full", "t": "fate", "no": "N°0002", "date": "2025 · 01 · 01",
       "spec": spec("k_full"), "source": source(), "mode": "full", "saved": false,
       "at": now - 20*day, "tended": 0, "lastTend": null, "sentAt": null},
    ];
    final state = {
      "data": {"box": box, "issued": 1, "aboutSeen": true},
      "pref": {}
    };

    // 실제 코드 경로 재현: jsonEncode -> (localStorage 저장 가정) -> jsonDecode -> fromJson
    final encoded = jsonEncode(state);
    print('encoded length: ${encoded.length}');
    final decoded = jsonDecode(encoded);
    final s = ShrineState.fromJson(decoded);
    expect(s.box.length, 1);
    print('OK: box[0].spec.name=${s.box[0].spec.name}');
  });
}
