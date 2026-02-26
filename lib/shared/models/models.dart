import 'package:equatable/equatable.dart';

class PropertyModel extends Equatable {
  final String id;
  final String ownerId;
  final String name;
  final String address;
  final String type;
  final int bedrooms;
  final int bathrooms;
  final int maxGuests;
  final double nightlyRate;
  final List<String> images;
  final bool isActive;
  final DateTime createdAt;

  const PropertyModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.address,
    required this.type,
    required this.bedrooms,
    required this.bathrooms,
    required this.maxGuests,
    required this.nightlyRate,
    required this.images,
    required this.isActive,
    required this.createdAt,
  });

  factory PropertyModel.fromJson(Map<String, dynamic> json) => PropertyModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        name: json['name'] as String,
        address: json['address'] as String? ?? '',
        type: json['type'] as String? ?? 'apartment',
        bedrooms: json['bedrooms'] as int? ?? 1,
        bathrooms: json['bathrooms'] as int? ?? 1,
        maxGuests: json['max_guests'] as int? ?? 2,
        nightlyRate: (json['nightly_rate'] as num?)?.toDouble() ?? 0,
        images: (json['images'] as List<dynamic>?)?.cast<String>() ?? [],
        isActive: json['is_active'] as bool? ?? true,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'owner_id': ownerId,
        'name': name,
        'address': address,
        'type': type,
        'bedrooms': bedrooms,
        'bathrooms': bathrooms,
        'max_guests': maxGuests,
        'nightly_rate': nightlyRate,
        'images': images,
        'is_active': isActive,
      };

  PropertyModel copyWith({
    String? name,
    String? address,
    String? type,
    int? bedrooms,
    int? bathrooms,
    int? maxGuests,
    double? nightlyRate,
    List<String>? images,
    bool? isActive,
  }) =>
      PropertyModel(
        id: id,
        ownerId: ownerId,
        name: name ?? this.name,
        address: address ?? this.address,
        type: type ?? this.type,
        bedrooms: bedrooms ?? this.bedrooms,
        bathrooms: bathrooms ?? this.bathrooms,
        maxGuests: maxGuests ?? this.maxGuests,
        nightlyRate: nightlyRate ?? this.nightlyRate,
        images: images ?? this.images,
        isActive: isActive ?? this.isActive,
        createdAt: createdAt,
      );

  @override
  List<Object?> get props => [id, ownerId, name, address, type, bedrooms,
        bathrooms, maxGuests, nightlyRate, images, isActive, createdAt];
}

class GuestModel extends Equatable {
  final String id;
  final String ownerId;
  final String fullName;
  final String email;
  final String phone;
  final String nationality;
  final DateTime createdAt;

  const GuestModel({
    required this.id,
    required this.ownerId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.nationality,
    required this.createdAt,
  });

  factory GuestModel.fromJson(Map<String, dynamic> json) => GuestModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        fullName: json['full_name'] as String,
        email: json['email'] as String? ?? '',
        phone: json['phone'] as String? ?? '',
        nationality: json['nationality'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'owner_id': ownerId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'nationality': nationality,
      };

  @override
  List<Object?> get props => [id, ownerId, fullName, email, phone, nationality];
}

class BookingModel extends Equatable {
  final String id;
  final String propertyId;
  final String guestId;
  final String ownerId;
  final DateTime checkIn;
  final DateTime checkOut;
  final double totalPrice;
  final String status;
  final String notes;
  final DateTime createdAt;
  // Joined fields
  final PropertyModel? property;
  final GuestModel? guest;

  const BookingModel({
    required this.id,
    required this.propertyId,
    required this.guestId,
    required this.ownerId,
    required this.checkIn,
    required this.checkOut,
    required this.totalPrice,
    required this.status,
    required this.notes,
    required this.createdAt,
    this.property,
    this.guest,
  });

  int get nights => checkOut.difference(checkIn).inDays;

  factory BookingModel.fromJson(Map<String, dynamic> json) => BookingModel(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        guestId: json['guest_id'] as String,
        ownerId: json['owner_id'] as String,
        checkIn: DateTime.parse(json['check_in'] as String),
        checkOut: DateTime.parse(json['check_out'] as String),
        totalPrice: (json['total_price'] as num?)?.toDouble() ?? 0,
        status: json['status'] as String? ?? 'confirmed',
        notes: json['notes'] as String? ?? '',
        createdAt: DateTime.parse(json['created_at'] as String),
        property: json['properties'] != null
            ? PropertyModel.fromJson(json['properties'] as Map<String, dynamic>)
            : null,
        guest: json['guests'] != null
            ? GuestModel.fromJson(json['guests'] as Map<String, dynamic>)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'property_id': propertyId,
        'guest_id': guestId,
        'owner_id': ownerId,
        'check_in': checkIn.toIso8601String().split('T')[0],
        'check_out': checkOut.toIso8601String().split('T')[0],
        'total_price': totalPrice,
        'status': status,
        'notes': notes,
      };

  @override
  List<Object?> get props => [id, propertyId, guestId, status, checkIn, checkOut];
}

class ExpenseModel extends Equatable {
  final String id;
  final String propertyId;
  final String ownerId;
  final String category;
  final double amount;
  final String description;
  final DateTime date;
  final DateTime createdAt;

  const ExpenseModel({
    required this.id,
    required this.propertyId,
    required this.ownerId,
    required this.category,
    required this.amount,
    required this.description,
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) => ExpenseModel(
        id: json['id'] as String,
        propertyId: json['property_id'] as String,
        ownerId: json['owner_id'] as String,
        category: json['category'] as String? ?? 'other',
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        description: json['description'] as String? ?? '',
        date: DateTime.parse(json['date'] as String),
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  Map<String, dynamic> toJson() => {
        'property_id': propertyId,
        'owner_id': ownerId,
        'category': category,
        'amount': amount,
        'description': description,
        'date': date.toIso8601String().split('T')[0],
      };

  @override
  List<Object?> get props => [id, propertyId, ownerId, amount, date];
}

class UserProfile extends Equatable {
  final String id;
  final String fullName;
  final String email;
  final String? avatarUrl;
  final DateTime createdAt;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.email,
    this.avatarUrl,
    required this.createdAt,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String,
        fullName: json['full_name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        avatarUrl: json['avatar_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );

  @override
  List<Object?> get props => [id, email, fullName];
}
