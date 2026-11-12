// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $ScriptsTable extends Scripts with TableInfo<$ScriptsTable, ScriptRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ScriptsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _rawTextMeta =
      const VerificationMeta('rawText');
  @override
  late final GeneratedColumn<String> rawText = GeneratedColumn<String>(
      'raw_text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _langMeta = const VerificationMeta('lang');
  @override
  late final GeneratedColumn<String> lang = GeneratedColumn<String>(
      'lang', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('zh'));
  static const VerificationMeta _folderIdMeta =
      const VerificationMeta('folderId');
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
      'folder_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _tagsMeta = const VerificationMeta('tags');
  @override
  late final GeneratedColumn<String> tags = GeneratedColumn<String>(
      'tags', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _favoriteMeta =
      const VerificationMeta('favorite');
  @override
  late final GeneratedColumn<bool> favorite = GeneratedColumn<bool>(
      'favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _archivedMeta =
      const VerificationMeta('archived');
  @override
  late final GeneratedColumn<bool> archived = GeneratedColumn<bool>(
      'archived', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("archived" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _deletedAtMeta =
      const VerificationMeta('deletedAt');
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
      'deleted_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _lastViewedAtMeta =
      const VerificationMeta('lastViewedAt');
  @override
  late final GeneratedColumn<int> lastViewedAt = GeneratedColumn<int>(
      'last_viewed_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        rawText,
        lang,
        folderId,
        tags,
        favorite,
        archived,
        deletedAt,
        createdAt,
        updatedAt,
        lastViewedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'scripts';
  @override
  VerificationContext validateIntegrity(Insertable<ScriptRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('raw_text')) {
      context.handle(_rawTextMeta,
          rawText.isAcceptableOrUnknown(data['raw_text']!, _rawTextMeta));
    } else if (isInserting) {
      context.missing(_rawTextMeta);
    }
    if (data.containsKey('lang')) {
      context.handle(
          _langMeta, lang.isAcceptableOrUnknown(data['lang']!, _langMeta));
    }
    if (data.containsKey('folder_id')) {
      context.handle(_folderIdMeta,
          folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta));
    }
    if (data.containsKey('tags')) {
      context.handle(
          _tagsMeta, tags.isAcceptableOrUnknown(data['tags']!, _tagsMeta));
    }
    if (data.containsKey('favorite')) {
      context.handle(_favoriteMeta,
          favorite.isAcceptableOrUnknown(data['favorite']!, _favoriteMeta));
    }
    if (data.containsKey('archived')) {
      context.handle(_archivedMeta,
          archived.isAcceptableOrUnknown(data['archived']!, _archivedMeta));
    }
    if (data.containsKey('deleted_at')) {
      context.handle(_deletedAtMeta,
          deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('last_viewed_at')) {
      context.handle(
          _lastViewedAtMeta,
          lastViewedAt.isAcceptableOrUnknown(
              data['last_viewed_at']!, _lastViewedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ScriptRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ScriptRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      rawText: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}raw_text'])!,
      lang: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}lang'])!,
      folderId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}folder_id']),
      tags: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}tags']),
      favorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}favorite'])!,
      archived: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}archived'])!,
      deletedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}deleted_at']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
      lastViewedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_viewed_at']),
    );
  }

  @override
  $ScriptsTable createAlias(String alias) {
    return $ScriptsTable(attachedDatabase, alias);
  }
}

class ScriptRow extends DataClass implements Insertable<ScriptRow> {
  final String id;
  final String title;
  final String rawText;
  final String lang;
  final String? folderId;
  final String? tags;
  final bool favorite;
  final bool archived;
  final int? deletedAt;
  final int createdAt;
  final int updatedAt;
  final int? lastViewedAt;
  const ScriptRow(
      {required this.id,
      required this.title,
      required this.rawText,
      required this.lang,
      this.folderId,
      this.tags,
      required this.favorite,
      required this.archived,
      this.deletedAt,
      required this.createdAt,
      required this.updatedAt,
      this.lastViewedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    map['raw_text'] = Variable<String>(rawText);
    map['lang'] = Variable<String>(lang);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    if (!nullToAbsent || tags != null) {
      map['tags'] = Variable<String>(tags);
    }
    map['favorite'] = Variable<bool>(favorite);
    map['archived'] = Variable<bool>(archived);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || lastViewedAt != null) {
      map['last_viewed_at'] = Variable<int>(lastViewedAt);
    }
    return map;
  }

