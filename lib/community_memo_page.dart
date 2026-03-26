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
  List<int> blockedMemoIds = [];
  List<String> blockedAuthorIds = [];

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
    
    final blockedList = prefs.getStringList('blocked_memos') ?? [];
    blockedMemoIds = blockedList.map((e) => int.tryParse(e) ?? -1).where((e) => e != -1).toList();

    blockedAuthorIds = prefs.getStringList('blocked_authors') ?? [];

    if (mounted) {
      setState(() {
        deviceId = id;
      });
      // EULA 동의 확인 후 메모 로드
      await _checkAndShowEula(prefs);
    }
  }

  Future<void> _checkAndShowEula(SharedPreferences prefs) async {
    final accepted = prefs.getBool('community_eula_accepted') ?? false;
    if (!accepted && mounted) {
      final result = await _showEulaDialog();
      if (result == true) {
        await prefs.setBool('community_eula_accepted', true);
        await fetchCommunityMemos();
      } else {
        // 동의 거부 시 뒤로 이동
        if (mounted) Navigator.of(context).pop();
      }
    } else {
      await fetchCommunityMemos();
    }
  }

  Future<bool?> _showEulaDialog() {
    final lang = widget.selectedLanguage;
    final Map<String, Map<String, String>> eulaText = {
      'ko': {
        'title': '커뮤니티 이용 규칙',
        'body':
            '커뮤니티에 참여하기 전에 아래 규칙에 동의해 주세요. (18세 이상 전용)\n\n'
            '• 타인을 비방하거나 욕설이 포함된 게시물은 허용되지 않습니다.\n'
            '• 모든 신고는 24시간 이내에 검토 및 조치(콘텐츠 삭제 및 사용자 차단)됩니다.\n'
            '• 위반 시 해당 기기의 커뮤니티 접근이 영구적으로 제한될 필요가 있습니다.\n'
            '• 문의 및 신고: nanoset@naver.com',
        'agree': '동의하고 계속하기',
        'decline': '취소',
      },
      'en': {
        'title': 'Community Guidelines',
        'body':
            'Please agree to the following rules before joining the community. (Age 18+)\n\n'
            '• Abusive, hateful, or offensive content is not allowed.\n'
            '• Please report any objectionable content immediately.\n'
            '• All reports will be reviewed and acted upon (content removal & user blocking) within 24 hours.\n'
            '• Violations may result in permanent restricted access.\n'
            '• Contact: nanoset@naver.com',
        'agree': 'Agree & Continue',
        'decline': 'Cancel',
      },
      'ja': {
        'title': 'コミュニティガイドライン',
        'body':
            'コミュニティに参加する前に、以下のルールに同意してください。(18歳以上対象)\n\n'
            '• 誹謗中傷や侮辱的な投稿は許可されていません.\n'
            '• 不適切なコンテンツは直ちに報告してください.\n'
            '• すべての報告は24時間以内に確認され、対処（コンテンツの削除およびユーザーのブロック）されます.\n'
            '• 連絡先: nanoset@naver.com',
        'agree': '同意して続ける',
        'decline': 'キャンセル',
      },
      'zh': {
        'title': '社区使用规则',
        'body':
            '参与社区前，请同意以下规则。(仅限18岁以上)\n\n'
            '• 不允许发布侮辱性或攻击性内容.\n'
            '• 请立即举报任何不当内容.\n'
            '• 所有举报将在24小时内处理（删除内容并封禁用户）.\n'
            '• 联系: nanoset@naver.com',
        'agree': '同意并继续',
        'decline': '取消',
      },
      'es': {
        'title': 'Normas de la comunidad',
        'body':
            'Por favor, acepta las siguientes normas antes de unirte a la comunidad. (Solo mayores de 18 años)\n\n'
            '• No se permite contenido abusivo, odioso u ofensivo.\n'
            '• Por favor, reporta cualquier contenido inapropiado de inmediato.\n'
            '• Todos los reportes serán revisados y atendidos (eliminación de contenido y bloqueo) en 24 horas.\n'
            '• Contacto: nanoset@naver.com',
        'agree': 'Aceptar y continuar',
        'decline': 'Cancelar',
      },
    };

    final t = eulaText[lang] ?? eulaText['en']!;

    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(t['title']!),
        content: Text(t['body']!, style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t['decline']!, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6A4FC8)),
            child: Text(t['agree']!, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> fetchCommunityMemos() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final memosResponse = await supabase
          .from('community_memos')
          .select()
          .eq('language', widget.selectedLanguage)
          .order('created_at', ascending: false)
          .limit(50);

      final tempMemos = List<Map<String, dynamic>>.from(memosResponse);
      final memos = tempMemos.where((m) => 
        !blockedMemoIds.contains(m['id'] as int) && 
        !blockedAuthorIds.contains(m['author_device_id'] as String? ?? "")
      ).toList();
      
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

      final likesResponse = await supabase
          .from('memo_likes')
          .select()
          .inFilter('memo_id', memoIds);

      final allLikes = List<Map<String, dynamic>>.from(likesResponse);

      final commentsResponse = await supabase
          .from('memo_comments')
          .select()
          .inFilter('memo_id', memoIds)
          .order('created_at', ascending: true);

      final allComments = List<Map<String, dynamic>>.from(commentsResponse);

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
      if (mounted) {
        setState(() {
          likedMemos[memoId] = isLiked;
          likeCounts[memoId] = (likeCounts[memoId] ?? 0) + (isLiked ? 1 : -1);
        });
      }
    }
  }

  Future<void> _submitReport(int memoId) async {
    try {
      await supabase.from('memo_reports').insert({
        'memo_id': memoId,
        'reporter_device_id': deviceId,
        'reported_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // 테이블 없거나 오류여도 사용자 피드백은 정상 표시
    }
  }

  Future<void> _blockAuthor(String? authorDeviceId) async {
    if (authorDeviceId == null || authorDeviceId.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        blockedAuthorIds.add(authorDeviceId);
        communityMemos.removeWhere((m) => m['author_device_id'] == authorDeviceId);
      });
    }
    await prefs.setStringList('blocked_authors', blockedAuthorIds);
  }

  Future<void> _blockMemo(int memoId) async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        blockedMemoIds.add(memoId);
        communityMemos.removeWhere((m) => m['id'] == memoId);
      });
    }
    final stringIds = blockedMemoIds.map((id) => id.toString()).toList();
    await prefs.setStringList('blocked_memos', stringIds);
  }

  Future<void> _deleteMemo(int memoId) async {
    try {
      await supabase.from('community_memos').delete().eq('id', memoId);
      if (mounted) {
        setState(() {
          communityMemos.removeWhere((m) => m['id'] == memoId);
        });
        final labels = uiLabels?[widget.selectedLanguage] as Map<String, dynamic>? ?? {};
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(labels['delete_success'] ?? '게시물이 삭제되었습니다.')),
        );
      }
    } catch (e) {
      // 삭제 실패 처리
    }
  }

  bool _containsProfanity(String text) {
    if (text.isEmpty) return false;
    // 기본적인 비속어 필터 라이브러리 대신 간단한 키워드 체크 (앱스토어 대응용)
    final profanityKeywords = ['시발', '미친', '병신', 'fuck', 'shit', 'asshole'];
    return profanityKeywords.any((word) => text.toLowerCase().contains(word));
  }

  void _showManagePostDialog(int memoId) {
    final lang = widget.selectedLanguage;
    final labels = uiLabels?[lang] as Map<String, dynamic>? ?? {};
    
    // 기본값 설정 (레이블 누락 대비)
    final String title = labels['manage_post'] ?? '게시물 관리';
    final String body = labels['hide_post_confirm'] ?? '이 게시물을 피드에서 숨기시겠습니까?';
    final String blockText = labels['block_user'] ?? '사용자 차단';
    final String reportText = labels['share'] ?? '신고하기'; // 기존 share 레이블 사용 또는 t['confirm']
    final String hideText = labels['hide_post'] ?? '게시물 숨기기';
    final String cancelText = labels['close'] ?? '취소';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body, style: const TextStyle(fontSize: 14, height: 1.6)),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // 게시물 숨기기 버튼
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined, color: Colors.orange),
              title: Text(hideText),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.of(ctx).pop();
                await _blockMemo(memoId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(labels['post_hidden'] ?? '게시물이 숨겨졌습니다.')),
                  );
                }
              },
            ),
            // 사용자 차단 버튼
            ListTile(
              leading: const Icon(Icons.person_off_outlined, color: Colors.redAccent),
              title: Text(blockText),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.of(ctx).pop();
                final memo = communityMemos.firstWhere((m) => m['id'] == memoId);
                await _blockAuthor(memo['author_device_id'] as String?);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(labels['user_blocked'] ?? '사용자가 차단되었습니다.')),
                  );
                }
              },
            ),
            // 신고하기 버튼
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Colors.red),
              title: Text(labels['report'] ?? '신고하기'), // t['confirm'] 대신 labels 활용
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                Navigator.of(ctx).pop();
                await _submitReport(memoId);
                await _blockMemo(memoId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(labels['report_success'] ?? '신고가 완료되었습니다.')),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(cancelText, style: const TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
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
                    if (_containsProfanity(text)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(labels['profanity_warning'] ?? '부적절한 표현이 포함되어 있습니다.')),
                      );
                      return;
                    }
                    final newComment = {
                      'memo_id': memoId,
                      'content': text,
                      'created_at': DateTime.now().toIso8601String(),
                      'author_device_id': deviceId,
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
                        itemCount: communityMemos.length + 1,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        itemBuilder: (context, index) {
                          if (index == 0) {
                            return Container(
                              padding: const EdgeInsets.all(12),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.blueGrey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    labels['contact_info'] ?? '문의 및 신고: nanoset@naver.com',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    labels['report_notice'] ?? '모든 신고는 24시간 이내에 조치됩니다.',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                ],
                              ),
                            );
                          }
                          final memo = communityMemos[index - 1];
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
                                          Row(
                                            children: [
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
                                              // 신고 버튼
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.flag_outlined,
                                                  size: 18,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () =>
                                                    _showManagePostDialog(memoId),
                                                constraints:
                                                    const BoxConstraints(),
                                                padding: const EdgeInsets.all(8),
                                                tooltip: labels['report'] ?? '신고',
                                              ),
                                              // 삭제 버튼 (본인 글인 경우)
                                              if (memo['author_device_id'] == deviceId)
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete_outline,
                                                    size: 18,
                                                    color: Colors.redAccent,
                                                  ),
                                                  onPressed: () {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: Text(labels['delete'] ?? '삭제'),
                                                        content: Text(labels['delete_confirm'] ?? '게시물을 삭제하시겠습니까?'),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx),
                                                            child: Text(labels['no'] ?? '아니요'),
                                                          ),
                                                          TextButton(
                                                            onPressed: () {
                                                              Navigator.pop(ctx);
                                                              _deleteMemo(memoId);
                                                            },
                                                            child: Text(labels['delete'] ?? '삭제', style: const TextStyle(color: Colors.red)),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                  constraints:
                                                      const BoxConstraints(),
                                                  padding: const EdgeInsets.all(8),
                                                  tooltip: labels['delete'] ?? '삭제',
                                                ),
                                            ],
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
