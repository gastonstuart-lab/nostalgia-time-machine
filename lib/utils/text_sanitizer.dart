String decodeHtmlEntities(String input) {
  if (input.isEmpty) return input;

  var output = input;
  // Decode twice to handle occasionally double-escaped payloads from APIs.
  for (var i = 0; i < 2; i++) {
    output = output
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#x27;', "'");
  }
  return output;
}
