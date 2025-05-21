import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import '../../../viewmodels/write_discussion_viewmodel.dart';
import '../../../viewmodels/user_viewmodel.dart';
import '../../../models/services/discussion_service.dart';
import '../../../models/services/auth_service.dart';
import '../../../widgets/snackbar_helper.dart';

class WriteDiscussionPage extends StatelessWidget {
  const WriteDiscussionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => WriteDiscussionViewModel(
        discussionService: DiscussionService(),
        authService: Provider.of<AuthService>(context, listen: false),
        quillController: QuillController.basic(),
      ),
      child: const _WriteDiscussionView(),
    );
  }
}

class _WriteDiscussionView extends StatefulWidget {
  const _WriteDiscussionView();

  @override
  State<_WriteDiscussionView> createState() => _WriteDiscussionViewState();
}

class _WriteDiscussionViewState extends State<_WriteDiscussionView> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Request focus after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit(BuildContext context, WriteDiscussionViewModel viewModel) async {
    final userVM = Provider.of<UserViewModel>(context, listen: false);
    
    if (userVM.firstName == null || userVM.lastName == null || userVM.classYear == null) {
      SnackbarHelper.showError(context, 'Please complete your profile first');
      return;
    }

    final success = await viewModel.submitDiscussion(
      authorName: '${userVM.firstName!} ${userVM.lastName!}',
      authorClass: userVM.classYear!,
      authorAvatar: userVM.profileImageUrl ?? '', // Add fallback URL
    );

    if (success && context.mounted) {
      Navigator.pop(context);
      SnackbarHelper.showSuccess(context, 'Discussion posted');
    } else if (context.mounted) {
      SnackbarHelper.showError(context, 'Failed to post discussion');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = context.watch<WriteDiscussionViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Post'),
        actions: [
          // Changed FilledButton.icon to IconButton
          IconButton(
            icon: viewModel.isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white), // Ensure color contrast if needed
                  )
                : const Icon(Icons.send),
            onPressed: viewModel.canSubmit 
              ? () => _handleSubmit(context, viewModel)
              : null,
            tooltip: 'Post Discussion', // Added tooltip
          ),
          const SizedBox(width: 8), // Added spacing similar to the proposal page
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface.withValues(alpha: 0.95),
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
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
                                ? theme.colorScheme.surface.withValues(alpha: 0.3)
                                : theme.colorScheme.surface,
                          ),
                          child: QuillEditor(
                            controller: viewModel.quillController,
                            focusNode: _focusNode, // Use the managed focus node
                            scrollController: ScrollController(),
                            configurations: QuillEditorConfigurations(
                              scrollable: true,
                              padding: const EdgeInsets.all(16),
                              placeholder: 'Share your thoughts...',
                              autoFocus: true, // Set autoFocus to true
                              expands: false,
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
                              controller: viewModel.quillController,
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
                                      color: viewModel.isOverCharacterLimit
                                          ? theme.colorScheme.error.withValues(alpha: 0.1)
                                          : theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Characters: ${viewModel.characterCount}/${viewModel.characterLimit}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: viewModel.isOverCharacterLimit
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
    );
  }
}
