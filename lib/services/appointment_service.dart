import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Creates a new appointment in Firestore
  static Future<void> addAppointment(String userId, String astrologistId, DateTime scheduledTime) async {
    await _firestore.collection('appointments').add({
      'user_id': userId,
      'astrologist_id': astrologistId,
      'scheduled_time': scheduledTime,
      'status': 'pending', // pending, confirmed, cancelled
      'created_at': FieldValue.serverTimestamp(),
    });
  }

  /// Retrieves all appointments for a specific user
  static Stream<QuerySnapshot> getUserAppointments(String userId) {
    return _firestore
        .collection('appointments')
        .where('user_id', isEqualTo: userId)
        .orderBy('scheduled_time', descending: true)
        .snapshots();
  }

  /// Retrieves all appointments for a specific astrologist
  static Stream<QuerySnapshot> getAstrologistAppointments(String astrologistId) {
    return _firestore
        .collection('appointments')
        .where('astrologist_id', isEqualTo: astrologistId)
        .orderBy('scheduled_time', descending: true)
        .snapshots();
  }

  /// Retrieves all appointments for a user without sorting
  static Stream<QuerySnapshot> getAppointments(String userId) {
    return _firestore
        .collection('appointments')
        .where('user_id', isEqualTo: userId)
        .snapshots();
  }

  /// Updates the status of an appointment
  static Future<void> updateAppointmentStatus(String appointmentId, String status) async {
    await _firestore.collection('appointments').doc(appointmentId).update({
      'status': status,
    });
  }
}