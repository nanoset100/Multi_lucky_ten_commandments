import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math' as math;

class CommunityMemoPage extends StatefulWidget {
  final String selectedLanguage;

  const CommunityMemoPage({super.key, required this.selectedLanguage});

  @override
  State<CommunityMemoPage> createState() => _CommunityMemoPageState();
}

class _CommunityMemoPageState extends State<CommunityMemoPage> {
  bool isLoading = true;
  List<Map<String, dynamic>> communityMemos = [];
  String? errorMessage;
  final supabase = Supabase.instance.client;
  String? deviceId;
  Map<int, bool> likedMemos = {};
  Map<int, int> likeCounts = {};

  @override
  void initState() {
    super.initState();
    _initDeviceId();
    fetchCommunityMemos();
  }

  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id == null) {
      id = 'device-${math.Random().nextInt(1000000)}';
      await prefs.setString('device_id', id);
    }
    setState(() {
      deviceId = id;
    });
  }

  Future<void> fetchCommunityMemos() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await supabase
          .from('community_memos')
          .select()
          .eq('language', widget.selectedLanguage)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        communityMemos = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });

      // 메모를 가져온 후 좋아요 상태도 불러옵니다
      if (deviceId != null) {
        loadAllLikeStatus();
      }
    } catch (e) {
      setState(() {
        errorMessage = '메모를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }

  Future<void> loadAllLikeStatus() async {
    if (deviceId == null || communityMemos.isEmpty) return;

    for (var memo in communityMemos) {
      final memoId = memo['id'];
      await loadLikeStatus(memoId);
    }
  }

  Future<void> loadLikeStatus(int memoId) async {
    if (deviceId == null) return;

    bool isLiked = await hasLiked(memoId, deviceId!);
    int likeCount = await getLikeCount(memoId);

    setState(() {
      likedMemos[memoId] = isLiked;
      likeCounts[memoId] = likeCount;
    });
  }

  Future<bool> hasLiked(int memoId, String deviceId) async {
    final response = await supabase
        .from('memo_likes')
        .select()
        .eq('memo_id', memoId)
        .eq('device_id', deviceId);

    return response.isNotEmpty;
  }

  Future<int> getLikeCount(int memoId) async {
    final response = await supabase
        .from('memo_likes')
        .select()
        .eq('memo_id', memoId);

    return response.length;
  }

  Future<void> toggleLike(int memoId, String deviceId) async {
    final response = await supabase
        .from('memo_likes')
        .select()
        .eq('memo_id', memoId)
        .eq('device_id', deviceId);

    if (response.isEmpty) {
      // 좋아요 등록
      await supabase.from('memo_likes').insert({
        'memo_id': memoId,
        'device_id': deviceId,
      });
    } else {
      // 좋아요 취소
      await supabase
          .from('memo_likes')
          .delete()
          .eq('memo_id', memoId)
          .eq('device_id', deviceId);
    }

    // 상태 업데이트
    await loadLikeStatus(memoId);
  }

  Future<List<Map<String, dynamic>>> fetchComments(int memoId) async {
    final comments = await supabase
        .from('memo_comments')
        .select()
        .eq('memo_id', memoId)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(comments);
  }

  void showCommentInput(int memoId) {
    final TextEditingController controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('댓글 달기', style: TextStyle(fontSize: 16)),
              TextField(
                controller: controller,
                decoration: const InputDecoration(hintText: '댓글을 입력하세요'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    await supabase.from('memo_comments').insert({
                      'memo_id': memoId,
                      'content': text,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                    Navigator.pop(context);
                    setState(() {}); // 댓글 새로고침용
                  }
                },
                child: const Text('등록'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('커뮤니티 메모'),
        backgroundColor: const Color(0xffdcd0f7),
      ),
      body:
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : communityMemos.isEmpty
              ? const Center(child: Text('공유된 메모가 없습니다.'))
              : RefreshIndicator(
                onRefresh: fetchCommunityMemos,
                child: ListView.builder(
                  itemCount: communityMemos.length,
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemBuilder: (context, index) {
                    final memo = communityMemos[index];
                    final int memoId = memo['id'];
                    final bool isLiked = likedMemos[memoId] ?? false;
                    final int likeCount = likeCounts[memoId] ?? 0;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  memo['content'] ?? '',
                                  style: const TextStyle(fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  memo['created_at']?.toString().substring(
                                        0,
                                        10,
                                      ) ??
                                      '날짜 없음',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    // 좋아요 버튼과 카운터
                                    Row(
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            isLiked
                                                ? Icons.favorite
                                                : Icons.favorite_border,
                                            color:
                                                isLiked
                                                    ? Colors.red
                                                    : Colors.grey,
                                            size: 20,
                                          ),
                                          onPressed:
                                              deviceId == null
                                                  ? null
                                                  : () {
                                                    if (deviceId != null) {
                                                      toggleLike(
                                                        memoId,
                                                        deviceId!,
                                                      );
                                                    }
                                                  },
                                          constraints: const BoxConstraints(),
                                          padding: const EdgeInsets.all(8),
                                        ),
                                        Text(
                                          '$likeCount',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ],
                                    ),
                                    // 댓글 버튼
                                    TextButton(
                                      onPressed:
                                          () => showCommentInput(memo['id']),
                                      child: const Text('댓글 달기'),
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 0,
                                        ),
                                        minimumSize: const Size(50, 26),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, thickness: 0.5),
                          FutureBuilder(
                            future: fetchComments(memo['id']),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              final comments =
                                  snapshot.data as List<Map<String, dynamic>>;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (comments.isNotEmpty)
                                    ...comments.map(
                                      (comment) => Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 1,
                                        ),
                                        child: Text(
                                          "💬 ${comment['content']}",
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
    );
  }
}
