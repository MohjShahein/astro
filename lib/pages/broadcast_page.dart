import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../services/agora_service.dart';
import '../services/live_stream_service.dart';
import '../widgets/chat_widget.dart';

class BroadcastPage extends StatefulWidget {
  final bool isBroadcaster;
  final String streamId;
  final String title;
  final String? userId;

  const BroadcastPage({
    Key? key,
    required this.isBroadcaster,
    required this.streamId,
    required this.title,
    this.userId,
  }) : super(key: key);

  @override
  State<BroadcastPage> createState() => _BroadcastPageState();
}

class _BroadcastPageState extends State<BroadcastPage> {
  final List<int> _remoteUids = [];
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _isInitialized = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      setState(() {
        _isInitialized = false;
        _errorMessage = null;
      });

      // تهيئة خدمة Agora
      await AgoraService.initialize();

      // الانضمام إلى القناة
      await AgoraService.joinLiveStreamChannel(
        widget.streamId,
        widget.userId ?? 'anonymous_user',
        widget.streamId,
        isBroadcaster: widget.isBroadcaster,
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'خطأ في تهيئة البث المباشر: $e';
      });
    }
  }

  void _onToggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    AgoraService.toggleMicrophone(widget.streamId, enabled: _isMuted);
  }

  void _onToggleCamera() {
    setState(() {
      _isCameraOff = !_isCameraOff;
    });
    AgoraService.toggleCamera(widget.streamId, enabled: _isCameraOff);
  }

  Future<void> _onLeaveChannel() async {
    try {
      await AgoraService.leaveChannel(widget.streamId);
      if (widget.isBroadcaster) {
        await LiveStreamService.endLiveStream(widget.streamId);
      }
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في مغادرة البث: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _onLeaveChannel();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            if (widget.isBroadcaster) ...[
              IconButton(
                icon: Icon(_isMuted ? Icons.mic_off : Icons.mic),
                onPressed: _onToggleMute,
              ),
              IconButton(
                icon: Icon(_isCameraOff ? Icons.videocam_off : Icons.videocam),
                onPressed: _onToggleCamera,
              ),
            ],
            IconButton(
              icon: const Icon(Icons.exit_to_app),
              onPressed: _onLeaveChannel,
            ),
          ],
        ),
        body: _errorMessage != null
            ? Center(child: Text(_errorMessage!))
            : !_isInitialized
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildVideoView(),
                      ),
                      if (_isInitialized)
                        Expanded(
                          flex: 1,
                          child: ChatWidget(
                            streamId: widget.streamId,
                            isBroadcaster: widget.isBroadcaster,
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildVideoView() {
    if (widget.isBroadcaster) {
      return AgoraVideoView(
        controller: VideoViewController(
          rtcEngine: AgoraService.engine!,
          canvas: const VideoCanvas(uid: 0),
        ),
      );
    }

    if (_remoteUids.isEmpty) {
      return const Center(child: Text('في انتظار بدء البث...'));
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: AgoraService.engine!,
        canvas: VideoCanvas(uid: _remoteUids[0]),
        connection: RtcConnection(channelId: widget.streamId),
      ),
    );
  }

  @override
  void dispose() {
    _onLeaveChannel();
    super.dispose();
  }
}
