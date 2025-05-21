import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/student_proposal.dart';
import '../../../models/services/auth_service.dart';
import '../../../models/services/proposal_service.dart';
import '../../../viewmodels/user_viewmodel.dart';

class AnswerProposalScreen extends StatefulWidget {
  final StudentProposal proposal;

  const AnswerProposalScreen({
    super.key,
    required this.proposal,
  });

  @override
  State<AnswerProposalScreen> createState() => _AnswerProposalScreenState();
}

class _AnswerProposalScreenState extends State<AnswerProposalScreen> {
  final QuillController _controller = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  int _characterCount = 0;
  final int _characterLimit = 5000;

  bool get _isValidAnswer {
    final hasContent = _controller.document.toPlainText().trim().isNotEmpty;
    final isUnderCharLimit = _characterCount <= _characterLimit;
    return hasContent && isUnderCharLimit;
  }

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCharacterCount);
    _controller.addListener(() => setState(() {}));
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _controller.document.toPlainText().length;
    });
  }

  void _submitAnswer() async {
    if (!_isValidAnswer) return;
    
    setState(() => _isSending = true);
    
    try {
      final proposalService = ProposalService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final userViewModel = Provider.of<UserViewModel>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to answer proposals')),
        );
        return;
      }

      final firstName = userViewModel.firstName;
      final lastName = userViewModel.lastName;
      
      if (firstName == null || lastName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please complete your profile first')),
        );
        return;
      }

      final delta = _controller.document.toDelta();
      final plainText = _controller.document.toPlainText();

      await proposalService.answerProposal(
        proposalId: widget.proposal.id,
        answer: delta,
        plainAnswer: plainText,
        adminId: user.uid,
        adminName: '$firstName $lastName',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer submitted successfully')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit answer: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Answer Proposal'),
        actions: [
          if (_isSending)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: FilledButton(
                onPressed: _isValidAnswer ? _submitAnswer : null,
                child: const Text('Submit Answer'),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Original proposal section
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha:0.5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Original Proposal',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.proposal.title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.proposal.plainContent,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Answer editor section
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  QuillToolbar.simple(
                    controller: _controller,
                    configurations: QuillSimpleToolbarConfigurations(
                      showFontFamily: false,
                      showFontSize: false,
                      showBackgroundColorButton: false,
                      showClearFormat: false,
                      showColorButton: false,
                      showCodeBlock: false,
                      showQuote: false,
                      showSubscript: false,
                      showSuperscript: false,
                      showSearchButton: false,
                      showAlignmentButtons: false,
                      showHeaderStyle: false,
                      showIndent: false,
                      showLink: false,
                      showInlineCode: false,
                      showDirection: false,
                      showDividers: false,
                      showStrikeThrough: false,
                      showListCheck: false,
                      showClipboardCopy: false,
                      showClipboardCut: false,
                      showClipboardPaste: false,
                      multiRowsDisplay: false,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha:0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: QuillEditor(
                        controller: _controller,
                        focusNode: _focusNode,
                        scrollController: _scrollController,
                        configurations: QuillEditorConfigurations(
                          placeholder: 'Write your answer here...',
                          autoFocus: true,
                          expands: true,
                          padding: EdgeInsets.zero,
                          scrollable: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '$_characterCount/$_characterLimit characters',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _characterCount > _characterLimit
                              ? theme.colorScheme.error
                              : theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 