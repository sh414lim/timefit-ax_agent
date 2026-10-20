// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $LocalConversationsTable extends LocalConversations
    with TableInfo<$LocalConversationsTable, LocalConversation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalConversationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _lastSequenceMeta = const VerificationMeta(
    'lastSequence',
  );
  @override
  late final GeneratedColumn<int> lastSequence = GeneratedColumn<int>(
    'last_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _messageCountMeta = const VerificationMeta(
    'messageCount',
  );
  @override
  late final GeneratedColumn<int> messageCount = GeneratedColumn<int>(
    'message_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _lastMessageIdMeta = const VerificationMeta(
    'lastMessageId',
  );
  @override
  late final GeneratedColumn<String> lastMessageId = GeneratedColumn<String>(
    'last_message_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _serverCreatedAtMeta = const VerificationMeta(
    'serverCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>(
        'server_created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverUpdatedAtMeta = const VerificationMeta(
    'serverUpdatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverUpdatedAt =
      GeneratedColumn<DateTime>(
        'server_updated_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _lastSyncedAtMeta = const VerificationMeta(
    'lastSyncedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
    'last_synced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStateMeta = const VerificationMeta(
    'syncState',
  );
  @override
  late final GeneratedColumn<String> syncState = GeneratedColumn<String>(
    'sync_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('synced'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    status,
    lastSequence,
    messageCount,
    lastMessageId,
    serverCreatedAt,
    serverUpdatedAt,
    lastSyncedAt,
    syncState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_conversations';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalConversation> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('last_sequence')) {
      context.handle(
        _lastSequenceMeta,
        lastSequence.isAcceptableOrUnknown(
          data['last_sequence']!,
          _lastSequenceMeta,
        ),
      );
    }
    if (data.containsKey('message_count')) {
      context.handle(
        _messageCountMeta,
        messageCount.isAcceptableOrUnknown(
          data['message_count']!,
          _messageCountMeta,
        ),
      );
    }
    if (data.containsKey('last_message_id')) {
      context.handle(
        _lastMessageIdMeta,
        lastMessageId.isAcceptableOrUnknown(
          data['last_message_id']!,
          _lastMessageIdMeta,
        ),
      );
    }
    if (data.containsKey('server_created_at')) {
      context.handle(
        _serverCreatedAtMeta,
        serverCreatedAt.isAcceptableOrUnknown(
          data['server_created_at']!,
          _serverCreatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverCreatedAtMeta);
    }
    if (data.containsKey('server_updated_at')) {
      context.handle(
        _serverUpdatedAtMeta,
        serverUpdatedAt.isAcceptableOrUnknown(
          data['server_updated_at']!,
          _serverUpdatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_serverUpdatedAtMeta);
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
        _lastSyncedAtMeta,
        lastSyncedAt.isAcceptableOrUnknown(
          data['last_synced_at']!,
          _lastSyncedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastSyncedAtMeta);
    }
    if (data.containsKey('sync_state')) {
      context.handle(
        _syncStateMeta,
        syncState.isAcceptableOrUnknown(data['sync_state']!, _syncStateMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalConversation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalConversation(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      lastSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_sequence'],
      )!,
      messageCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}message_count'],
      )!,
      lastMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_message_id'],
      ),
      serverCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_created_at'],
      )!,
      serverUpdatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_updated_at'],
      )!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_synced_at'],
      )!,
      syncState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_state'],
      )!,
    );
  }

  @override
  $LocalConversationsTable createAlias(String alias) {
    return $LocalConversationsTable(attachedDatabase, alias);
  }
}

