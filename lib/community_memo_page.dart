import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    fetchCommunityMemos();
  }

  Future<void> fetchCommunityMemos() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await Supabase.instance.client
          .from('community_memos')
          .select()
          .eq('language', widget.selectedLanguage)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        communityMemos = List<Map<String, dynamic>>.from(response);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = '메모를 불러오는 중 오류가 발생했습니다.';
        isLoading = false;
      });
    }
  }

  Future<List<Map<String, dynamic>>> fetchComments(int memoId) async {
    final comments = await Supabase.instance.client
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
                    await Supabase.instance.client
                        .from('memo_comments')
                        .insert({
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
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
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
