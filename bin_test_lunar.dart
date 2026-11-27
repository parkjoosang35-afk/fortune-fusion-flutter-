import 'package:lunar/lunar.dart';

void main() {
  // 박주상: 1972-02-13 02:00 남성 (양력)
  final solar = Solar.fromYmdHms(1972, 2, 13, 2, 0, 0);
  final lunar = solar.getLunar();
  final eightChar = lunar.getEightChar();

  print('연주: ${eightChar.getYear()}');
  print('월주: ${eightChar.getMonth()}');
  print('일주: ${eightChar.getDay()}');
  print('시주: ${eightChar.getTime()}');
  print('일간: ${eightChar.getDayGan()}');
  print('일지: ${eightChar.getDayZhi()}');
}
