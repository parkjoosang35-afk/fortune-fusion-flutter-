import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/util/image_gallery_saver.dart';
import '../../../../core/widgets/app_toast.dart';
import '../../application/shrine_v3_provider.dart';
import '../../domain/shrine_order.dart';
import '../theme/shrine_v3_theme.dart';
import '../widgets/incense_rite_overlay.dart';
import '../widgets/talisman_save_image.dart';
import '../widgets/talisman_zoom_overlay.dart';
import '../widgets/unique_talisman_overlay.dart';
import 'shrine_v3_detail_screen.dart';

/// 신당(THE SHRINE) v3 — 10 부적함 · 부적 상세. 서버 상세 응답
/// ([ShrineOrderDetail])을 그대로 표시만 한다. 향 올리기는
/// [ShrineV3Provider.lightIncense]를 호출해 서버가 계산한 daysAfter/
/// expiresDateKey를 그대로 반영한다(클라이언트 재계산 없음).
class ShrineV3OwnedScreen extends StatefulWidget {
  const ShrineV3OwnedScreen({super.key, required this.orderId});
  final int orderId;

  @override
  State<ShrineV3OwnedScreen> createState() => _ShrineV3OwnedScreenState();
}

class _ShrineV3OwnedScreenState extends State<ShrineV3OwnedScreen> {
  ShrineOrderDetail? _detail;
  bool _loading = true;
  String? _error;
  bool _lighting = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<ShrineV3Provider>();
    final result = await repo.getBoxDetailPublic(widget.orderId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result != null) {
        _detail = result;
      } else {
        _error = repo.error ?? '부적 정보를 불러오지 못했어요.';
      }
    });
  }

  Future<void> _lightIncense() async {
    final order = _detail?.order;
    if (order == null) return;
    setState(() => _lighting = true);
    final provider = context.read<ShrineV3Provider>();
    final result = await showIncenseRiteDialog(context, provider: provider, order: order);
    if (!mounted) return;
    setState(() => _lighting = false);
    if (result != null) {
      AppToast.show(context, '향을 올렸습니다 · ${result.daysAfter}일 남음');
      _load();
    } else {
      final err = provider.error;
      if (err != null) {
        AppToast.show(context, err, isError: true);
      }
    }
  }

  /// README §6/§7 "사진첩 저장" — HTML `saveTalisman()`의 Canvas 합성을
  /// [buildTalismanSaveImageBytes]로 그대로 재현한 뒤, 기존
  /// [saveImageBytesToGalleryDetailed](Android: gal 갤러리 저장, Web: 파일
  /// 다운로드)에 그대로 넘긴다 — 저장 경로 자체는 귀인지도 등 기존 화면과
  /// 완전히 동일하게 재사용한다(§3 저장 단일 경로 유지 원칙).
  Future<void> _saveToGallery(ShrineOrder order) async {
    setState(() => _saving = true);
    try {
      final bytes = await buildTalismanSaveImageBytes(order);
      final result = await saveImageBytesToGalleryDetailed(
        bytes,
        name: '신당_${order.talisman.name}_${order.serial.replaceFirst('神堂 ', '')}',
      );
      if (!mounted) return;
      if (result.isSuccess) {
        AppToast.show(context, gallerySaveSuccessMessage());
      } else {
        AppToast.show(
          context,
          result.failureMessage ?? '저장하지 못했어요 · 잠시 뒤 다시',
          isError: true,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToast.show(context, '저장하지 못했어요 · 잠시 뒤 다시', isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShrineV3Colors.paper,
      appBar: AppBar(
        backgroundColor: ShrineV3Colors.paper,
        foregroundColor: ShrineV3Colors.ink,
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, style: ShrineV3TextStyles.ui.copyWith(fontSize: 13)),
                    const SizedBox(height: 12),
                    ElevatedButton(onPressed: _load, child: const Text('다시 시도')),
                  ],
                ),
              )
            : _buildBody(_detail!),
      ),
    );
  }

  Widget _buildBody(ShrineOrderDetail d) {
    final o = d.order;
    final info = d.talismanDetail;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Center(
          child: Column(
            children: [
              GestureDetector(
                onTap: () => showTalismanZoomOverlay(context, talisman: info, order: o),
                child: UniqueTalismanOverlay(order: o, width: 112, height: 258),
              ),
              const SizedBox(height: 10),
              Text('${o.talisman.hanja} · 내 부적', style: ShrineV3TextStyles.mono.copyWith(fontSize: 11)),
              Text(o.talisman.name, style: ShrineV3TextStyles.title.copyWith(fontSize: 22)),
              const SizedBox(height: 6),
              Text(
                '부적을 누르면 크게 볼 수 있어요',
                style: ShrineV3TextStyles.ui.copyWith(fontSize: 11, color: ShrineV3Colors.ink3),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        UniqueRecordCard(order: o),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: ShrineV3Colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShrineV3Colors.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _row2('상태', o.isActive ? '소지 중 · ${o.daysRemaining}일 남음' : o.isExpired ? '기간 만료' : '보관 중'),
              _row2('소지 기간', o.isArchived ? '보관 중' : '49일 · ${o.expiresDateKey}까지'),
              if (o.isActive)
                _row2('오늘의 향', o.incenseLitToday ? '올렸어요 · 내일 다시' : '아직 올리지 않았어요'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.fromLTRB(0, 6, 0, 16),
          decoration: BoxDecoration(
            color: ShrineV3Colors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: ShrineV3Colors.line),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _section('意', '부적의 의미', info.meaning),
                _section('期', '효력 기간', info.validityTerm),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (o.isActive) ...[
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: (_lighting || o.incenseLitToday) ? null : _lightIncense,
              style: ElevatedButton.styleFrom(
                backgroundColor: o.incenseLitToday ? ShrineV3Colors.paperDark : const Color(0xFF2A1A10),
                foregroundColor: o.incenseLitToday ? ShrineV3Colors.ink3 : const Color(0xFFFFD98A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _lighting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(o.incenseLitToday ? '香 오늘 향을 올렸어요' : '香 향 올리기 · 기운 +3일 ›'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => showTalismanZoomOverlay(context, talisman: info, order: o),
              style: OutlinedButton.styleFrom(
                foregroundColor: ShrineV3Colors.ink,
                side: const BorderSide(color: ShrineV3Colors.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('부적 크게 보기'),
            ),
          ),
        ] else if (o.isExpired)
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ShrineV3DetailScreen(talismanId: info.id)),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: ShrineV3Colors.seal,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('같은 부적 다시 부탁하기 ›'),
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => showTalismanZoomOverlay(context, talisman: info, order: o),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2A1A10),
                foregroundColor: const Color(0xFFFFD98A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('부적 크게 보기 ›'),
            ),
          ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: _saving ? null : () => _saveToGallery(o),
            style: OutlinedButton.styleFrom(
              foregroundColor: ShrineV3Colors.seal,
              side: const BorderSide(color: ShrineV3Colors.seal),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('⤓ 사진첩에 저장'),
          ),
        ),
      ],
    );
  }

  Widget _row2(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: ShrineV3TextStyles.ui.copyWith(fontSize: 12)),
        Text(value, style: ShrineV3TextStyles.body.copyWith(fontSize: 13)),
      ],
    ),
  );

  Widget _section(String icon, String title, String body) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(icon, style: const TextStyle(color: ShrineV3Colors.seal, fontWeight: FontWeight.w900)),
            const SizedBox(width: 6),
            Text(title, style: ShrineV3TextStyles.body.copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 4),
        Text(body, style: ShrineV3TextStyles.ui.copyWith(fontSize: 12.5)),
      ],
    ),
  );
}
