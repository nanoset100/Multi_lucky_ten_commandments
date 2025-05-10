import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:logger/logger.dart';

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
  int currentCardIndex = 0;
  List<Map<String, dynamic>> cards = [];
  TextEditingController memoController = TextEditingController();
  List<Map<String, dynamic>> memos = [];
  bool isLoading = true;
  String? errorMessage;

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

      final response = await Supabase.instance.client
          .from('cards')
          .select()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('서버 연결 시간이 초과되었습니다.');
            },
          );

      logger.i('Fetched ${response.length} cards from Supabase');
      final fetchedCards = List<Map<String, dynamic>>.from(response);

      if (fetchedCards.isNotEmpty) {
        final random = Random();
        final randomIndex = random.nextInt(fetchedCards.length);
        setState(() {
          cards = fetchedCards;
          currentCardIndex = randomIndex;
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
      logger.e('Error fetching cards: $e');
    }
  }

  Future<void> saveMemo() async {
    final prefs = await SharedPreferences.getInstance();
    final memo = memoController.text.trim();
    if (memo.isNotEmpty && cards.isNotEmpty) {
      final card = cards[currentCardIndex];
      final now = DateTime.now(); // ✅ 추가
      final formattedDate =
          "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
      final newMemo = {
        'id': card['id'],
        'title': card['title'],
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

    if (cards.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xffdcd0f7),
        body: Center(child: Text('카드를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.')),
      );
    }

    final card = cards[currentCardIndex];
    final questions =
        card['questions'].map<String>((e) => e.toString()).toList();

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
                card['title'],
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
              Text(card['story'], style: const TextStyle(fontSize: 16)),
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
                        currentCardIndex = random.nextInt(cards.length);
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
