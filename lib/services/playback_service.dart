import 'package:flutter/foundation.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class PlaybackQueueItem {
  final String videoId;
  final String title;
  final String subtitle;

  const PlaybackQueueItem({
    required this.videoId,
    required this.title,
    required this.subtitle,
  });
}

class PlaybackService extends ChangeNotifier {
  PlaybackService() {
    _controller = YoutubePlayerController.fromVideoId(
      // Neutral bootstrap id; real track id is always loaded on first play.
      videoId: 'M7lc1UVf-VE',
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
    _controller.listen(_onPlayerStateChange);
  }

  late final YoutubePlayerController _controller;
  YoutubePlayerController get controller => _controller;

  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  String? _currentVideoId;
  String? get currentVideoId => _currentVideoId;

  String? _currentTitle;
  String? get currentTitle => _currentTitle;

  String? _currentSubtitle;
  String? get currentSubtitle => _currentSubtitle;

  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;

  bool _showVideoWindow = false;
  bool get showVideoWindow => _showVideoWindow;

  final List<PlaybackQueueItem> _queue = [];
  int _queueIndex = -1;
  bool _autoAdvance = false;
  bool get canGoPrevious => _queueIndex > 0;
  bool get canGoNext => _queueIndex >= 0 && _queueIndex < _queue.length - 1;
  String? _queueLabel;
  String? get queueLabel => _queueLabel;

  bool get hasTrack => _currentVideoId != null && _currentVideoId!.isNotEmpty;

  void _onPlayerStateChange(YoutubePlayerValue value) {
    final playing = value.playerState == PlayerState.playing;
    if (playing != _isPlaying) {
      _isPlaying = playing;
      notifyListeners();
    }
    if (value.playerState == PlayerState.ended && _autoAdvance && canGoNext) {
      next();
    }
  }

  Future<void> play({
    required String videoId,
    required String title,
    required String subtitle,
  }) async {
    _currentVideoId = videoId;
    _currentTitle = title;
    _currentSubtitle = subtitle;
    notifyListeners();
    // Keep calls in the same gesture phase when possible; some browsers
    // block autoplay if play happens too late after tap.
    _controller.loadVideoById(videoId: videoId);
  }

  Future<void> setQueueAndPlay({
    required List<PlaybackQueueItem> queue,
    required int startIndex,
    bool autoAdvance = false,
  }) async {
    if (queue.isEmpty) return;
    if (startIndex < 0 || startIndex >= queue.length) return;

    _queue
      ..clear()
      ..addAll(queue);
    _queueIndex = startIndex;
    _autoAdvance = autoAdvance;
    _queueLabel = '${_queueIndex + 1}/${_queue.length} Queue';
    notifyListeners();

    final item = _queue[_queueIndex];
    await play(
      videoId: item.videoId,
      title: item.title,
      subtitle: item.subtitle,
    );
  }

  Future<void> pause() => _controller.pauseVideo();

  Future<void> resume() async {
    if (!hasTrack) return;
    await _controller.playVideo();
  }

  Future<void> stop() async {
    await _controller.pauseVideo();
    _currentVideoId = null;
    _currentTitle = null;
    _currentSubtitle = null;
    _queue.clear();
    _queueIndex = -1;
    _autoAdvance = false;
    _queueLabel = null;
    _showVideoWindow = false;
    _isMinimized = false;
    _isPlaying = false;
    notifyListeners();
  }

  void clearTransport() {
    _queue.clear();
    _queueIndex = -1;
    _autoAdvance = false;
    _queueLabel = null;
    notifyListeners();
  }

  void showVideo() {
    if (_showVideoWindow) return;
    _showVideoWindow = true;
    notifyListeners();
  }

  void hideVideo() {
    if (!_showVideoWindow) return;
    _showVideoWindow = false;
    notifyListeners();
  }

  void toggleVideo() {
    _showVideoWindow = !_showVideoWindow;
    notifyListeners();
  }

  Future<void> previous() async {
    if (!canGoPrevious) return;
    _queueIndex--;
    _queueLabel = '${_queueIndex + 1}/${_queue.length} Queue';
    final item = _queue[_queueIndex];
    await play(
      videoId: item.videoId,
      title: item.title,
      subtitle: item.subtitle,
    );
  }

  Future<void> next() async {
    if (!canGoNext) return;
    _queueIndex++;
    _queueLabel = '${_queueIndex + 1}/${_queue.length} Queue';
    final item = _queue[_queueIndex];
    await play(
      videoId: item.videoId,
      title: item.title,
      subtitle: item.subtitle,
    );
  }

  void minimize() {
    if (_isMinimized) return;
    _isMinimized = true;
    notifyListeners();
  }

  void expand() {
    if (!_isMinimized) return;
    _isMinimized = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }
}
