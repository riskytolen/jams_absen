import 'package:flutter/material.dart';

import '../../core/theme/app_spacing.dart';

/// Tampilkan foto bukti fullscreen dengan pinch-zoom.
///
/// Dipakai dari layar detail FO dan mode lihat bukti agar foto lama bisa
/// diperiksa jelas. Mendukung geser antar foto bila lebih dari satu.
Future<void> showEpodEvidenceViewer(
  BuildContext context, {
    required List<String> urls,
    int initialIndex = 0,
  }) {
  if (urls.isEmpty) return Future.value();
  final start = initialIndex.clamp(0, urls.length - 1);
  return showDialog(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => _EpodEvidenceViewerDialog(urls: urls, initialIndex: start),
  );
}

class _EpodEvidenceViewerDialog extends StatefulWidget {
  final List<String> urls;
  final int initialIndex;

  const _EpodEvidenceViewerDialog({
    required this.urls,
    required this.initialIndex,
  });

  @override
  State<_EpodEvidenceViewerDialog> createState() =>
      _EpodEvidenceViewerDialogState();
}

class _EpodEvidenceViewerDialogState
    extends State<_EpodEvidenceViewerDialog> {
  late final PageController _controller;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(
                              AppSpacing.radiusFull),
                        ),
                        child: Text(
                          widget.urls.length > 1
                              ? '${_index + 1}/${widget.urls.length}'
                              : 'Bukti foto',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white,
                    tooltip: 'Tutup',
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.urls.length == 1
                  ? InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Image.network(
                          widget.urls.first,
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.broken_image_rounded,
                            color: Colors.white54,
                            size: 48,
                          ),
                        ),
                      ),
                    )
                  : PageView.builder(
                      controller: _controller,
                      itemCount: widget.urls.length,
                      onPageChanged: (value) =>
                          setState(() => _index = value),
                      itemBuilder: (_, index) => InteractiveViewer(
                        minScale: 1,
                        maxScale: 4,
                        child: Center(
                          child: Image.network(
                            widget.urls[index],
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const Icon(
                              Icons.broken_image_rounded,
                              color: Colors.white54,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                'Cubit untuk zoom • Geser untuk pindah foto',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
