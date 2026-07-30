/// A customer review of a completed appointment. Matches the shared reviews
/// table: authorship is via the appointment (no user_id), the reviewer name is
/// the denormalized customer_name, and visibility is is_published AND status.
class Review {
  final String id;
  final String businessId;
  final String appointmentId;
  final int rating;
  final String? body;
  final bool isPublished;
  final String status; // published | reported | flagged | removed | hidden
  final String? businessReply;
  final DateTime? businessReplyAt;
  final DateTime? editedAt;
  final DateTime createdAt;
  final String? reviewerName;

  const Review({
    required this.id,
    required this.businessId,
    required this.appointmentId,
    required this.rating,
    this.body,
    this.isPublished = true,
    this.status = 'published',
    this.businessReply,
    this.businessReplyAt,
    this.editedAt,
    required this.createdAt,
    this.reviewerName,
  });

  /// Shown publicly = published by the web flag AND not moderated out.
  bool get isVisible => isPublished && status == 'published';
  bool get hasReply => (businessReply ?? '').trim().isNotEmpty;

  factory Review.fromJson(Map<String, dynamic> json) => Review(
        id: json['id'] as String,
        businessId: json['business_id'] as String,
        appointmentId: json['appointment_id'] as String,
        rating: json['rating'] as int? ?? 0,
        body: json['body'] as String?,
        isPublished: json['is_published'] as bool? ?? true,
        status: json['status'] as String? ?? 'published',
        businessReply: json['business_reply'] as String?,
        businessReplyAt: json['business_reply_at'] != null
            ? DateTime.parse(json['business_reply_at'] as String)
            : null,
        editedAt: json['edited_at'] != null
            ? DateTime.parse(json['edited_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
        reviewerName: json['customer_name'] as String?,
      );
}

const String reviewSelectColumns = '''
  id, business_id, appointment_id, rating, body, is_published, status,
  business_reply, business_reply_at, edited_at, created_at, customer_name
''';
