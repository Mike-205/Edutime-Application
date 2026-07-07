import 'package:equatable/equatable.dart';

/// Mirrors the `user_role` enum in the database.
enum UserRole { student, classRep, facultyRep }

UserRole userRoleFromDb(String value) => switch (value) {
  'student' => UserRole.student,
  'class_rep' => UserRole.classRep,
  'faculty_rep' => UserRole.facultyRep,
  _ => throw ArgumentError('Unknown role: $value'),
};

/// A platform user. `email` is readable only by the owner + superadmin (DPA),
/// so it is nullable here for rows fetched via the cohort-member directory.
class AppUser extends Equatable {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.role,
    this.email,
    this.cohortId,
  });

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    fullName: map['full_name'] as String,
    role: userRoleFromDb(map['role'] as String),
    email: map['email'] as String?,
    cohortId: map['cohort_id'] as String?,
  );

  final String id;
  final String fullName;
  final UserRole role;
  final String? email;
  final String? cohortId;

  @override
  List<Object?> get props => [id, fullName, role, email, cohortId];
}
