/// A single message in a conversation. `senderRole` is 'vendor',
/// 'customer', or 'system' (automated status notes). Attachment / metadata
/// fields are present now so photos, documents, voice and location can be
/// added without a model change.
class Message {
  final String id;
  final String conversationId;
  final String senderRole; // 'vendor' | 'customer' | 'system'
  final String? senderUserId;
  final String body;
  final String messageType; // 'text' | 'image' | 'document' | 'voice' | 'location' | 'system'
  final String? attachmentUrl;
  final Map<String, dynamic>? metadata;
  final DateTime? deliveredAt;
  final DateTime? readAt;
  final DateTime createdAt;

  const Message({
    required this.id,
    required this.conversationId,
    required this.senderRole,
    this.senderUserId,
    required this.body,
    this.messageType = 'text',
    this.attachmentUrl,
    this.metadata,
    this.deliveredAt,
    this.readAt,
    required this.createdAt,
  });

  bool get isSystem => senderRole == 'system';

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        id: json['id'] as String,
        conversationId: json['conversation_id'] as String,
        senderRole: json['sender_role'] as String,
        senderUserId: json['sender_user_id'] as String?,
        body: json['body'] as String? ?? '',
        messageType: json['message_type'] as String? ?? 'text',
        attachmentUrl: json['attachment_url'] as String?,
        metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
        deliveredAt: json['delivered_at'] == null
            ? null
            : DateTime.parse(json['delivered_at'] as String),
        readAt: json['read_at'] == null
            ? null
            : DateTime.parse(json['read_at'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
