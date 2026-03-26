import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const deepBlue = Color(0xFF5A43E3);
  static const deepPurple = Color(0xFF6C4DFF);
  static const purple = Color(0xFF7E66FF);
  static const violet = Color(0xFFF4F1FF);
  static const pinkPurple = Color(0xFF8E74FF);
  static const skyBlue = Color(0xFFEFF4FF);

  static const primary = deepPurple;
  static const primaryStrong = deepBlue;
  static const primarySoft = violet;
  static const accentPink = pinkPurple;
  static const accentSky = skyBlue;

  static const background = Color(0xFFFAFBFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceAlt = Color(0xFFF6F8FC);
  static const surfaceMuted = Color(0xFFF1F3F8);
  static const surfacePanel = Color(0xFFFFFFFF);

  static const title = Color(0xFF1F2340);
  static const body = Color(0xFF59617C);
  static const subtle = Color(0xFF7B819C);

  static const border = Color(0xFFE9ECF4);
  static const shadow = Color(0x0D1F2340);
  static const onPrimary = Colors.white;

  static const successBackground = Color(0xFFECF8F1);
  static const successForeground = Color(0xFF2E9B62);
  static const waitlistBackground = Color(0xFFFFF4E8);
  static const waitlistForeground = Color(0xFFF4A340);
  static const highlightBackground = primarySoft;
  static const highlightForeground = primary;
  static const infoBackground = primarySoft;
  static const infoForeground = primary;
  static const neutralBackground = surfaceMuted;
  static const neutralForeground = body;
  static const errorBackground = Color(0xFFFCEEEE);
  static const errorForeground = Color(0xFFD95C5C);
  static const calendarOpen = primary;
  static const calendarReserved = successForeground;
  static const calendarCancelled = subtle;
  static const todayBadgeBackground = primarySoft;
  static const todayBadgeForeground = primary;

  static const brandGradient = LinearGradient(
    colors: [Color(0xFF5A43E3), Color(0xFF6C4DFF), Color(0xFF9B83FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppColorToken {
  const AppColorToken({
    required this.name,
    required this.hex,
    required this.color,
    required this.usage,
  });

  final String name;
  final String hex;
  final Color color;
  final String usage;
}

class AppColorSection {
  const AppColorSection({
    required this.title,
    required this.description,
    required this.tokens,
  });

  final String title;
  final String description;
  final List<AppColorToken> tokens;
}

class AppPaletteBoardData {
  AppPaletteBoardData._();

  static const sections = [
    AppColorSection(
      title: 'Brand',
      description: '앱 아이콘과 핵심 인터랙션에 맞춘 메인 팔레트',
      tokens: [
        AppColorToken(
          name: 'Primary',
          hex: '#6C4DFF',
          color: AppColors.primary,
          usage: '기본 버튼',
        ),
        AppColorToken(
          name: 'Primary Strong',
          hex: '#5A43E3',
          color: AppColors.primaryStrong,
          usage: 'hover, active',
        ),
        AppColorToken(
          name: 'Primary Soft',
          hex: '#F4F1FF',
          color: AppColors.primarySoft,
          usage: '선택, 연한 강조',
        ),
        AppColorToken(
          name: 'Accent Pink',
          hex: '#8E74FF',
          color: AppColors.accentPink,
          usage: '보조 포인트',
        ),
        AppColorToken(
          name: 'Accent Sky',
          hex: '#EFF4FF',
          color: AppColors.accentSky,
          usage: '보조 배경',
        ),
      ],
    ),
    AppColorSection(
      title: 'Surfaces',
      description: '웹과 앱 공통 배경/카드 시스템',
      tokens: [
        AppColorToken(
          name: 'Background',
          hex: '#FAFBFF',
          color: AppColors.background,
          usage: '전체 배경',
        ),
        AppColorToken(
          name: 'Surface',
          hex: '#FFFFFF',
          color: AppColors.surface,
          usage: '카드, 모달',
        ),
        AppColorToken(
          name: 'Surface Alt',
          hex: '#F6F8FC',
          color: AppColors.surfaceAlt,
          usage: '입력창, 보조 패널',
        ),
        AppColorToken(
          name: 'Surface Muted',
          hex: '#F1F3F8',
          color: AppColors.surfaceMuted,
          usage: '보더, 중립 배경',
        ),
      ],
    ),
    AppColorSection(
      title: 'Text',
      description: '냉한 블루 퍼플 톤에 맞춘 텍스트 계층',
      tokens: [
        AppColorToken(
          name: 'Title',
          hex: '#1F2340',
          color: AppColors.title,
          usage: '타이틀',
        ),
        AppColorToken(
          name: 'Body',
          hex: '#59617C',
          color: AppColors.body,
          usage: '본문',
        ),
        AppColorToken(
          name: 'Subtle',
          hex: '#7B819C',
          color: AppColors.subtle,
          usage: '보조 텍스트',
        ),
      ],
    ),
  ];
}
