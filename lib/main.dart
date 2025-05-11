import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

/// 앱에서 지원하는 언어 코드와 표시 이름을 담은 Map
final Map<String, String> supportedLanguages = {
  'ko': '한국어',
  'en': 'English',
  'ja': '日本語',
  'zh': '中文',
  'es': 'Español',
};

final logger = Logger();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
    logger.i('ENV loaded successfully');
    await Supabase.initialize(
      url: dotenv.env['SUPABASE_URL']!,
      anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    );
    logger.i('Supabase initialized successfully');
  } catch (e) {
    logger.e('초기화 중 오류 발생: $e');
  }
  runApp(const LuckyTenCommandmentsApp());
}

class LuckyTenCommandmentsApp extends StatelessWidget {
  const LuckyTenCommandmentsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '행운의 십계명 카드',
      theme: ThemeData(primarySwatch: Colors.deepPurple, fontFamily: 'Roboto'),
      home: const CommandmentCardPage(),
    );
  }
}

class CommandmentCardPage extends StatefulWidget {
  const CommandmentCardPage({super.key});

  @override
  State<CommandmentCardPage> createState() => _CommandmentCardPageState();
}

class _CommandmentCardPageState extends State<CommandmentCardPage> {
  List<CardModel> _cards = [];
  int _currentCardIndex = 0;
  TextEditingController memoController = TextEditingController();
  List<Map<String, dynamic>> memos = [];
  bool isLoading = true;
  String? errorMessage;

  /// 사용자가 선택한 언어 코드 (기본값: 'ko')
  String selectedLang = 'ko';

  @override
  void initState() {
    super.initState();
    fetchCardsFromSupabase();
    loadMemos();
  }

  Future<void> fetchCardsFromSupabase() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final selectFields = [
        'id',
        'title_$selectedLang',
        'story_$selectedLang',
        'q1_$selectedLang',
        'q2_$selectedLang',
        'title_ko',
        'story_ko',
        'q1_ko',
        'q2_ko',
        'title_en',
        'story_en',
        'q1_en',
        'q2_en',
        'title_ja',
        'story_ja',
        'q1_ja',
        'q2_ja',
        'title_zh',
        'story_zh',
        'q1_zh',
        'q2_zh',
        'title_es',
        'story_es',
        'q1_es',
        'q2_es',
      ].join(', ');

