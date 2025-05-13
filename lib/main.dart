import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]).then((_) {
    runApp(const MyTVApp());
  });
}

class MyTVApp extends StatelessWidget {
  const MyTVApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const VideoListPage(),
    );
  }
}

class VideoListPage extends StatefulWidget {
  const VideoListPage({Key? key}) : super(key: key);

  @override
  State<VideoListPage> createState() => _VideoListPageState();
}

class _VideoListPageState extends State<VideoListPage> {
  final String apiKey = 'API_KEY'; //Nhập API Key
  List _videos = [];
  bool _isLoading = true;
  String? _error;
  String _query = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<FocusNode> _videoFocusNodes = [];
  final FocusNode _searchFieldNode = FocusNode();

  @override
  void initState() {
    super.initState();
    fetchTrending();
  }

  Future<void> fetchTrending() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _query = '';
      _searchController.clear();
    });
    final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/videos?'
            'key=$apiKey&part=snippet&chart=mostPopular&maxResults=50&regionCode=Vi'
    );
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = data['items'] as List;
        final newVideos = items.map((item) {
          return {'snippet': item['snippet'], 'id': {'videoId': item['id']}};
        }).toList();
        _updateVideos(newVideos);
      } else {
        setState(() => _error = 'API error: ${resp.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Connection error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> fetchVideos({required String query}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    final url = Uri.parse(
        'https://www.googleapis.com/youtube/v3/search?'
            'key=$apiKey&part=snippet&q=${Uri.encodeQueryComponent(query)}&type=video&maxResults=20'
    );
    try {
      final resp = await http.get(url);
      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final items = data['items'] as List;
        final newVideos = items.where((i) => i['id']['videoId'] != null).toList();
        _updateVideos(newVideos);
      } else {
        setState(() => _error = 'API error: ${resp.statusCode}');
      }
    } catch (_) {
      setState(() => _error = 'Connection error');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _updateVideos(List newVideos) {
    for (var node in _videoFocusNodes) node.dispose();
    _videoFocusNodes.clear();
    _videoFocusNodes.addAll(List.generate(newVideos.length, (_) => FocusNode()));
    setState(() => _videos = newVideos);
    if (_videoFocusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        FocusScope.of(context).requestFocus(_videoFocusNodes[0]);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _searchFieldNode.dispose();
    for (var node in _videoFocusNodes) node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('YouTube TV')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              focusNode: _searchFieldNode,
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Tìm kiếm video...',
                hintStyle: const TextStyle(color: Colors.white54),
                filled: true,
                fillColor: Colors.white12,
                prefixIcon: const Icon(Icons.search, color: Colors.white),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white),
                  onPressed: fetchTrending,
                )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _query = v;
                fetchVideos(query: v);
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!, style: const TextStyle(color: Colors.red)))
                : GridView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 16 / 9,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _videos.length,
              itemBuilder: (context, index) {
                final video = _videos[index];
                final thumb = video['snippet']['thumbnails']['high']['url'];
                final title = video['snippet']['title'];
                final videoId = video['id']['videoId'];
                return FocusableActionDetector(
                  focusNode: _videoFocusNodes[index],
                  shortcuts: {
                    LogicalKeySet(LogicalKeyboardKey.select): ActivateIntent(),
                    LogicalKeySet(LogicalKeyboardKey.enter): ActivateIntent(),
                  },
                  actions: {
                    ActivateIntent: CallbackAction(onInvoke: (_) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VideoPlayerPage(videoId: videoId),
                        ),
                      );
                      return null;
                    }),
                  },
                  child: Builder(builder: (context) {
                    final hasFocus = Focus.of(context).hasFocus;
                    return GestureDetector(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => VideoPlayerPage(videoId: videoId)),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        decoration: BoxDecoration(
                          border: hasFocus
                              ? Border.all(color: Colors.blueAccent, width: 4)
                              : null,
                          boxShadow: hasFocus
                              ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.5), blurRadius: 12)]
                              : [],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CachedNetworkImage(
                                  imageUrl: thumb,
                                  fit: BoxFit.cover,
                                  placeholder: (c, u) => const Center(child: CircularProgressIndicator()),
                                  errorWidget: (c, u, e) => const Icon(Icons.error),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  color: Colors.black54,
                                  padding: const EdgeInsets.all(4),
                                  child: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 14),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class VideoPlayerPage extends StatefulWidget {
  final String videoId;
  const VideoPlayerPage({Key? key, required this.videoId}) : super(key: key);

  @override
  State<VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<VideoPlayerPage> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.videoId,
      flags: const YoutubePlayerFlags(autoPlay: true, mute: false),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayerBuilder(
      player: YoutubePlayer(controller: _controller),
      builder: (context, player) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(child: player),
        );
      },
    );
  }
}
