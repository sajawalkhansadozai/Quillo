import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/app_theme.dart';

enum LegalDocumentType { privacy, terms }

class LegalDocumentScreen extends StatelessWidget {
  final LegalDocumentType type;

  const LegalDocumentScreen({super.key, required this.type});

  static Future<void> open(BuildContext context, LegalDocumentType type) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentScreen(type: type),
      ),
    );
  }

  String get _title => switch (type) {
        LegalDocumentType.privacy => 'Privacy Policy',
        LegalDocumentType.terms => 'Terms & Conditions',
      };

  String get _assetPath => switch (type) {
        LegalDocumentType.privacy => 'legal/privacy_policy.md',
        LegalDocumentType.terms => 'legal/terms_and_conditions.md',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: AppColors.textDark,
            fontFamily: 'Nunito',
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<String>(
        future: rootBundle.loadString(_assetPath),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            );
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Could not load document. Please try again later.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textMedium),
                ),
              ),
            );
          }
          return _LegalMarkdownBody(text: snapshot.data!);
        },
      ),
    );
  }
}

class _LegalMarkdownBody extends StatelessWidget {
  final String text;
  const _LegalMarkdownBody({required this.text});

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      itemCount: blocks.length,
      itemBuilder: (_, i) {
        final block = blocks[i];
        return switch (block.type) {
          _BlockType.h1 => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito',
                  height: 1.25,
                ),
              ),
            ),
          _BlockType.h2 => Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 8),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                  fontFamily: 'Nunito',
                ),
              ),
            ),
          _BlockType.h3 => Padding(
              padding: const EdgeInsets.only(top: 14, bottom: 6),
              child: Text(
                block.text,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
          _ => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SelectableText(
                block.text,
                style: TextStyle(
                  fontSize: block.isBold ? 13 : 13,
                  fontWeight:
                      block.isBold ? FontWeight.w700 : FontWeight.w400,
                  color: AppColors.textMedium,
                  height: 1.55,
                ),
              ),
            ),
        };
      },
    );
  }

  List<_ParsedBlock> _parseBlocks(String raw) {
    final lines = raw.split('\n');
    final blocks = <_ParsedBlock>[];
    final buffer = StringBuffer();

    void flushParagraph() {
      final t = buffer.toString().trim();
      buffer.clear();
      if (t.isEmpty) return;
      blocks.add(_ParsedBlock(_BlockType.body, _stripInline(t)));
    }

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        flushParagraph();
        continue;
      }
      if (trimmed.startsWith('---')) {
        flushParagraph();
        continue;
      }
      if (trimmed.startsWith('# ')) {
        flushParagraph();
        blocks.add(_ParsedBlock(_BlockType.h1, trimmed.substring(2).trim()));
        continue;
      }
      if (trimmed.startsWith('## ')) {
        flushParagraph();
        blocks.add(_ParsedBlock(_BlockType.h2, trimmed.substring(3).trim()));
        continue;
      }
      if (trimmed.startsWith('### ')) {
        flushParagraph();
        blocks.add(_ParsedBlock(_BlockType.h3, trimmed.substring(4).trim()));
        continue;
      }
      if (trimmed.startsWith('|')) continue; // skip table rows
      if (buffer.isNotEmpty) buffer.write(' ');
      buffer.write(_stripInline(trimmed));
    }
    flushParagraph();
    return blocks;
  }

  String _stripInline(String s) {
    return s
        .replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1')
        .replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
  }
}

enum _BlockType { h1, h2, h3, body }

class _ParsedBlock {
  final _BlockType type;
  final String text;
  const _ParsedBlock(this.type, this.text);
  bool get isBold => false;
}
