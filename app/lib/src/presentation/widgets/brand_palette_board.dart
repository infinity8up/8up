import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import 'common_widgets.dart';

class BrandPaletteBoard extends StatelessWidget {
  const BrandPaletteBoard({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      padding: EdgeInsets.all(compact ? 16 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '컬러 정보판',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '차가운 블루 + 부드러운 퍼플 + 살짝 네온 느낌',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.body),
          ),
          const SizedBox(height: 16),
          Container(
            height: compact ? 52 : 64,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final sectionWidth = compact ? constraints.maxWidth : 240.0;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: AppPaletteBoardData.sections
                    .map(
                      (section) => SizedBox(
                        width: sectionWidth.clamp(0, constraints.maxWidth),
                        child: _PaletteSection(section: section),
                      ),
                    )
                    .toList(growable: false),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaletteSection extends StatelessWidget {
  const _PaletteSection({required this.section});

  final AppColorSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppColors.title,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            section.description,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
          ),
          const SizedBox(height: 12),
          ...section.tokens.map(
            (token) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _SwatchTile(token: token),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwatchTile extends StatelessWidget {
  const _SwatchTile({required this.token});

  final AppColorToken token;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: token.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                token.name,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.title,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${token.hex} · ${token.usage}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.subtle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
