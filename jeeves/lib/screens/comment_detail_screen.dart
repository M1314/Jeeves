import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import '../services/ecosophia_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_app_bar.dart';
import '../widgets/retro_card.dart';
import '../widgets/retro_button.dart';
import '../widgets/retro_loading_indicator.dart';
import '../widgets/retro_error_widget.dart';

class CommentDetailScreen extends StatefulWidget {
  final int commentId;

  const CommentDetailScreen({super.key, required this.commentId});

  @override
  State<CommentDetailScreen> createState() => _CommentDetailScreenState();
}

class _CommentDetailScreenState extends State<CommentDetailScreen> {
  final EcosophiaApiService _service = EcosophiaApiService();
  Comment? _comment;
  Comment? _parentComment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComment();
  }

  Future<void> _loadComment() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comment = await _service.getCommentById(widget.commentId);
      if (comment == null) {
        setState(() {
          _error = 'Comment #${widget.commentId} not found.';
          _loading = false;
        });
        return;
      }
      Comment? parent;
      if (comment.parentCommentId > 0) {
        parent = await _service.getCommentById(comment.parentCommentId);
      }
      setState(() {
        _comment = comment;
        _parentComment = parent;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RetroAppBar(title: 'COMMENT'),
      body: _loading
          ? const Center(child: RetroLoadingIndicator())
          : _error != null
              ? RetroErrorWidget(message: _error!, onRetry: _loadComment)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final comment = _comment!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go(
                      '/writer/${Uri.encodeComponent(comment.author)}'),
                  child: Text(
                    comment.author.toUpperCase(),
                    style: GoogleFonts.pressStart2p(
                      fontSize: 10,
                      color: RetroColors.electricBlue,
                    ),
                  ),
                ),
              ),
              Text(
                _formatDate(comment.date),
                style: GoogleFonts.courierPrime(
                  fontSize: 12,
                  color: RetroColors.neonGreen.withAlpha(180),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RetroCard(
            child: Text(
              comment.content,
              style: GoogleFonts.courierPrime(
                fontSize: 14,
                color: RetroColors.white,
                height: 1.6,
              ),
            ),
          ),
          if (_parentComment != null) ...[
            const SizedBox(height: 16),
            Text(
              'IN REPLY TO:',
              style: GoogleFonts.pressStart2p(
                fontSize: 8,
                color: RetroColors.hotPink,
              ),
            ),
            const SizedBox(height: 8),
            RetroCard(
              backgroundColor: RetroColors.darkSurface2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _parentComment!.author.toUpperCase(),
                    style: GoogleFonts.pressStart2p(
                      fontSize: 8,
                      color: RetroColors.hotPink,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _parentComment!.content.length > 200
                        ? '${_parentComment!.content.substring(0, 200)}...'
                        : _parentComment!.content,
                    style: GoogleFonts.courierPrime(
                      fontSize: 12,
                      color: RetroColors.white.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (comment.postUrl != null || comment.postTitle != null) ...[
            const SizedBox(height: 16),
            Text(
              'POST: ${comment.postTitle ?? comment.postUrl ?? ''}',
              style: GoogleFonts.courierPrime(
                fontSize: 12,
                color: RetroColors.hotPink,
              ),
            ),
          ],
          const SizedBox(height: 24),
          RetroButton(
            label: '< BACK',
            onPressed: () => context.pop(),
            color: RetroColors.electricBlue,
          ),
        ],
      ),
    );
  }
}
