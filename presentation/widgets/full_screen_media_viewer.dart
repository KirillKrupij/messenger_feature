import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_view/photo_view.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:dio/dio.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';
import 'dart:typed_data';

import '../../../../core/notifications/index.dart';

class FullScreenMediaViewer extends ConsumerStatefulWidget {
  final String url;
  final bool isVideo;
  final String? fileName;

  const FullScreenMediaViewer({
    super.key,
    required this.url,
    required this.isVideo,
    this.fileName,
  });

  @override
  ConsumerState<FullScreenMediaViewer> createState() => _FullScreenMediaViewerState();
}

class _FullScreenMediaViewerState extends ConsumerState<FullScreenMediaViewer> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    if (widget.isVideo) {
      _initializePlayer();
    }
  }

  Future<void> _initializePlayer() async {
    _videoPlayerController =
        VideoPlayerController.networkUrl(Uri.parse(widget.url));
    await _videoPlayerController!.initialize();
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController!,
      autoPlay: true,
      looping: false,
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      errorBuilder: (context, errorMessage) {
        return Center(
          child: Text(
            errorMessage,
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
    setState(() {});
  }

  Future<void> _handleSave() async {
    try {
      if (kIsWeb) {
        final response = await Dio().get<List<int>>(
          widget.url,
          options: Options(responseType: ResponseType.bytes),
        );
        final blob = html.Blob([Uint8List.fromList(response.data!)]);
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.AnchorElement(href: url)
          ..setAttribute('download', widget.fileName ?? 'download')
          ..click();
        html.Url.revokeObjectUrl(url);
        return;
      }

      if (!await Gal.hasAccess()) {
        await Gal.requestAccess();
      }

      final tempDir = await getTemporaryDirectory();
      final savePath = '${tempDir.path}/${widget.fileName ?? 'download'}';

      await Dio().download(widget.url, savePath);

      if (widget.isVideo) {
        await Gal.putVideo(savePath);
      } else {
        await Gal.putImage(savePath);
      }

      if (mounted) {
        ref.read(notificationServiceProvider.notifier).success(
          widget.isVideo ? 'Видео сохранено' : 'Изображение сохранено',
        );
      }
    } catch (e) {
      debugPrint('Error saving media: $e');
      if (mounted) {
        ref.read(notificationServiceProvider.notifier).error(
          'Ошибка при сохранении',
        );
      }
    }
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: widget.fileName != null
            ? Text(
                widget.fileName!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              )
            : null,
        actions: [
          IconButton(
            onPressed: _handleSave,
            icon: const Icon(Icons.download),
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: widget.isVideo
          ? Center(
              child: _chewieController != null &&
                      _chewieController!
                          .videoPlayerController.value.isInitialized
                  ? Chewie(controller: _chewieController!)
                  : const CircularProgressIndicator(),
            )
          : PhotoView(
              imageProvider: NetworkImage(widget.url),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2,
              loadingBuilder: (context, event) => const Center(
                child: CircularProgressIndicator(),
              ),
            ),
    );
  }
}
