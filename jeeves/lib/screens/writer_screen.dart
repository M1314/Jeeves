import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/comment.dart';
import '../services/ecosophia_api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/retro_app_bar.dart';
import '../widgets/comment_card.dart';
import '../widgets/retro_loading_indicator.dart';
import '../widgets/retro_error_widget.dart';

class WriterScreen extends StatefulWidget {
  final String writerName;

  const WriterScreen({super.key, required this.writerName});

  @override
  State<WriterScreen> createState() => _WriterScreenState();
}

class _WriterScreenState extends State<WriterScreen> {
  final EcosophiaApiService _service = EcosophiaApiService();
  List<Comment> _comments = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final comments =
          await _service.searchCommentsByAuthor(widget.writerName);
      setState(() {
        _comments = comments;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: RetroAppBar(title: widget.writerName.toUpperCase()),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: RetroColors.darkSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.writerName.toUpperCase(),
                  style: GoogleFonts.vt323(
                    fontSize: 36,
                    color: RetroColors.electricBlue,
                    letterSpacing: 3,
                  ),
                ),
                if (!_loading && _error == null)
                  Text(
                    '${_comments.length} COMMENTS FOUND',
                    style: GoogleFonts.pressStart2p(
                      fontSize: 8,
                      color: RetroColors.neonGreen,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: RetroLoadingIndicator())
                : _error != null
                    ? RetroErrorWidget(
                        message: _error!,
                        onRetry: _loadComments,
                      )
                    : _comments.isEmpty
                        ? Center(
                            child: Text(
                              'NO COMMENTS FOUND',
                              style: GoogleFonts.vt323(
                                fontSize: 32,
                                color: RetroColors.hotPink,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(12),
                            itemCount: _comments.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (_, i) =>
                                CommentCard(comment: _comments[i]),
                          ),
          ),
        ],
      ),
    );
  }
}
