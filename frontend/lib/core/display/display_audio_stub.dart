class DisplayAudio {
  DisplayAudio._();
  static final DisplayAudio instance = DisplayAudio._();

  bool enabled = true;
  bool unlocked = false;

  Future<void> unlock() async {
    unlocked = true;
  }

  Future<void> playCourtReady() async {}

  Future<void> playNextUp() async {}

  Future<void> playCelebration() async {}
}
