import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../models/entities/article.dart';
import '../../../viewmodels/article_viewmodel.dart';
import '../../../viewmodels/user_viewmodel.dart';

class WriteArticlePage extends StatefulWidget {
  final Article? article;

  const WriteArticlePage({
    super.key,
    this.article,
  });

  @override
  State<WriteArticlePage> createState() => _WriteArticlePageState();
}

class _WriteArticlePageState extends State<WriteArticlePage> {
  late final QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final TextEditingController _titleController;
  final ImagePicker _imagePicker = ImagePicker();
  String? _thumbnailUrl;
  File? _thumbnailFile;
  Uint8List? _webImage;
  bool _isSending = false;
  bool _isUploadingImage = false;
  bool _isToolbarExpanded = true;

  bool get _isValidArticle {
    final hasTitle = _titleController.text.trim().isNotEmpty;
    final hasContent = _controller.document.toPlainText().trim().isNotEmpty;
    return hasTitle && hasContent;
  }

  @override
  void initState() {
    super.initState();
    // Initialize controllers with existing data if editing
    _controller = QuillController.basic();
    if (widget.article != null) {
      _controller.document = Document.fromJson(widget.article!.content['ops']);
    }
    
    _titleController = TextEditingController(text: widget.article?.title ?? '');
    _thumbnailUrl = widget.article?.thumbnailUrl;
    
    _controller.addListener(() => setState(() {}));
    _titleController.addListener(() => setState(() {}));
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        if (kIsWeb) {
          // Handle web platform
          final bytes = await image.readAsBytes();
          setState(() {
            _webImage = bytes;
            _thumbnailFile = null;
          });
        } else {
          // Handle mobile platform
          setState(() {
            _thumbnailFile = File(image.path);
            _webImage = null;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  Future<void> _pickContentImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image != null && mounted) {
        final viewModel = Provider.of<ArticleViewModel>(context, listen: false);
        final tempId = DateTime.now().millisecondsSinceEpoch.toString();
        
        setState(() => _isUploadingImage = true);
        
        String? url;
        if (kIsWeb) {
          // For web, read bytes and upload
          final bytes = await image.readAsBytes();
          url = await viewModel.uploadWebImage(bytes, tempId);
        } else {
          // For mobile, use File
          url = await viewModel.uploadImage(File(image.path), tempId);
        }
        
        setState(() => _isUploadingImage = false);
        
        if (url != null && mounted) {
          // Insert the image into the editor
          final index = _controller.selection.baseOffset;
          final length = _controller.selection.extentOffset - index;
          
          // Insert a newline before the image if we're not at the start of a line
          if (index > 0 && _controller.document.toPlainText()[index - 1] != '\n') {
            _controller.replaceText(index, 0, '\n', null);
          }
          
          // Insert the image
          _controller.replaceText(
            _controller.selection.baseOffset,
            length,
            BlockEmbed.image(url),
            null,
          );
          
          // Insert a newline after the image
          _controller.replaceText(
            _controller.selection.baseOffset,
            0,
            '\n',
            null,
          );
        }
      }
    } catch (e) {
      setState(() => _isUploadingImage = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add image: $e')),
        );
      }
    }
  }

