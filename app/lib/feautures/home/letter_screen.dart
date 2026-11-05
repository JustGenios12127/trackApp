import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/app_theme.dart';
import 'data/cover_letter_gateway.dart';
import 'data/resume_files.dart';
import 'widgets/chat_widgets.dart';
import 'widgets/tab_header.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({
    super.key,
    this.letters,
    this.pickFiles = pickResumeFiles,
    this.visible = true,
  });

  final CoverLetterGateway? letters;
  final ResumePicker pickFiles;
  final bool visible;

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> {
  static const _maxFiles = 5;
  static const _maxBytes = 10 * 1024 * 1024;

  late final CoverLetterGateway _letters =
      widget.letters ?? const SupabaseCoverLetterGateway();
  final _vacancy = TextEditingController();
  List<SavedResume> _resumes = const [];
  CoverLetter? _result;
  var _loading = true;
  var _failed = false;
  var _saving = false;
  var _writing = false;
  String? _removing;
  String? _notice;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _vacancy.addListener(_onVacancy);
    if (widget.visible) {
      _load(silent: true);
    } else {
      _loading = false;
    }
  }

  @override
  void didUpdateWidget(LetterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible && !oldWidget.visible) {
      _load(silent: _resumes.isNotEmpty);
    }
  }

  @override
  void dispose() {
    _vacancy.removeListener(_onVacancy);
    _vacancy.dispose();
    super.dispose();
  }

  void _onVacancy() {
    if (mounted) setState(() {});
  }

  bool get _canWrite {
    return !_writing &&
        !_saving &&
        _resumes.isNotEmpty &&
        _vacancy.text.trim().length >= 10;
  }

  Future<void> _load({bool silent = false}) async {
    final generation = ++_generation;
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }
    try {
      final rows = await _letters.list();
      if (!mounted || generation != _generation) return;
      setState(() {
        _resumes = rows;
        _loading = false;
        _failed = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _loading = false;
        _failed = _resumes.isEmpty;
        if (_resumes.isNotEmpty) {
          _notice = 'Не удалось обновить резюме. Попробуй ещё раз.';
        }
      });
    }
  }

  Future<void> _upload() async {
    if (_saving || _writing) return;
    FocusManager.instance.primaryFocus?.unfocus();
    if (_resumes.length >= _maxFiles) {
      setState(
        () => _notice = 'Можно сохранить не больше 5 резюме. Удали лишнее.',
      );
      return;
    }
    List<PickedResume> files;
    try {
      files = await widget.pickFiles();
    } catch (_) {
      if (!mounted) return;
      setState(() => _notice = 'Не удалось открыть файлы.');
      return;
    }
    if (!mounted || files.isEmpty) return;

    setState(() {
      _saving = true;
      _notice = null;
    });
    final problems = <String>[];
    var stored = _resumes.length;
    for (final file in files) {
      if (stored >= _maxFiles) {
        problems.add('Можно сохранить не больше 5 резюме.');
        break;
      }
      final problem = _fileProblem(file);
      if (problem != null) {
        problems.add(problem);
        continue;
      }
      try {
        await _letters.save(fileName: file.name, bytes: file.bytes);
        stored++;
      } on CoverLetterException catch (error) {
        problems.add('${file.name}: ${error.message}');
      } catch (_) {
        problems.add('${file.name}: не удалось загрузить.');
      }
    }
    if (!mounted) return;
    await _load(silent: true);
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (problems.isNotEmpty) _notice = problems.join('\n');
    });
  }

  String? _fileProblem(PickedResume file) {
    final name = file.name.trim();
    if (!name.toLowerCase().endsWith('.docx')) {
      return '$name: нужен файл Word .docx.';
    }
    if (file.bytes.isEmpty) return '$name: файл пустой.';
    if (file.bytes.length > _maxBytes) return '$name: файл больше 10 МБ.';
    return null;
  }

  Future<void> _write() async {
    if (!_canWrite) return;
    FocusManager.instance.primaryFocus?.unfocus();
    final vacancy = _vacancy.text.trim();
    setState(() {
      _writing = true;
      _notice = null;
    });
    try {
      final result = await _letters.write(vacancy: vacancy);
      if (!mounted) return;
      setState(() {
        _result = result;
        _writing = false;
      });
    } on CoverLetterException catch (error) {
      if (!mounted) return;
      setState(() {
        _writing = false;
        _notice = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _writing = false;
        _notice = 'Не получилось составить письмо. Попробуй ещё раз.';
      });
    }
  }

  Future<void> _remove(SavedResume resume) async {
    if (_removing != null || _saving) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainer,
          title: Text(
            'Удалить резюме?',
            style: AppText.headlineSm(Colors.white),
          ),
          content: Text(
            '«${resume.fileName}» пропадёт из профиля.',
            style: AppText.bodyMd(AppColors.onSurfaceVariant),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Отмена', style: AppText.bodyMd(Colors.white)),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                'Удалить',
                style: AppText.bodyMd(Colors.white, weight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
    if (leave != true || !mounted) return;
    setState(() => _removing = resume.id);
    try {
      await _letters.remove(resume.id);
      if (!mounted) return;
      setState(() {
        _resumes = [
          for (final item in _resumes)
            if (item.id != resume.id) item,
        ];
        _removing = null;
      });
    } on CoverLetterException catch (error) {
      if (!mounted) return;
      setState(() {
        _removing = null;
        _notice = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _removing = null;
        _notice = 'Не получилось удалить резюме. Попробуй ещё раз.';
      });
    }
  }

  Future<void> _copy(String letter) async {
    await Clipboard.setData(ClipboardData(text: letter));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Письмо скопировано')));
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Stack(
        children: [
          const ChatBackdrop(),
          Column(
            children: [
              const TabHeader(title: 'Письмо'),
              Expanded(
                child: RefreshIndicator(
                  color: Colors.white,
                  backgroundColor: AppColors.surfaceContainer,
                  onRefresh: () => _load(silent: true),
                  child: ListView(
                    primary: false,
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: ClampingScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    children: [
                      const _Intro(),
                      const SizedBox(height: 16),
                      _ResumesCard(
                        resumes: _resumes,
                        loading: _loading && _resumes.isEmpty,
                        failed: _failed,
                        saving: _saving,
                        removing: _removing,
                        onUpload: _saving ? null : _upload,
                        onRetry: () => _load(),
                        onDelete: _remove,
                      ),
                      const SizedBox(height: 16),
                      _VacancyCard(
                        controller: _vacancy,
                        writing: _writing,
                        enabled: _canWrite,
                        onWrite: _write,
                      ),
                      if (_notice != null) ...[
                        const SizedBox(height: 16),
                        _Notice(text: _notice!),
                      ],
                      if (result != null) ...[
                        const SizedBox(height: 16),
                        _LetterCard(
                          result: result,
                          onCopy: () => _copy(result.letter),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Intro extends StatelessWidget {
  const _Intro();

  @override
  Widget build(BuildContext context) {
    return ChatGlass(
      radius: 24,
      color: AppColors.surfaceContainer.withValues(alpha: 0.82),
      padding: const EdgeInsets.all(20),
      child: Text(
        'Ассистент читает резюме в Word и запоминает профиль. По тексту вакансии он выбирает подходящее резюме и пишет короткое сопроводительное письмо.',
        style: AppText.bodyMd(AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _ResumesCard extends StatelessWidget {
  const _ResumesCard({
    required this.resumes,
    required this.loading,
    required this.failed,
    required this.saving,
    required this.removing,
    required this.onUpload,
    required this.onRetry,
    required this.onDelete,
  });

  final List<SavedResume> resumes;
  final bool loading;
  final bool failed;
  final bool saving;
  final String? removing;
  final VoidCallback? onUpload;
  final VoidCallback onRetry;
  final ValueChanged<SavedResume> onDelete;

  @override
  Widget build(BuildContext context) {
    return ChatGlass(
      radius: 24,
      color: AppColors.surfaceContainer.withValues(alpha: 0.82),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'РЕЗЮМЕ',
            style: AppText.labelSm(
              AppColors.onSurfaceVariant,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          if (loading)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          else if (failed)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(48, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Не удалось загрузить резюме. Повторить',
                style: AppText.bodyMd(Colors.white),
              ),
            )
          else if (resumes.isEmpty)
            Text(
              'Резюме ещё нет',
              style: AppText.bodyMd(AppColors.onSurfaceVariant),
            )
          else
            for (var i = 0; i < resumes.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              _ResumeTile(
                resume: resumes[i],
                onDelete: removing == null ? () => onDelete(resumes[i]) : null,
              ),
            ],
          const SizedBox(height: 16),
          _ActionButton(
            label: 'Загрузить Word',
            icon: Icons.upload_file_outlined,
            busy: saving,
            filled: false,
            onPressed: onUpload,
          ),
          const SizedBox(height: 8),
          Text(
            'Формат .docx, до 5 файлов и 10 МБ.',
            style: AppText.bodySm(AppColors.outline),
          ),
        ],
      ),
    );
  }
}

class _ResumeTile extends StatelessWidget {
  const _ResumeTile({required this.resume, required this.onDelete});

  final SavedResume resume;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
        child: Row(
          children: [
            const Icon(
              Icons.description_outlined,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    resume.fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMd(
                      Colors.white,
                      weight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${resume.fullName} · ${resume.direction}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodySm(AppColors.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Удалить резюме «${resume.fileName}»',
              onPressed: onDelete,
              icon: const Icon(
                Icons.delete_outline,
                color: AppColors.outline,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VacancyCard extends StatelessWidget {
  const _VacancyCard({
    required this.controller,
    required this.writing,
    required this.enabled,
    required this.onWrite,
  });

  final TextEditingController controller;
  final bool writing;
  final bool enabled;
  final VoidCallback onWrite;

  @override
  Widget build(BuildContext context) {
    return ChatGlass(
      radius: 24,
      color: AppColors.surfaceContainer.withValues(alpha: 0.82),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ВАКАНСИЯ',
            style: AppText.labelSm(
              AppColors.onSurfaceVariant,
              weight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            minLines: 5,
            maxLines: 10,
            maxLength: 8000,
            enabled: !writing,
            textCapitalization: TextCapitalization.sentences,
            keyboardType: TextInputType.multiline,
            style: AppText.bodyMd(Colors.white),
            cursorColor: Colors.white,
            decoration: InputDecoration(
              hintText: 'Вставь текст вакансии',
              hintStyle: AppText.bodyMd(AppColors.outline),
              counterText: '',
              filled: true,
              fillColor: AppColors.surfaceHighest.withValues(alpha: 0.72),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Составить письмо',
            icon: Icons.auto_awesome,
            busy: writing,
            onPressed: enabled ? onWrite : null,
          ),
        ],
      ),
    );
  }
}

class _LetterCard extends StatelessWidget {
  const _LetterCard({required this.result, required this.onCopy});

  final CoverLetter result;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return ChatGlass(
      radius: 24,
      color: AppColors.surfaceContainer.withValues(alpha: 0.82),
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ПИСЬМО',
                  style: AppText.labelSm(
                    AppColors.onSurfaceVariant,
                    weight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Скопировать письмо',
                onPressed: onCopy,
                icon: const Icon(
                  Icons.copy_outlined,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          Text(
            'Подошло: ${result.resume.fileName}',
            style: AppText.bodyMd(Colors.white, weight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '${result.resume.fullName} · ${result.resume.direction}',
            style: AppText.bodySm(AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            result.vacancyTitle,
            style: AppText.bodySm(AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SelectableText(
              result.letter,
              style: AppText.bodyMd(AppColors.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.error_outline, size: 18, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: AppText.bodySm(AppColors.onSurface)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
    this.filled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final background = filled ? Colors.white : AppColors.surfaceHighest;
    final foreground = filled ? AppColors.onPrimary : AppColors.onSurface;
    return Opacity(
      opacity: enabled || busy ? 1 : 0.45,
      child: Semantics(
        button: true,
        label: label,
        enabled: enabled,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(999),
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: enabled ? onPressed : null,
            child: SizedBox(
              height: 52,
              child: Center(
                child: busy
                    ? SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: foreground,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 18, color: foreground),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: AppText.bodyMd(
                              foreground,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
