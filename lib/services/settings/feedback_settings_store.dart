/// 計測中に1秒ごとに鳴らす楽器。[folder] は assets/sounds/scale/ の下のフォルダ名。
enum MeasureInstrument {
  none('なし', null),
  marimba('木琴', 'marimba'),
  glockenspiel('鉄琴', 'glockenspiel'),
  musicBox('オルゴール', 'musicbox'),
  kalimba('カリンバ', 'kalimba'),
  harp('ハープ', 'harp'),
  koto('琴', 'koto'),
  soft('やさしい電子音', 'soft'),

  /// パチンコ風。計測完了で画面が暗転し、効果音とともに体調の入力へ進む。
  pachinko('シークレット', 'pachinko');

  const MeasureInstrument(this.label, this.folder);
  final String label;
  final String? folder;

  /// [note]（0〜14）番目の音のファイル（assets/sounds/scale/[folder]/ の下）。
  /// パチンコ風は12段階の素材を15秒に均等に割り当てる。
  String fileFor(int note) => switch (this) {
    pachinko => 'free_sound${1055 + (note * 11 / 14).round()}.mp3',
    _ => '${note.toString().padLeft(2, '0')}.m4a',
  };
}

/// 効果音と振動のオン／オフ、計測中の音（端末内の設定）。新しく入れた端末は両方オン・木琴。
class FeedbackSettings {
  const FeedbackSettings({
    this.sound = true,
    this.haptics = true,
    this.instrument = MeasureInstrument.marimba,
  });

  final bool sound;
  final bool haptics;
  final MeasureInstrument instrument;

  FeedbackSettings copyWith({
    bool? sound,
    bool? haptics,
    MeasureInstrument? instrument,
  }) => FeedbackSettings(
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    instrument: instrument ?? this.instrument,
  );
}

abstract interface class FeedbackSettingsStore {
  Future<FeedbackSettings> load();
  Future<void> save(FeedbackSettings settings);
}