  Future<void> _uploadThumbnail(String articleId) async {
    if (_thumbnailFile == null && _webImage == null) return;

    setState(() => _isUploadingImage = true);
    try {
      String? url;
      if (kIsWeb && _webImage != null) {
        // Upload web image
        url = await context.read<ArticleViewModel>().uploadWebImage(
          _webImage!,
          articleId,
        );
      } else if (!kIsWeb && _thumbnailFile != null) {
        // Upload file from mobile
        url = await context.read<ArticleViewModel>().uploadImage(
          _thumbnailFile!,
          articleId,
        );
      }
      
      if (url != null) {
        setState(() => _thumbnailUrl = url);
      }
    } finally {
      setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _sendArticle() async {
    if (!_isValidArticle) return;
    
    setState(() => _isSending = true);
    
    try {
      final userViewModel = Provider.of<UserViewModel>(context, listen: false);
      final user = userViewModel.currentUser;

      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to create a article')),
        );
        return;
      }

      final article = Article(
        id: widget.article?.id ?? '',
        title: _titleController.text.trim(),
        authorId: user.uid,
        authorName: '${userViewModel.firstName} ${userViewModel.lastName}',
        authorAvatar: userViewModel.profileImageUrl ?? '',
        content: {'ops': _controller.document.toDelta().toJson()},
        plainContent: _controller.document.toPlainText(),
        thumbnailUrl: _thumbnailUrl,
        datePublished: widget.article?.datePublished ?? DateTime.now(),
        isPublished: false,
        isFeatured: widget.article?.isFeatured ?? false,
      );

      final viewModel = context.read<ArticleViewModel>();
      String? id;
      
      if (widget.article != null) {
        await viewModel.updateArticle(article);
        id = article.id;
      } else {
        id = await viewModel.createArticle(article);
      }
      
      if (id != null && (_thumbnailFile != null || _webImage != null)) {
        await _uploadThumbnail(id);
        if (_thumbnailUrl != null) {
          await viewModel.updateArticle(
            article.copyWith(
              id: id,
              thumbnailUrl: _thumbnailUrl,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(widget.article != null ? 'Article updated' : 'Article created'),
              ],
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to ${widget.article != null ? 'update' : 'create'} article: $e')),
        );
      }
    
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
    final screenWidth = MediaQuery.of(context).size.width;
    final isLargeScreen = screenWidth > 1200;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Write Article'),
        forceMaterialTransparency: true,
        actions: [
          if (_isUploadingImage)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ElevatedButton.icon(
              icon: _isSending 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send, size: 20),
              label: const Text('Save Draft'),
              onPressed: _isValidArticle && !_isSending ? _sendArticle : null,
              style: ElevatedButton.styleFrom(
                elevation: 0,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
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
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: isLargeScreen
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column - Title and Thumbnail
                    SizedBox(
                      width: 400,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTitleInput(theme),
                          const SizedBox(height: 24),
                          _buildThumbnailPicker(theme),
                        ],
                      ),
                    ),
                    const SizedBox(width: 24),
                    // Right column - Rich Text Editor
                    Expanded(
                      child: _buildEditor(theme),
                    ),
                  ],
                )
              : Column(
                  children: [
                    _buildTitleInput(theme),
                    const SizedBox(height: 24),
                    _buildThumbnailPicker(theme),
                    const SizedBox(height: 24),
                    Expanded(
                      child: _buildEditor(theme),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTitleInput(ThemeData theme) {
    return TextField(
      controller: _titleController,
      decoration: InputDecoration(
        hintText: 'Enter article title',
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
    );
  }

  Widget _buildThumbnailPicker(ThemeData theme) {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        height: 200,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha:0.5),
          ),
        ),
        child: (_thumbnailFile != null || _webImage != null)
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb && _webImage != null
                    ? Image.memory(
                        _webImage!,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      )
                    : !kIsWeb && _thumbnailFile != null
                        ? Image.file(
                            _thumbnailFile!,
                            fit: BoxFit.cover,
                            width: double.infinity,
                          )
                        : Container(
                            color: theme.colorScheme.surfaceVariant,
                            child: Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: theme.colorScheme.error,
                            ),
                          ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 48,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add Thumbnail Image',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEditor(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha:0.3),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
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
                    placeholder: 'Write your article here...',
                    enableInteractiveSelection: true,
                    onImagePaste: (imageBytes) async {
                      if (kIsWeb) {
                        try {
                          setState(() => _isUploadingImage = true);
                          final viewModel = Provider.of<ArticleViewModel>(context, listen: false);
                          final tempId = DateTime.now().millisecondsSinceEpoch.toString();
                          final url = await viewModel.uploadWebImage(imageBytes, tempId);
                          setState(() => _isUploadingImage = false);
                          return url;
                        } catch (e) {
                          setState(() => _isUploadingImage = false);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to paste image: $e')),
                            );
                          }
                          return null;
                        }
                      }
                      return null;
                    },
                    customStyles: DefaultStyles(
                      h1: DefaultTextBlockStyle(
                        TextStyle(
                          fontSize: 32,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        const HorizontalSpacing(16, 0),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const BoxDecoration(),
                      ),
                      h2: DefaultTextBlockStyle(
                        TextStyle(
                          fontSize: 24,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        const HorizontalSpacing(12, 0),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const BoxDecoration(),
                      ),
                      h3: DefaultTextBlockStyle(
                        TextStyle(
                          fontSize: 20,
                          height: 1.3,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        const HorizontalSpacing(10, 0),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const BoxDecoration(),
                      ),
                      paragraph: DefaultTextBlockStyle(
                        TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurface,
                        ),
                        const HorizontalSpacing(0, 8),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const BoxDecoration(),
                      ),
                      placeHolder: DefaultTextBlockStyle(
                        TextStyle(
                          fontSize: 16,
                          height: 1.5,
                          color: theme.colorScheme.onSurface.withValues(alpha:0.5),
                        ),
                        const HorizontalSpacing(0, 8),
                        const VerticalSpacing(0, 0),
                        const VerticalSpacing(0, 0),
                        const BoxDecoration(),
                      ),
                    ),
                    embedBuilders: [
                      ...FlutterQuillEmbeds.defaultEditorBuilders(),
                      QuillEditorImageEmbedBuilder(
                        configurations: const QuillEditorImageEmbedConfigurations(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: theme.dividerColor.withValues(alpha:0.1)),
                ),
                color: theme.colorScheme.surface,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isToolbarExpanded = !_isToolbarExpanded),
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withValues(alpha:0.5),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Formatting Tools',
                            style: theme.textTheme.titleSmall,
                          ),
                          const Spacer(),
                          AnimatedRotation(
                            turns: _isToolbarExpanded ? 0.5 : 0.0,
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              Icons.keyboard_arrow_down,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: ClipRect(
                      child: AnimatedSlide(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        offset: _isToolbarExpanded ? Offset.zero : const Offset(0, -1),
                        child: AnimatedOpacity(
                          duration: const Duration(milliseconds: 150),
                          opacity: _isToolbarExpanded ? 1.0 : 0.0,
                          child: _isToolbarExpanded ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              QuillToolbar.simple(
                                controller: _controller,
                                configurations: QuillSimpleToolbarConfigurations(
                                  showFontFamily: false,
                                  showFontSize: true,
                                  showBackgroundColorButton: false,
                                  showClearFormat: true,
                                  showColorButton: true,
                                  showCodeBlock: false,
                                  showQuote: true,
                                  showSubscript: false,
                                  showSuperscript: false,
                                  showSearchButton: false,
                                  showAlignmentButtons: true,
                                  showHeaderStyle: true,
                                  showIndent: true,
                                  showLink: true,
                                  showInlineCode: false,
                                  showDirection: false,
                                  showDividers: true,
                                  showStrikeThrough: true,
                                  showListCheck: true,
                                  showClipboardCopy: false,
                                  showClipboardCut: false,
                                  showClipboardPaste: false,
                                  multiRowsDisplay: true,
                                ),
                              ),
                              Divider(height: 1, color: theme.dividerColor.withValues(alpha:0.1)),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  children: [
                                    IconButton(
                                      onPressed: _isUploadingImage ? null : _pickContentImage,
                                      icon: const Icon(Icons.image_outlined),
                                      tooltip: 'Insert image',
                                    ),
                                    const SizedBox(width: 8),
                                    if (_isUploadingImage)
                                      const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ) : const SizedBox(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}