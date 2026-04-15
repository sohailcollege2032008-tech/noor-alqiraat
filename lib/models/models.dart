class Surah {
  final int id;
  final String name;
  final String audioFile;

  Surah({required this.id, required this.name, required this.audioFile});

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'],
      name: json['name'],
      audioFile: json['audio_file'],
    );
  }
}

class Mutoon {
  final String id;
  final String name;
  final String folder;
  final List<MutoonChapter> chapters;

  Mutoon({required this.id, required this.name, required this.folder, required this.chapters});

  factory Mutoon.fromJson(Map<String, dynamic> json) {
    var chapList = json['chapters'] as List;
    List<MutoonChapter> chapters = chapList.map((i) => MutoonChapter.fromJson(i)).toList();
    return Mutoon(
      id: json['id'],
      name: json['name'],
      folder: json['folder'],
      chapters: chapters,
    );
  }
}

class MutoonChapter {
  final int id;
  final String name;
  final String audioFile;

  MutoonChapter({required this.id, required this.name, required this.audioFile});

  factory MutoonChapter.fromJson(Map<String, dynamic> json) {
    return MutoonChapter(
      id: json['id'],
      name: json['name'],
      audioFile: json['audio_file'],
    );
  }
}
