import 'package:cloud_firestore/cloud_firestore.dart';
import '../entities/report.dart';

class ReportService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Submit a new report
  Future<void> submitReport({
    required String contentType,
    required String contentId,
    required String reporterId,
    required String reason,
    String? additionalInfo,
  }) async {
    try {
      await _firestore.collection('reports').add({
        'contentType': contentType,
        'contentId': contentId,
        'reporterId': reporterId,
        'reason': reason,
        'additionalInfo': additionalInfo,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      throw Exception('Failed to submit report: $e');
    }
  }

  // Get all reports for a specific content
  Stream<List<Report>> getReportsForContent(String contentId) {
    return _firestore
        .collection('reports')
        .where('contentId', isEqualTo: contentId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Report.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Get all reports by a specific user
  Stream<List<Report>> getUserReports(String userId) {
    return _firestore
        .collection('reports')
        .where('reporterId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Report.fromMap(doc.id, doc.data()))
            .toList());
  }

  // Update report status (for admin use)
  Future<void> updateReportStatus(String reportId, String newStatus) async {
    try {
      await _firestore.collection('reports').doc(reportId).update({
        'status': newStatus,
      });
    } catch (e) {
      throw Exception('Failed to update report status: $e');
    }
  }

  // Get all reports for admin view
  Stream<List<Report>> getAllReports() {
    return _firestore
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Report.fromMap(doc.id, doc.data()))
            .toList());
  }
}