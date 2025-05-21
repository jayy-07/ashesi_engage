import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../models/entities/student_proposal.dart';
import '../../../models/services/auth_service.dart';
import '../../../models/services/proposal_service.dart';
import '../../../viewmodels/user_viewmodel.dart';
import '../../../widgets/snackbar_helper.dart';

class WriteProposalPage extends StatefulWidget {
  const WriteProposalPage({super.key});

  @override
  State<WriteProposalPage> createState() => _WriteProposalPageState();
}

class _WriteProposalPageState extends State<WriteProposalPage> {
  final QuillController _controller = QuillController.basic();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _titleController = TextEditingController();
  int _characterCount = 0;
  final int _characterLimit = 2200;
  final int _titleCharacterLimit = 100;
  bool _isSending = false;
  ProposalTier _selectedTier = ProposalTier.minor;

  bool get _isValidProposal {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasContent = _controller.document.toPlainText().trim().isNotEmpty;
    final isUnderCharLimit = _characterCount <= _characterLimit;
    return hasTitle && hasContent && isUnderCharLimit;
  }


  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateCharacterCount);
    _titleController.addListener(() => setState(() {}));
    _controller.addListener(() => setState(() {}));
  }

  void _updateCharacterCount() {
    setState(() {
      _characterCount = _controller.document.toPlainText().length;
    });
  }

  void _sendProposal() async {
    if (!_isValidProposal) return;
    
    setState(() => _isSending = true);
    
    try {
      final proposalService = ProposalService();
      final authService = Provider.of<AuthService>(context, listen: false);
      final userViewModel = Provider.of<UserViewModel>(context, listen: false);
      final user = authService.currentUser;

      if (user == null) {
        SnackbarHelper.showError(context, 'You must be logged in to submit a proposal');
        return;
      }

      final firstName = userViewModel.firstName;
      final lastName = userViewModel.lastName;
      final studentClass = userViewModel.classYear; // Get class from profile
      
      if (firstName == null || lastName == null || studentClass == null) {
        SnackbarHelper.showError(context, 'Please complete your profile first');
        return;
      }

      final delta = _controller.document.toDelta();
      final plainText = _controller.document.toPlainText();

      await proposalService.createProposal(
        authorId: user.uid,
        authorName: '$firstName $lastName',
        title: _titleController.text.trim(),
        content: delta,
        plainContent: plainText,
        authorClass: studentClass, // Use class from profile
        authorAvatar: userViewModel.profileImageUrl ?? '',
        tier: _selectedTier, // Add the selected tier
      );

      if (mounted) {
        Navigator.pop(context);
        SnackbarHelper.showSuccess(context, 'Proposal sent');
      }
    } catch (e) {
      if (mounted) {
        SnackbarHelper.showError(context, 'Failed to submit proposal: $e');
      }
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
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Proposal'),
        forceMaterialTransparency: true,
        actions: [
          // Tier Selection PopupMenuButton (now first)
          PopupMenuButton<ProposalTier>(
            onSelected: (ProposalTier tier) {
              setState(() {
                _selectedTier = tier;
              });
            },
            itemBuilder: (BuildContext context) {
              return ProposalTier.values.map((ProposalTier tier) {
                return PopupMenuItem<ProposalTier>(
                  value: tier,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(tier.label),
                      Text(
                        '${tier.requiredSignatures} sigs', // Shortened for PopupMenu
                        style: TextStyle(
                          fontSize: theme.textTheme.bodySmall?.fontSize,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList();
            },
            icon: const Icon(Icons.layers_outlined), 
            tooltip: 'Impact: ${_selectedTier.label} (${_selectedTier.requiredSignatures} sigs)', // Updated tooltip
          ),
          // Send Button (IconButton - now second)
          IconButton(
            icon: _isSending 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.send),
            onPressed: _isValidProposal && !_isSending ? _sendProposal : null,
            tooltip: 'Send Proposal',
          ),
          const SizedBox(width: 8), // Spacing at the end
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha:0.95),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                TextField(
                  controller: _titleController,
                  maxLength: _titleCharacterLimit,
                  decoration: InputDecoration(
                    hintText: 'Enter your proposal title',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha:0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary.withValues(alpha:0.2)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    fillColor: theme.colorScheme.surface,
                    filled: true,
                  ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.dark
                          ? theme.colorScheme.surface.withValues(alpha:0.8)
                          : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.brightness == Brightness.dark
                            ? theme.colorScheme.onSurface.withValues(alpha:0.2)
                            : theme.colorScheme.outline.withValues(alpha:0.3),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Column(
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.dark
                                    ? theme.colorScheme.surface.withValues(alpha:0.3)
                                    : theme.colorScheme.surface,
                              ),
                              child: QuillEditor(
                                controller: _controller,
                                focusNode: _focusNode,
                                scrollController: _scrollController,
                                configurations: QuillEditorConfigurations(
                                  scrollable: true,
                                  padding: const EdgeInsets.all(20),
                                  autoFocus: false,
                                  expands: false,
                                  placeholder: 'Write your proposal here...',
                                  enableInteractiveSelection: true,
                                ),
                              ),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                top: BorderSide(color: theme.dividerColor.withValues(alpha: 0.1)),
                              ),
                              color: theme.colorScheme.surface,
                            ),
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
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: _characterCount > _characterLimit
                                            ? theme.colorScheme.error.withValues(alpha: 0.1)
                                            : theme.colorScheme.primary.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          'Characters: $_characterCount/$_characterLimit',
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: _characterCount > _characterLimit 
                                              ? theme.colorScheme.error
                                              : theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}