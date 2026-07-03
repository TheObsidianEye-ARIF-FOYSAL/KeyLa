import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/credential.dart';

class CredentialCard extends StatelessWidget {
  const CredentialCard({
    super.key,
    required this.credential,
    required this.onTap,
    required this.onDelete,
    required this.onToggleFavorite,
  });

  final Credential credential;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: ValueKey(credential.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(color: AppColors.danger, borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // repository/list refresh removes the item; avoid double-remove animation glitches
      },
      child: Card(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                _Monogram(title: credential.title),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(credential.title, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(
                        credential.username,
                        style: Theme.of(context).textTheme.bodySmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    credential.isFavorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: credential.isFavorite ? AppColors.warning : Theme.of(context).textTheme.bodySmall?.color,
                  ),
                  onPressed: onToggleFavorite,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Monogram extends StatelessWidget {
  const _Monogram({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final letter = title.isNotEmpty ? title[0].toUpperCase() : '?';
    final colors = [AppColors.primary, AppColors.success, AppColors.warning, AppColors.danger, AppColors.primaryDark];
    final color = colors[title.hashCode.abs() % colors.length];
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
      alignment: Alignment.center,
      child: Text(letter, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
    );
  }
}