  ScriptsCompanion toCompanion(bool nullToAbsent) {
    return ScriptsCompanion(
      id: Value(id),
      title: Value(title),
      rawText: Value(rawText),
      lang: Value(lang),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      tags: tags == null && nullToAbsent ? const Value.absent() : Value(tags),
      favorite: Value(favorite),
      archived: Value(archived),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastViewedAt: lastViewedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastViewedAt),
    );
  }

  factory ScriptRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ScriptRow(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      rawText: serializer.fromJson<String>(json['rawText']),
      lang: serializer.fromJson<String>(json['lang']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      tags: serializer.fromJson<String?>(json['tags']),
      favorite: serializer.fromJson<bool>(json['favorite']),
      archived: serializer.fromJson<bool>(json['archived']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      lastViewedAt: serializer.fromJson<int?>(json['lastViewedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'rawText': serializer.toJson<String>(rawText),
      'lang': serializer.toJson<String>(lang),
      'folderId': serializer.toJson<String?>(folderId),
      'tags': serializer.toJson<String?>(tags),
      'favorite': serializer.toJson<bool>(favorite),
      'archived': serializer.toJson<bool>(archived),
      'deletedAt': serializer.toJson<int?>(deletedAt),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'lastViewedAt': serializer.toJson<int?>(lastViewedAt),
    };
  }

  ScriptRow copyWith(
          {String? id,
          String? title,
          String? rawText,
          String? lang,
          Value<String?> folderId = const Value.absent(),
          Value<String?> tags = const Value.absent(),
          bool? favorite,
          bool? archived,
          Value<int?> deletedAt = const Value.absent(),
          int? createdAt,
          int? updatedAt,
          Value<int?> lastViewedAt = const Value.absent()}) =>
      ScriptRow(
        id: id ?? this.id,
        title: title ?? this.title,
        rawText: rawText ?? this.rawText,
        lang: lang ?? this.lang,
        folderId: folderId.present ? folderId.value : this.folderId,
        tags: tags.present ? tags.value : this.tags,
        favorite: favorite ?? this.favorite,
        archived: archived ?? this.archived,
        deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastViewedAt:
            lastViewedAt.present ? lastViewedAt.value : this.lastViewedAt,
      );
  ScriptRow copyWithCompanion(ScriptsCompanion data) {
    return ScriptRow(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      rawText: data.rawText.present ? data.rawText.value : this.rawText,
      lang: data.lang.present ? data.lang.value : this.lang,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      tags: data.tags.present ? data.tags.value : this.tags,
      favorite: data.favorite.present ? data.favorite.value : this.favorite,
      archived: data.archived.present ? data.archived.value : this.archived,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastViewedAt: data.lastViewedAt.present
          ? data.lastViewedAt.value
          : this.lastViewedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ScriptRow(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('rawText: $rawText, ')
          ..write('lang: $lang, ')
          ..write('folderId: $folderId, ')
          ..write('tags: $tags, ')
          ..write('favorite: $favorite, ')
          ..write('archived: $archived, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastViewedAt: $lastViewedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, rawText, lang, folderId, tags,
      favorite, archived, deletedAt, createdAt, updatedAt, lastViewedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ScriptRow &&
          other.id == this.id &&
          other.title == this.title &&
          other.rawText == this.rawText &&
          other.lang == this.lang &&
          other.folderId == this.folderId &&
          other.tags == this.tags &&
          other.favorite == this.favorite &&
          other.archived == this.archived &&
          other.deletedAt == this.deletedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastViewedAt == this.lastViewedAt);
}

class ScriptsCompanion extends UpdateCompanion<ScriptRow> {
  final Value<String> id;
  final Value<String> title;
  final Value<String> rawText;
  final Value<String> lang;
  final Value<String?> folderId;
  final Value<String?> tags;
  final Value<bool> favorite;
  final Value<bool> archived;
  final Value<int?> deletedAt;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<int?> lastViewedAt;
  final Value<int> rowid;
  const ScriptsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.rawText = const Value.absent(),
    this.lang = const Value.absent(),
    this.folderId = const Value.absent(),
    this.tags = const Value.absent(),
    this.favorite = const Value.absent(),
    this.archived = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastViewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ScriptsCompanion.insert({
    required String id,
    required String title,
    required String rawText,
    this.lang = const Value.absent(),
    this.folderId = const Value.absent(),
    this.tags = const Value.absent(),
    this.favorite = const Value.absent(),
    this.archived = const Value.absent(),
    this.deletedAt = const Value.absent(),
    required int createdAt,
    required int updatedAt,
    this.lastViewedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title),
        rawText = Value(rawText),
        createdAt = Value(createdAt),
        updatedAt = Value(updatedAt);
  static Insertable<ScriptRow> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? rawText,
    Expression<String>? lang,
    Expression<String>? folderId,
    Expression<String>? tags,
    Expression<bool>? favorite,
    Expression<bool>? archived,
    Expression<int>? deletedAt,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<int>? lastViewedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (rawText != null) 'raw_text': rawText,
      if (lang != null) 'lang': lang,
      if (folderId != null) 'folder_id': folderId,
      if (tags != null) 'tags': tags,
      if (favorite != null) 'favorite': favorite,
      if (archived != null) 'archived': archived,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastViewedAt != null) 'last_viewed_at': lastViewedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ScriptsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<String>? rawText,
      Value<String>? lang,
      Value<String?>? folderId,
      Value<String?>? tags,
      Value<bool>? favorite,
      Value<bool>? archived,
      Value<int?>? deletedAt,
      Value<int>? createdAt,
      Value<int>? updatedAt,
      Value<int?>? lastViewedAt,
      Value<int>? rowid}) {
    return ScriptsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      rawText: rawText ?? this.rawText,
      lang: lang ?? this.lang,
      folderId: folderId ?? this.folderId,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      archived: archived ?? this.archived,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastViewedAt: lastViewedAt ?? this.lastViewedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (rawText.present) {
      map['raw_text'] = Variable<String>(rawText.value);
    }
    if (lang.present) {
      map['lang'] = Variable<String>(lang.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (tags.present) {
      map['tags'] = Variable<String>(tags.value);
    }
    if (favorite.present) {
      map['favorite'] = Variable<bool>(favorite.value);
    }
    if (archived.present) {
      map['archived'] = Variable<bool>(archived.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (lastViewedAt.present) {
      map['last_viewed_at'] = Variable<int>(lastViewedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ScriptsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('rawText: $rawText, ')
          ..write('lang: $lang, ')
          ..write('folderId: $folderId, ')
          ..write('tags: $tags, ')
          ..write('favorite: $favorite, ')
          ..write('archived: $archived, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastViewedAt: $lastViewedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SectionsTable extends Sections
    with TableInfo<$SectionsTable, SectionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SectionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scriptIdMeta =
      const VerificationMeta('scriptId');
  @override
  late final GeneratedColumn<String> scriptId = GeneratedColumn<String>(
      'script_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _ordMeta = const VerificationMeta('ord');
  @override
  late final GeneratedColumn<int> ord = GeneratedColumn<int>(
      'ord', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _bodyMeta = const VerificationMeta('body');
  @override
  late final GeneratedColumn<String> body = GeneratedColumn<String>(
      'text', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
      'note', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _charCountMeta =
      const VerificationMeta('charCount');
  @override
  late final GeneratedColumn<int> charCount = GeneratedColumn<int>(
      'char_count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [id, scriptId, ord, body, note, charCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sections';
  @override
  VerificationContext validateIntegrity(Insertable<SectionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('script_id')) {
      context.handle(_scriptIdMeta,
          scriptId.isAcceptableOrUnknown(data['script_id']!, _scriptIdMeta));
    } else if (isInserting) {
      context.missing(_scriptIdMeta);
    }
    if (data.containsKey('ord')) {
      context.handle(
          _ordMeta, ord.isAcceptableOrUnknown(data['ord']!, _ordMeta));
    } else if (isInserting) {
      context.missing(_ordMeta);
    }
    if (data.containsKey('text')) {
      context.handle(
          _bodyMeta, body.isAcceptableOrUnknown(data['text']!, _bodyMeta));
    } else if (isInserting) {
      context.missing(_bodyMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
          _noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('char_count')) {
      context.handle(_charCountMeta,
          charCount.isAcceptableOrUnknown(data['char_count']!, _charCountMeta));
    } else if (isInserting) {
      context.missing(_charCountMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SectionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SectionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      scriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}script_id'])!,
      ord: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ord'])!,
      body: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text'])!,
      note: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}note']),
      charCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}char_count'])!,
    );
  }

  @override
  $SectionsTable createAlias(String alias) {
    return $SectionsTable(attachedDatabase, alias);
  }
}

class SectionRow extends DataClass implements Insertable<SectionRow> {
  final String id;
  final String scriptId;
  final int ord;

  /// Dart 端命名为 body，SQL 列名保持 `text`（避免与 drift 的 text() 构造器同名）。
  final String body;
  final String? note;
  final int charCount;
  const SectionRow(
      {required this.id,
      required this.scriptId,
      required this.ord,
      required this.body,
      this.note,
      required this.charCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['script_id'] = Variable<String>(scriptId);
    map['ord'] = Variable<int>(ord);
    map['text'] = Variable<String>(body);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['char_count'] = Variable<int>(charCount);
    return map;
  }

  SectionsCompanion toCompanion(bool nullToAbsent) {
    return SectionsCompanion(
      id: Value(id),
      scriptId: Value(scriptId),
      ord: Value(ord),
      body: Value(body),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      charCount: Value(charCount),
    );
  }

  factory SectionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SectionRow(
      id: serializer.fromJson<String>(json['id']),
      scriptId: serializer.fromJson<String>(json['scriptId']),
      ord: serializer.fromJson<int>(json['ord']),
      body: serializer.fromJson<String>(json['body']),
      note: serializer.fromJson<String?>(json['note']),
      charCount: serializer.fromJson<int>(json['charCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scriptId': serializer.toJson<String>(scriptId),
      'ord': serializer.toJson<int>(ord),
      'body': serializer.toJson<String>(body),
      'note': serializer.toJson<String?>(note),
      'charCount': serializer.toJson<int>(charCount),
    };
  }

  SectionRow copyWith(
          {String? id,
          String? scriptId,
          int? ord,
          String? body,
          Value<String?> note = const Value.absent(),
          int? charCount}) =>
      SectionRow(
        id: id ?? this.id,
        scriptId: scriptId ?? this.scriptId,
        ord: ord ?? this.ord,
        body: body ?? this.body,
        note: note.present ? note.value : this.note,
        charCount: charCount ?? this.charCount,
      );
  SectionRow copyWithCompanion(SectionsCompanion data) {
    return SectionRow(
      id: data.id.present ? data.id.value : this.id,
      scriptId: data.scriptId.present ? data.scriptId.value : this.scriptId,
      ord: data.ord.present ? data.ord.value : this.ord,
      body: data.body.present ? data.body.value : this.body,
      note: data.note.present ? data.note.value : this.note,
      charCount: data.charCount.present ? data.charCount.value : this.charCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SectionRow(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('ord: $ord, ')
          ..write('body: $body, ')
          ..write('note: $note, ')
          ..write('charCount: $charCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, scriptId, ord, body, note, charCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SectionRow &&
          other.id == this.id &&
          other.scriptId == this.scriptId &&
          other.ord == this.ord &&
          other.body == this.body &&
          other.note == this.note &&
          other.charCount == this.charCount);
}

class SectionsCompanion extends UpdateCompanion<SectionRow> {
  final Value<String> id;
  final Value<String> scriptId;
  final Value<int> ord;
  final Value<String> body;
  final Value<String?> note;
  final Value<int> charCount;
  final Value<int> rowid;
  const SectionsCompanion({
    this.id = const Value.absent(),
    this.scriptId = const Value.absent(),
    this.ord = const Value.absent(),
    this.body = const Value.absent(),
    this.note = const Value.absent(),
    this.charCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SectionsCompanion.insert({
    required String id,
    required String scriptId,
    required int ord,
    required String body,
    this.note = const Value.absent(),
    required int charCount,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        scriptId = Value(scriptId),
        ord = Value(ord),
        body = Value(body),
        charCount = Value(charCount);
  static Insertable<SectionRow> custom({
    Expression<String>? id,
    Expression<String>? scriptId,
    Expression<int>? ord,
    Expression<String>? body,
    Expression<String>? note,
    Expression<int>? charCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scriptId != null) 'script_id': scriptId,
      if (ord != null) 'ord': ord,
      if (body != null) 'text': body,
      if (note != null) 'note': note,
      if (charCount != null) 'char_count': charCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SectionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? scriptId,
      Value<int>? ord,
      Value<String>? body,
      Value<String?>? note,
      Value<int>? charCount,
      Value<int>? rowid}) {
    return SectionsCompanion(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      ord: ord ?? this.ord,
      body: body ?? this.body,
      note: note ?? this.note,
      charCount: charCount ?? this.charCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scriptId.present) {
      map['script_id'] = Variable<String>(scriptId.value);
    }
    if (ord.present) {
      map['ord'] = Variable<int>(ord.value);
    }
    if (body.present) {
      map['text'] = Variable<String>(body.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (charCount.present) {
      map['char_count'] = Variable<int>(charCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SectionsCompanion(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('ord: $ord, ')
          ..write('body: $body, ')
          ..write('note: $note, ')
          ..write('charCount: $charCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MarkersTable extends Markers with TableInfo<$MarkersTable, MarkerRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MarkersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scriptIdMeta =
      const VerificationMeta('scriptId');
  @override
  late final GeneratedColumn<String> scriptId = GeneratedColumn<String>(
      'script_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sectionIdMeta =
      const VerificationMeta('sectionId');
  @override
  late final GeneratedColumn<String> sectionId = GeneratedColumn<String>(
      'section_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _charOffsetMeta =
      const VerificationMeta('charOffset');
  @override
  late final GeneratedColumn<int> charOffset = GeneratedColumn<int>(
      'char_offset', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
      'kind', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
      'label', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
      'color', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, scriptId, sectionId, charOffset, kind, label, color];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'markers';
  @override
  VerificationContext validateIntegrity(Insertable<MarkerRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('script_id')) {
      context.handle(_scriptIdMeta,
          scriptId.isAcceptableOrUnknown(data['script_id']!, _scriptIdMeta));
    } else if (isInserting) {
      context.missing(_scriptIdMeta);
    }
    if (data.containsKey('section_id')) {
      context.handle(_sectionIdMeta,
          sectionId.isAcceptableOrUnknown(data['section_id']!, _sectionIdMeta));
    } else if (isInserting) {
      context.missing(_sectionIdMeta);
    }
    if (data.containsKey('char_offset')) {
      context.handle(
          _charOffsetMeta,
          charOffset.isAcceptableOrUnknown(
              data['char_offset']!, _charOffsetMeta));
    } else if (isInserting) {
      context.missing(_charOffsetMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
          _kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('label')) {
      context.handle(
          _labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('color')) {
      context.handle(
          _colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MarkerRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MarkerRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      scriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}script_id'])!,
      sectionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}section_id'])!,
      charOffset: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}char_offset'])!,
      kind: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      label: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}label']),
      color: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}color']),
    );
  }

  @override
  $MarkersTable createAlias(String alias) {
    return $MarkersTable(attachedDatabase, alias);
  }
}

class MarkerRow extends DataClass implements Insertable<MarkerRow> {
  final String id;
  final String scriptId;
  final String sectionId;
  final int charOffset;
  final String kind;
  final String? label;
  final int? color;
  const MarkerRow(
      {required this.id,
      required this.scriptId,
      required this.sectionId,
      required this.charOffset,
      required this.kind,
      this.label,
      this.color});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['script_id'] = Variable<String>(scriptId);
    map['section_id'] = Variable<String>(sectionId);
    map['char_offset'] = Variable<int>(charOffset);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || label != null) {
      map['label'] = Variable<String>(label);
    }
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    return map;
  }

  MarkersCompanion toCompanion(bool nullToAbsent) {
    return MarkersCompanion(
      id: Value(id),
      scriptId: Value(scriptId),
      sectionId: Value(sectionId),
      charOffset: Value(charOffset),
      kind: Value(kind),
      label:
          label == null && nullToAbsent ? const Value.absent() : Value(label),
      color:
          color == null && nullToAbsent ? const Value.absent() : Value(color),
    );
  }

  factory MarkerRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MarkerRow(
      id: serializer.fromJson<String>(json['id']),
      scriptId: serializer.fromJson<String>(json['scriptId']),
      sectionId: serializer.fromJson<String>(json['sectionId']),
      charOffset: serializer.fromJson<int>(json['charOffset']),
      kind: serializer.fromJson<String>(json['kind']),
      label: serializer.fromJson<String?>(json['label']),
      color: serializer.fromJson<int?>(json['color']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scriptId': serializer.toJson<String>(scriptId),
      'sectionId': serializer.toJson<String>(sectionId),
      'charOffset': serializer.toJson<int>(charOffset),
      'kind': serializer.toJson<String>(kind),
      'label': serializer.toJson<String?>(label),
      'color': serializer.toJson<int?>(color),
    };
  }

  MarkerRow copyWith(
          {String? id,
          String? scriptId,
          String? sectionId,
          int? charOffset,
          String? kind,
          Value<String?> label = const Value.absent(),
          Value<int?> color = const Value.absent()}) =>
      MarkerRow(
        id: id ?? this.id,
        scriptId: scriptId ?? this.scriptId,
        sectionId: sectionId ?? this.sectionId,
        charOffset: charOffset ?? this.charOffset,
        kind: kind ?? this.kind,
        label: label.present ? label.value : this.label,
        color: color.present ? color.value : this.color,
      );
  MarkerRow copyWithCompanion(MarkersCompanion data) {
    return MarkerRow(
      id: data.id.present ? data.id.value : this.id,
      scriptId: data.scriptId.present ? data.scriptId.value : this.scriptId,
      sectionId: data.sectionId.present ? data.sectionId.value : this.sectionId,
      charOffset:
          data.charOffset.present ? data.charOffset.value : this.charOffset,
      kind: data.kind.present ? data.kind.value : this.kind,
      label: data.label.present ? data.label.value : this.label,
      color: data.color.present ? data.color.value : this.color,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MarkerRow(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('sectionId: $sectionId, ')
          ..write('charOffset: $charOffset, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('color: $color')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, scriptId, sectionId, charOffset, kind, label, color);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MarkerRow &&
          other.id == this.id &&
          other.scriptId == this.scriptId &&
          other.sectionId == this.sectionId &&
          other.charOffset == this.charOffset &&
          other.kind == this.kind &&
          other.label == this.label &&
          other.color == this.color);
}

class MarkersCompanion extends UpdateCompanion<MarkerRow> {
  final Value<String> id;
  final Value<String> scriptId;
  final Value<String> sectionId;
  final Value<int> charOffset;
  final Value<String> kind;
  final Value<String?> label;
  final Value<int?> color;
  final Value<int> rowid;
  const MarkersCompanion({
    this.id = const Value.absent(),
    this.scriptId = const Value.absent(),
    this.sectionId = const Value.absent(),
    this.charOffset = const Value.absent(),
    this.kind = const Value.absent(),
    this.label = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MarkersCompanion.insert({
    required String id,
    required String scriptId,
    required String sectionId,
    required int charOffset,
    required String kind,
    this.label = const Value.absent(),
    this.color = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        scriptId = Value(scriptId),
        sectionId = Value(sectionId),
        charOffset = Value(charOffset),
        kind = Value(kind);
  static Insertable<MarkerRow> custom({
    Expression<String>? id,
    Expression<String>? scriptId,
    Expression<String>? sectionId,
    Expression<int>? charOffset,
    Expression<String>? kind,
    Expression<String>? label,
    Expression<int>? color,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scriptId != null) 'script_id': scriptId,
      if (sectionId != null) 'section_id': sectionId,
      if (charOffset != null) 'char_offset': charOffset,
      if (kind != null) 'kind': kind,
      if (label != null) 'label': label,
      if (color != null) 'color': color,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MarkersCompanion copyWith(
      {Value<String>? id,
      Value<String>? scriptId,
      Value<String>? sectionId,
      Value<int>? charOffset,
      Value<String>? kind,
      Value<String?>? label,
      Value<int?>? color,
      Value<int>? rowid}) {
    return MarkersCompanion(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      sectionId: sectionId ?? this.sectionId,
      charOffset: charOffset ?? this.charOffset,
      kind: kind ?? this.kind,
      label: label ?? this.label,
      color: color ?? this.color,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scriptId.present) {
      map['script_id'] = Variable<String>(scriptId.value);
    }
    if (sectionId.present) {
      map['section_id'] = Variable<String>(sectionId.value);
    }
    if (charOffset.present) {
      map['char_offset'] = Variable<int>(charOffset.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MarkersCompanion(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('sectionId: $sectionId, ')
          ..write('charOffset: $charOffset, ')
          ..write('kind: $kind, ')
          ..write('label: $label, ')
          ..write('color: $color, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PresetsTable extends Presets with TableInfo<$PresetsTable, PresetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PresetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _jsonMeta = const VerificationMeta('json');
  @override
  late final GeneratedColumn<String> json = GeneratedColumn<String>(
      'json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isDefaultMeta =
      const VerificationMeta('isDefault');
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
      'is_default', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_default" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, json, isDefault, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'presets';
  @override
  VerificationContext validateIntegrity(Insertable<PresetRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('json')) {
      context.handle(
          _jsonMeta, json.isAcceptableOrUnknown(data['json']!, _jsonMeta));
    } else if (isInserting) {
      context.missing(_jsonMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(_isDefaultMeta,
          isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PresetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PresetRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      json: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json'])!,
      isDefault: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_default'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $PresetsTable createAlias(String alias) {
    return $PresetsTable(attachedDatabase, alias);
  }
}

class PresetRow extends DataClass implements Insertable<PresetRow> {
  final String id;
  final String name;
  final String json;
  final bool isDefault;
  final int updatedAt;
  const PresetRow(
      {required this.id,
      required this.name,
      required this.json,
      required this.isDefault,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['json'] = Variable<String>(json);
    map['is_default'] = Variable<bool>(isDefault);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  PresetsCompanion toCompanion(bool nullToAbsent) {
    return PresetsCompanion(
      id: Value(id),
      name: Value(name),
      json: Value(json),
      isDefault: Value(isDefault),
      updatedAt: Value(updatedAt),
    );
  }

  factory PresetRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PresetRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      json: serializer.fromJson<String>(json['json']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'json': serializer.toJson<String>(json),
      'isDefault': serializer.toJson<bool>(isDefault),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  PresetRow copyWith(
          {String? id,
          String? name,
          String? json,
          bool? isDefault,
          int? updatedAt}) =>
      PresetRow(
        id: id ?? this.id,
        name: name ?? this.name,
        json: json ?? this.json,
        isDefault: isDefault ?? this.isDefault,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  PresetRow copyWithCompanion(PresetsCompanion data) {
    return PresetRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      json: data.json.present ? data.json.value : this.json,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PresetRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('json: $json, ')
          ..write('isDefault: $isDefault, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, json, isDefault, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PresetRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.json == this.json &&
          other.isDefault == this.isDefault &&
          other.updatedAt == this.updatedAt);
}

class PresetsCompanion extends UpdateCompanion<PresetRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> json;
  final Value<bool> isDefault;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const PresetsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.json = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PresetsCompanion.insert({
    required String id,
    required String name,
    required String json,
    this.isDefault = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        json = Value(json),
        updatedAt = Value(updatedAt);
  static Insertable<PresetRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? json,
    Expression<bool>? isDefault,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (json != null) 'json': json,
      if (isDefault != null) 'is_default': isDefault,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PresetsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String>? json,
      Value<bool>? isDefault,
      Value<int>? updatedAt,
      Value<int>? rowid}) {
    return PresetsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      json: json ?? this.json,
      isDefault: isDefault ?? this.isDefault,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (json.present) {
      map['json'] = Variable<String>(json.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PresetsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('json: $json, ')
          ..write('isDefault: $isDefault, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SessionsTable extends Sessions
    with TableInfo<$SessionsTable, SessionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scriptIdMeta =
      const VerificationMeta('scriptId');
  @override
  late final GeneratedColumn<String> scriptId = GeneratedColumn<String>(
      'script_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _startedAtMeta =
      const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<int> startedAt = GeneratedColumn<int>(
      'started_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _endedAtMeta =
      const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<int> endedAt = GeneratedColumn<int>(
      'ended_at', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _anchorMeta = const VerificationMeta('anchor');
  @override
  late final GeneratedColumn<int> anchor = GeneratedColumn<int>(
      'anchor', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _statsJsonMeta =
      const VerificationMeta('statsJson');
  @override
  late final GeneratedColumn<String> statsJson = GeneratedColumn<String>(
      'stats_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _settingsJsonMeta =
      const VerificationMeta('settingsJson');
  @override
  late final GeneratedColumn<String> settingsJson = GeneratedColumn<String>(
      'settings_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, scriptId, startedAt, endedAt, anchor, statsJson, settingsJson];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(Insertable<SessionRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('script_id')) {
      context.handle(_scriptIdMeta,
          scriptId.isAcceptableOrUnknown(data['script_id']!, _scriptIdMeta));
    } else if (isInserting) {
      context.missing(_scriptIdMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta,
          startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta,
          endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    }
    if (data.containsKey('anchor')) {
      context.handle(_anchorMeta,
          anchor.isAcceptableOrUnknown(data['anchor']!, _anchorMeta));
    }
    if (data.containsKey('stats_json')) {
      context.handle(_statsJsonMeta,
          statsJson.isAcceptableOrUnknown(data['stats_json']!, _statsJsonMeta));
    }
    if (data.containsKey('settings_json')) {
      context.handle(
          _settingsJsonMeta,
          settingsJson.isAcceptableOrUnknown(
              data['settings_json']!, _settingsJsonMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      scriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}script_id'])!,
      startedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ended_at']),
      anchor: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}anchor']),
      statsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}stats_json']),
      settingsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}settings_json']),
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class SessionRow extends DataClass implements Insertable<SessionRow> {
  final String id;
  final String scriptId;
  final int startedAt;
  final int? endedAt;
  final int? anchor;
  final String? statsJson;
  final String? settingsJson;
  const SessionRow(
      {required this.id,
      required this.scriptId,
      required this.startedAt,
      this.endedAt,
      this.anchor,
      this.statsJson,
      this.settingsJson});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['script_id'] = Variable<String>(scriptId);
    map['started_at'] = Variable<int>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<int>(endedAt);
    }
    if (!nullToAbsent || anchor != null) {
      map['anchor'] = Variable<int>(anchor);
    }
    if (!nullToAbsent || statsJson != null) {
      map['stats_json'] = Variable<String>(statsJson);
    }
    if (!nullToAbsent || settingsJson != null) {
      map['settings_json'] = Variable<String>(settingsJson);
    }
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      scriptId: Value(scriptId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      anchor:
          anchor == null && nullToAbsent ? const Value.absent() : Value(anchor),
      statsJson: statsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(statsJson),
      settingsJson: settingsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(settingsJson),
    );
  }

  factory SessionRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionRow(
      id: serializer.fromJson<String>(json['id']),
      scriptId: serializer.fromJson<String>(json['scriptId']),
      startedAt: serializer.fromJson<int>(json['startedAt']),
      endedAt: serializer.fromJson<int?>(json['endedAt']),
      anchor: serializer.fromJson<int?>(json['anchor']),
      statsJson: serializer.fromJson<String?>(json['statsJson']),
      settingsJson: serializer.fromJson<String?>(json['settingsJson']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scriptId': serializer.toJson<String>(scriptId),
      'startedAt': serializer.toJson<int>(startedAt),
      'endedAt': serializer.toJson<int?>(endedAt),
      'anchor': serializer.toJson<int?>(anchor),
      'statsJson': serializer.toJson<String?>(statsJson),
      'settingsJson': serializer.toJson<String?>(settingsJson),
    };
  }

  SessionRow copyWith(
          {String? id,
          String? scriptId,
          int? startedAt,
          Value<int?> endedAt = const Value.absent(),
          Value<int?> anchor = const Value.absent(),
          Value<String?> statsJson = const Value.absent(),
          Value<String?> settingsJson = const Value.absent()}) =>
      SessionRow(
        id: id ?? this.id,
        scriptId: scriptId ?? this.scriptId,
        startedAt: startedAt ?? this.startedAt,
        endedAt: endedAt.present ? endedAt.value : this.endedAt,
        anchor: anchor.present ? anchor.value : this.anchor,
        statsJson: statsJson.present ? statsJson.value : this.statsJson,
        settingsJson:
            settingsJson.present ? settingsJson.value : this.settingsJson,
      );
  SessionRow copyWithCompanion(SessionsCompanion data) {
    return SessionRow(
      id: data.id.present ? data.id.value : this.id,
      scriptId: data.scriptId.present ? data.scriptId.value : this.scriptId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      anchor: data.anchor.present ? data.anchor.value : this.anchor,
      statsJson: data.statsJson.present ? data.statsJson.value : this.statsJson,
      settingsJson: data.settingsJson.present
          ? data.settingsJson.value
          : this.settingsJson,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionRow(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('anchor: $anchor, ')
          ..write('statsJson: $statsJson, ')
          ..write('settingsJson: $settingsJson')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, scriptId, startedAt, endedAt, anchor, statsJson, settingsJson);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionRow &&
          other.id == this.id &&
          other.scriptId == this.scriptId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.anchor == this.anchor &&
          other.statsJson == this.statsJson &&
          other.settingsJson == this.settingsJson);
}

class SessionsCompanion extends UpdateCompanion<SessionRow> {
  final Value<String> id;
  final Value<String> scriptId;
  final Value<int> startedAt;
  final Value<int?> endedAt;
  final Value<int?> anchor;
  final Value<String?> statsJson;
  final Value<String?> settingsJson;
  final Value<int> rowid;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.scriptId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.anchor = const Value.absent(),
    this.statsJson = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SessionsCompanion.insert({
    required String id,
    required String scriptId,
    required int startedAt,
    this.endedAt = const Value.absent(),
    this.anchor = const Value.absent(),
    this.statsJson = const Value.absent(),
    this.settingsJson = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        scriptId = Value(scriptId),
        startedAt = Value(startedAt);
  static Insertable<SessionRow> custom({
    Expression<String>? id,
    Expression<String>? scriptId,
    Expression<int>? startedAt,
    Expression<int>? endedAt,
    Expression<int>? anchor,
    Expression<String>? statsJson,
    Expression<String>? settingsJson,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scriptId != null) 'script_id': scriptId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (anchor != null) 'anchor': anchor,
      if (statsJson != null) 'stats_json': statsJson,
      if (settingsJson != null) 'settings_json': settingsJson,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SessionsCompanion copyWith(
      {Value<String>? id,
      Value<String>? scriptId,
      Value<int>? startedAt,
      Value<int?>? endedAt,
      Value<int?>? anchor,
      Value<String?>? statsJson,
      Value<String?>? settingsJson,
      Value<int>? rowid}) {
    return SessionsCompanion(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      anchor: anchor ?? this.anchor,
      statsJson: statsJson ?? this.statsJson,
      settingsJson: settingsJson ?? this.settingsJson,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scriptId.present) {
      map['script_id'] = Variable<String>(scriptId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<int>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<int>(endedAt.value);
    }
    if (anchor.present) {
      map['anchor'] = Variable<int>(anchor.value);
    }
    if (statsJson.present) {
      map['stats_json'] = Variable<String>(statsJson.value);
    }
    if (settingsJson.present) {
      map['settings_json'] = Variable<String>(settingsJson.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('anchor: $anchor, ')
          ..write('statsJson: $statsJson, ')
          ..write('settingsJson: $settingsJson, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecordingsTable extends Recordings
    with TableInfo<$RecordingsTable, RecordingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecordingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _scriptIdMeta =
      const VerificationMeta('scriptId');
  @override
  late final GeneratedColumn<String> scriptId = GeneratedColumn<String>(
      'script_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sessionIdMeta =
      const VerificationMeta('sessionId');
  @override
  late final GeneratedColumn<String> sessionId = GeneratedColumn<String>(
      'session_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
      'path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durMsMeta = const VerificationMeta('durMs');
  @override
  late final GeneratedColumn<int> durMs = GeneratedColumn<int>(
      'dur_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _timelineJsonMeta =
      const VerificationMeta('timelineJson');
  @override
  late final GeneratedColumn<String> timelineJson = GeneratedColumn<String>(
      'timeline_json', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
      'created_at', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        scriptId,
        sessionId,
        path,
        durMs,
        timelineJson,
        createdAt,
        sizeBytes
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recordings';
  @override
  VerificationContext validateIntegrity(Insertable<RecordingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('script_id')) {
      context.handle(_scriptIdMeta,
          scriptId.isAcceptableOrUnknown(data['script_id']!, _scriptIdMeta));
    } else if (isInserting) {
      context.missing(_scriptIdMeta);
    }
    if (data.containsKey('session_id')) {
      context.handle(_sessionIdMeta,
          sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta));
    }
    if (data.containsKey('path')) {
      context.handle(
          _pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('dur_ms')) {
      context.handle(
          _durMsMeta, durMs.isAcceptableOrUnknown(data['dur_ms']!, _durMsMeta));
    } else if (isInserting) {
      context.missing(_durMsMeta);
    }
    if (data.containsKey('timeline_json')) {
      context.handle(
          _timelineJsonMeta,
          timelineJson.isAcceptableOrUnknown(
              data['timeline_json']!, _timelineJsonMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecordingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecordingRow(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      scriptId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}script_id'])!,
      sessionId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}session_id']),
      path: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      durMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}dur_ms'])!,
      timelineJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}timeline_json']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}created_at'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
    );
  }

  @override
  $RecordingsTable createAlias(String alias) {
    return $RecordingsTable(attachedDatabase, alias);
  }
}

class RecordingRow extends DataClass implements Insertable<RecordingRow> {
  final String id;
  final String scriptId;
  final String? sessionId;
  final String path;
  final int durMs;
  final String? timelineJson;
  final int createdAt;
  final int sizeBytes;
  const RecordingRow(
      {required this.id,
      required this.scriptId,
      this.sessionId,
      required this.path,
      required this.durMs,
      this.timelineJson,
      required this.createdAt,
      required this.sizeBytes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['script_id'] = Variable<String>(scriptId);
    if (!nullToAbsent || sessionId != null) {
      map['session_id'] = Variable<String>(sessionId);
    }
    map['path'] = Variable<String>(path);
    map['dur_ms'] = Variable<int>(durMs);
    if (!nullToAbsent || timelineJson != null) {
      map['timeline_json'] = Variable<String>(timelineJson);
    }
    map['created_at'] = Variable<int>(createdAt);
    map['size_bytes'] = Variable<int>(sizeBytes);
    return map;
  }

  RecordingsCompanion toCompanion(bool nullToAbsent) {
    return RecordingsCompanion(
      id: Value(id),
      scriptId: Value(scriptId),
      sessionId: sessionId == null && nullToAbsent
          ? const Value.absent()
          : Value(sessionId),
      path: Value(path),
      durMs: Value(durMs),
      timelineJson: timelineJson == null && nullToAbsent
          ? const Value.absent()
          : Value(timelineJson),
      createdAt: Value(createdAt),
      sizeBytes: Value(sizeBytes),
    );
  }

  factory RecordingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecordingRow(
      id: serializer.fromJson<String>(json['id']),
      scriptId: serializer.fromJson<String>(json['scriptId']),
      sessionId: serializer.fromJson<String?>(json['sessionId']),
      path: serializer.fromJson<String>(json['path']),
      durMs: serializer.fromJson<int>(json['durMs']),
      timelineJson: serializer.fromJson<String?>(json['timelineJson']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'scriptId': serializer.toJson<String>(scriptId),
      'sessionId': serializer.toJson<String?>(sessionId),
      'path': serializer.toJson<String>(path),
      'durMs': serializer.toJson<int>(durMs),
      'timelineJson': serializer.toJson<String?>(timelineJson),
      'createdAt': serializer.toJson<int>(createdAt),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
    };
  }

  RecordingRow copyWith(
          {String? id,
          String? scriptId,
          Value<String?> sessionId = const Value.absent(),
          String? path,
          int? durMs,
          Value<String?> timelineJson = const Value.absent(),
          int? createdAt,
          int? sizeBytes}) =>
      RecordingRow(
        id: id ?? this.id,
        scriptId: scriptId ?? this.scriptId,
        sessionId: sessionId.present ? sessionId.value : this.sessionId,
        path: path ?? this.path,
        durMs: durMs ?? this.durMs,
        timelineJson:
            timelineJson.present ? timelineJson.value : this.timelineJson,
        createdAt: createdAt ?? this.createdAt,
        sizeBytes: sizeBytes ?? this.sizeBytes,
      );
  RecordingRow copyWithCompanion(RecordingsCompanion data) {
    return RecordingRow(
      id: data.id.present ? data.id.value : this.id,
      scriptId: data.scriptId.present ? data.scriptId.value : this.scriptId,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      path: data.path.present ? data.path.value : this.path,
      durMs: data.durMs.present ? data.durMs.value : this.durMs,
      timelineJson: data.timelineJson.present
          ? data.timelineJson.value
          : this.timelineJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecordingRow(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('sessionId: $sessionId, ')
          ..write('path: $path, ')
          ..write('durMs: $durMs, ')
          ..write('timelineJson: $timelineJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('sizeBytes: $sizeBytes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, scriptId, sessionId, path, durMs, timelineJson, createdAt, sizeBytes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecordingRow &&
          other.id == this.id &&
          other.scriptId == this.scriptId &&
          other.sessionId == this.sessionId &&
          other.path == this.path &&
          other.durMs == this.durMs &&
          other.timelineJson == this.timelineJson &&
          other.createdAt == this.createdAt &&
          other.sizeBytes == this.sizeBytes);
}

class RecordingsCompanion extends UpdateCompanion<RecordingRow> {
  final Value<String> id;
  final Value<String> scriptId;
  final Value<String?> sessionId;
  final Value<String> path;
  final Value<int> durMs;
  final Value<String?> timelineJson;
  final Value<int> createdAt;
  final Value<int> sizeBytes;
  final Value<int> rowid;
  const RecordingsCompanion({
    this.id = const Value.absent(),
    this.scriptId = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.path = const Value.absent(),
    this.durMs = const Value.absent(),
    this.timelineJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecordingsCompanion.insert({
    required String id,
    required String scriptId,
    this.sessionId = const Value.absent(),
    required String path,
    required int durMs,
    this.timelineJson = const Value.absent(),
    required int createdAt,
    required int sizeBytes,
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        scriptId = Value(scriptId),
        path = Value(path),
        durMs = Value(durMs),
        createdAt = Value(createdAt),
        sizeBytes = Value(sizeBytes);
  static Insertable<RecordingRow> custom({
    Expression<String>? id,
    Expression<String>? scriptId,
    Expression<String>? sessionId,
    Expression<String>? path,
    Expression<int>? durMs,
    Expression<String>? timelineJson,
    Expression<int>? createdAt,
    Expression<int>? sizeBytes,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (scriptId != null) 'script_id': scriptId,
      if (sessionId != null) 'session_id': sessionId,
      if (path != null) 'path': path,
      if (durMs != null) 'dur_ms': durMs,
      if (timelineJson != null) 'timeline_json': timelineJson,
      if (createdAt != null) 'created_at': createdAt,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecordingsCompanion copyWith(
      {Value<String>? id,
      Value<String>? scriptId,
      Value<String?>? sessionId,
      Value<String>? path,
      Value<int>? durMs,
      Value<String?>? timelineJson,
      Value<int>? createdAt,
      Value<int>? sizeBytes,
      Value<int>? rowid}) {
    return RecordingsCompanion(
      id: id ?? this.id,
      scriptId: scriptId ?? this.scriptId,
      sessionId: sessionId ?? this.sessionId,
      path: path ?? this.path,
      durMs: durMs ?? this.durMs,
      timelineJson: timelineJson ?? this.timelineJson,
      createdAt: createdAt ?? this.createdAt,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (scriptId.present) {
      map['script_id'] = Variable<String>(scriptId.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<String>(sessionId.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (durMs.present) {
      map['dur_ms'] = Variable<int>(durMs.value);
    }
    if (timelineJson.present) {
      map['timeline_json'] = Variable<String>(timelineJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecordingsCompanion(')
          ..write('id: $id, ')
          ..write('scriptId: $scriptId, ')
          ..write('sessionId: $sessionId, ')
          ..write('path: $path, ')
          ..write('durMs: $durMs, ')
          ..write('timelineJson: $timelineJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTable extends AppSettings
    with TableInfo<$AppSettingsTable, SettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(Insertable<SettingRow> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingRow(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $AppSettingsTable createAlias(String alias) {
    return $AppSettingsTable(attachedDatabase, alias);
  }
}

class SettingRow extends DataClass implements Insertable<SettingRow> {
  final String key;
  final String value;
  const SettingRow({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  AppSettingsCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory SettingRow.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingRow(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  SettingRow copyWith({String? key, String? value}) => SettingRow(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  SettingRow copyWithCompanion(AppSettingsCompanion data) {
    return SettingRow(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingRow(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SettingRow &&
          other.key == this.key &&
          other.value == this.value);
}

class AppSettingsCompanion extends UpdateCompanion<SettingRow> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const AppSettingsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppSettingsCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<SettingRow> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppSettingsCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return AppSettingsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ScriptsTable scripts = $ScriptsTable(this);
  late final $SectionsTable sections = $SectionsTable(this);
  late final $MarkersTable markers = $MarkersTable(this);
  late final $PresetsTable presets = $PresetsTable(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $RecordingsTable recordings = $RecordingsTable(this);
  late final $AppSettingsTable appSettings = $AppSettingsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [scripts, sections, markers, presets, sessions, recordings, appSettings];
}

typedef $$ScriptsTableCreateCompanionBuilder = ScriptsCompanion Function({
  required String id,
  required String title,
  required String rawText,
  Value<String> lang,
  Value<String?> folderId,
  Value<String?> tags,
  Value<bool> favorite,
  Value<bool> archived,
  Value<int?> deletedAt,
  required int createdAt,
  required int updatedAt,
  Value<int?> lastViewedAt,
  Value<int> rowid,
});
typedef $$ScriptsTableUpdateCompanionBuilder = ScriptsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<String> rawText,
  Value<String> lang,
  Value<String?> folderId,
  Value<String?> tags,
  Value<bool> favorite,
  Value<bool> archived,
  Value<int?> deletedAt,
  Value<int> createdAt,
  Value<int> updatedAt,
  Value<int?> lastViewedAt,
  Value<int> rowid,
});

class $$ScriptsTableFilterComposer
    extends Composer<_$AppDatabase, $ScriptsTable> {
  $$ScriptsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lang => $composableBuilder(
      column: $table.lang, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get folderId => $composableBuilder(
      column: $table.folderId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastViewedAt => $composableBuilder(
      column: $table.lastViewedAt, builder: (column) => ColumnFilters(column));
}

class $$ScriptsTableOrderingComposer
    extends Composer<_$AppDatabase, $ScriptsTable> {
  $$ScriptsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rawText => $composableBuilder(
      column: $table.rawText, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lang => $composableBuilder(
      column: $table.lang, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get folderId => $composableBuilder(
      column: $table.folderId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get tags => $composableBuilder(
      column: $table.tags, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get favorite => $composableBuilder(
      column: $table.favorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get archived => $composableBuilder(
      column: $table.archived, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get deletedAt => $composableBuilder(
      column: $table.deletedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastViewedAt => $composableBuilder(
      column: $table.lastViewedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$ScriptsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ScriptsTable> {
  $$ScriptsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get rawText =>
      $composableBuilder(column: $table.rawText, builder: (column) => column);

  GeneratedColumn<String> get lang =>
      $composableBuilder(column: $table.lang, builder: (column) => column);

  GeneratedColumn<String> get folderId =>
      $composableBuilder(column: $table.folderId, builder: (column) => column);

  GeneratedColumn<String> get tags =>
      $composableBuilder(column: $table.tags, builder: (column) => column);

  GeneratedColumn<bool> get favorite =>
      $composableBuilder(column: $table.favorite, builder: (column) => column);

  GeneratedColumn<bool> get archived =>
      $composableBuilder(column: $table.archived, builder: (column) => column);

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<int> get lastViewedAt => $composableBuilder(
      column: $table.lastViewedAt, builder: (column) => column);
}

class $$ScriptsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ScriptsTable,
    ScriptRow,
    $$ScriptsTableFilterComposer,
    $$ScriptsTableOrderingComposer,
    $$ScriptsTableAnnotationComposer,
    $$ScriptsTableCreateCompanionBuilder,
    $$ScriptsTableUpdateCompanionBuilder,
    (ScriptRow, BaseReferences<_$AppDatabase, $ScriptsTable, ScriptRow>),
    ScriptRow,
    PrefetchHooks Function()> {
  $$ScriptsTableTableManager(_$AppDatabase db, $ScriptsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ScriptsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ScriptsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ScriptsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String> rawText = const Value.absent(),
            Value<String> lang = const Value.absent(),
            Value<String?> folderId = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int?> lastViewedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScriptsCompanion(
            id: id,
            title: title,
            rawText: rawText,
            lang: lang,
            folderId: folderId,
            tags: tags,
            favorite: favorite,
            archived: archived,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastViewedAt: lastViewedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            required String rawText,
            Value<String> lang = const Value.absent(),
            Value<String?> folderId = const Value.absent(),
            Value<String?> tags = const Value.absent(),
            Value<bool> favorite = const Value.absent(),
            Value<bool> archived = const Value.absent(),
            Value<int?> deletedAt = const Value.absent(),
            required int createdAt,
            required int updatedAt,
            Value<int?> lastViewedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ScriptsCompanion.insert(
            id: id,
            title: title,
            rawText: rawText,
            lang: lang,
            folderId: folderId,
            tags: tags,
            favorite: favorite,
            archived: archived,
            deletedAt: deletedAt,
            createdAt: createdAt,
            updatedAt: updatedAt,
            lastViewedAt: lastViewedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$ScriptsTable, ScriptRow>(table),
                    BaseReferences<_$AppDatabase, $ScriptsTable, ScriptRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ScriptsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ScriptsTable,
    ScriptRow,
    $$ScriptsTableFilterComposer,
    $$ScriptsTableOrderingComposer,
    $$ScriptsTableAnnotationComposer,
    $$ScriptsTableCreateCompanionBuilder,
    $$ScriptsTableUpdateCompanionBuilder,
    (ScriptRow, BaseReferences<_$AppDatabase, $ScriptsTable, ScriptRow>),
    ScriptRow,
    PrefetchHooks Function()>;
typedef $$SectionsTableCreateCompanionBuilder = SectionsCompanion Function({
  required String id,
  required String scriptId,
  required int ord,
  required String body,
  Value<String?> note,
  required int charCount,
  Value<int> rowid,
});
typedef $$SectionsTableUpdateCompanionBuilder = SectionsCompanion Function({
  Value<String> id,
  Value<String> scriptId,
  Value<int> ord,
  Value<String> body,
  Value<String?> note,
  Value<int> charCount,
  Value<int> rowid,
});

class $$SectionsTableFilterComposer
    extends Composer<_$AppDatabase, $SectionsTable> {
  $$SectionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ord => $composableBuilder(
      column: $table.ord, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get charCount => $composableBuilder(
      column: $table.charCount, builder: (column) => ColumnFilters(column));
}

class $$SectionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SectionsTable> {
  $$SectionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ord => $composableBuilder(
      column: $table.ord, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get body => $composableBuilder(
      column: $table.body, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note => $composableBuilder(
      column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get charCount => $composableBuilder(
      column: $table.charCount, builder: (column) => ColumnOrderings(column));
}

class $$SectionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SectionsTable> {
  $$SectionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scriptId =>
      $composableBuilder(column: $table.scriptId, builder: (column) => column);

  GeneratedColumn<int> get ord =>
      $composableBuilder(column: $table.ord, builder: (column) => column);

  GeneratedColumn<String> get body =>
      $composableBuilder(column: $table.body, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<int> get charCount =>
      $composableBuilder(column: $table.charCount, builder: (column) => column);
}

class $$SectionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SectionsTable,
    SectionRow,
    $$SectionsTableFilterComposer,
    $$SectionsTableOrderingComposer,
    $$SectionsTableAnnotationComposer,
    $$SectionsTableCreateCompanionBuilder,
    $$SectionsTableUpdateCompanionBuilder,
    (SectionRow, BaseReferences<_$AppDatabase, $SectionsTable, SectionRow>),
    SectionRow,
    PrefetchHooks Function()> {
  $$SectionsTableTableManager(_$AppDatabase db, $SectionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SectionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SectionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SectionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> scriptId = const Value.absent(),
            Value<int> ord = const Value.absent(),
            Value<String> body = const Value.absent(),
            Value<String?> note = const Value.absent(),
            Value<int> charCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SectionsCompanion(
            id: id,
            scriptId: scriptId,
            ord: ord,
            body: body,
            note: note,
            charCount: charCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String scriptId,
            required int ord,
            required String body,
            Value<String?> note = const Value.absent(),
            required int charCount,
            Value<int> rowid = const Value.absent(),
          }) =>
              SectionsCompanion.insert(
            id: id,
            scriptId: scriptId,
            ord: ord,
            body: body,
            note: note,
            charCount: charCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SectionsTable, SectionRow>(table),
                    BaseReferences<_$AppDatabase, $SectionsTable, SectionRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SectionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SectionsTable,
    SectionRow,
    $$SectionsTableFilterComposer,
    $$SectionsTableOrderingComposer,
    $$SectionsTableAnnotationComposer,
    $$SectionsTableCreateCompanionBuilder,
    $$SectionsTableUpdateCompanionBuilder,
    (SectionRow, BaseReferences<_$AppDatabase, $SectionsTable, SectionRow>),
    SectionRow,
    PrefetchHooks Function()>;
typedef $$MarkersTableCreateCompanionBuilder = MarkersCompanion Function({
  required String id,
  required String scriptId,
  required String sectionId,
  required int charOffset,
  required String kind,
  Value<String?> label,
  Value<int?> color,
  Value<int> rowid,
});
typedef $$MarkersTableUpdateCompanionBuilder = MarkersCompanion Function({
  Value<String> id,
  Value<String> scriptId,
  Value<String> sectionId,
  Value<int> charOffset,
  Value<String> kind,
  Value<String?> label,
  Value<int?> color,
  Value<int> rowid,
});

class $$MarkersTableFilterComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sectionId => $composableBuilder(
      column: $table.sectionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnFilters(column));
}

class $$MarkersTableOrderingComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sectionId => $composableBuilder(
      column: $table.sectionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind => $composableBuilder(
      column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label => $composableBuilder(
      column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color => $composableBuilder(
      column: $table.color, builder: (column) => ColumnOrderings(column));
}

class $$MarkersTableAnnotationComposer
    extends Composer<_$AppDatabase, $MarkersTable> {
  $$MarkersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scriptId =>
      $composableBuilder(column: $table.scriptId, builder: (column) => column);

  GeneratedColumn<String> get sectionId =>
      $composableBuilder(column: $table.sectionId, builder: (column) => column);

  GeneratedColumn<int> get charOffset => $composableBuilder(
      column: $table.charOffset, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => column);
}

class $$MarkersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MarkersTable,
    MarkerRow,
    $$MarkersTableFilterComposer,
    $$MarkersTableOrderingComposer,
    $$MarkersTableAnnotationComposer,
    $$MarkersTableCreateCompanionBuilder,
    $$MarkersTableUpdateCompanionBuilder,
    (MarkerRow, BaseReferences<_$AppDatabase, $MarkersTable, MarkerRow>),
    MarkerRow,
    PrefetchHooks Function()> {
  $$MarkersTableTableManager(_$AppDatabase db, $MarkersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MarkersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MarkersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MarkersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> scriptId = const Value.absent(),
            Value<String> sectionId = const Value.absent(),
            Value<int> charOffset = const Value.absent(),
            Value<String> kind = const Value.absent(),
            Value<String?> label = const Value.absent(),
            Value<int?> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MarkersCompanion(
            id: id,
            scriptId: scriptId,
            sectionId: sectionId,
            charOffset: charOffset,
            kind: kind,
            label: label,
            color: color,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String scriptId,
            required String sectionId,
            required int charOffset,
            required String kind,
            Value<String?> label = const Value.absent(),
            Value<int?> color = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MarkersCompanion.insert(
            id: id,
            scriptId: scriptId,
            sectionId: sectionId,
            charOffset: charOffset,
            kind: kind,
            label: label,
            color: color,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$MarkersTable, MarkerRow>(table),
                    BaseReferences<_$AppDatabase, $MarkersTable, MarkerRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MarkersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MarkersTable,
    MarkerRow,
    $$MarkersTableFilterComposer,
    $$MarkersTableOrderingComposer,
    $$MarkersTableAnnotationComposer,
    $$MarkersTableCreateCompanionBuilder,
    $$MarkersTableUpdateCompanionBuilder,
    (MarkerRow, BaseReferences<_$AppDatabase, $MarkersTable, MarkerRow>),
    MarkerRow,
    PrefetchHooks Function()>;
typedef $$PresetsTableCreateCompanionBuilder = PresetsCompanion Function({
  required String id,
  required String name,
  required String json,
  Value<bool> isDefault,
  required int updatedAt,
  Value<int> rowid,
});
typedef $$PresetsTableUpdateCompanionBuilder = PresetsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> json,
  Value<bool> isDefault,
  Value<int> updatedAt,
  Value<int> rowid,
});

class $$PresetsTableFilterComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$PresetsTableOrderingComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get json => $composableBuilder(
      column: $table.json, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDefault => $composableBuilder(
      column: $table.isDefault, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$PresetsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PresetsTable> {
  $$PresetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get json =>
      $composableBuilder(column: $table.json, builder: (column) => column);

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PresetsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PresetsTable,
    PresetRow,
    $$PresetsTableFilterComposer,
    $$PresetsTableOrderingComposer,
    $$PresetsTableAnnotationComposer,
    $$PresetsTableCreateCompanionBuilder,
    $$PresetsTableUpdateCompanionBuilder,
    (PresetRow, BaseReferences<_$AppDatabase, $PresetsTable, PresetRow>),
    PresetRow,
    PrefetchHooks Function()> {
  $$PresetsTableTableManager(_$AppDatabase db, $PresetsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PresetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PresetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PresetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> json = const Value.absent(),
            Value<bool> isDefault = const Value.absent(),
            Value<int> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              PresetsCompanion(
            id: id,
            name: name,
            json: json,
            isDefault: isDefault,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            required String json,
            Value<bool> isDefault = const Value.absent(),
            required int updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              PresetsCompanion.insert(
            id: id,
            name: name,
            json: json,
            isDefault: isDefault,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$PresetsTable, PresetRow>(table),
                    BaseReferences<_$AppDatabase, $PresetsTable, PresetRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PresetsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PresetsTable,
    PresetRow,
    $$PresetsTableFilterComposer,
    $$PresetsTableOrderingComposer,
    $$PresetsTableAnnotationComposer,
    $$PresetsTableCreateCompanionBuilder,
    $$PresetsTableUpdateCompanionBuilder,
    (PresetRow, BaseReferences<_$AppDatabase, $PresetsTable, PresetRow>),
    PresetRow,
    PrefetchHooks Function()>;
typedef $$SessionsTableCreateCompanionBuilder = SessionsCompanion Function({
  required String id,
  required String scriptId,
  required int startedAt,
  Value<int?> endedAt,
  Value<int?> anchor,
  Value<String?> statsJson,
  Value<String?> settingsJson,
  Value<int> rowid,
});
typedef $$SessionsTableUpdateCompanionBuilder = SessionsCompanion Function({
  Value<String> id,
  Value<String> scriptId,
  Value<int> startedAt,
  Value<int?> endedAt,
  Value<int?> anchor,
  Value<String?> statsJson,
  Value<String?> settingsJson,
  Value<int> rowid,
});

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get anchor => $composableBuilder(
      column: $table.anchor, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get statsJson => $composableBuilder(
      column: $table.statsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson, builder: (column) => ColumnFilters(column));
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get startedAt => $composableBuilder(
      column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get endedAt => $composableBuilder(
      column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get anchor => $composableBuilder(
      column: $table.anchor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get statsJson => $composableBuilder(
      column: $table.statsJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson,
      builder: (column) => ColumnOrderings(column));
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scriptId =>
      $composableBuilder(column: $table.scriptId, builder: (column) => column);

  GeneratedColumn<int> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<int> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get anchor =>
      $composableBuilder(column: $table.anchor, builder: (column) => column);

  GeneratedColumn<String> get statsJson =>
      $composableBuilder(column: $table.statsJson, builder: (column) => column);

  GeneratedColumn<String> get settingsJson => $composableBuilder(
      column: $table.settingsJson, builder: (column) => column);
}

class $$SessionsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SessionsTable,
    SessionRow,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
    SessionRow,
    PrefetchHooks Function()> {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> scriptId = const Value.absent(),
            Value<int> startedAt = const Value.absent(),
            Value<int?> endedAt = const Value.absent(),
            Value<int?> anchor = const Value.absent(),
            Value<String?> statsJson = const Value.absent(),
            Value<String?> settingsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion(
            id: id,
            scriptId: scriptId,
            startedAt: startedAt,
            endedAt: endedAt,
            anchor: anchor,
            statsJson: statsJson,
            settingsJson: settingsJson,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String scriptId,
            required int startedAt,
            Value<int?> endedAt = const Value.absent(),
            Value<int?> anchor = const Value.absent(),
            Value<String?> statsJson = const Value.absent(),
            Value<String?> settingsJson = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              SessionsCompanion.insert(
            id: id,
            scriptId: scriptId,
            startedAt: startedAt,
            endedAt: endedAt,
            anchor: anchor,
            statsJson: statsJson,
            settingsJson: settingsJson,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$SessionsTable, SessionRow>(table),
                    BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>(
                        db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SessionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SessionsTable,
    SessionRow,
    $$SessionsTableFilterComposer,
    $$SessionsTableOrderingComposer,
    $$SessionsTableAnnotationComposer,
    $$SessionsTableCreateCompanionBuilder,
    $$SessionsTableUpdateCompanionBuilder,
    (SessionRow, BaseReferences<_$AppDatabase, $SessionsTable, SessionRow>),
    SessionRow,
    PrefetchHooks Function()>;
typedef $$RecordingsTableCreateCompanionBuilder = RecordingsCompanion Function({
  required String id,
  required String scriptId,
  Value<String?> sessionId,
  required String path,
  required int durMs,
  Value<String?> timelineJson,
  required int createdAt,
  required int sizeBytes,
  Value<int> rowid,
});
typedef $$RecordingsTableUpdateCompanionBuilder = RecordingsCompanion Function({
  Value<String> id,
  Value<String> scriptId,
  Value<String?> sessionId,
  Value<String> path,
  Value<int> durMs,
  Value<String?> timelineJson,
  Value<int> createdAt,
  Value<int> sizeBytes,
  Value<int> rowid,
});

class $$RecordingsTableFilterComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durMs => $composableBuilder(
      column: $table.durMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get timelineJson => $composableBuilder(
      column: $table.timelineJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));
}

class $$RecordingsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get scriptId => $composableBuilder(
      column: $table.scriptId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get sessionId => $composableBuilder(
      column: $table.sessionId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path => $composableBuilder(
      column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durMs => $composableBuilder(
      column: $table.durMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get timelineJson => $composableBuilder(
      column: $table.timelineJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));
}

class $$RecordingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecordingsTable> {
  $$RecordingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scriptId =>
      $composableBuilder(column: $table.scriptId, builder: (column) => column);

  GeneratedColumn<String> get sessionId =>
      $composableBuilder(column: $table.sessionId, builder: (column) => column);

  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get durMs =>
      $composableBuilder(column: $table.durMs, builder: (column) => column);

  GeneratedColumn<String> get timelineJson => $composableBuilder(
      column: $table.timelineJson, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);
}

class $$RecordingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RecordingsTable,
    RecordingRow,
    $$RecordingsTableFilterComposer,
    $$RecordingsTableOrderingComposer,
    $$RecordingsTableAnnotationComposer,
    $$RecordingsTableCreateCompanionBuilder,
    $$RecordingsTableUpdateCompanionBuilder,
    (
      RecordingRow,
      BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>
    ),
    RecordingRow,
    PrefetchHooks Function()> {
  $$RecordingsTableTableManager(_$AppDatabase db, $RecordingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecordingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecordingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecordingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> scriptId = const Value.absent(),
            Value<String?> sessionId = const Value.absent(),
            Value<String> path = const Value.absent(),
            Value<int> durMs = const Value.absent(),
            Value<String?> timelineJson = const Value.absent(),
            Value<int> createdAt = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordingsCompanion(
            id: id,
            scriptId: scriptId,
            sessionId: sessionId,
            path: path,
            durMs: durMs,
            timelineJson: timelineJson,
            createdAt: createdAt,
            sizeBytes: sizeBytes,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String scriptId,
            Value<String?> sessionId = const Value.absent(),
            required String path,
            required int durMs,
            Value<String?> timelineJson = const Value.absent(),
            required int createdAt,
            required int sizeBytes,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecordingsCompanion.insert(
            id: id,
            scriptId: scriptId,
            sessionId: sessionId,
            path: path,
            durMs: durMs,
            timelineJson: timelineJson,
            createdAt: createdAt,
            sizeBytes: sizeBytes,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$RecordingsTable, RecordingRow>(table),
                    BaseReferences<_$AppDatabase, $RecordingsTable,
                        RecordingRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecordingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RecordingsTable,
    RecordingRow,
    $$RecordingsTableFilterComposer,
    $$RecordingsTableOrderingComposer,
    $$RecordingsTableAnnotationComposer,
    $$RecordingsTableCreateCompanionBuilder,
    $$RecordingsTableUpdateCompanionBuilder,
    (
      RecordingRow,
      BaseReferences<_$AppDatabase, $RecordingsTable, RecordingRow>
    ),
    RecordingRow,
    PrefetchHooks Function()>;
typedef $$AppSettingsTableCreateCompanionBuilder = AppSettingsCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$AppSettingsTableUpdateCompanionBuilder = AppSettingsCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$AppSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$AppSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$AppSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppSettingsTable> {
  $$AppSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$AppSettingsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    SettingRow,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()> {
  $$AppSettingsTableTableManager(_$AppDatabase db, $AppSettingsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              AppSettingsCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable<$AppSettingsTable, SettingRow>(table),
                    BaseReferences<_$AppDatabase, $AppSettingsTable,
                        SettingRow>(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$AppSettingsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $AppSettingsTable,
    SettingRow,
    $$AppSettingsTableFilterComposer,
    $$AppSettingsTableOrderingComposer,
    $$AppSettingsTableAnnotationComposer,
    $$AppSettingsTableCreateCompanionBuilder,
    $$AppSettingsTableUpdateCompanionBuilder,
    (SettingRow, BaseReferences<_$AppDatabase, $AppSettingsTable, SettingRow>),
    SettingRow,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ScriptsTableTableManager get scripts =>
      $$ScriptsTableTableManager(_db, _db.scripts);
  $$SectionsTableTableManager get sections =>
      $$SectionsTableTableManager(_db, _db.sections);
  $$MarkersTableTableManager get markers =>
      $$MarkersTableTableManager(_db, _db.markers);
  $$PresetsTableTableManager get presets =>
      $$PresetsTableTableManager(_db, _db.presets);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$RecordingsTableTableManager get recordings =>
      $$RecordingsTableTableManager(_db, _db.recordings);
  $$AppSettingsTableTableManager get appSettings =>
      $$AppSettingsTableTableManager(_db, _db.appSettings);
}
