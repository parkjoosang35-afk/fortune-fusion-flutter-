import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../application/consultation_provider.dart';
import '../domain/consultation_model.dart';
import 'widgets/consultation_type_style.dart';
import 'widgets/message_bubble.dart';
import 'widgets/input_bar.dart';
import 'widgets/consultation_step_widgets.dart';

/// 07단계 - ConsultationChatScreen (채팅형 패턴)
/// 09단계 §1.2 스트리밍 응답을 말풍선에 실시간으로 이어붙여 표시한다.
///
/// 07단계(추가) §3.4 - HelloBot류 앱의 따뜻하고 친근한 채팅 UX를 참고하여
/// 다음을 개편한다:
///  1) 헤더에 상담 유형별 이모지/색상 + "상담 변경" 버튼 추가
///  2) 메시지 리스트를 MessageBubble(FadeInUp+Scale) 컴포넌트로 분리
///  3) 새 메시지 추가 시 자동 하단 스크롤 유지
///  4) 상담 유형 변경 시 부드러운 페이드아웃 → 유형 선택 화면 이동 → 복귀 시 새 웰컴 메시지 페이드인
///
/// 07단계(추가) §3.5 - 사주상담/타로상담을 채팅 흐름 안에서 완결시키기 위해
/// [ConsultationProvider.currentStep]에 따라 하단 입력 영역을 동적으로 전환한다
/// ([_buildInputArea]). 텍스트 입력(InputBar) / 날짜·시간 피커 / 성별 버튼
/// (GenderSelectionBar) / 타로 카드 선택 버튼(TarotCardSelectionBar) / 계산 중
/// 표시(CalculatingIndicatorBar) 5가지 상태를 오간다.
class ConsultationChatScreen extends StatefulWidget {
  const ConsultationChatScreen({super.key});

  @override
  State<ConsultationChatScreen> createState() => _ConsultationChatScreenState();
}

