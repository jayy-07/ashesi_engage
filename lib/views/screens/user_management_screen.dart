import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/user_management_viewmodel.dart';
import '../../viewmodels/user_viewmodel.dart';
import '../../auth/models/app_user.dart';
import '../widgets/user_avatar.dart';
import 'package:intl/intl.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSelectionMode = false;
  final Set<String> _selectedUserIds = {};
  Set<String> _selectedClasses = {};
  Set<String> _selectedRoles = {};
  Set<String> _selectedStatuses = {};
  final TextEditingController _classSearchController = TextEditingController();
  final TextEditingController _roleSearchController = TextEditingController();
  final TextEditingController _statusSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Load users when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<UserManagementViewModel>().loadUsers();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _classSearchController.dispose();
    _roleSearchController.dispose();
    _statusSearchController.dispose();
    super.dispose();
  }

  Future<void> _showBanDialog(AppUser user) async {
    final banDurations = [
      {'label': '24 Hours', 'duration': const Duration(days: 1)},
      {'label': '7 Days', 'duration': const Duration(days: 7)},
      {'label': '30 Days', 'duration': const Duration(days: 30)},
      {'label': 'Permanent', 'duration': null},
    ];

    final banReasons = [
      'Violation of community guidelines',
      'Inappropriate content',
      'Harassment or bullying',
      'Spam or misleading content',
      'Other (specify)',
    ];

    String? selectedReason = banReasons.first;
    String? customReason;
    String? selectedDurationLabel;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Ban ${user.firstName} ${user.lastName}'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Select ban duration:'),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: banDurations.map((duration) => ChoiceChip(
                    label: Text(duration['label'] as String),
                    selected: selectedDurationLabel == duration['label'],
                    onSelected: (selected) {
                      setState(() {
                        selectedDurationLabel = selected ? duration['label'] as String : null;
                      });
                    },
                  )).toList(),
                ),
                const SizedBox(height: 24),
                const Text('Select ban reason:'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  items: banReasons.map((reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedReason = value;
                      if (value != 'Other (specify)') {
                        customReason = null;
                      }
                    });
                  },
                ),
                if (selectedReason == 'Other (specify)') ...[
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Enter reason',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      customReason = value;
                    },
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            FilledButton(
              onPressed: selectedDurationLabel == null ? null : () {
                final duration = banDurations.firstWhere(
                  (d) => d['label'] == selectedDurationLabel,
                )['duration'] as Duration?;

                final reason = selectedReason == 'Other (specify)'
                    ? customReason
                    : selectedReason;

                if (reason != null) {
                  Navigator.pop(context, {
                    'duration': duration,
                    'reason': reason,
                  });
                }
              },
              child: const Text('BAN USER'),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      final duration = result['duration'] as Duration?;
      final until = duration != null 
          ? DateTime.now().add(duration)
          : null;
      final reason = result['reason'] as String;

      await context.read<UserManagementViewModel>().banUser(
        user.uid,
        until: until,
        reason: reason,
      );
    }
  }

  Future<void> _showDeleteDialog(AppUser user) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${user.firstName} ${user.lastName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Choose deletion type:'),
            const SizedBox(height: 16),
            ListTile(
              title: const Text('Soft Delete'),
              subtitle: const Text('User can be restored later'),
              onTap: () => Navigator.pop(context, false),
            ),
            ListTile(
              title: const Text('Permanent Delete'),
              subtitle: const Text('User cannot create account again'),
              onTap: () => Navigator.pop(context, true),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      if (result) {
        await context.read<UserManagementViewModel>().permanentlyDeleteUser(user.uid);
      } else {
        await context.read<UserManagementViewModel>().deleteUser(user.uid);
      }
    }
  }

  Future<void> _deleteSelectedUsers(List<AppUser> selectedUsers) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Users'),
        content: Text(
          'Are you sure you want to delete ${selectedUsers.length} selected user${selectedUsers.length > 1 ? 's' : ''}?'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCEL'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        for (final user in selectedUsers) {
          await context.read<UserManagementViewModel>().deleteUser(user.uid);
        }
        setState(() {
          _isSelectionMode = false;
          _selectedUserIds.clear();
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${selectedUsers.length} user${selectedUsers.length > 1 ? 's' : ''} deleted successfully'),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete users: $e')),
        );
      }
    }
  }

  void _showMultiSelectFilterDialog({
    required BuildContext context,
    required String title,
    required Set<String> selectedValues,
    required Set<String> options,
    required ValueChanged<Set<String>> onChanged,
    required TextEditingController searchController,
  }) {
    String localSearchQuery = '';
    Set<String> tempSelected = Set.from(selectedValues);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 400,
              maxHeight: 500,
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      hintText: 'Search ${title.toLowerCase()}...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: localSearchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                searchController.clear();
                                setState(() {
                                  localSearchQuery = '';
                                });
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(32),
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {
                        localSearchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          ListTile(
                            leading: Icon(
                              tempSelected.isEmpty ? Icons.check_circle : Icons.check_box_outline_blank,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            title: const Text('All'),
                            onTap: () {
                              setState(() {
                                tempSelected.clear();
                              });
                            },
                          ),
                          const Divider(height: 1),
                          ...options
                              .where((option) => localSearchQuery.isEmpty ||
                                  option.toLowerCase().contains(localSearchQuery.toLowerCase()))
                              .map(
                                (option) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ListTile(
                                      leading: Icon(
                                        tempSelected.contains(option) ? Icons.check_box : Icons.check_box_outline_blank,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                      title: Text(option),
                                      onTap: () {
                                        setState(() {
                                          if (tempSelected.contains(option)) {
                                            tempSelected.remove(option);
                                          } else {
                                            tempSelected.add(option);
                                          }
                                        });
                                      },
                                    ),
                                    if (option != options.last) const Divider(height: 1),
                                  ],
                                ),
                              ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('CANCEL'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          onChanged(tempSelected);
                          Navigator.pop(context);
                        },
                        child: const Text('APPLY'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<AppUser> _filterUsers(List<AppUser> users) {
    return users.where((user) {
      // Search query filter
      if (_searchQuery.isNotEmpty) {
        final query = _searchQuery.toLowerCase();
        if (!('${user.firstName} ${user.lastName}'.toLowerCase().contains(query)) &&
            !user.email.toLowerCase().contains(query)) {
          return false;
        }
      }

      // Class filter
      if (_selectedClasses.isNotEmpty && !_selectedClasses.contains(user.classYear)) {
        return false;
      }

      // Role filter
      if (_selectedRoles.isNotEmpty) {
        final roleText = user.role == 1 ? 'Superadmin' : user.role == 2 ? 'Admin' : 'User';
        if (!_selectedRoles.contains(roleText)) {
          return false;
        }
      }

      // Status filter
      if (_selectedStatuses.isNotEmpty) {
        final status = user.isBanned ? 'Banned' : user.isDeleted ? 'Deleted' : 'Active';
        if (!_selectedStatuses.contains(status)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Set<String> _getUniqueClasses(List<AppUser> users) {
    return users.map((e) => e.classYear).toSet();
  }

  Set<String> _getRoles() {
    return {'Superadmin', 'Admin', 'User'};
  }

  Set<String> _getStatuses() {
    return {'Active', 'Banned', 'Deleted'};
  }

  Widget _buildSearchAndFilters(List<AppUser> users) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          // Search field
          Expanded(
            flex: 2,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search users...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          const SizedBox(width: 48),
          
          // Filters
          Expanded(
            flex: 5,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Class filter
                  FilterChip(
                    label: Text(_selectedClasses.isEmpty 
                        ? 'Select Classes' 
                        : _selectedClasses.length == 1 
                            ? _selectedClasses.first 
                            : '${_selectedClasses.length} Classes'),
                    selected: _selectedClasses.isNotEmpty,
                    onSelected: (bool selected) {
                      _showMultiSelectFilterDialog(
                        context: context,
                        title: 'Classes',
                        selectedValues: _selectedClasses,
                        options: _getUniqueClasses(users),
                        onChanged: (value) => setState(() => _selectedClasses = value),
                        searchController: _classSearchController,
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.school,
                      color: _selectedClasses.isNotEmpty
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Role filter
                  FilterChip(
                    label: Text(_selectedRoles.isEmpty 
                        ? 'Select Roles' 
                        : _selectedRoles.length == 1 
                            ? _selectedRoles.first 
                            : '${_selectedRoles.length} Roles'),
                    selected: _selectedRoles.isNotEmpty,
                    onSelected: (bool selected) {
                      _showMultiSelectFilterDialog(
                        context: context,
                        title: 'Roles',
                        selectedValues: _selectedRoles,
                        options: _getRoles(),
                        onChanged: (value) => setState(() => _selectedRoles = value),
                        searchController: _roleSearchController,
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.admin_panel_settings,
                      color: _selectedRoles.isNotEmpty
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  
                  // Status filter
                  FilterChip(
                    label: Text(_selectedStatuses.isEmpty 
                        ? 'Select Status' 
                        : _selectedStatuses.length == 1 
                            ? _selectedStatuses.first 
                            : '${_selectedStatuses.length} Statuses'),
                    selected: _selectedStatuses.isNotEmpty,
                    onSelected: (bool selected) {
                      _showMultiSelectFilterDialog(
                        context: context,
                        title: 'Status',
                        selectedValues: _selectedStatuses,
                        options: _getStatuses(),
                        onChanged: (value) => setState(() => _selectedStatuses = value),
                        searchController: _statusSearchController,
                      );
                    },
                    showCheckmark: false,
                    avatar: Icon(
                      Icons.person_outline,
                      color: _selectedStatuses.isNotEmpty
                          ? Theme.of(context).colorScheme.onSecondaryContainer
                          : null,
                    ),
                  ),

                  // Clear filters button
                  if (_searchQuery.isNotEmpty ||
                      _selectedClasses.isNotEmpty ||
                      _selectedRoles.isNotEmpty ||
                      _selectedStatuses.isNotEmpty) ...[
                    const SizedBox(width: 16),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                          _searchController.clear();
                          _selectedClasses.clear();
                          _selectedRoles.clear();
                          _selectedStatuses.clear();
                        });
                      },
                      icon: const Icon(Icons.clear_all),
                      label: const Text('Clear Filters'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(AppUser user, bool isSelected, Function(bool) onSelected) {
    final roleText = user.role == 1 ? 'Superadmin' : user.role == 2 ? 'Admin' : 'User';
    final statusColor = user.isBanned 
        ? Colors.red 
        : user.isDeleted 
            ? Colors.grey 
            : Colors.green;
    final statusText = user.isBanned ? 'Banned' : user.isDeleted ? 'Deleted' : 'Active';
    final currentUser = context.read<UserViewModel>().currentUser;
    final isSuperAdmin = currentUser?.role == 1;
    final isAdmin = currentUser?.role == 2;

    // Check if the current user can perform actions on the target user
    final canModifyUser = isSuperAdmin || 
        (isAdmin && user.role > 2); // Admins can only modify regular users

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _isSelectionMode ? () => onSelected(!isSelected) : null,
        child: Stack(
          children: [
            if (_isSelectionMode)
              Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            SizedBox(
              height: 200, // Increased height to accommodate chips
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        UserAvatar(
                          imageUrl: user.photoURL,
                          radius: 24,
                          fallbackInitial: user.firstName[0],
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${user.firstName} ${user.lastName}',
                                style: Theme.of(context).textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                user.email,
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        if (!_isSelectionMode && canModifyUser)
                          PopupMenuButton<String>(
                            onSelected: (value) async {
                              switch (value) {
                                case 'ban':
                                  await _showBanDialog(user);
                                  break;
                                case 'unban':
                                  await context.read<UserManagementViewModel>().unbanUser(user.uid);
                                  break;
                                case 'delete':
                                  await _showDeleteDialog(user);
                                  break;
                                case 'make_admin':
                                  await context.read<UserManagementViewModel>().updateUserRole(user.uid, 2);
                                  break;
                                case 'remove_admin':
                                  await context.read<UserManagementViewModel>().updateUserRole(user.uid, 3);
                                  break;
                              }
                            },
                            itemBuilder: (context) => [
                              if (isSuperAdmin && user.role != 1) ...[
                                if (user.role == 3)
                                  const PopupMenuItem(
                                    value: 'make_admin',
                                    child: Text('Make Admin'),
                                  )
                                else if (user.role == 2)
                                  const PopupMenuItem(
                                    value: 'remove_admin',
                                    child: Text('Remove Admin'),
                                  ),
                              ],
                              if (!user.isBanned)
                                const PopupMenuItem(
                                  value: 'ban',
                                  child: Text('Ban User'),
                                )
                              else if (canModifyUser)
                                const PopupMenuItem(
                                  value: 'unban',
                                  child: Text('Unban User'),
                                ),
                              if (canModifyUser)
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Text('Delete User'),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const Spacer(),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Chip(
                            label: Text(user.classYear),
                            avatar: const Icon(Icons.school),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(roleText),
                            avatar: const Icon(Icons.admin_panel_settings),
                          ),
                          const SizedBox(width: 8),
                          Chip(
                            label: Text(statusText),
                            avatar: Icon(Icons.circle, color: statusColor, size: 12),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Joined ${DateFormat.yMMMd().format(user.accountCreationDate)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<UserManagementViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.isLoading) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final users = _filterUsers(viewModel.users);
        final selectedUsers = users.where((u) => _selectedUserIds.contains(u.uid)).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
              child: Row(
                children: [
                  if (!_isSelectionMode) ...[
                    Text(
                      'Manage Users',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (users.isNotEmpty)
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _isSelectionMode = true;
                          });
                        },
                        icon: const Icon(Icons.checklist),
                        tooltip: 'Select users',
                      ),
                  ] else ...[
                    Text(
                      '${_selectedUserIds.length} selected',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _isSelectionMode = false;
                          _selectedUserIds.clear();
                        });
                      },
                      icon: const Icon(Icons.close),
                      label: const Text('Cancel'),
                    ),
                    if (_selectedUserIds.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor: Theme.of(context).colorScheme.onError,
                        ),
                        onPressed: () => _deleteSelectedUsers(selectedUsers),
                        icon: const Icon(Icons.delete),
                        label: const Text('Delete Selected'),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            _buildSearchAndFilters(viewModel.users),
            const SizedBox(height: 16),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(),
            ),
            Expanded(
              child: users.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No users found',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Try adjusting your filters',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 600,
                        mainAxisExtent: 200,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: MediaQuery.of(context).size.width > 1400 ? 1.2 : 1,
                      ),
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        return _buildUserCard(
                          user,
                          _selectedUserIds.contains(user.uid),
                          (selected) {
                            setState(() {
                              if (selected) {
                                _selectedUserIds.add(user.uid);
                              } else {
                                _selectedUserIds.remove(user.uid);
                              }
                            });
                          },
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
} 