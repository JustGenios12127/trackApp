import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

class SavedResume {
  const SavedResume({
    required this.id,
    required this.fileName,
    required this.fullName,
    required this.direction,
  });

  final String id;
  final String fileName;
  final String fullName;
  final String direction;
}

class CoverLetter {
  const CoverLetter({
    required this.letter,
    required this.vacancyTitle,
    required this.resume,
  });

  final String letter;
  final String vacancyTitle;
  final SavedResume resume;
}

class CoverLetterException implements Exception {
  const CoverLetterException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract interface class CoverLetterGateway {
  Future<List<SavedResume>> list();

  Future<SavedResume> save({
    required String fileName,
    required Uint8List bytes,
  });

  Future<void> remove(String id);

  Future<CoverLetter> write({required String vacancy});
}

class SupabaseCoverLetterGateway implements CoverLetterGateway {
  const SupabaseCoverLetterGateway();

  @override
  Future<List<SavedResume>> list() async {
    final data = await _invoke({'action': 'list'});
    if (data is! Map) {
      throw const CoverLetterException('Ассистент прислал пустой ответ.');
    }
    final raw = data['resumes'];
    if (raw is! List) {
      throw const CoverLetterException('Ассистент прислал пустой ответ.');
    }
    final resumes = <SavedResume>[];
    for (final item in raw) {
      final resume = _resume(item);
      if (resume != null) resumes.add(resume);
    }
    return resumes;
  }

  @override
  Future<SavedResume> save({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final data = await _invoke({
      'action': 'save',
      'file_name': fileName,
      'file_base64': base64Encode(bytes),
    });
    if (data is! Map) {
      throw const CoverLetterException('Ассистент прислал пустой ответ.');
    }
    final resume = _resume(data['resume']);
    if (resume == null) {
      throw const CoverLetterException('Ассистент прислал пустой ответ.');
    }
    return resume;
  }

  @override
  Future<void> remove(String id) async {
    await _invoke({'action': 'delete', 'id': id});
  }

  @override
  Future<CoverLetter> write({required String vacancy}) async {
    final data = await _invoke({'action': 'write', 'vacancy': vacancy});
    if (data is! Map) {
      throw const CoverLetterException('Ассистент прислал пустой ответ.');
    }
    final letter = data['letter'];
    final title = data['vacancy_title'];
    final resume = _resume(data['resume']);
    if (letter is! String ||
        letter.trim().isEmpty ||
        title is! String ||
        title.trim().isEmpty ||
        resume == null) {
      throw const CoverLetterException('Ассистент прислал пустой ответ.');
    }
    return CoverLetter(
      letter: letter.trim(),
      vacancyTitle: title.trim(),
      resume: resume,
    );
  }

  Future<dynamic> _invoke(Map<String, dynamic> body) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'cover-letter',
        body: body,
      );
      return response.data;
    } on CoverLetterException {
      rethrow;
    } on FunctionException catch (error) {
      throw CoverLetterException(_message(error));
    } catch (_) {
      throw const CoverLetterException(
        'Не получилось связаться с ассистентом. Проверь интернет и попробуй ещё раз.',
      );
    }
  }

  SavedResume? _resume(Object? data) {
    if (data is! Map) return null;
    final id = data['id'];
    final fileName = data['file_name'];
    final fullName = data['full_name'];
    final direction = data['direction'];
    if (id is! String ||
        fileName is! String ||
        fullName is! String ||
        direction is! String) {
      return null;
    }
    if (id.isEmpty || fileName.isEmpty || fullName.isEmpty || direction.isEmpty) {
      return null;
    }
    return SavedResume(
      id: id,
      fileName: fileName,
      fullName: fullName,
      direction: direction,
    );
  }

  String _message(FunctionException error) {
    final details = error.details;
    if (details is Map) {
      final value = details['error'];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    if (error.status == 401 || error.status == 403) {
      return 'Сессия истекла. Войди снова.';
    }
    return 'Ассистент сейчас недоступен. Попробуй ещё раз.';
  }
}
