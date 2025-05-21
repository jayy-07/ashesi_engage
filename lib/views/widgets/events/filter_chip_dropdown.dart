import 'package:flutter/material.dart';

class FilterChipItem {
  final String label;
  final dynamic value;

  FilterChipItem({
    required this.label,
    required this.value,
  });
}

class FilterChipDropdown extends StatefulWidget {
  final List<FilterChipItem> items;
  final Widget? leading;
  final String initialLabel;
  final Function(dynamic) onSelectionChanged;
  final dynamic selectedValue;

  const FilterChipDropdown({
    super.key,
    required this.items,
    this.leading,
    required this.initialLabel,
    required this.onSelectionChanged,
    this.selectedValue,
  });

  @override
  State<FilterChipDropdown> createState() => _FilterChipDropdownState();
}

class _FilterChipDropdownState extends State<FilterChipDropdown> {
  final GlobalKey _chipKey = GlobalKey();
  final LayerLink _layerLink = LayerLink();
  bool _isDropdownOpen = false;
  double _maxItemWidth = 0;
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateMaxItemWidth();
    });
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _toggleDropdown(bool? value) {
    if (_isDropdownOpen) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
    setState(() {
      _isDropdownOpen = !_isDropdownOpen;
    });
  }

  void _selectItem(FilterChipItem item) {
    _removeOverlay();
    setState(() {
      _isDropdownOpen = false;
    });
    widget.onSelectionChanged(item.value);
  }

  void _clearSelection() {
    _removeOverlay();
    setState(() {
      _isDropdownOpen = false;
    });
    widget.onSelectionChanged(null);
  }

  void _handleOutsideTap(PointerDownEvent evt) {
    if (_isDropdownOpen) {
      _removeOverlay();
      setState(() {
        _isDropdownOpen = false;
      });
    }
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _showOverlay() {
    final RenderBox renderBox = _chipKey.currentContext!.findRenderObject() as RenderBox;
    final Size size = renderBox.size;
    
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: _maxItemWidth,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: Offset(0, size.height + 4),
          child: TapRegion(
            onTapOutside: _handleOutsideTap,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              color: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: _maxItemWidth,
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.items.map((item) {
                      return InkWell(
                        onTap: () => _selectItem(item),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          child: Text(item.label),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _calculateMaxItemWidth() {
    double maxWidth = 0.0;
    for (var item in widget.items) {
      final textPainter = TextPainter(
        text: TextSpan(
            text: item.label, style: DefaultTextStyle.of(context).style),
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      maxWidth = maxWidth < textPainter.width ? textPainter.width + 48 : maxWidth;
    }

    final chipBox = _chipKey.currentContext?.findRenderObject() as RenderBox?;
    double chipWidth = chipBox?.size.width ?? 0;
    setState(() {
      _maxItemWidth = maxWidth > chipWidth ? maxWidth : chipWidth;
    });
  }

  String get _selectedLabel {
    if (widget.selectedValue == null) return widget.initialLabel;
    final selectedItem = widget.items.firstWhere(
      (item) => item.value == widget.selectedValue,
      orElse: () => FilterChipItem(label: widget.initialLabel, value: null),
    );
    return selectedItem.label;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: FilterChip(
        key: _chipKey,
        avatar: widget.leading,
        label: Text(_selectedLabel),
        selected: widget.selectedValue != null,
        onSelected: _toggleDropdown,
        deleteIcon: widget.selectedValue != null
            ? const Icon(Icons.close, size: 18)
            : const Icon(Icons.arrow_drop_down),
        onDeleted: widget.selectedValue != null ? _clearSelection : null,
        showCheckmark: false,
      ),
    );
  }
}