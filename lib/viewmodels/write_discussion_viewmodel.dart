import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../models/services/discussion_service.dart';
import '../models/services/auth_service.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'mixins/offline_action_mixin.dart';
import 'package:uuid/uuid.dart';

class WriteDiscussionViewModel extends ChangeNotifier with OfflineActionMixin {
  final DiscussionService _discussionService;
  final AuthService _authService;
  final QuillController quillController;
  bool _isSending = false;
  final int characterLimit = 500;
  final _uuid = const Uuid();

  WriteDiscussionViewModel({
    required DiscussionService discussionService,
    required AuthService authService,
    required this.quillController,
  }) : _discussionService = discussionService,
       _authService = authService {
    quillController.addListener(_onTextChanged);
  }

  bool get isSending => _isSending;
  bool get isOverCharacterLimit => characterCount > characterLimit;
  int get characterCount => quillController.document.toPlainText().length;
  bool get canSubmit => !isSending && characterCount > 0 && !isOverCharacterLimit;

  Future<bool> submitDiscussion({
    required String authorName,
    required String authorClass,
    required String authorAvatar,
  }) async {
    if (!canSubmit) return false;
    
    _isSending = true;
    notifyListeners();

    try {
      final user = _authService.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final content = quillController.document.toPlainText();
      final contentDelta = quillController.document.toDelta();
      final discussionId = _uuid.v4();

      try {
        await _discussionService.createDiscussion(
          authorId: user.uid,
          content: content,
          contentDelta: contentDelta,
          authorName: authorName,
          authorClass: authorClass,
          authorAvatar: authorAvatar,
        );
        _isSending = false;
        notifyListeners();
        return true;
      } on FirebaseException catch (e) {
        if (e.code == 'unavailable') {
          // Handle offline case
          addPendingAction(PendingAction(
            type: 'discussion',
            id: discussionId,
            data: {
              'authorId': user.uid,
              'content': content,
              'contentDelta': contentDelta.toJson(),
              'authorName': authorName,
              'authorClass': authorClass,
              'authorAvatar': authorAvatar,
            },
          ));
          _isSending = false;
          notifyListeners();
          return true;
        }
        rethrow;
      }
    } catch (e) {
      _isSending = false;
      notifyListeners();
      rethrow;
    }
  }

  void _onTextChanged() {
    notifyListeners();
  }

  @override
  void dispose() {
    quillController.removeListener(_onTextChanged);
    quillController.dispose();
    super.dispose();
  }

  @override
  Future<void> processPendingAction(PendingAction action) async {
    if (action.type == 'discussion') {
      await _discussionService.createDiscussion(
        authorId: action.data['authorId'],
        content: action.data['content'],
        contentDelta: Delta.fromJson(action.data['contentDelta']),
        authorName: action.data['authorName'],
        authorClass: action.data['authorClass'],
        authorAvatar: action.data['authorAvatar'],
      );
    }
  }
}
