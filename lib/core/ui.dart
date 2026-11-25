// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import 'app_theme.dart';

const itemCategories = [
  'Утас',
  'Түрийвч',
  'Түлхүүр',
  'Бичиг баримт',
  'Цүнх',
  'Электрон төхөөрөмж',
  'Бусад',
];
const itemDistricts = [
  'Баянгол',
  'Баянзүрх',
  'Сүхбаатар',
  'Сонгинохайрхан',
  'Хан-Уул',
  'Чингэлтэй',
  'Багануур',
  'Багахангай',
  'Налайх',
];
IconData categoryIcon(String category) => switch (category) {
  'Утас' => Icons.phone_iphone_rounded,
  'Түрийвч' => Icons.account_balance_wallet_outlined,
  'Түлхүүр' => Icons.key_rounded,
  'Бичиг баримт' => Icons.badge_outlined,
  'Цүнх' => Icons.backpack_outlined,
  'Электрон төхөөрөмж' => Icons.headphones_rounded,
  _ => Icons.inventory_2_outlined,
};
String displayDate(DateTime date) =>
    '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';

class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.width = 720});
  final Widget child;
  final double width;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width),
      child: child,
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => const Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.teal,
        child: Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 25),
      ),
      SizedBox(width: 10),
      Text(
        'оллоо',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        ),
      ),
    ],
  );
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.text,
    this.icon = Icons.shield_outlined,
  });
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.mint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.teal, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: AppColors.teal, height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class StateMessage extends StatelessWidget {
  const StateMessage({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.search_rounded,
    this.action,
    this.onAction,
  });
  final String title, message;
  final IconData icon;
  final String? action;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(
          radius: 36,
          backgroundColor: AppColors.mint,
          child: Icon(icon, size: 32, color: AppColors.teal),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        if (action != null) ...[
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onAction, child: Text(action!)),
        ],
      ],
    ),
  );
}

class ItemArtwork extends StatelessWidget {
  const ItemArtwork({
    super.key,
    required this.category,
    this.height = 150,
    this.lost = false,
  });
  final String category;
  final double height;
  final bool lost;
  @override
  Widget build(BuildContext context) => Container(
    height: height,
    width: double.infinity,
    decoration: BoxDecoration(
      color: lost ? AppColors.peach : AppColors.mint,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: height * .8,
          height: height * .8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: .65),
              width: 1,
            ),
          ),
        ),
        Container(
          width: height * .58,
          height: height * .58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: .45),
          ),
        ),
        Transform.rotate(
          angle: -.15,
          child: Icon(
            categoryIcon(category),
            size: height * .38,
            color: lost ? AppColors.coral : AppColors.teal,
          ),
        ),
      ],
    ),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.lost, this.returned = false});
  final bool lost, returned;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: returned
          ? AppColors.mint
          : (lost ? AppColors.peach : AppColors.mint),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      returned ? 'Буцаан олгосон' : (lost ? 'ГЭЭСЭН' : 'ОЛСОН'),
      style: TextStyle(
        fontSize: 11,
        letterSpacing: .5,
        fontWeight: FontWeight.w800,
        color: lost && !returned ? AppColors.coral : AppColors.teal,
      ),
    ),
  );
}