class _ConsultationChatScreenState extends State<ConsultationChatScreen>
    with TickerProviderStateMixin {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  // 07단계(추가) §3.4 - 상담 유형 변경 시 화면 전체를 부드럽게 페이드아웃/인 시키기 위한 컨트롤러
  late final AnimationController _screenFadeController;
  late final Animation<double> _screenFadeAnim;

  int _prevMessageCount = 0;

  @override
  void initState() {
    super.initState();
    _screenFadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: 1.0,
    );
    _screenFadeAnim = CurvedAnimation(
      parent: _screenFadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _screenFadeController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      final target = _scrollController.position.maxScrollExtent;
      if (animated) {
        _scrollController.animateTo(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _scrollController.jumpTo(target);
      }
    });
  }

  void _send(ConsultationProvider provider) {
    final text = _inputController.text;
    if (text.trim().isEmpty || provider.isLoading) return;
    _inputController.clear();
    // 07단계(추가) §3.5 - provider.sendMessage()가 currentStep(이름/생년월일/
    // 출생시간/타로질문/자유대화)에 따라 내부적으로 분기하므로 화면에서는
    // 기존과 동일하게 단일 호출만 하면 된다.
    provider.sendMessage(text);
    _scrollToBottom();
  }

  /// 07단계(추가) §3.5 - 생년월일 입력 단계에서 네이티브 날짜 피커를 연다.
  /// 초기값은 오늘로부터 30년 전(성인 사용자 평균 가정)으로 설정한다.
  Future<void> _pickBirthDate(ConsultationProvider provider) async {
    if (provider.isLoading) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: '생년월일 선택',
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
    await provider.setUserInfo(field: 'birthDate', value: formatted);
    _scrollToBottom();
  }

  /// 07단계(추가) §3.5 - 출생시간 입력 단계에서 네이티브 시간 피커를 연다.
  /// 초기값은 정오(12:00)로 설정한다.
  Future<void> _pickBirthTime(ConsultationProvider provider) async {
    if (provider.isLoading) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 12, minute: 0),
      helpText: '출생시간 선택',
    );
    if (picked == null || !mounted) return;
    final formatted =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    await provider.setUserInfo(field: 'birthTime', value: formatted);
    _scrollToBottom();
  }

  /// 07단계(추가) §3.4 - 헤더의 "상담 변경" 버튼 → 부드러운 페이드아웃 후
  /// 유형 선택 화면으로 이동한다. 유형 선택 화면에서 새 유형을 고르면
  /// ConsultationTypeScreen이 provider.changeType()을 호출하고 현재 화면으로
  /// 되돌아오며(pop), 새 웰컴 메시지가 자연스럽게 페이드인 되도록 다시 페이드를 재생한다.
  Future<void> _openTypeChange() async {
    final provider = context.read<ConsultationProvider>();
    if (provider.isLoading) return;
    final navigator = Navigator.of(context);

    await _screenFadeController.reverse();
    if (!mounted) return;
    await navigator.pushNamed('/ai-fortune/consultation/type', arguments: true);
    if (!mounted) return;
    _screenFadeController.forward();
    _scrollToBottom(animated: false);
  }

  /// 07단계(추가) §3.5 - 사주/타로 정보 수집 중(계산/뽑기 진행 중 제외)인지 여부.
  bool _isInInputFlow(ConsultationStep step) {
    return step == ConsultationStep.inputName ||
        step == ConsultationStep.inputBirthDate ||
        step == ConsultationStep.inputBirthTime ||
        step == ConsultationStep.selectGender ||
        step == ConsultationStep.inputTarotQuestion ||
        step == ConsultationStep.selectTarotTopic ||
        step == ConsultationStep.selectTarotCard;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ConsultationProvider>();
    final typeStyle = ConsultationTypeStyle.of(provider.type);

    // 새 메시지가 추가되면(사용자 전송 또는 AI 스트리밍 시작) 자동으로 하단 스크롤
    if (provider.messages.length != _prevMessageCount) {
      _prevMessageCount = provider.messages.length;
      _scrollToBottom();
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Text(typeStyle.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: AppSpacing.sm),
            Text(typeStyle.label),
          ],
        ),
        actions: [
          // 07단계(추가) §3.5 - 사주/타로 정보 수집 도중(이름/생년월일/출생시간/
          // 성별/타로질문 단계)에는 "취소" 버튼을 노출해 흐름을 중단하고
          // 자유 대화 상태로 되돌릴 수 있게 한다(요구사항: 입력 취소 처리 방안).
          if (_isInInputFlow(provider.currentStep))
            TextButton(
              onPressed: provider.isLoading ? null : provider.cancelInputFlow,
              child: const Text('취소'),
            ),
          TextButton.icon(
            onPressed: () => _openTypeChange(),
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('상담 변경'),
            style: TextButton.styleFrom(
              foregroundColor: typeStyle.primaryColor,
            ),
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _screenFadeAnim,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: provider.isStarting
                    ? Center(
                        child: CircularProgressIndicator(
                          color: typeStyle.primaryColor,
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        itemCount: provider.messages.length,
                        itemBuilder: (context, index) {
                          final msg = provider.messages[index];
                          final isLast = index == provider.messages.length - 1;
                          // key를 message.id로 지정해 메시지가 다시 빌드되어도
                          // MessageBubble의 등장 애니메이션이 재생되지 않도록 함
                          return MessageBubble(
                            key: ValueKey(msg.id),
                            message: msg,
                            typeStyle: typeStyle,
                            showTypingCursor:
                                isLast &&
                                msg.role == ConsultationRole.ai &&
                                provider.isStreaming,
                          );
                        },
                      ),
              ),
              _buildInputArea(provider, typeStyle),
            ],
          ),
        ),
      ),
    );
  }

  /// 07단계(추가) §3.5 - [ConsultationProvider.currentStep]에 따라 하단 입력
  /// 영역을 동적으로 전환한다. 일반상담(chatting)에서는 기존 InputBar를
  /// 그대로 사용하고, 사주/타로 정보 수집 단계에서는 전용 위젯으로 교체한다.
  Widget _buildInputArea(
    ConsultationProvider provider,
    ConsultationTypeStyle typeStyle,
  ) {
    switch (provider.currentStep) {
      case ConsultationStep.inputBirthDate:
        // 텍스트 직접 입력(YYYY-MM-DD) + 날짜 피커 버튼을 함께 제공한다.
        return InputBar(
          controller: _inputController,
          enabled: !provider.isLoading,
          onSend: () => _send(provider),
          typeStyle: typeStyle,
          hintText: '예: 1995-03-15',
          leadingIcon: Icons.calendar_month_rounded,
          onLeadingTap: () => _pickBirthDate(provider),
        );
      case ConsultationStep.inputBirthTime:
        // 텍스트 직접 입력(HH:MM) + 시간 피커 버튼 + "건너뛰기" 보조 액션.
        return InputBar(
          controller: _inputController,
          enabled: !provider.isLoading,
          onSend: () => _send(provider),
          typeStyle: typeStyle,
          hintText: '예: 14:30 (모르면 건너뛰기)',
          leadingIcon: Icons.access_time_rounded,
          onLeadingTap: () => _pickBirthTime(provider),
          trailingAction: Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: provider.isLoading ? null : provider.skipBirthTime,
              child: const Text('출생시간 모름 - 건너뛰기'),
            ),
          ),
        );
      case ConsultationStep.selectGender:
        return GenderSelectionBar(
          typeStyle: typeStyle,
          enabled: !provider.isLoading,
          onSelect: (gender) {
            provider.selectGender(gender);
            _scrollToBottom();
          },
        );
      case ConsultationStep.selectTarotTopic:
        return TarotTopicSelectionBar(
          typeStyle: typeStyle,
          enabled: !provider.isLoading,
          onSelect: (topicId) {
            provider.selectTarotTopic(topicId);
            _scrollToBottom();
          },
        );
      case ConsultationStep.selectTarotCard:
        return TarotCardSelectionBar(
          typeStyle: typeStyle,
          enabled: !provider.isLoading,
          onSelect: (label) {
            provider.selectTarotCard(label);
            _scrollToBottom();
          },
        );
      case ConsultationStep.calculatingSaju:
        return CalculatingIndicatorBar(
          typeStyle: typeStyle,
          label: '사주를 분석하고 있어요...',
        );
      case ConsultationStep.drawingTarot:
        return CalculatingIndicatorBar(
          typeStyle: typeStyle,
          label: '카드를 해석하고 있어요...',
        );
      case ConsultationStep.inputName:
      case ConsultationStep.inputTarotQuestion:
      case ConsultationStep.chatting:
        // 이름 입력 / 타로 질문 입력 / 자유대화는 모두 기본 텍스트 입력창을 사용한다.
        return InputBar(
          controller: _inputController,
          enabled: !provider.isLoading,
          onSend: () => _send(provider),
          typeStyle: typeStyle,
        );
    }
  }
}
