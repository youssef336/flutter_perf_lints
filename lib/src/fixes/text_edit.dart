/// A plain text replacement, kept free of analysis-server types so fix logic
/// can be unit tested on parsed code.
class TextEdit {
  const TextEdit(this.offset, this.length, this.replacement);

  /// Insertion at [offset].
  const TextEdit.insert(this.offset, this.replacement) : length = 0;

  final int offset;
  final int length;
  final String replacement;

  @override
  String toString() => 'TextEdit($offset, $length, "$replacement")';
}

/// Applies [edits] (which must not overlap) to [content].
String applyEdits(String content, List<TextEdit> edits) {
  final sorted = [...edits]..sort((a, b) => b.offset.compareTo(a.offset));
  var result = content;
  for (final edit in sorted) {
    result = result.replaceRange(
      edit.offset,
      edit.offset + edit.length,
      edit.replacement,
    );
  }
  return result;
}

/// The whitespace at the start of the line containing [offset].
String linePrefix(String content, int offset) {
  var start = offset;
  while (start > 0 && content[start - 1] != '\n') {
    start--;
  }
  var end = start;
  while (end < content.length &&
      (content[end] == ' ' || content[end] == '\t')) {
    end++;
  }
  return content.substring(start, end);
}
