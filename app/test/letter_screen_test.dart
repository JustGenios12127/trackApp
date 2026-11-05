import 'dart:typed_data';

import 'package:app/app/app_theme.dart';
import 'package:app/feautures/home/data/cover_letter_gateway.dart';
import 'package:app/feautures/home/data/resume_files.dart';
import 'package:app/feautures/home/letter_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('пустой экран предлагает загрузить резюме', (tester) async {
    await _pump(tester, const LetterScreen(letters: _EmptyLetters()));
    await tester.pump();

    expect(find.text('Письмо'), findsOneWidget);
    expect(find.text('Резюме ещё нет'), findsOneWidget);
    expect(find.text('Загрузить Word'), findsOneWidget);
    expect(find.text('Составить письмо'), findsOneWidget);
    expect(find.text('ПИСЬМО'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ошибку списка можно повторить', (tester) async {
    final letters = _MemoryLetters()..failList = true;
    await _pump(tester, LetterScreen(letters: letters));
    await tester.pump();

    expect(find.text('Не удалось загрузить резюме. Повторить'), findsOneWidget);

    letters.failList = false;
    await tester.tap(find.text('Не удалось загрузить резюме. Повторить'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Резюме ещё нет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('word-файл сохраняется и показывается в профиле', (tester) async {
    final letters = _MemoryLetters();
    final picked = [
      PickedResume(name: 'backend.docx', bytes: Uint8List.fromList([1, 2, 3])),
    ];
    await _pump(
      tester,
      LetterScreen(letters: letters, pickFiles: () async => picked),
    );
    await tester.pump();

    await tester.tap(find.text('Загрузить Word'));
    await tester.pump();
    await tester.pump();

    expect(find.text('backend.docx'), findsOneWidget);
    expect(find.text('Иван Иванов · backend-разработка'), findsOneWidget);
    expect(letters.saved, ['backend.docx']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('чужой формат не уходит на сервер', (tester) async {
    final letters = _MemoryLetters();
    await _pump(
      tester,
      LetterScreen(
        letters: letters,
        pickFiles: () async => [
          PickedResume(name: 'resume.pdf', bytes: Uint8List.fromList([1])),
        ],
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Загрузить Word'));
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('нужен файл Word .docx'), findsOneWidget);
    expect(letters.saved, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('вакансия выбирает резюме и показывает письмо', (tester) async {
    final letters = _MemoryLetters()
      ..resumes.add(
        const SavedResume(
          id: 'cv-1',
          fileName: 'backend.docx',
          fullName: 'Иван Иванов',
          direction: 'backend-разработка',
        ),
      );
    await _pump(tester, LetterScreen(letters: letters));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'Ищем backend-разработчика для серверной части продукта.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Составить письмо'));
    await tester.tap(find.text('Составить письмо'));
    await tester.pump();
    await tester.pump();

    expect(letters.vacancy, contains('backend-разработчика'));
    expect(find.text('Подошло: backend.docx'), findsOneWidget);
    expect(find.textContaining('Здравствуйте!'), findsOneWidget);
    expect(find.textContaining('Иван Иванов'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('короткая вакансия не отправляет запрос', (tester) async {
    final letters = _MemoryLetters()
      ..resumes.add(
        const SavedResume(
          id: 'cv-1',
          fileName: 'backend.docx',
          fullName: 'Иван Иванов',
          direction: 'backend-разработка',
        ),
      );
    await _pump(tester, LetterScreen(letters: letters));
    await tester.pump();

    await tester.enterText(find.byType(TextField), 'backend');
    await tester.pump();
    await tester.ensureVisible(find.text('Составить письмо'));
    await tester.tap(find.text('Составить письмо'));
    await tester.pump();

    expect(letters.writes, 0);
    expect(find.text('ПИСЬМО'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ошибка генерации остаётся на экране', (tester) async {
    final letters = _MemoryLetters()
      ..failWrite = true
      ..resumes.add(
        const SavedResume(
          id: 'cv-1',
          fileName: 'backend.docx',
          fullName: 'Иван Иванов',
          direction: 'backend-разработка',
        ),
      );
    await _pump(tester, LetterScreen(letters: letters));
    await tester.pump();

    await tester.enterText(
      find.byType(TextField),
      'Нужен дизайнер интерфейсов в продуктовую команду.',
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Составить письмо'));
    await tester.tap(find.text('Составить письмо'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Ассистент не составил письмо.'), findsOneWidget);
    expect(find.text('ПИСЬМО'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('резюме можно удалить', (tester) async {
    final letters = _MemoryLetters()
      ..resumes.add(
        const SavedResume(
          id: 'cv-1',
          fileName: 'backend.docx',
          fullName: 'Иван Иванов',
          direction: 'backend-разработка',
        ),
      );
    await _pump(tester, LetterScreen(letters: letters));
    await tester.pump();

    await tester.tap(find.byTooltip('Удалить резюме «backend.docx»'));
    await tester.pumpAndSettle();
    expect(find.text('Удалить резюме?'), findsOneWidget);

    await tester.tap(find.text('Отмена'));
    await tester.pumpAndSettle();
    expect(find.text('backend.docx'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить резюме «backend.docx»'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Удалить'));
    await tester.pumpAndSettle();

    expect(find.text('backend.docx'), findsNothing);
    expect(find.text('Резюме ещё нет'), findsOneWidget);
    expect(letters.removed, ['cv-1']);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 1200);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.dark, home: home));
}

class _EmptyLetters implements CoverLetterGateway {
  const _EmptyLetters();

  @override
  Future<List<SavedResume>> list() async => const [];

  @override
  Future<void> remove(String id) async {}

  @override
  Future<SavedResume> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    throw const CoverLetterException('empty');
  }

  @override
  Future<CoverLetter> write({required String vacancy}) async {
    throw const CoverLetterException('empty');
  }
}

class _MemoryLetters implements CoverLetterGateway {
  final resumes = <SavedResume>[];
  final saved = <String>[];
  final removed = <String>[];
  var failList = false;
  var failWrite = false;
  var writes = 0;
  String? vacancy;

  @override
  Future<List<SavedResume>> list() async {
    if (failList) throw const CoverLetterException('Сеть');
    return List<SavedResume>.of(resumes);
  }

  @override
  Future<SavedResume> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    saved.add(fileName);
    final resume = SavedResume(
      id: 'id-${resumes.length + 1}',
      fileName: fileName,
      fullName: 'Иван Иванов',
      direction: 'backend-разработка',
    );
    resumes.add(resume);
    return resume;
  }

  @override
  Future<void> remove(String id) async {
    removed.add(id);
    resumes.removeWhere((resume) => resume.id == id);
  }

  @override
  Future<CoverLetter> write({required String vacancy}) async {
    writes += 1;
    this.vacancy = vacancy;
    if (failWrite) {
      throw const CoverLetterException('Ассистент не составил письмо.');
    }
    final resume = resumes.first;
    return CoverLetter(
      letter:
          'Здравствуйте!\n\nМеня заинтересовала вакансия.\n\nС уважением,\n${resume.fullName}',
      vacancyTitle: 'Backend-разработчик',
      resume: resume,
    );
  }
}
