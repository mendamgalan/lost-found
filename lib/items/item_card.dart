// Keep compatibility with the project's Flutter 3.47 Android baseline.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../core/ui.dart';
import 'item.dart';
import '../services/media.dart';

class ItemCard extends StatelessWidget {
  const ItemCard({super.key, required this.item, required this.onTap});
  final Item item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (item.imagePaths.isNotEmpty)
                  StorageImage(path: item.imagePaths.first, height: 132)
                else
                  ItemArtwork(
                    category: item.category,
                    lost: item.type == 'lost',
                    height: 132,
                  ),
                Positioned(
                  top: 10,
                  left: 10,
                  child: StatusPill(
                    lost: item.type == 'lost',
                    returned: item.status == 'returned',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              item.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 15,
                  color: AppColors.muted,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.district,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              item.placeName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    displayDate(item.eventDate),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ),
                const Icon(
                  Icons.arrow_outward_rounded,
                  size: 18,
                  color: AppColors.teal,
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
