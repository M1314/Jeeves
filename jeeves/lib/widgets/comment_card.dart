import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import '../theme/app_theme.dart';
import 'retro_card.dart';

class CommentCard extends StatelessWidget {
  final Comment comment;

  const CommentCard({super.key, required this.comment});

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final snippet = comment.content.length > 150
        ? '${comment.content.substring(0, 150)}...'
        : comment.content;

    return GestureDetector(
      onTap: () => context.go('/comment/${comment.id}'),
      child: RetroCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                GestureDetector(
                  onTap: () => context.go(
                      '/writer/${Uri.encodeComponent(comment.author)}'),
                  child: Text(
                    comment.author.toUpperCase(),
                    style: GoogleFonts.pressStart2p(
                      fontSize: 9,
                      color: RetroColors.electricBlue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(comment.date),
                  style: GoogleFonts.courierPrime(
                    fontSize: 11,
                    color: RetroColors.neonGreen.withAlpha(180),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              snippet,
              style: GoogleFonts.courierPrime(
                fontSize: 13,
                color: RetroColors.white,
              ),
            ),
            if (comment.postTitle != null || comment.postUrl != null) ...[
              const SizedBox(height: 8),
              Text(
                '↳ ${comment.postTitle ?? comment.postUrl ?? ''}',
                style: GoogleFonts.courierPrime(
                  fontSize: 11,
                  color: RetroColors.hotPink,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
