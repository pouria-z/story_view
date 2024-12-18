import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:video_player/video_player.dart';

import '../utils.dart';
import '../controller/story_controller.dart';

class VideoLoader {
  String url;

  File? videoFile;

  Map<String, dynamic>? requestHeaders;

  LoadState state = LoadState.loading;

  VideoLoader(this.url, {this.requestHeaders});

  void loadVideo(VoidCallback onComplete) {
    if (this.videoFile != null) {
      this.state = LoadState.success;
      onComplete();
    }

    final fileStream =
        DefaultCacheManager().getFileStream(this.url, headers: this.requestHeaders as Map<String, String>?);

    fileStream.listen((fileResponse) {
      if (fileResponse is FileInfo) {
        if (this.videoFile == null) {
          this.state = LoadState.success;
          this.videoFile = fileResponse.file;
          onComplete();
        }
      }
    });
  }
}

class StoryVideo extends StatefulWidget {
  final StoryController? storyController;
  final VideoLoader videoLoader;
  final Widget? loadingWidget;
  final Widget? errorWidget;
  final double? width;
  final double? height;

  StoryVideo(
    this.videoLoader, {
    Key? key,
    this.storyController,
    this.loadingWidget,
    this.errorWidget,
    this.width,
    this.height,
  }) : super(key: key ?? UniqueKey());

  static StoryVideo url(
    String url, {
    StoryController? controller,
    Map<String, dynamic>? requestHeaders,
    Key? key,
    Widget? loadingWidget,
    Widget? errorWidget,
    double? width,
    double? height,
  }) {
    return StoryVideo(
      VideoLoader(url, requestHeaders: requestHeaders),
      storyController: controller,
      key: key,
      loadingWidget: loadingWidget,
      errorWidget: errorWidget,
      width: width,
      height: height,
    );
  }

  @override
  State<StatefulWidget> createState() {
    return StoryVideoState();
  }
}

class StoryVideoState extends State<StoryVideo> {
  Future<void>? playerLoader;

  StreamSubscription? _streamSubscription;

  VideoPlayerController? playerController;

  @override
  void initState() {
    super.initState();

    widget.storyController!.pause();

    widget.videoLoader.loadVideo(() {
      if (widget.videoLoader.state == LoadState.success) {
        this.playerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoLoader.url));

        playerController!.initialize().then((v) {
          setState(() {});
          widget.storyController!.play();
        });

        if (widget.storyController != null) {
          _streamSubscription = widget.storyController!.playbackNotifier.listen((playbackState) {
            if (playbackState == PlaybackState.pause) {
              playerController!.pause();
            } else {
              playerController!.play();
            }
          });
        }
      } else {
        setState(() {});
      }
    });
  }

  Widget getContentView() {
    if (widget.videoLoader.state == LoadState.success && playerController!.value.isInitialized) {
      // if (Platform.isAndroid) {
        return Center(
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: VideoPlayer(playerController!),
          ),
        );
      // } else {
        return Center(
          child: AspectRatio(
            aspectRatio: playerController!.value.aspectRatio,
            child: VideoPlayer(playerController!),
          ),
        );
      // }
    }

    return widget.videoLoader.state == LoadState.loading
        ? Center(
            child: widget.loadingWidget ??
                Container(
                  width: 70,
                  height: 70,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 3,
                  ),
                ),
          )
        : Center(
            child: widget.errorWidget ??
                Text(
                  "Media failed to load.",
                  style: TextStyle(
                    color: Colors.white,
                  ),
                ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // height: double.infinity,
      // width: double.infinity,
      body: getContentView(),
    );
  }

  @override
  void dispose() {
    playerController?.dispose();
    _streamSubscription?.cancel();
    super.dispose();
  }
}
