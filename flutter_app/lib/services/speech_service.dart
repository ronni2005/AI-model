class SpeechService {
  SpeechService._();
  static final SpeechService instance = SpeechService._();

  static const Map<String, String> kLocales = {
    'English': 'en_IN',
    'हिन्दी':  'hi_IN',
    'తెలుగు':  'te_IN',
    'தமிழ்':   'ta_IN',
    'ओड़िआ':   'or_IN',
  };

  bool get isAvailable => false;
  bool get isListening  => false;

  Future<void> init() async {}
  void setLocale(String locale) {}
  Future<void> startListening({
    required void Function(String) onResult,
    required void Function() onDone,
  }) async { onDone(); }
  Future<void> stopListening()  async {}
  Future<void> speak(String t)  async {}
  Future<void> stopSpeaking()   async {}
  Future<void> speakResult({
    required String riskLevel,
    required String primaryDisease,
    required String locale,
  }) async {}
}