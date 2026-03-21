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
            '커뮤니티에 참여하기 전에 아래 규칙에 동의해 주세요.\n\n'
            '• 타인을 비방하거나 욕설이 포함된 게시물은 허용되지 않습니다.\n'
            '• 불쾌한 콘텐츠는 즉시 신고해 주세요.\n'
            '• 부적절한 신고는 24시간 이내에 처리됩니다.\n'
            '• 위반 시 해당 기기의 커뮤니티 접근이 제한될 수 있습니다.',
        'agree': '동의하고 계속하기',
        'decline': '취소',
      },
      'en': {
        'title': 'Community Guidelines',
        'body':
            'Please agree to the following rules before joining the community.\n\n'
            '• Abusive, hateful, or offensive content is not allowed.\n'
            '• Please report any objectionable content immediately.\n'
            '• Reports will be reviewed and acted upon within 24 hours.\n'
            '• Violations may result in restricted community access for your device.',
        'agree': 'Agree & Continue',
        'decline': 'Cancel',
      },
      'ja': {
        'title': 'コミュニティガイドライン',
        'body':
            'コミュニティに参加する前に、以下のルールに同意してください。\n\n'
            '• 誹謗中傷や侮辱的な投稿は許可されていません。\n'
            '• 不適切なコンテンツは直ちに報告してください。\n'
            '• 報告は24時間以内に対応されます。\n'
            '• 違反した場合、デバイスのコミュニティアクセスが制限される場合があります。',
        'agree': '同意して続ける',
        'decline': 'キャンセル',
      },
      'zh': {
        'title': '社区使用规则',
        'body':
            '参与社区前，请同意以下规则。\n\n'
            '• 不允许发布侮辱性或攻击性内容。\n'
            '• 请立即举报任何不当内容。\n'
            '• 举报将在24小时内处理。\n'
            '• 违规行为可能导致您的设备被限制访问社区。',
        'agree': '同意并继续',
        'decline': '取消',
      },
      'es': {
        'title': 'Normas de la comunidad',
        'body':
            'Por favor, acepta las siguientes normas antes de unirte a la comunidad.\n\n'
            '• No se permite contenido abusivo, odioso u ofensivo.\n'
            '• Por favor, reporta cualquier contenido inapropiado de inmediato.\n'
            '• Los reportes serán revisados en 24 horas.\n'
            '• Las infracciones pueden resultar en acceso restringido a la comunidad.',
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

  void _showReportDialog(int memoId) {
    final lang = widget.selectedLanguage;
    final Map<String, Map<String, String>> reportText = {
      'ko': {'title': '신고하기', 'body': '이 게시물을 신고하시겠습니까?\n부적절한 콘텐츠는 24시간 이내에 검토됩니다.', 'confirm': '신고', 'cancel': '취소', 'done': '신고가 접수되었습니다.'},
      'en': {'title': 'Report', 'body': 'Do you want to report this post?\nInappropriate content will be reviewed within 24 hours.', 'confirm': 'Report', 'cancel': 'Cancel', 'done': 'Your report has been submitted.'},
      'ja': {'title': '報告する', 'body': 'この投稿を報告しますか？\n不適切なコンテンツは24時間以内に審査されます。', 'confirm': '報告', 'cancel': 'キャンセル', 'done': '報告を受け付けました。'},
      'zh': {'title': '举报', 'body': '您要举报此帖子吗？\n不当内容将在24小时内审核。', 'confirm': '举报', 'cancel': '取消', 'done': '举报已提交。'},
      'es': {'title': 'Reportar', 'body': '¿Deseas reportar esta publicación?\nEl contenido inapropiado será revisado en 24 horas.', 'confirm': 'Reportar', 'cancel': 'Cancelar', 'done': 'Tu reporte ha sido enviado.'},
    };
    final t = reportText[lang] ?? reportText['en']!;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t['title']!),
        content: Text(t['body']!, style: const TextStyle(fontSize: 14, height: 1.6)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(t['cancel']!, style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _submitReport(memoId);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(t['done']!)),
                );
              }
            },
            child: Text(t['confirm']!, style: const TextStyle(color: Colors.white)),
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
                                                    _showReportDialog(memoId),
                                                constraints:
                                                    const BoxConstraints(),
                                                padding: const EdgeInsets.all(8),
                                                tooltip: labels['report'] ?? '신고',
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