      final response = await Supabase.instance.client
          .from('multilang_cards')
          .select(selectFields)
          .order('id')
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('서버 연결 시간이 초과되었습니다.');
            },
          );

      logger.i('Fetched ${response.length} cards from Supabase');
      final fetchedCards = List<Map<String, dynamic>>.from(response);
      final cardModels =
          fetchedCards.map((json) => CardModel.fromJson(json)).toList();

      if (cardModels.isNotEmpty) {
        final random = Random();
        final randomIndex = random.nextInt(cardModels.length);
        setState(() {
          _cards = cardModels;
          _currentCardIndex = randomIndex;
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage = '카드를 불러올 수 없습니다.\n잠시 후 다시 시도해주세요.';
          isLoading = false;
        });
        logger.w('No cards found in the response');
      }
    } catch (e) {
      setState(() {
        if (e is TimeoutException) {
          errorMessage = '서버 연결 시간이 초과되었습니다.\n네트워크 연결을 확인하고 다시 시도해주세요.';
        } else if (e.toString().contains('connection')) {
          errorMessage = '네트워크 연결을 확인해주세요.\n인터넷이 연결되어 있는지 확인 후 다시 시도해주세요.';
        } else {
          errorMessage = '오류가 발생했습니다.\n잠시 후 다시 시도해주세요.';
        }
        isLoading = false;
      });
      print('Error fetching cards: $e');
    }
  }

  Future<void> saveMemo() async {
    final prefs = await SharedPreferences.getInstance();
    final memo = memoController.text.trim();
    if (memo.isNotEmpty && _cards.isNotEmpty) {
      final card = _cards[_currentCardIndex];
      final now = DateTime.now(); // ✅ 추가
      final formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final newMemo = {
        'id': card.id,
        'title': card.getTitle(selectedLang),
        'memo': memo,
        'date': formattedDate,
      };
      memos.add(newMemo);
      await prefs.setString('memos', jsonEncode(memos));
      memoController.clear();
      setState(() {});
    }
  }

  Future<void> loadMemos() async {
    final prefs = await SharedPreferences.getInstance();
    final memoString = prefs.getString('memos');
    if (memoString != null) {
      try {
        final decodedData = jsonDecode(memoString);
        if (decodedData is List) {
          setState(() {
            memos = List<Map<String, dynamic>>.from(
              decodedData.whereType<Map<String, dynamic>>(),
            );
          });
        }
      } catch (e) {
        logger.e('Error decoding memo data: $e');
      }
    }
  }

  void showAllMemos() {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('📚 전체 메모 보기'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                itemCount: memos.length,
                itemBuilder: (context, index) {
                  final memo = memos.reversed.toList()[index];
                  final String title = memo['title'] ?? '';
                  final String content = memo['memo'] ?? '';
                  final String date = memo['date']?.substring(0, 10) ?? '날짜 없음';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📝 $title',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(content, style: const TextStyle(fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(
                          '📅 $date',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        const Divider(height: 20, thickness: 1),
                      ],
                    ),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  '닫기',
                  style: TextStyle(color: Colors.deepPurple),
                ),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xffdcd0f7),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('카드를 불러오는 중입니다...', style: TextStyle(fontSize: 16)),
              Text(
                '잠시만 기다려주세요.',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Scaffold(
        backgroundColor: const Color(0xffdcd0f7),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: fetchCardsFromSupabase,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 시도'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepPurple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_cards.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xffdcd0f7),
        body: Center(child: Text('카드를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.')),
      );
    }

    final card = _cards[_currentCardIndex];
    final questions = card.getQuestions(selectedLang);

    return Scaffold(
      backgroundColor: const Color(0xfffdf8ff),
      appBar: AppBar(
        title: const Text(
          '행운의 십계명 카드',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xffdcd0f7),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              /// 언어 선택 드롭다운
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  DropdownButton<String>(
                    value: selectedLang,
                    items:
                        supportedLanguages.entries
                            .map(
                              (entry) => DropdownMenuItem<String>(
                                value: entry.key,
                                child: Text(entry.value),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedLang = value;
                        });
                        fetchCardsFromSupabase();
                      }
                    },
                  ),
                ],
              ),
              const Text(
                '🎯 오늘의 실천 제목',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.getTitle(selectedLang),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                '📖 오늘의 스토리',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.deepPurple,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                card.getStory(selectedLang),
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                '❓ 실천을 위한 질문',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ...questions.map((q) => Text('• $q')).toList(),
              const SizedBox(height: 16),
              const Text(
                '✍️ 메모하기',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              TextField(
                controller: memoController,
                decoration: const InputDecoration(
                  hintText: '오늘의 실천을 기록해보세요',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: saveMemo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  foregroundColor: Colors.white,
                ),
                child: const Text('📂 메모 저장'),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        final random = Random();
                        _currentCardIndex = random.nextInt(_cards.length);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade100,
                    ),
                    child: const Text('🔄 새 카드 뽑기'),
                  ),
                  ElevatedButton(
                    onPressed: showAllMemos,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple.shade100,
                    ),
                    child: const Text('📁 내 메모 보기'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardModel {
  final int id;
  final String? title_ko, story_ko, q1_ko, q2_ko;
  final String? title_en, story_en, q1_en, q2_en;
  final String? title_ja, story_ja, q1_ja, q2_ja;
  final String? title_zh, story_zh, q1_zh, q2_zh;
  final String? title_es, story_es, q1_es, q2_es;

  CardModel({
    required this.id,
    this.title_ko,
    this.story_ko,
    this.q1_ko,
    this.q2_ko,
    this.title_en,
    this.story_en,
    this.q1_en,
    this.q2_en,
    this.title_ja,
    this.story_ja,
    this.q1_ja,
    this.q2_ja,
    this.title_zh,
    this.story_zh,
    this.q1_zh,
    this.q2_zh,
    this.title_es,
    this.story_es,
    this.q1_es,
    this.q2_es,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'] as int,
      title_ko: json['title_ko']?.toString(),
      story_ko: json['story_ko']?.toString(),
      q1_ko: json['q1_ko']?.toString(),
      q2_ko: json['q2_ko']?.toString(),
      title_en: json['title_en']?.toString(),
      story_en: json['story_en']?.toString(),
      q1_en: json['q1_en']?.toString(),
      q2_en: json['q2_en']?.toString(),
      title_ja: json['title_ja']?.toString(),
      story_ja: json['story_ja']?.toString(),
      q1_ja: json['q1_ja']?.toString(),
      q2_ja: json['q2_ja']?.toString(),
      title_zh: json['title_zh']?.toString(),
      story_zh: json['story_zh']?.toString(),
      q1_zh: json['q1_zh']?.toString(),
      q2_zh: json['q2_zh']?.toString(),
      title_es: json['title_es']?.toString(),
      story_es: json['story_es']?.toString(),
      q1_es: json['q1_es']?.toString(),
      q2_es: json['q2_es']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title_ko': title_ko,
    'story_ko': story_ko,
    'q1_ko': q1_ko,
    'q2_ko': q2_ko,
    'title_en': title_en,
    'story_en': story_en,
    'q1_en': q1_en,
    'q2_en': q2_en,
    'title_ja': title_ja,
    'story_ja': story_ja,
    'q1_ja': q1_ja,
    'q2_ja': q2_ja,
    'title_zh': title_zh,
    'story_zh': story_zh,
    'q1_zh': q1_zh,
    'q2_zh': q2_zh,
    'title_es': title_es,
    'story_es': story_es,
    'q1_es': q1_es,
    'q2_es': q2_es,
  };

  String getTitle(String langCode) {
    switch (langCode) {
      case 'ko':
        return title_ko ?? '';
      case 'en':
        return title_en ?? '';
      case 'ja':
        return title_ja ?? '';
      case 'zh':
        return title_zh ?? '';
      case 'es':
        return title_es ?? '';
      default:
        return '';
    }
  }

  String getStory(String langCode) {
    switch (langCode) {
      case 'ko':
        return story_ko ?? '';
      case 'en':
        return story_en ?? '';
      case 'ja':
        return story_ja ?? '';
      case 'zh':
        return story_zh ?? '';
      case 'es':
        return story_es ?? '';
      default:
        return '';
    }
  }

  List<String> getQuestions(String langCode) {
    String? q1;
    String? q2;
    switch (langCode) {
      case 'ko':
        q1 = q1_ko;
        q2 = q2_ko;
        break;
      case 'en':
        q1 = q1_en;
        q2 = q2_en;
        break;
      case 'ja':
        q1 = q1_ja;
        q2 = q2_ja;
        break;
      case 'zh':
        q1 = q1_zh;
        q2 = q2_zh;
        break;
      case 'es':
        q1 = q1_es;
        q2 = q2_es;
        break;
      default:
        q1 = null;
        q2 = null;
    }
    return [q1, q2]
        .where((q) => q != null && q.toString().trim().isNotEmpty)
        .map((q) => q!.toString())
        .toList();
  }
}