class LocalConversation extends DataClass
    implements Insertable<LocalConversation> {
  final String id;
  final String? title;
  final String status;
  final int lastSequence;
  final int messageCount;
  final String? lastMessageId;
  final DateTime serverCreatedAt;
  final DateTime serverUpdatedAt;
  final DateTime lastSyncedAt;
  final String syncState;
  const LocalConversation({
    required this.id,
    this.title,
    required this.status,
    required this.lastSequence,
    required this.messageCount,
    this.lastMessageId,
    required this.serverCreatedAt,
    required this.serverUpdatedAt,
    required this.lastSyncedAt,
    required this.syncState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['status'] = Variable<String>(status);
    map['last_sequence'] = Variable<int>(lastSequence);
    map['message_count'] = Variable<int>(messageCount);
    if (!nullToAbsent || lastMessageId != null) {
      map['last_message_id'] = Variable<String>(lastMessageId);
    }
    map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt);
    map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    map['sync_state'] = Variable<String>(syncState);
    return map;
  }

  LocalConversationsCompanion toCompanion(bool nullToAbsent) {
    return LocalConversationsCompanion(
      id: Value(id),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      status: Value(status),
      lastSequence: Value(lastSequence),
      messageCount: Value(messageCount),
      lastMessageId: lastMessageId == null && nullToAbsent
          ? const Value.absent()
          : Value(lastMessageId),
      serverCreatedAt: Value(serverCreatedAt),
      serverUpdatedAt: Value(serverUpdatedAt),
      lastSyncedAt: Value(lastSyncedAt),
      syncState: Value(syncState),
    );
  }

  factory LocalConversation.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalConversation(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      status: serializer.fromJson<String>(json['status']),
      lastSequence: serializer.fromJson<int>(json['lastSequence']),
      messageCount: serializer.fromJson<int>(json['messageCount']),
      lastMessageId: serializer.fromJson<String?>(json['lastMessageId']),
      serverCreatedAt: serializer.fromJson<DateTime>(json['serverCreatedAt']),
      serverUpdatedAt: serializer.fromJson<DateTime>(json['serverUpdatedAt']),
      lastSyncedAt: serializer.fromJson<DateTime>(json['lastSyncedAt']),
      syncState: serializer.fromJson<String>(json['syncState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String?>(title),
      'status': serializer.toJson<String>(status),
      'lastSequence': serializer.toJson<int>(lastSequence),
      'messageCount': serializer.toJson<int>(messageCount),
      'lastMessageId': serializer.toJson<String?>(lastMessageId),
      'serverCreatedAt': serializer.toJson<DateTime>(serverCreatedAt),
      'serverUpdatedAt': serializer.toJson<DateTime>(serverUpdatedAt),
      'lastSyncedAt': serializer.toJson<DateTime>(lastSyncedAt),
      'syncState': serializer.toJson<String>(syncState),
    };
  }

  LocalConversation copyWith({
    String? id,
    Value<String?> title = const Value.absent(),
    String? status,
    int? lastSequence,
    int? messageCount,
    Value<String?> lastMessageId = const Value.absent(),
    DateTime? serverCreatedAt,
    DateTime? serverUpdatedAt,
    DateTime? lastSyncedAt,
    String? syncState,
  }) => LocalConversation(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    status: status ?? this.status,
    lastSequence: lastSequence ?? this.lastSequence,
    messageCount: messageCount ?? this.messageCount,
    lastMessageId: lastMessageId.present
        ? lastMessageId.value
        : this.lastMessageId,
    serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
    serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    syncState: syncState ?? this.syncState,
  );
  LocalConversation copyWithCompanion(LocalConversationsCompanion data) {
    return LocalConversation(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      status: data.status.present ? data.status.value : this.status,
      lastSequence: data.lastSequence.present
          ? data.lastSequence.value
          : this.lastSequence,
      messageCount: data.messageCount.present
          ? data.messageCount.value
          : this.messageCount,
      lastMessageId: data.lastMessageId.present
          ? data.lastMessageId.value
          : this.lastMessageId,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
      serverUpdatedAt: data.serverUpdatedAt.present
          ? data.serverUpdatedAt.value
          : this.serverUpdatedAt,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
      syncState: data.syncState.present ? data.syncState.value : this.syncState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversation(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('lastSequence: $lastSequence, ')
          ..write('messageCount: $messageCount, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncState: $syncState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    status,
    lastSequence,
    messageCount,
    lastMessageId,
    serverCreatedAt,
    serverUpdatedAt,
    lastSyncedAt,
    syncState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalConversation &&
          other.id == this.id &&
          other.title == this.title &&
          other.status == this.status &&
          other.lastSequence == this.lastSequence &&
          other.messageCount == this.messageCount &&
          other.lastMessageId == this.lastMessageId &&
          other.serverCreatedAt == this.serverCreatedAt &&
          other.serverUpdatedAt == this.serverUpdatedAt &&
          other.lastSyncedAt == this.lastSyncedAt &&
          other.syncState == this.syncState);
}

class LocalConversationsCompanion extends UpdateCompanion<LocalConversation> {
  final Value<String> id;
  final Value<String?> title;
  final Value<String> status;
  final Value<int> lastSequence;
  final Value<int> messageCount;
  final Value<String?> lastMessageId;
  final Value<DateTime> serverCreatedAt;
  final Value<DateTime> serverUpdatedAt;
  final Value<DateTime> lastSyncedAt;
  final Value<String> syncState;
  final Value<int> rowid;
  const LocalConversationsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSequence = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.serverUpdatedAt = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalConversationsCompanion.insert({
    required String id,
    this.title = const Value.absent(),
    this.status = const Value.absent(),
    this.lastSequence = const Value.absent(),
    this.messageCount = const Value.absent(),
    this.lastMessageId = const Value.absent(),
    required DateTime serverCreatedAt,
    required DateTime serverUpdatedAt,
    required DateTime lastSyncedAt,
    this.syncState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       serverCreatedAt = Value(serverCreatedAt),
       serverUpdatedAt = Value(serverUpdatedAt),
       lastSyncedAt = Value(lastSyncedAt);
  static Insertable<LocalConversation> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<String>? status,
    Expression<int>? lastSequence,
    Expression<int>? messageCount,
    Expression<String>? lastMessageId,
    Expression<DateTime>? serverCreatedAt,
    Expression<DateTime>? serverUpdatedAt,
    Expression<DateTime>? lastSyncedAt,
    Expression<String>? syncState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (status != null) 'status': status,
      if (lastSequence != null) 'last_sequence': lastSequence,
      if (messageCount != null) 'message_count': messageCount,
      if (lastMessageId != null) 'last_message_id': lastMessageId,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (serverUpdatedAt != null) 'server_updated_at': serverUpdatedAt,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (syncState != null) 'sync_state': syncState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalConversationsCompanion copyWith({
    Value<String>? id,
    Value<String?>? title,
    Value<String>? status,
    Value<int>? lastSequence,
    Value<int>? messageCount,
    Value<String?>? lastMessageId,
    Value<DateTime>? serverCreatedAt,
    Value<DateTime>? serverUpdatedAt,
    Value<DateTime>? lastSyncedAt,
    Value<String>? syncState,
    Value<int>? rowid,
  }) {
    return LocalConversationsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      status: status ?? this.status,
      lastSequence: lastSequence ?? this.lastSequence,
      messageCount: messageCount ?? this.messageCount,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      serverUpdatedAt: serverUpdatedAt ?? this.serverUpdatedAt,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      syncState: syncState ?? this.syncState,
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
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (lastSequence.present) {
      map['last_sequence'] = Variable<int>(lastSequence.value);
    }
    if (messageCount.present) {
      map['message_count'] = Variable<int>(messageCount.value);
    }
    if (lastMessageId.present) {
      map['last_message_id'] = Variable<String>(lastMessageId.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (serverUpdatedAt.present) {
      map['server_updated_at'] = Variable<DateTime>(serverUpdatedAt.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (syncState.present) {
      map['sync_state'] = Variable<String>(syncState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalConversationsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('status: $status, ')
          ..write('lastSequence: $lastSequence, ')
          ..write('messageCount: $messageCount, ')
          ..write('lastMessageId: $lastMessageId, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('serverUpdatedAt: $serverUpdatedAt, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('syncState: $syncState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalMessagesTable extends LocalMessages
    with TableInfo<$LocalMessagesTable, LocalMessage> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalMessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _serverIdMeta = const VerificationMeta(
    'serverId',
  );
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
    'server_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientMessageIdMeta = const VerificationMeta(
    'clientMessageId',
  );
  @override
  late final GeneratedColumn<String> clientMessageId = GeneratedColumn<String>(
    'client_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceMeta = const VerificationMeta(
    'sequence',
  );
  @override
  late final GeneratedColumn<int> sequence = GeneratedColumn<int>(
    'sequence',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _senderKindMeta = const VerificationMeta(
    'senderKind',
  );
  @override
  late final GeneratedColumn<String> senderKind = GeneratedColumn<String>(
    'sender_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bodyTextMeta = const VerificationMeta(
    'bodyText',
  );
  @override
  late final GeneratedColumn<String> bodyText = GeneratedColumn<String>(
    'body_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _messageKindMeta = const VerificationMeta(
    'messageKind',
  );
  @override
  late final GeneratedColumn<String> messageKind = GeneratedColumn<String>(
    'message_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientCreatedAtMeta = const VerificationMeta(
    'clientCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> clientCreatedAt =
      GeneratedColumn<DateTime>(
        'client_created_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _serverCreatedAtMeta = const VerificationMeta(
    'serverCreatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> serverCreatedAt =
      GeneratedColumn<DateTime>(
        'server_created_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _deliveryStateMeta = const VerificationMeta(
    'deliveryState',
  );
  @override
  late final GeneratedColumn<String> deliveryState = GeneratedColumn<String>(
    'delivery_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    serverId,
    conversationId,
    clientMessageId,
    sequence,
    senderKind,
    bodyText,
    messageKind,
    clientCreatedAt,
    serverCreatedAt,
    deliveryState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalMessage> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('server_id')) {
      context.handle(
        _serverIdMeta,
        serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('client_message_id')) {
      context.handle(
        _clientMessageIdMeta,
        clientMessageId.isAcceptableOrUnknown(
          data['client_message_id']!,
          _clientMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientMessageIdMeta);
    }
    if (data.containsKey('sequence')) {
      context.handle(
        _sequenceMeta,
        sequence.isAcceptableOrUnknown(data['sequence']!, _sequenceMeta),
      );
    }
    if (data.containsKey('sender_kind')) {
      context.handle(
        _senderKindMeta,
        senderKind.isAcceptableOrUnknown(data['sender_kind']!, _senderKindMeta),
      );
    } else if (isInserting) {
      context.missing(_senderKindMeta);
    }
    if (data.containsKey('body_text')) {
      context.handle(
        _bodyTextMeta,
        bodyText.isAcceptableOrUnknown(data['body_text']!, _bodyTextMeta),
      );
    }
    if (data.containsKey('message_kind')) {
      context.handle(
        _messageKindMeta,
        messageKind.isAcceptableOrUnknown(
          data['message_kind']!,
          _messageKindMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_messageKindMeta);
    }
    if (data.containsKey('client_created_at')) {
      context.handle(
        _clientCreatedAtMeta,
        clientCreatedAt.isAcceptableOrUnknown(
          data['client_created_at']!,
          _clientCreatedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientCreatedAtMeta);
    }
    if (data.containsKey('server_created_at')) {
      context.handle(
        _serverCreatedAtMeta,
        serverCreatedAt.isAcceptableOrUnknown(
          data['server_created_at']!,
          _serverCreatedAtMeta,
        ),
      );
    }
    if (data.containsKey('delivery_state')) {
      context.handle(
        _deliveryStateMeta,
        deliveryState.isAcceptableOrUnknown(
          data['delivery_state']!,
          _deliveryStateMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {conversationId, clientMessageId},
    {conversationId, sequence},
  ];
  @override
  LocalMessage map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalMessage(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      serverId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}server_id'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      clientMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_message_id'],
      )!,
      sequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence'],
      ),
      senderKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_kind'],
      )!,
      bodyText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_text'],
      ),
      messageKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_kind'],
      )!,
      clientCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}client_created_at'],
      )!,
      serverCreatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}server_created_at'],
      ),
      deliveryState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivery_state'],
      )!,
    );
  }

  @override
  $LocalMessagesTable createAlias(String alias) {
    return $LocalMessagesTable(attachedDatabase, alias);
  }
}

class LocalMessage extends DataClass implements Insertable<LocalMessage> {
  final String localId;
  final String? serverId;
  final String conversationId;
  final String clientMessageId;
  final int? sequence;
  final String senderKind;
  final String? bodyText;
  final String messageKind;
  final DateTime clientCreatedAt;
  final DateTime? serverCreatedAt;
  final String deliveryState;
  const LocalMessage({
    required this.localId,
    this.serverId,
    required this.conversationId,
    required this.clientMessageId,
    this.sequence,
    required this.senderKind,
    this.bodyText,
    required this.messageKind,
    required this.clientCreatedAt,
    this.serverCreatedAt,
    required this.deliveryState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || serverId != null) {
      map['server_id'] = Variable<String>(serverId);
    }
    map['conversation_id'] = Variable<String>(conversationId);
    map['client_message_id'] = Variable<String>(clientMessageId);
    if (!nullToAbsent || sequence != null) {
      map['sequence'] = Variable<int>(sequence);
    }
    map['sender_kind'] = Variable<String>(senderKind);
    if (!nullToAbsent || bodyText != null) {
      map['body_text'] = Variable<String>(bodyText);
    }
    map['message_kind'] = Variable<String>(messageKind);
    map['client_created_at'] = Variable<DateTime>(clientCreatedAt);
    if (!nullToAbsent || serverCreatedAt != null) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt);
    }
    map['delivery_state'] = Variable<String>(deliveryState);
    return map;
  }

  LocalMessagesCompanion toCompanion(bool nullToAbsent) {
    return LocalMessagesCompanion(
      localId: Value(localId),
      serverId: serverId == null && nullToAbsent
          ? const Value.absent()
          : Value(serverId),
      conversationId: Value(conversationId),
      clientMessageId: Value(clientMessageId),
      sequence: sequence == null && nullToAbsent
          ? const Value.absent()
          : Value(sequence),
      senderKind: Value(senderKind),
      bodyText: bodyText == null && nullToAbsent
          ? const Value.absent()
          : Value(bodyText),
      messageKind: Value(messageKind),
      clientCreatedAt: Value(clientCreatedAt),
      serverCreatedAt: serverCreatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(serverCreatedAt),
      deliveryState: Value(deliveryState),
    );
  }

  factory LocalMessage.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalMessage(
      localId: serializer.fromJson<String>(json['localId']),
      serverId: serializer.fromJson<String?>(json['serverId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      clientMessageId: serializer.fromJson<String>(json['clientMessageId']),
      sequence: serializer.fromJson<int?>(json['sequence']),
      senderKind: serializer.fromJson<String>(json['senderKind']),
      bodyText: serializer.fromJson<String?>(json['bodyText']),
      messageKind: serializer.fromJson<String>(json['messageKind']),
      clientCreatedAt: serializer.fromJson<DateTime>(json['clientCreatedAt']),
      serverCreatedAt: serializer.fromJson<DateTime?>(json['serverCreatedAt']),
      deliveryState: serializer.fromJson<String>(json['deliveryState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'serverId': serializer.toJson<String?>(serverId),
      'conversationId': serializer.toJson<String>(conversationId),
      'clientMessageId': serializer.toJson<String>(clientMessageId),
      'sequence': serializer.toJson<int?>(sequence),
      'senderKind': serializer.toJson<String>(senderKind),
      'bodyText': serializer.toJson<String?>(bodyText),
      'messageKind': serializer.toJson<String>(messageKind),
      'clientCreatedAt': serializer.toJson<DateTime>(clientCreatedAt),
      'serverCreatedAt': serializer.toJson<DateTime?>(serverCreatedAt),
      'deliveryState': serializer.toJson<String>(deliveryState),
    };
  }

  LocalMessage copyWith({
    String? localId,
    Value<String?> serverId = const Value.absent(),
    String? conversationId,
    String? clientMessageId,
    Value<int?> sequence = const Value.absent(),
    String? senderKind,
    Value<String?> bodyText = const Value.absent(),
    String? messageKind,
    DateTime? clientCreatedAt,
    Value<DateTime?> serverCreatedAt = const Value.absent(),
    String? deliveryState,
  }) => LocalMessage(
    localId: localId ?? this.localId,
    serverId: serverId.present ? serverId.value : this.serverId,
    conversationId: conversationId ?? this.conversationId,
    clientMessageId: clientMessageId ?? this.clientMessageId,
    sequence: sequence.present ? sequence.value : this.sequence,
    senderKind: senderKind ?? this.senderKind,
    bodyText: bodyText.present ? bodyText.value : this.bodyText,
    messageKind: messageKind ?? this.messageKind,
    clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
    serverCreatedAt: serverCreatedAt.present
        ? serverCreatedAt.value
        : this.serverCreatedAt,
    deliveryState: deliveryState ?? this.deliveryState,
  );
  LocalMessage copyWithCompanion(LocalMessagesCompanion data) {
    return LocalMessage(
      localId: data.localId.present ? data.localId.value : this.localId,
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      clientMessageId: data.clientMessageId.present
          ? data.clientMessageId.value
          : this.clientMessageId,
      sequence: data.sequence.present ? data.sequence.value : this.sequence,
      senderKind: data.senderKind.present
          ? data.senderKind.value
          : this.senderKind,
      bodyText: data.bodyText.present ? data.bodyText.value : this.bodyText,
      messageKind: data.messageKind.present
          ? data.messageKind.value
          : this.messageKind,
      clientCreatedAt: data.clientCreatedAt.present
          ? data.clientCreatedAt.value
          : this.clientCreatedAt,
      serverCreatedAt: data.serverCreatedAt.present
          ? data.serverCreatedAt.value
          : this.serverCreatedAt,
      deliveryState: data.deliveryState.present
          ? data.deliveryState.value
          : this.deliveryState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessage(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('sequence: $sequence, ')
          ..write('senderKind: $senderKind, ')
          ..write('bodyText: $bodyText, ')
          ..write('messageKind: $messageKind, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('deliveryState: $deliveryState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    serverId,
    conversationId,
    clientMessageId,
    sequence,
    senderKind,
    bodyText,
    messageKind,
    clientCreatedAt,
    serverCreatedAt,
    deliveryState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalMessage &&
          other.localId == this.localId &&
          other.serverId == this.serverId &&
          other.conversationId == this.conversationId &&
          other.clientMessageId == this.clientMessageId &&
          other.sequence == this.sequence &&
          other.senderKind == this.senderKind &&
          other.bodyText == this.bodyText &&
          other.messageKind == this.messageKind &&
          other.clientCreatedAt == this.clientCreatedAt &&
          other.serverCreatedAt == this.serverCreatedAt &&
          other.deliveryState == this.deliveryState);
}

class LocalMessagesCompanion extends UpdateCompanion<LocalMessage> {
  final Value<String> localId;
  final Value<String?> serverId;
  final Value<String> conversationId;
  final Value<String> clientMessageId;
  final Value<int?> sequence;
  final Value<String> senderKind;
  final Value<String?> bodyText;
  final Value<String> messageKind;
  final Value<DateTime> clientCreatedAt;
  final Value<DateTime?> serverCreatedAt;
  final Value<String> deliveryState;
  final Value<int> rowid;
  const LocalMessagesCompanion({
    this.localId = const Value.absent(),
    this.serverId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.clientMessageId = const Value.absent(),
    this.sequence = const Value.absent(),
    this.senderKind = const Value.absent(),
    this.bodyText = const Value.absent(),
    this.messageKind = const Value.absent(),
    this.clientCreatedAt = const Value.absent(),
    this.serverCreatedAt = const Value.absent(),
    this.deliveryState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalMessagesCompanion.insert({
    required String localId,
    this.serverId = const Value.absent(),
    required String conversationId,
    required String clientMessageId,
    this.sequence = const Value.absent(),
    required String senderKind,
    this.bodyText = const Value.absent(),
    required String messageKind,
    required DateTime clientCreatedAt,
    this.serverCreatedAt = const Value.absent(),
    this.deliveryState = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       conversationId = Value(conversationId),
       clientMessageId = Value(clientMessageId),
       senderKind = Value(senderKind),
       messageKind = Value(messageKind),
       clientCreatedAt = Value(clientCreatedAt);
  static Insertable<LocalMessage> custom({
    Expression<String>? localId,
    Expression<String>? serverId,
    Expression<String>? conversationId,
    Expression<String>? clientMessageId,
    Expression<int>? sequence,
    Expression<String>? senderKind,
    Expression<String>? bodyText,
    Expression<String>? messageKind,
    Expression<DateTime>? clientCreatedAt,
    Expression<DateTime>? serverCreatedAt,
    Expression<String>? deliveryState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (serverId != null) 'server_id': serverId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (sequence != null) 'sequence': sequence,
      if (senderKind != null) 'sender_kind': senderKind,
      if (bodyText != null) 'body_text': bodyText,
      if (messageKind != null) 'message_kind': messageKind,
      if (clientCreatedAt != null) 'client_created_at': clientCreatedAt,
      if (serverCreatedAt != null) 'server_created_at': serverCreatedAt,
      if (deliveryState != null) 'delivery_state': deliveryState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalMessagesCompanion copyWith({
    Value<String>? localId,
    Value<String?>? serverId,
    Value<String>? conversationId,
    Value<String>? clientMessageId,
    Value<int?>? sequence,
    Value<String>? senderKind,
    Value<String?>? bodyText,
    Value<String>? messageKind,
    Value<DateTime>? clientCreatedAt,
    Value<DateTime?>? serverCreatedAt,
    Value<String>? deliveryState,
    Value<int>? rowid,
  }) {
    return LocalMessagesCompanion(
      localId: localId ?? this.localId,
      serverId: serverId ?? this.serverId,
      conversationId: conversationId ?? this.conversationId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      sequence: sequence ?? this.sequence,
      senderKind: senderKind ?? this.senderKind,
      bodyText: bodyText ?? this.bodyText,
      messageKind: messageKind ?? this.messageKind,
      clientCreatedAt: clientCreatedAt ?? this.clientCreatedAt,
      serverCreatedAt: serverCreatedAt ?? this.serverCreatedAt,
      deliveryState: deliveryState ?? this.deliveryState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (clientMessageId.present) {
      map['client_message_id'] = Variable<String>(clientMessageId.value);
    }
    if (sequence.present) {
      map['sequence'] = Variable<int>(sequence.value);
    }
    if (senderKind.present) {
      map['sender_kind'] = Variable<String>(senderKind.value);
    }
    if (bodyText.present) {
      map['body_text'] = Variable<String>(bodyText.value);
    }
    if (messageKind.present) {
      map['message_kind'] = Variable<String>(messageKind.value);
    }
    if (clientCreatedAt.present) {
      map['client_created_at'] = Variable<DateTime>(clientCreatedAt.value);
    }
    if (serverCreatedAt.present) {
      map['server_created_at'] = Variable<DateTime>(serverCreatedAt.value);
    }
    if (deliveryState.present) {
      map['delivery_state'] = Variable<String>(deliveryState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalMessagesCompanion(')
          ..write('localId: $localId, ')
          ..write('serverId: $serverId, ')
          ..write('conversationId: $conversationId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('sequence: $sequence, ')
          ..write('senderKind: $senderKind, ')
          ..write('bodyText: $bodyText, ')
          ..write('messageKind: $messageKind, ')
          ..write('clientCreatedAt: $clientCreatedAt, ')
          ..write('serverCreatedAt: $serverCreatedAt, ')
          ..write('deliveryState: $deliveryState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalAttachmentsTable extends LocalAttachments
    with TableInfo<$LocalAttachmentsTable, LocalAttachment> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalAttachmentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attachmentIdMeta = const VerificationMeta(
    'attachmentId',
  );
  @override
  late final GeneratedColumn<String> attachmentId = GeneratedColumn<String>(
    'attachment_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientMessageIdMeta = const VerificationMeta(
    'clientMessageId',
  );
  @override
  late final GeneratedColumn<String> clientMessageId = GeneratedColumn<String>(
    'client_message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localFileUriMeta = const VerificationMeta(
    'localFileUri',
  );
  @override
  late final GeneratedColumn<String> localFileUri = GeneratedColumn<String>(
    'local_file_uri',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadStateMeta = const VerificationMeta(
    'uploadState',
  );
  @override
  late final GeneratedColumn<String> uploadState = GeneratedColumn<String>(
    'upload_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _bytesTotalMeta = const VerificationMeta(
    'bytesTotal',
  );
  @override
  late final GeneratedColumn<int> bytesTotal = GeneratedColumn<int>(
    'bytes_total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _bytesSentMeta = const VerificationMeta(
    'bytesSent',
  );
  @override
  late final GeneratedColumn<int> bytesSent = GeneratedColumn<int>(
    'bytes_sent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _contentTypeMeta = const VerificationMeta(
    'contentType',
  );
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
    'content_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sha256Meta = const VerificationMeta('sha256');
  @override
  late final GeneratedColumn<String> sha256 = GeneratedColumn<String>(
    'sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _failureCodeMeta = const VerificationMeta(
    'failureCode',
  );
  @override
  late final GeneratedColumn<String> failureCode = GeneratedColumn<String>(
    'failure_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _uploadObjectPathMeta = const VerificationMeta(
    'uploadObjectPath',
  );
  @override
  late final GeneratedColumn<String> uploadObjectPath = GeneratedColumn<String>(
    'upload_object_path',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _verificationFailuresMeta =
      const VerificationMeta('verificationFailures');
  @override
  late final GeneratedColumn<int> verificationFailures = GeneratedColumn<int>(
    'verification_failures',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    attachmentId,
    conversationId,
    clientMessageId,
    localFileUri,
    uploadState,
    bytesTotal,
    bytesSent,
    contentType,
    sha256,
    failureCode,
    uploadObjectPath,
    verificationFailures,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_attachments';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalAttachment> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('attachment_id')) {
      context.handle(
        _attachmentIdMeta,
        attachmentId.isAcceptableOrUnknown(
          data['attachment_id']!,
          _attachmentIdMeta,
        ),
      );
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('client_message_id')) {
      context.handle(
        _clientMessageIdMeta,
        clientMessageId.isAcceptableOrUnknown(
          data['client_message_id']!,
          _clientMessageIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientMessageIdMeta);
    }
    if (data.containsKey('local_file_uri')) {
      context.handle(
        _localFileUriMeta,
        localFileUri.isAcceptableOrUnknown(
          data['local_file_uri']!,
          _localFileUriMeta,
        ),
      );
    }
    if (data.containsKey('upload_state')) {
      context.handle(
        _uploadStateMeta,
        uploadState.isAcceptableOrUnknown(
          data['upload_state']!,
          _uploadStateMeta,
        ),
      );
    }
    if (data.containsKey('bytes_total')) {
      context.handle(
        _bytesTotalMeta,
        bytesTotal.isAcceptableOrUnknown(data['bytes_total']!, _bytesTotalMeta),
      );
    }
    if (data.containsKey('bytes_sent')) {
      context.handle(
        _bytesSentMeta,
        bytesSent.isAcceptableOrUnknown(data['bytes_sent']!, _bytesSentMeta),
      );
    }
    if (data.containsKey('content_type')) {
      context.handle(
        _contentTypeMeta,
        contentType.isAcceptableOrUnknown(
          data['content_type']!,
          _contentTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_contentTypeMeta);
    }
    if (data.containsKey('sha256')) {
      context.handle(
        _sha256Meta,
        sha256.isAcceptableOrUnknown(data['sha256']!, _sha256Meta),
      );
    } else if (isInserting) {
      context.missing(_sha256Meta);
    }
    if (data.containsKey('failure_code')) {
      context.handle(
        _failureCodeMeta,
        failureCode.isAcceptableOrUnknown(
          data['failure_code']!,
          _failureCodeMeta,
        ),
      );
    }
    if (data.containsKey('upload_object_path')) {
      context.handle(
        _uploadObjectPathMeta,
        uploadObjectPath.isAcceptableOrUnknown(
          data['upload_object_path']!,
          _uploadObjectPathMeta,
        ),
      );
    }
    if (data.containsKey('verification_failures')) {
      context.handle(
        _verificationFailuresMeta,
        verificationFailures.isAcceptableOrUnknown(
          data['verification_failures']!,
          _verificationFailuresMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalAttachment map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalAttachment(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      attachmentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attachment_id'],
      ),
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      clientMessageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_message_id'],
      )!,
      localFileUri: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_file_uri'],
      ),
      uploadState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_state'],
      )!,
      bytesTotal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_total'],
      )!,
      bytesSent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes_sent'],
      )!,
      contentType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content_type'],
      )!,
      sha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sha256'],
      )!,
      failureCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_code'],
      ),
      uploadObjectPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}upload_object_path'],
      ),
      verificationFailures: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}verification_failures'],
      )!,
    );
  }

  @override
  $LocalAttachmentsTable createAlias(String alias) {
    return $LocalAttachmentsTable(attachedDatabase, alias);
  }
}

class LocalAttachment extends DataClass implements Insertable<LocalAttachment> {
  final String localId;
  final String? attachmentId;
  final String conversationId;
  final String clientMessageId;
  final String? localFileUri;
  final String uploadState;
  final int bytesTotal;
  final int bytesSent;
  final String contentType;
  final String sha256;
  final String? failureCode;
  final String? uploadObjectPath;
  final int verificationFailures;
  const LocalAttachment({
    required this.localId,
    this.attachmentId,
    required this.conversationId,
    required this.clientMessageId,
    this.localFileUri,
    required this.uploadState,
    required this.bytesTotal,
    required this.bytesSent,
    required this.contentType,
    required this.sha256,
    this.failureCode,
    this.uploadObjectPath,
    required this.verificationFailures,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || attachmentId != null) {
      map['attachment_id'] = Variable<String>(attachmentId);
    }
    map['conversation_id'] = Variable<String>(conversationId);
    map['client_message_id'] = Variable<String>(clientMessageId);
    if (!nullToAbsent || localFileUri != null) {
      map['local_file_uri'] = Variable<String>(localFileUri);
    }
    map['upload_state'] = Variable<String>(uploadState);
    map['bytes_total'] = Variable<int>(bytesTotal);
    map['bytes_sent'] = Variable<int>(bytesSent);
    map['content_type'] = Variable<String>(contentType);
    map['sha256'] = Variable<String>(sha256);
    if (!nullToAbsent || failureCode != null) {
      map['failure_code'] = Variable<String>(failureCode);
    }
    if (!nullToAbsent || uploadObjectPath != null) {
      map['upload_object_path'] = Variable<String>(uploadObjectPath);
    }
    map['verification_failures'] = Variable<int>(verificationFailures);
    return map;
  }

  LocalAttachmentsCompanion toCompanion(bool nullToAbsent) {
    return LocalAttachmentsCompanion(
      localId: Value(localId),
      attachmentId: attachmentId == null && nullToAbsent
          ? const Value.absent()
          : Value(attachmentId),
      conversationId: Value(conversationId),
      clientMessageId: Value(clientMessageId),
      localFileUri: localFileUri == null && nullToAbsent
          ? const Value.absent()
          : Value(localFileUri),
      uploadState: Value(uploadState),
      bytesTotal: Value(bytesTotal),
      bytesSent: Value(bytesSent),
      contentType: Value(contentType),
      sha256: Value(sha256),
      failureCode: failureCode == null && nullToAbsent
          ? const Value.absent()
          : Value(failureCode),
      uploadObjectPath: uploadObjectPath == null && nullToAbsent
          ? const Value.absent()
          : Value(uploadObjectPath),
      verificationFailures: Value(verificationFailures),
    );
  }

  factory LocalAttachment.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalAttachment(
      localId: serializer.fromJson<String>(json['localId']),
      attachmentId: serializer.fromJson<String?>(json['attachmentId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      clientMessageId: serializer.fromJson<String>(json['clientMessageId']),
      localFileUri: serializer.fromJson<String?>(json['localFileUri']),
      uploadState: serializer.fromJson<String>(json['uploadState']),
      bytesTotal: serializer.fromJson<int>(json['bytesTotal']),
      bytesSent: serializer.fromJson<int>(json['bytesSent']),
      contentType: serializer.fromJson<String>(json['contentType']),
      sha256: serializer.fromJson<String>(json['sha256']),
      failureCode: serializer.fromJson<String?>(json['failureCode']),
      uploadObjectPath: serializer.fromJson<String?>(json['uploadObjectPath']),
      verificationFailures: serializer.fromJson<int>(
        json['verificationFailures'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'attachmentId': serializer.toJson<String?>(attachmentId),
      'conversationId': serializer.toJson<String>(conversationId),
      'clientMessageId': serializer.toJson<String>(clientMessageId),
      'localFileUri': serializer.toJson<String?>(localFileUri),
      'uploadState': serializer.toJson<String>(uploadState),
      'bytesTotal': serializer.toJson<int>(bytesTotal),
      'bytesSent': serializer.toJson<int>(bytesSent),
      'contentType': serializer.toJson<String>(contentType),
      'sha256': serializer.toJson<String>(sha256),
      'failureCode': serializer.toJson<String?>(failureCode),
      'uploadObjectPath': serializer.toJson<String?>(uploadObjectPath),
      'verificationFailures': serializer.toJson<int>(verificationFailures),
    };
  }

  LocalAttachment copyWith({
    String? localId,
    Value<String?> attachmentId = const Value.absent(),
    String? conversationId,
    String? clientMessageId,
    Value<String?> localFileUri = const Value.absent(),
    String? uploadState,
    int? bytesTotal,
    int? bytesSent,
    String? contentType,
    String? sha256,
    Value<String?> failureCode = const Value.absent(),
    Value<String?> uploadObjectPath = const Value.absent(),
    int? verificationFailures,
  }) => LocalAttachment(
    localId: localId ?? this.localId,
    attachmentId: attachmentId.present ? attachmentId.value : this.attachmentId,
    conversationId: conversationId ?? this.conversationId,
    clientMessageId: clientMessageId ?? this.clientMessageId,
    localFileUri: localFileUri.present ? localFileUri.value : this.localFileUri,
    uploadState: uploadState ?? this.uploadState,
    bytesTotal: bytesTotal ?? this.bytesTotal,
    bytesSent: bytesSent ?? this.bytesSent,
    contentType: contentType ?? this.contentType,
    sha256: sha256 ?? this.sha256,
    failureCode: failureCode.present ? failureCode.value : this.failureCode,
    uploadObjectPath: uploadObjectPath.present
        ? uploadObjectPath.value
        : this.uploadObjectPath,
    verificationFailures: verificationFailures ?? this.verificationFailures,
  );
  LocalAttachment copyWithCompanion(LocalAttachmentsCompanion data) {
    return LocalAttachment(
      localId: data.localId.present ? data.localId.value : this.localId,
      attachmentId: data.attachmentId.present
          ? data.attachmentId.value
          : this.attachmentId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      clientMessageId: data.clientMessageId.present
          ? data.clientMessageId.value
          : this.clientMessageId,
      localFileUri: data.localFileUri.present
          ? data.localFileUri.value
          : this.localFileUri,
      uploadState: data.uploadState.present
          ? data.uploadState.value
          : this.uploadState,
      bytesTotal: data.bytesTotal.present
          ? data.bytesTotal.value
          : this.bytesTotal,
      bytesSent: data.bytesSent.present ? data.bytesSent.value : this.bytesSent,
      contentType: data.contentType.present
          ? data.contentType.value
          : this.contentType,
      sha256: data.sha256.present ? data.sha256.value : this.sha256,
      failureCode: data.failureCode.present
          ? data.failureCode.value
          : this.failureCode,
      uploadObjectPath: data.uploadObjectPath.present
          ? data.uploadObjectPath.value
          : this.uploadObjectPath,
      verificationFailures: data.verificationFailures.present
          ? data.verificationFailures.value
          : this.verificationFailures,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttachment(')
          ..write('localId: $localId, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('conversationId: $conversationId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('localFileUri: $localFileUri, ')
          ..write('uploadState: $uploadState, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('bytesSent: $bytesSent, ')
          ..write('contentType: $contentType, ')
          ..write('sha256: $sha256, ')
          ..write('failureCode: $failureCode, ')
          ..write('uploadObjectPath: $uploadObjectPath, ')
          ..write('verificationFailures: $verificationFailures')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    attachmentId,
    conversationId,
    clientMessageId,
    localFileUri,
    uploadState,
    bytesTotal,
    bytesSent,
    contentType,
    sha256,
    failureCode,
    uploadObjectPath,
    verificationFailures,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalAttachment &&
          other.localId == this.localId &&
          other.attachmentId == this.attachmentId &&
          other.conversationId == this.conversationId &&
          other.clientMessageId == this.clientMessageId &&
          other.localFileUri == this.localFileUri &&
          other.uploadState == this.uploadState &&
          other.bytesTotal == this.bytesTotal &&
          other.bytesSent == this.bytesSent &&
          other.contentType == this.contentType &&
          other.sha256 == this.sha256 &&
          other.failureCode == this.failureCode &&
          other.uploadObjectPath == this.uploadObjectPath &&
          other.verificationFailures == this.verificationFailures);
}

class LocalAttachmentsCompanion extends UpdateCompanion<LocalAttachment> {
  final Value<String> localId;
  final Value<String?> attachmentId;
  final Value<String> conversationId;
  final Value<String> clientMessageId;
  final Value<String?> localFileUri;
  final Value<String> uploadState;
  final Value<int> bytesTotal;
  final Value<int> bytesSent;
  final Value<String> contentType;
  final Value<String> sha256;
  final Value<String?> failureCode;
  final Value<String?> uploadObjectPath;
  final Value<int> verificationFailures;
  final Value<int> rowid;
  const LocalAttachmentsCompanion({
    this.localId = const Value.absent(),
    this.attachmentId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.clientMessageId = const Value.absent(),
    this.localFileUri = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.bytesSent = const Value.absent(),
    this.contentType = const Value.absent(),
    this.sha256 = const Value.absent(),
    this.failureCode = const Value.absent(),
    this.uploadObjectPath = const Value.absent(),
    this.verificationFailures = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalAttachmentsCompanion.insert({
    required String localId,
    this.attachmentId = const Value.absent(),
    required String conversationId,
    required String clientMessageId,
    this.localFileUri = const Value.absent(),
    this.uploadState = const Value.absent(),
    this.bytesTotal = const Value.absent(),
    this.bytesSent = const Value.absent(),
    required String contentType,
    required String sha256,
    this.failureCode = const Value.absent(),
    this.uploadObjectPath = const Value.absent(),
    this.verificationFailures = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       conversationId = Value(conversationId),
       clientMessageId = Value(clientMessageId),
       contentType = Value(contentType),
       sha256 = Value(sha256);
  static Insertable<LocalAttachment> custom({
    Expression<String>? localId,
    Expression<String>? attachmentId,
    Expression<String>? conversationId,
    Expression<String>? clientMessageId,
    Expression<String>? localFileUri,
    Expression<String>? uploadState,
    Expression<int>? bytesTotal,
    Expression<int>? bytesSent,
    Expression<String>? contentType,
    Expression<String>? sha256,
    Expression<String>? failureCode,
    Expression<String>? uploadObjectPath,
    Expression<int>? verificationFailures,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (attachmentId != null) 'attachment_id': attachmentId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (localFileUri != null) 'local_file_uri': localFileUri,
      if (uploadState != null) 'upload_state': uploadState,
      if (bytesTotal != null) 'bytes_total': bytesTotal,
      if (bytesSent != null) 'bytes_sent': bytesSent,
      if (contentType != null) 'content_type': contentType,
      if (sha256 != null) 'sha256': sha256,
      if (failureCode != null) 'failure_code': failureCode,
      if (uploadObjectPath != null) 'upload_object_path': uploadObjectPath,
      if (verificationFailures != null)
        'verification_failures': verificationFailures,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalAttachmentsCompanion copyWith({
    Value<String>? localId,
    Value<String?>? attachmentId,
    Value<String>? conversationId,
    Value<String>? clientMessageId,
    Value<String?>? localFileUri,
    Value<String>? uploadState,
    Value<int>? bytesTotal,
    Value<int>? bytesSent,
    Value<String>? contentType,
    Value<String>? sha256,
    Value<String?>? failureCode,
    Value<String?>? uploadObjectPath,
    Value<int>? verificationFailures,
    Value<int>? rowid,
  }) {
    return LocalAttachmentsCompanion(
      localId: localId ?? this.localId,
      attachmentId: attachmentId ?? this.attachmentId,
      conversationId: conversationId ?? this.conversationId,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      localFileUri: localFileUri ?? this.localFileUri,
      uploadState: uploadState ?? this.uploadState,
      bytesTotal: bytesTotal ?? this.bytesTotal,
      bytesSent: bytesSent ?? this.bytesSent,
      contentType: contentType ?? this.contentType,
      sha256: sha256 ?? this.sha256,
      failureCode: failureCode ?? this.failureCode,
      uploadObjectPath: uploadObjectPath ?? this.uploadObjectPath,
      verificationFailures: verificationFailures ?? this.verificationFailures,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (attachmentId.present) {
      map['attachment_id'] = Variable<String>(attachmentId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (clientMessageId.present) {
      map['client_message_id'] = Variable<String>(clientMessageId.value);
    }
    if (localFileUri.present) {
      map['local_file_uri'] = Variable<String>(localFileUri.value);
    }
    if (uploadState.present) {
      map['upload_state'] = Variable<String>(uploadState.value);
    }
    if (bytesTotal.present) {
      map['bytes_total'] = Variable<int>(bytesTotal.value);
    }
    if (bytesSent.present) {
      map['bytes_sent'] = Variable<int>(bytesSent.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (sha256.present) {
      map['sha256'] = Variable<String>(sha256.value);
    }
    if (failureCode.present) {
      map['failure_code'] = Variable<String>(failureCode.value);
    }
    if (uploadObjectPath.present) {
      map['upload_object_path'] = Variable<String>(uploadObjectPath.value);
    }
    if (verificationFailures.present) {
      map['verification_failures'] = Variable<int>(verificationFailures.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalAttachmentsCompanion(')
          ..write('localId: $localId, ')
          ..write('attachmentId: $attachmentId, ')
          ..write('conversationId: $conversationId, ')
          ..write('clientMessageId: $clientMessageId, ')
          ..write('localFileUri: $localFileUri, ')
          ..write('uploadState: $uploadState, ')
          ..write('bytesTotal: $bytesTotal, ')
          ..write('bytesSent: $bytesSent, ')
          ..write('contentType: $contentType, ')
          ..write('sha256: $sha256, ')
          ..write('failureCode: $failureCode, ')
          ..write('uploadObjectPath: $uploadObjectPath, ')
          ..write('verificationFailures: $verificationFailures, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $OutboxCommandsTable extends OutboxCommands
    with TableInfo<$OutboxCommandsTable, OutboxCommand> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OutboxCommandsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _commandTypeMeta = const VerificationMeta(
    'commandType',
  );
  @override
  late final GeneratedColumn<String> commandType = GeneratedColumn<String>(
    'command_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggregateIdMeta = const VerificationMeta(
    'aggregateId',
  );
  @override
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
    'aggregate_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _clientRequestIdMeta = const VerificationMeta(
    'clientRequestId',
  );
  @override
  late final GeneratedColumn<String> clientRequestId = GeneratedColumn<String>(
    'client_request_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtMeta = const VerificationMeta(
    'nextAttemptAt',
  );
  @override
  late final GeneratedColumn<DateTime> nextAttemptAt =
      GeneratedColumn<DateTime>(
        'next_attempt_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _leaseOwnerMeta = const VerificationMeta(
    'leaseOwner',
  );
  @override
  late final GeneratedColumn<String> leaseOwner = GeneratedColumn<String>(
    'lease_owner',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _leaseUntilMeta = const VerificationMeta(
    'leaseUntil',
  );
  @override
  late final GeneratedColumn<DateTime> leaseUntil = GeneratedColumn<DateTime>(
    'lease_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    commandType,
    aggregateId,
    clientRequestId,
    payloadJson,
    state,
    attemptCount,
    nextAttemptAt,
    leaseOwner,
    leaseUntil,
    lastErrorCode,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'outbox_commands';
  @override
  VerificationContext validateIntegrity(
    Insertable<OutboxCommand> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('command_type')) {
      context.handle(
        _commandTypeMeta,
        commandType.isAcceptableOrUnknown(
          data['command_type']!,
          _commandTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_commandTypeMeta);
    }
    if (data.containsKey('aggregate_id')) {
      context.handle(
        _aggregateIdMeta,
        aggregateId.isAcceptableOrUnknown(
          data['aggregate_id']!,
          _aggregateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggregateIdMeta);
    }
    if (data.containsKey('client_request_id')) {
      context.handle(
        _clientRequestIdMeta,
        clientRequestId.isAcceptableOrUnknown(
          data['client_request_id']!,
          _clientRequestIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_clientRequestIdMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    }
    if (data.containsKey('next_attempt_at')) {
      context.handle(
        _nextAttemptAtMeta,
        nextAttemptAt.isAcceptableOrUnknown(
          data['next_attempt_at']!,
          _nextAttemptAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtMeta);
    }
    if (data.containsKey('lease_owner')) {
      context.handle(
        _leaseOwnerMeta,
        leaseOwner.isAcceptableOrUnknown(data['lease_owner']!, _leaseOwnerMeta),
      );
    }
    if (data.containsKey('lease_until')) {
      context.handle(
        _leaseUntilMeta,
        leaseUntil.isAcceptableOrUnknown(data['lease_until']!, _leaseUntilMeta),
      );
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OutboxCommand map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OutboxCommand(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      commandType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}command_type'],
      )!,
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      )!,
      clientRequestId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}client_request_id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      nextAttemptAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_attempt_at'],
      )!,
      leaseOwner: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lease_owner'],
      ),
      leaseUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}lease_until'],
      ),
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OutboxCommandsTable createAlias(String alias) {
    return $OutboxCommandsTable(attachedDatabase, alias);
  }
}

class OutboxCommand extends DataClass implements Insertable<OutboxCommand> {
  final String id;
  final String commandType;
  final String aggregateId;
  final String clientRequestId;
  final String payloadJson;
  final String state;
  final int attemptCount;
  final DateTime nextAttemptAt;
  final String? leaseOwner;
  final DateTime? leaseUntil;
  final String? lastErrorCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OutboxCommand({
    required this.id,
    required this.commandType,
    required this.aggregateId,
    required this.clientRequestId,
    required this.payloadJson,
    required this.state,
    required this.attemptCount,
    required this.nextAttemptAt,
    this.leaseOwner,
    this.leaseUntil,
    this.lastErrorCode,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['command_type'] = Variable<String>(commandType);
    map['aggregate_id'] = Variable<String>(aggregateId);
    map['client_request_id'] = Variable<String>(clientRequestId);
    map['payload_json'] = Variable<String>(payloadJson);
    map['state'] = Variable<String>(state);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt);
    if (!nullToAbsent || leaseOwner != null) {
      map['lease_owner'] = Variable<String>(leaseOwner);
    }
    if (!nullToAbsent || leaseUntil != null) {
      map['lease_until'] = Variable<DateTime>(leaseUntil);
    }
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OutboxCommandsCompanion toCompanion(bool nullToAbsent) {
    return OutboxCommandsCompanion(
      id: Value(id),
      commandType: Value(commandType),
      aggregateId: Value(aggregateId),
      clientRequestId: Value(clientRequestId),
      payloadJson: Value(payloadJson),
      state: Value(state),
      attemptCount: Value(attemptCount),
      nextAttemptAt: Value(nextAttemptAt),
      leaseOwner: leaseOwner == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseOwner),
      leaseUntil: leaseUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(leaseUntil),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OutboxCommand.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OutboxCommand(
      id: serializer.fromJson<String>(json['id']),
      commandType: serializer.fromJson<String>(json['commandType']),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      clientRequestId: serializer.fromJson<String>(json['clientRequestId']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      state: serializer.fromJson<String>(json['state']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      nextAttemptAt: serializer.fromJson<DateTime>(json['nextAttemptAt']),
      leaseOwner: serializer.fromJson<String?>(json['leaseOwner']),
      leaseUntil: serializer.fromJson<DateTime?>(json['leaseUntil']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'commandType': serializer.toJson<String>(commandType),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'clientRequestId': serializer.toJson<String>(clientRequestId),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'state': serializer.toJson<String>(state),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'nextAttemptAt': serializer.toJson<DateTime>(nextAttemptAt),
      'leaseOwner': serializer.toJson<String?>(leaseOwner),
      'leaseUntil': serializer.toJson<DateTime?>(leaseUntil),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OutboxCommand copyWith({
    String? id,
    String? commandType,
    String? aggregateId,
    String? clientRequestId,
    String? payloadJson,
    String? state,
    int? attemptCount,
    DateTime? nextAttemptAt,
    Value<String?> leaseOwner = const Value.absent(),
    Value<DateTime?> leaseUntil = const Value.absent(),
    Value<String?> lastErrorCode = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OutboxCommand(
    id: id ?? this.id,
    commandType: commandType ?? this.commandType,
    aggregateId: aggregateId ?? this.aggregateId,
    clientRequestId: clientRequestId ?? this.clientRequestId,
    payloadJson: payloadJson ?? this.payloadJson,
    state: state ?? this.state,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    leaseOwner: leaseOwner.present ? leaseOwner.value : this.leaseOwner,
    leaseUntil: leaseUntil.present ? leaseUntil.value : this.leaseUntil,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OutboxCommand copyWithCompanion(OutboxCommandsCompanion data) {
    return OutboxCommand(
      id: data.id.present ? data.id.value : this.id,
      commandType: data.commandType.present
          ? data.commandType.value
          : this.commandType,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      clientRequestId: data.clientRequestId.present
          ? data.clientRequestId.value
          : this.clientRequestId,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      state: data.state.present ? data.state.value : this.state,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      nextAttemptAt: data.nextAttemptAt.present
          ? data.nextAttemptAt.value
          : this.nextAttemptAt,
      leaseOwner: data.leaseOwner.present
          ? data.leaseOwner.value
          : this.leaseOwner,
      leaseUntil: data.leaseUntil.present
          ? data.leaseUntil.value
          : this.leaseUntil,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCommand(')
          ..write('id: $id, ')
          ..write('commandType: $commandType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('clientRequestId: $clientRequestId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    commandType,
    aggregateId,
    clientRequestId,
    payloadJson,
    state,
    attemptCount,
    nextAttemptAt,
    leaseOwner,
    leaseUntil,
    lastErrorCode,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OutboxCommand &&
          other.id == this.id &&
          other.commandType == this.commandType &&
          other.aggregateId == this.aggregateId &&
          other.clientRequestId == this.clientRequestId &&
          other.payloadJson == this.payloadJson &&
          other.state == this.state &&
          other.attemptCount == this.attemptCount &&
          other.nextAttemptAt == this.nextAttemptAt &&
          other.leaseOwner == this.leaseOwner &&
          other.leaseUntil == this.leaseUntil &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OutboxCommandsCompanion extends UpdateCompanion<OutboxCommand> {
  final Value<String> id;
  final Value<String> commandType;
  final Value<String> aggregateId;
  final Value<String> clientRequestId;
  final Value<String> payloadJson;
  final Value<String> state;
  final Value<int> attemptCount;
  final Value<DateTime> nextAttemptAt;
  final Value<String?> leaseOwner;
  final Value<DateTime?> leaseUntil;
  final Value<String?> lastErrorCode;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const OutboxCommandsCompanion({
    this.id = const Value.absent(),
    this.commandType = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.clientRequestId = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.nextAttemptAt = const Value.absent(),
    this.leaseOwner = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OutboxCommandsCompanion.insert({
    required String id,
    required String commandType,
    required String aggregateId,
    required String clientRequestId,
    required String payloadJson,
    this.state = const Value.absent(),
    this.attemptCount = const Value.absent(),
    required DateTime nextAttemptAt,
    this.leaseOwner = const Value.absent(),
    this.leaseUntil = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       commandType = Value(commandType),
       aggregateId = Value(aggregateId),
       clientRequestId = Value(clientRequestId),
       payloadJson = Value(payloadJson),
       nextAttemptAt = Value(nextAttemptAt),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<OutboxCommand> custom({
    Expression<String>? id,
    Expression<String>? commandType,
    Expression<String>? aggregateId,
    Expression<String>? clientRequestId,
    Expression<String>? payloadJson,
    Expression<String>? state,
    Expression<int>? attemptCount,
    Expression<DateTime>? nextAttemptAt,
    Expression<String>? leaseOwner,
    Expression<DateTime>? leaseUntil,
    Expression<String>? lastErrorCode,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (commandType != null) 'command_type': commandType,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (clientRequestId != null) 'client_request_id': clientRequestId,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (state != null) 'state': state,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (nextAttemptAt != null) 'next_attempt_at': nextAttemptAt,
      if (leaseOwner != null) 'lease_owner': leaseOwner,
      if (leaseUntil != null) 'lease_until': leaseUntil,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OutboxCommandsCompanion copyWith({
    Value<String>? id,
    Value<String>? commandType,
    Value<String>? aggregateId,
    Value<String>? clientRequestId,
    Value<String>? payloadJson,
    Value<String>? state,
    Value<int>? attemptCount,
    Value<DateTime>? nextAttemptAt,
    Value<String?>? leaseOwner,
    Value<DateTime?>? leaseUntil,
    Value<String?>? lastErrorCode,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return OutboxCommandsCompanion(
      id: id ?? this.id,
      commandType: commandType ?? this.commandType,
      aggregateId: aggregateId ?? this.aggregateId,
      clientRequestId: clientRequestId ?? this.clientRequestId,
      payloadJson: payloadJson ?? this.payloadJson,
      state: state ?? this.state,
      attemptCount: attemptCount ?? this.attemptCount,
      nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
      leaseOwner: leaseOwner ?? this.leaseOwner,
      leaseUntil: leaseUntil ?? this.leaseUntil,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAt: createdAt ?? this.createdAt,
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
    if (commandType.present) {
      map['command_type'] = Variable<String>(commandType.value);
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (clientRequestId.present) {
      map['client_request_id'] = Variable<String>(clientRequestId.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (nextAttemptAt.present) {
      map['next_attempt_at'] = Variable<DateTime>(nextAttemptAt.value);
    }
    if (leaseOwner.present) {
      map['lease_owner'] = Variable<String>(leaseOwner.value);
    }
    if (leaseUntil.present) {
      map['lease_until'] = Variable<DateTime>(leaseUntil.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OutboxCommandsCompanion(')
          ..write('id: $id, ')
          ..write('commandType: $commandType, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('clientRequestId: $clientRequestId, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('state: $state, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('nextAttemptAt: $nextAttemptAt, ')
          ..write('leaseOwner: $leaseOwner, ')
          ..write('leaseUntil: $leaseUntil, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalConversationsTable localConversations =
      $LocalConversationsTable(this);
  late final $LocalMessagesTable localMessages = $LocalMessagesTable(this);
  late final $LocalAttachmentsTable localAttachments = $LocalAttachmentsTable(
    this,
  );
  late final $OutboxCommandsTable outboxCommands = $OutboxCommandsTable(this);
  late final ConversationDao conversationDao = ConversationDao(
    this as AppDatabase,
  );
  late final MessageDao messageDao = MessageDao(this as AppDatabase);
  late final AttachmentDao attachmentDao = AttachmentDao(this as AppDatabase);
  late final OutboxDao outboxDao = OutboxDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localConversations,
    localMessages,
    localAttachments,
    outboxCommands,
  ];
}

typedef $$LocalConversationsTableCreateCompanionBuilder =
    LocalConversationsCompanion Function({
      required String id,
      Value<String?> title,
      Value<String> status,
      Value<int> lastSequence,
      Value<int> messageCount,
      Value<String?> lastMessageId,
      required DateTime serverCreatedAt,
      required DateTime serverUpdatedAt,
      required DateTime lastSyncedAt,
      Value<String> syncState,
      Value<int> rowid,
    });
typedef $$LocalConversationsTableUpdateCompanionBuilder =
    LocalConversationsCompanion Function({
      Value<String> id,
      Value<String?> title,
      Value<String> status,
      Value<int> lastSequence,
      Value<int> messageCount,
      Value<String?> lastMessageId,
      Value<DateTime> serverCreatedAt,
      Value<DateTime> serverUpdatedAt,
      Value<DateTime> lastSyncedAt,
      Value<String> syncState,
      Value<int> rowid,
    });

class $$LocalConversationsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalConversationsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncState => $composableBuilder(
    column: $table.syncState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalConversationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalConversationsTable> {
  $$LocalConversationsTableAnnotationComposer({
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

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get lastSequence => $composableBuilder(
    column: $table.lastSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get messageCount => $composableBuilder(
    column: $table.messageCount,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastMessageId => $composableBuilder(
    column: $table.lastMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverUpdatedAt => $composableBuilder(
    column: $table.serverUpdatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
    column: $table.lastSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncState =>
      $composableBuilder(column: $table.syncState, builder: (column) => column);
}

class $$LocalConversationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation,
          $$LocalConversationsTableFilterComposer,
          $$LocalConversationsTableOrderingComposer,
          $$LocalConversationsTableAnnotationComposer,
          $$LocalConversationsTableCreateCompanionBuilder,
          $$LocalConversationsTableUpdateCompanionBuilder,
          (
            LocalConversation,
            BaseReferences<
              _$AppDatabase,
              $LocalConversationsTable,
              LocalConversation
            >,
          ),
          LocalConversation,
          PrefetchHooks Function()
        > {
  $$LocalConversationsTableTableManager(
    _$AppDatabase db,
    $LocalConversationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalConversationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalConversationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalConversationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> lastSequence = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<String?> lastMessageId = const Value.absent(),
                Value<DateTime> serverCreatedAt = const Value.absent(),
                Value<DateTime> serverUpdatedAt = const Value.absent(),
                Value<DateTime> lastSyncedAt = const Value.absent(),
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConversationsCompanion(
                id: id,
                title: title,
                status: status,
                lastSequence: lastSequence,
                messageCount: messageCount,
                lastMessageId: lastMessageId,
                serverCreatedAt: serverCreatedAt,
                serverUpdatedAt: serverUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> title = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> lastSequence = const Value.absent(),
                Value<int> messageCount = const Value.absent(),
                Value<String?> lastMessageId = const Value.absent(),
                required DateTime serverCreatedAt,
                required DateTime serverUpdatedAt,
                required DateTime lastSyncedAt,
                Value<String> syncState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalConversationsCompanion.insert(
                id: id,
                title: title,
                status: status,
                lastSequence: lastSequence,
                messageCount: messageCount,
                lastMessageId: lastMessageId,
                serverCreatedAt: serverCreatedAt,
                serverUpdatedAt: serverUpdatedAt,
                lastSyncedAt: lastSyncedAt,
                syncState: syncState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalConversationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalConversationsTable,
      LocalConversation,
      $$LocalConversationsTableFilterComposer,
      $$LocalConversationsTableOrderingComposer,
      $$LocalConversationsTableAnnotationComposer,
      $$LocalConversationsTableCreateCompanionBuilder,
      $$LocalConversationsTableUpdateCompanionBuilder,
      (
        LocalConversation,
        BaseReferences<
          _$AppDatabase,
          $LocalConversationsTable,
          LocalConversation
        >,
      ),
      LocalConversation,
      PrefetchHooks Function()
    >;
typedef $$LocalMessagesTableCreateCompanionBuilder =
    LocalMessagesCompanion Function({
      required String localId,
      Value<String?> serverId,
      required String conversationId,
      required String clientMessageId,
      Value<int?> sequence,
      required String senderKind,
      Value<String?> bodyText,
      required String messageKind,
      required DateTime clientCreatedAt,
      Value<DateTime?> serverCreatedAt,
      Value<String> deliveryState,
      Value<int> rowid,
    });
typedef $$LocalMessagesTableUpdateCompanionBuilder =
    LocalMessagesCompanion Function({
      Value<String> localId,
      Value<String?> serverId,
      Value<String> conversationId,
      Value<String> clientMessageId,
      Value<int?> sequence,
      Value<String> senderKind,
      Value<String?> bodyText,
      Value<String> messageKind,
      Value<DateTime> clientCreatedAt,
      Value<DateTime?> serverCreatedAt,
      Value<String> deliveryState,
      Value<int> rowid,
    });

class $$LocalMessagesTableFilterComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderKind => $composableBuilder(
    column: $table.senderKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get clientCreatedAt => $composableBuilder(
    column: $table.clientCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalMessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get serverId => $composableBuilder(
    column: $table.serverId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequence => $composableBuilder(
    column: $table.sequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderKind => $composableBuilder(
    column: $table.senderKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyText => $composableBuilder(
    column: $table.bodyText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get clientCreatedAt => $composableBuilder(
    column: $table.clientCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalMessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalMessagesTable> {
  $$LocalMessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequence =>
      $composableBuilder(column: $table.sequence, builder: (column) => column);

  GeneratedColumn<String> get senderKind => $composableBuilder(
    column: $table.senderKind,
    builder: (column) => column,
  );

  GeneratedColumn<String> get bodyText =>
      $composableBuilder(column: $table.bodyText, builder: (column) => column);

  GeneratedColumn<String> get messageKind => $composableBuilder(
    column: $table.messageKind,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get clientCreatedAt => $composableBuilder(
    column: $table.clientCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get serverCreatedAt => $composableBuilder(
    column: $table.serverCreatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => column,
  );
}

class $$LocalMessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalMessagesTable,
          LocalMessage,
          $$LocalMessagesTableFilterComposer,
          $$LocalMessagesTableOrderingComposer,
          $$LocalMessagesTableAnnotationComposer,
          $$LocalMessagesTableCreateCompanionBuilder,
          $$LocalMessagesTableUpdateCompanionBuilder,
          (
            LocalMessage,
            BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
          ),
          LocalMessage,
          PrefetchHooks Function()
        > {
  $$LocalMessagesTableTableManager(_$AppDatabase db, $LocalMessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalMessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalMessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalMessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String?> serverId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> clientMessageId = const Value.absent(),
                Value<int?> sequence = const Value.absent(),
                Value<String> senderKind = const Value.absent(),
                Value<String?> bodyText = const Value.absent(),
                Value<String> messageKind = const Value.absent(),
                Value<DateTime> clientCreatedAt = const Value.absent(),
                Value<DateTime?> serverCreatedAt = const Value.absent(),
                Value<String> deliveryState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion(
                localId: localId,
                serverId: serverId,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                sequence: sequence,
                senderKind: senderKind,
                bodyText: bodyText,
                messageKind: messageKind,
                clientCreatedAt: clientCreatedAt,
                serverCreatedAt: serverCreatedAt,
                deliveryState: deliveryState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> serverId = const Value.absent(),
                required String conversationId,
                required String clientMessageId,
                Value<int?> sequence = const Value.absent(),
                required String senderKind,
                Value<String?> bodyText = const Value.absent(),
                required String messageKind,
                required DateTime clientCreatedAt,
                Value<DateTime?> serverCreatedAt = const Value.absent(),
                Value<String> deliveryState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalMessagesCompanion.insert(
                localId: localId,
                serverId: serverId,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                sequence: sequence,
                senderKind: senderKind,
                bodyText: bodyText,
                messageKind: messageKind,
                clientCreatedAt: clientCreatedAt,
                serverCreatedAt: serverCreatedAt,
                deliveryState: deliveryState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalMessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalMessagesTable,
      LocalMessage,
      $$LocalMessagesTableFilterComposer,
      $$LocalMessagesTableOrderingComposer,
      $$LocalMessagesTableAnnotationComposer,
      $$LocalMessagesTableCreateCompanionBuilder,
      $$LocalMessagesTableUpdateCompanionBuilder,
      (
        LocalMessage,
        BaseReferences<_$AppDatabase, $LocalMessagesTable, LocalMessage>,
      ),
      LocalMessage,
      PrefetchHooks Function()
    >;
typedef $$LocalAttachmentsTableCreateCompanionBuilder =
    LocalAttachmentsCompanion Function({
      required String localId,
      Value<String?> attachmentId,
      required String conversationId,
      required String clientMessageId,
      Value<String?> localFileUri,
      Value<String> uploadState,
      Value<int> bytesTotal,
      Value<int> bytesSent,
      required String contentType,
      required String sha256,
      Value<String?> failureCode,
      Value<String?> uploadObjectPath,
      Value<int> verificationFailures,
      Value<int> rowid,
    });
typedef $$LocalAttachmentsTableUpdateCompanionBuilder =
    LocalAttachmentsCompanion Function({
      Value<String> localId,
      Value<String?> attachmentId,
      Value<String> conversationId,
      Value<String> clientMessageId,
      Value<String?> localFileUri,
      Value<String> uploadState,
      Value<int> bytesTotal,
      Value<int> bytesSent,
      Value<String> contentType,
      Value<String> sha256,
      Value<String?> failureCode,
      Value<String?> uploadObjectPath,
      Value<int> verificationFailures,
      Value<int> rowid,
    });

class $$LocalAttachmentsTableFilterComposer
    extends Composer<_$AppDatabase, $LocalAttachmentsTable> {
  $$LocalAttachmentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localFileUri => $composableBuilder(
    column: $table.localFileUri,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytesSent => $composableBuilder(
    column: $table.bytesSent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uploadObjectPath => $composableBuilder(
    column: $table.uploadObjectPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get verificationFailures => $composableBuilder(
    column: $table.verificationFailures,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalAttachmentsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalAttachmentsTable> {
  $$LocalAttachmentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localFileUri => $composableBuilder(
    column: $table.localFileUri,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytesSent => $composableBuilder(
    column: $table.bytesSent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sha256 => $composableBuilder(
    column: $table.sha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uploadObjectPath => $composableBuilder(
    column: $table.uploadObjectPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get verificationFailures => $composableBuilder(
    column: $table.verificationFailures,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalAttachmentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalAttachmentsTable> {
  $$LocalAttachmentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get attachmentId => $composableBuilder(
    column: $table.attachmentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientMessageId => $composableBuilder(
    column: $table.clientMessageId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localFileUri => $composableBuilder(
    column: $table.localFileUri,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadState => $composableBuilder(
    column: $table.uploadState,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesTotal => $composableBuilder(
    column: $table.bytesTotal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bytesSent =>
      $composableBuilder(column: $table.bytesSent, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
    column: $table.contentType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sha256 =>
      $composableBuilder(column: $table.sha256, builder: (column) => column);

  GeneratedColumn<String> get failureCode => $composableBuilder(
    column: $table.failureCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get uploadObjectPath => $composableBuilder(
    column: $table.uploadObjectPath,
    builder: (column) => column,
  );

  GeneratedColumn<int> get verificationFailures => $composableBuilder(
    column: $table.verificationFailures,
    builder: (column) => column,
  );
}

class $$LocalAttachmentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalAttachmentsTable,
          LocalAttachment,
          $$LocalAttachmentsTableFilterComposer,
          $$LocalAttachmentsTableOrderingComposer,
          $$LocalAttachmentsTableAnnotationComposer,
          $$LocalAttachmentsTableCreateCompanionBuilder,
          $$LocalAttachmentsTableUpdateCompanionBuilder,
          (
            LocalAttachment,
            BaseReferences<
              _$AppDatabase,
              $LocalAttachmentsTable,
              LocalAttachment
            >,
          ),
          LocalAttachment,
          PrefetchHooks Function()
        > {
  $$LocalAttachmentsTableTableManager(
    _$AppDatabase db,
    $LocalAttachmentsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalAttachmentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalAttachmentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalAttachmentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String?> attachmentId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> clientMessageId = const Value.absent(),
                Value<String?> localFileUri = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> bytesTotal = const Value.absent(),
                Value<int> bytesSent = const Value.absent(),
                Value<String> contentType = const Value.absent(),
                Value<String> sha256 = const Value.absent(),
                Value<String?> failureCode = const Value.absent(),
                Value<String?> uploadObjectPath = const Value.absent(),
                Value<int> verificationFailures = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttachmentsCompanion(
                localId: localId,
                attachmentId: attachmentId,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                localFileUri: localFileUri,
                uploadState: uploadState,
                bytesTotal: bytesTotal,
                bytesSent: bytesSent,
                contentType: contentType,
                sha256: sha256,
                failureCode: failureCode,
                uploadObjectPath: uploadObjectPath,
                verificationFailures: verificationFailures,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> attachmentId = const Value.absent(),
                required String conversationId,
                required String clientMessageId,
                Value<String?> localFileUri = const Value.absent(),
                Value<String> uploadState = const Value.absent(),
                Value<int> bytesTotal = const Value.absent(),
                Value<int> bytesSent = const Value.absent(),
                required String contentType,
                required String sha256,
                Value<String?> failureCode = const Value.absent(),
                Value<String?> uploadObjectPath = const Value.absent(),
                Value<int> verificationFailures = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalAttachmentsCompanion.insert(
                localId: localId,
                attachmentId: attachmentId,
                conversationId: conversationId,
                clientMessageId: clientMessageId,
                localFileUri: localFileUri,
                uploadState: uploadState,
                bytesTotal: bytesTotal,
                bytesSent: bytesSent,
                contentType: contentType,
                sha256: sha256,
                failureCode: failureCode,
                uploadObjectPath: uploadObjectPath,
                verificationFailures: verificationFailures,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalAttachmentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalAttachmentsTable,
      LocalAttachment,
      $$LocalAttachmentsTableFilterComposer,
      $$LocalAttachmentsTableOrderingComposer,
      $$LocalAttachmentsTableAnnotationComposer,
      $$LocalAttachmentsTableCreateCompanionBuilder,
      $$LocalAttachmentsTableUpdateCompanionBuilder,
      (
        LocalAttachment,
        BaseReferences<_$AppDatabase, $LocalAttachmentsTable, LocalAttachment>,
      ),
      LocalAttachment,
      PrefetchHooks Function()
    >;
typedef $$OutboxCommandsTableCreateCompanionBuilder =
    OutboxCommandsCompanion Function({
      required String id,
      required String commandType,
      required String aggregateId,
      required String clientRequestId,
      required String payloadJson,
      Value<String> state,
      Value<int> attemptCount,
      required DateTime nextAttemptAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseUntil,
      Value<String?> lastErrorCode,
      required DateTime createdAt,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$OutboxCommandsTableUpdateCompanionBuilder =
    OutboxCommandsCompanion Function({
      Value<String> id,
      Value<String> commandType,
      Value<String> aggregateId,
      Value<String> clientRequestId,
      Value<String> payloadJson,
      Value<String> state,
      Value<int> attemptCount,
      Value<DateTime> nextAttemptAt,
      Value<String?> leaseOwner,
      Value<DateTime?> leaseUntil,
      Value<String?> lastErrorCode,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$OutboxCommandsTableFilterComposer
    extends Composer<_$AppDatabase, $OutboxCommandsTable> {
  $$OutboxCommandsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OutboxCommandsTableOrderingComposer
    extends Composer<_$AppDatabase, $OutboxCommandsTable> {
  $$OutboxCommandsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OutboxCommandsTableAnnotationComposer
    extends Composer<_$AppDatabase, $OutboxCommandsTable> {
  $$OutboxCommandsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get commandType => $composableBuilder(
    column: $table.commandType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get clientRequestId => $composableBuilder(
    column: $table.clientRequestId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get nextAttemptAt => $composableBuilder(
    column: $table.nextAttemptAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get leaseOwner => $composableBuilder(
    column: $table.leaseOwner,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get leaseUntil => $composableBuilder(
    column: $table.leaseUntil,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OutboxCommandsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $OutboxCommandsTable,
          OutboxCommand,
          $$OutboxCommandsTableFilterComposer,
          $$OutboxCommandsTableOrderingComposer,
          $$OutboxCommandsTableAnnotationComposer,
          $$OutboxCommandsTableCreateCompanionBuilder,
          $$OutboxCommandsTableUpdateCompanionBuilder,
          (
            OutboxCommand,
            BaseReferences<_$AppDatabase, $OutboxCommandsTable, OutboxCommand>,
          ),
          OutboxCommand,
          PrefetchHooks Function()
        > {
  $$OutboxCommandsTableTableManager(
    _$AppDatabase db,
    $OutboxCommandsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OutboxCommandsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OutboxCommandsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OutboxCommandsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> commandType = const Value.absent(),
                Value<String> aggregateId = const Value.absent(),
                Value<String> clientRequestId = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<DateTime> nextAttemptAt = const Value.absent(),
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseUntil = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => OutboxCommandsCompanion(
                id: id,
                commandType: commandType,
                aggregateId: aggregateId,
                clientRequestId: clientRequestId,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                leaseOwner: leaseOwner,
                leaseUntil: leaseUntil,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String commandType,
                required String aggregateId,
                required String clientRequestId,
                required String payloadJson,
                Value<String> state = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                required DateTime nextAttemptAt,
                Value<String?> leaseOwner = const Value.absent(),
                Value<DateTime?> leaseUntil = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => OutboxCommandsCompanion.insert(
                id: id,
                commandType: commandType,
                aggregateId: aggregateId,
                clientRequestId: clientRequestId,
                payloadJson: payloadJson,
                state: state,
                attemptCount: attemptCount,
                nextAttemptAt: nextAttemptAt,
                leaseOwner: leaseOwner,
                leaseUntil: leaseUntil,
                lastErrorCode: lastErrorCode,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OutboxCommandsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $OutboxCommandsTable,
      OutboxCommand,
      $$OutboxCommandsTableFilterComposer,
      $$OutboxCommandsTableOrderingComposer,
      $$OutboxCommandsTableAnnotationComposer,
      $$OutboxCommandsTableCreateCompanionBuilder,
      $$OutboxCommandsTableUpdateCompanionBuilder,
      (
        OutboxCommand,
        BaseReferences<_$AppDatabase, $OutboxCommandsTable, OutboxCommand>,
      ),
      OutboxCommand,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalConversationsTableTableManager get localConversations =>
      $$LocalConversationsTableTableManager(_db, _db.localConversations);
  $$LocalMessagesTableTableManager get localMessages =>
      $$LocalMessagesTableTableManager(_db, _db.localMessages);
  $$LocalAttachmentsTableTableManager get localAttachments =>
      $$LocalAttachmentsTableTableManager(_db, _db.localAttachments);
  $$OutboxCommandsTableTableManager get outboxCommands =>
      $$OutboxCommandsTableTableManager(_db, _db.outboxCommands);
}
