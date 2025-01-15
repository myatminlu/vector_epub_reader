import 'package:flutter_test/flutter_test.dart';

import 'package:vector_epub_reader/vector_epub_reader.dart';

void main() {
  test('adds one to input values', () {
    final epubReader = EpubReader(
      epubUrl: '',
    );
    expect(epubReader, isNotNull);
  });
}
