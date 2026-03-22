import 'dart:io';

import 'package:epub_reader/services/file_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileService.cleanOrphanFiles', () {
    late Directory tempDir;
    late _TestFileService fileService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'epub_reader_file_service_test_',
      );
      fileService = _TestFileService(tempDir.path);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('cleans orphan epub left by failed import on next startup', () async {
      final orphanFile = await _createBookFile(
        fileService,
        'failed-import-copy.epub',
      );

      await fileService.cleanOrphanFiles(
        validBookFileNames: const {},
        validCoverFileNames: const {},
      );

      expect(await orphanFile.exists(), isFalse);
    });

    test(
      'keeps imported epub whose stored file name differs from book id',
      () async {
        final retainedFile = await _createBookFile(
          fileService,
          'stored-file-uuid.epub',
        );
        final orphanFile = await _createBookFile(
          fileService,
          'orphan-file.epub',
        );

        await fileService.cleanOrphanFiles(
          validBookFileNames: {'stored-file-uuid'},
          validCoverFileNames: const {},
        );

        expect(await retainedFile.exists(), isTrue);
        expect(await orphanFile.exists(), isFalse);
      },
    );
  });
}

Future<File> _createBookFile(FileService fileService, String fileName) async {
  final booksDirectory = await fileService.getBooksDirectory();
  final file = File(path.join(booksDirectory, fileName));
  await file.writeAsString('epub-bytes');
  return file;
}

class _TestFileService extends FileService {
  _TestFileService(this._documentsPath);

  final String _documentsPath;

  @override
  Future<String> getAppDocumentsPath() async => _documentsPath;
}
