import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

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
  Map<int, List<Map<String, dynamic>>> commentsMap = {};
  Map<String, dynamic>? uiLabels;

  @override
  void initState() {
    super.initState();
    _loadLabels();
    _initDeviceId();
  }

  Future<void> _loadLabels() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/lucky_ten_ui_labels.json',
      );
      final Map<String, dynamic> labels = json.decode(jsonString);
      if (mounted) {
        setState(() {
          uiLabels = labels;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          uiLabels = {};
        });
      }
    }
  }

  Future<void> _initDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? id = prefs.getString('device_id');
    if (id == null) {
      id = const Uuid().v4();
      await prefs.setString('device_id', id);
    }
    if (mounted) {
      setState(() {
        deviceId = id;
      });
      await fetchCommunityMemos();
    }
  }

  Future<void> fetchCommunityMemos() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      // 1. 메모 목록 조회
      final memosResponse = await supabase
          .from('community_memos')
          .select()
          .eq('language', widget.selectedLanguage)
          .order('created_at', ascending: false)
          .limit(50);

      final memos = List<Map<String, dynamic>>.from(memosResponse);
      if (memos.isEmpty) {
        if (mounted) {
          setState(() {
            communityMemos = [];
            isLoading = false;
          });
        }
        return;
      }

      final memoIds = memos.map((m) => m['id'] as int).toList();

      // 2. 좋아요 전체 한 번에 조회
      final likesResponse = await supabase
          .from('memo_likes')
          .select()
          .inFilter('memo_id', memoIds);

      final allLikes = List<Map<String, dynamic>>.from(likesResponse);

      // 3. 댓글 전체 한 번에 조회
      final commentsResponse = await supabase
          .from('memo_comments')
          .select()
          .inFilter('memo_id', memoIds)
          .order('created_at', ascending: true);

      final allComments = List<Map<String, dynamic>>.from(commentsResponse);

      // 4. 메모리에서 집계
      final newLikedMemos = <int, bool>{};
      final newLikeCounts = <int, int>{};
      final newCommentsMap = <int, List<Map<String, dynamic>>>{};

      for (final id in memoIds) {
        final likesForMemo = allLikes.where((l) => l['memo_id'] == id).toList();
        newLikeCounts[id] = likesForMemo.length;
        newLikedMemos[id] =
            deviceId != null &&
            likesForMemo.any((l) => l['device_id'] == deviceId);
        newCommentsMap[id] =
            allComments.where((c) => c['memo_id'] == id).toList();
      }

      if (mounted) {
        setState(() {
          communityMemos = memos;
          likedMemos = newLikedMemos;
          likeCounts = newLikeCounts;
          commentsMap = newCommentsMap;
          isLoading = false;
        });
      }
    } catch (e) {
      final labels =
          uiLabels?[widget.selectedLanguage] as Map<String, dynamic>? ?? {};
      if (mounted) {
        setState(() {
          errorMessage =
              labels['error_loading_memos'] ?? '메모를 불러오는 중 오류가 발생했습니다.';
          isLoading = false;
        });
      }
    }
  }

  Future<void> toggleLike(int memoId) async {
    if (deviceId == null) return;

    final isLiked = likedMemos[memoId] ?? false;

    // 낙관적 업데이트 (즉시 UI 반영)
    setState(() {
      likedMemos[memoId] = !isLiked;
      likeCounts[memoId] = (likeCounts[memoId] ?? 0) + (isLiked ? -1 : 1);
    });

    try {
      if (isLiked) {
        await supabase
            .from('memo_likes')
            .delete()
            .eq('memo_id', memoId)
            .eq('device_id', deviceId!);
      } else {
        await supabase.from('memo_likes').insert({
          'memo_id': memoId,
          'device_id': deviceId,
        });
      }
    } catch (e) {
      // 실패 시 롤백
      if (mounted) {
        setState(() {
          likedMemos[memoId] = isLiked;
          likeCounts[memoId] = (likeCounts[memoId] ?? 0) + (isLiked ? 1 : -1);
        });
      }
    }
  }

  void showCommentInput(int memoId) {
    final TextEditingController controller = TextEditingController();
    final labels =
        uiLabels?[widget.selectedLanguage] as Map<String, dynamic>? ?? {};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                labels['add_comment'] ?? '댓글 달기',
                style: const TextStyle(fontSize: 16),
              ),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  hintText: labels['enter_comment'] ?? '댓글을 입력하세요',
                ),
                autofocus: true,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  final text = controller.text.trim();
                  if (text.isNotEmpty) {
                    final newComment = {
                      'memo_id': memoId,
                      'content': text,
                      'created_at': DateTime.now().toIso8601String(),
                    };
                    await supabase.from('memo_comments').insert(newComment);
                    if (context.mounted) {
                      Navigator.pop(context);
                      if (mounted) {
                        setState(() {
                          commentsMap[memoId] = [
                            ...(commentsMap[memoId] ?? []),
                            newComment,
                          ];
                        });
                      }
                    }
                  }
                },
                child: Text(labels['submit'] ?? '등록'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final labels =
        uiLabels?[widget.selectedLanguage] as Map<String, dynamic>? ?? {};

    return Scaffold(
      appBar: AppBar(
        title: Text(labels['community_memos'] ?? '커뮤니티 메모'),
        backgroundColor: const Color(0xffdcd0f7),
      ),
      body: isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(labels['loading_memos'] ?? '메모를 불러오는 중...'),
                ],
              ),
            )
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : communityMemos.isEmpty
                  ? Center(
                      child: Text(
                        labels['no_shared_memos'] ?? '공유된 메모가 없습니다.',
                      ),
                    )
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
                          final comments = commentsMap[memoId] ?? [];

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
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    12,
                                    16,
                                    4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        memo['content'] ?? '',
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        memo['created_at']
                                                ?.toString()
                                                .substring(0, 10) ??
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
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: Icon(
                                                  isLiked
                                                      ? Icons.favorite
                                                      : Icons.favorite_border,
                                                  color: isLiked
                                                      ? Colors.red
                                                      : Colors.grey,
                                                  size: 20,
                                                ),
                                                onPressed: deviceId == null
                                                    ? null
                                                    : () => toggleLike(memoId),
                                                constraints:
                                                    const BoxConstraints(),
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                              ),
                                              Text(
                                                '$likeCount',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                showCommentInput(memoId),
                                            style: TextButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 0,
                                              ),
                                              minimumSize: const Size(50, 26),
                                            ),
                                            child: Text(
                                              labels['add_comment'] ?? '댓글 달기',
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (comments.isNotEmpty) ...[
                                  const Divider(height: 1, thickness: 0.5),
                                  ...comments.map(
                                    (comment) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 4,
                                      ),
                                      child: Text(
                                        '💬 ${comment['content']}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}
