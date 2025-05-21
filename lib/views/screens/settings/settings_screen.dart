import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../viewmodels/settings_viewmodel.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  PackageInfo? _packageInfo;

  @override
  void initState() {
    super.initState();
    _loadPackageInfo();
    // Provide context to SettingsViewModel after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Provider.of<SettingsViewModel>(context, listen: false).setContext(context);
      }
    });
  }

  Future<void> _loadPackageInfo() async {
    final info = await PackageInfo.fromPlatform();
    setState(() {
      _packageInfo = info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Consumer<SettingsViewModel>(
        builder: (context, settings, child) {
          if (settings.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            children: [
              // Theme Settings
              _buildSection(
                theme,
                title: 'Appearance',
                icon: Icons.palette_outlined,
                children: [
                  ListTile(
                    title: const Text('Theme'),
                    subtitle: Text(_getThemeModeName(settings.themeMode)),
                    trailing: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                        ),
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                        ),
                      ],
                      selected: {settings.themeMode},
                      onSelectionChanged: (Set<ThemeMode> selection) {
                        settings.setThemeMode(selection.first);
                      },
                    ),
                  ),
                  const Divider(),
                  ListTile(
                    title: const Text('Theme Color'),
                    subtitle: Text(settings.themeColorName),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _buildColorOption(theme, settings, SettingsViewModel.systemDefaultTheme),
                        ...SettingsViewModel.themeColors.keys
                            .map((colorName) => _buildColorOption(theme, settings, colorName))
                            .toList(),
                      ],
                    ),
                  ),
                ],
              ),

              // Notification Settings
              _buildSection(
                theme,
                title: 'Notifications',
                icon: Icons.notifications_outlined,
                children: [
                  // Poll Notifications
                  ListTile(
                    title: const Text('Poll Notifications'),
                    subtitle: const Text('Manage poll-related notifications'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('New Polls'),
                          subtitle: const Text('Get notified when new polls are created'),
                          value: settings.notifyNewPoll,
                          onChanged: settings.setNotifyNewPoll,
                        ),
                        SwitchListTile(
                          title: const Text('Poll Deadlines'),
                          subtitle: const Text('Get reminders before polls close'),
                          value: settings.notifyPollDeadline,
                          onChanged: settings.setNotifyPollDeadline,
                        ),
                        SwitchListTile(
                          title: const Text('Poll Results'),
                          subtitle: const Text('Get notified when poll results are available'),
                          value: settings.notifyPollResults,
                          onChanged: settings.setNotifyPollResults,
                        ),
                      ],
                    ),
                  ),
                  const Divider(),
                  // Proposal Notifications
                  ListTile(
                    title: const Text('Proposal Notifications'),
                    subtitle: const Text('Manage proposal-related notifications'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('Endorsement Progress'),
                          subtitle: const Text('Get notified when your proposal reaches endorsement milestones'),
                          value: settings.notifyProposalEndorsement,
                          onChanged: settings.setNotifyProposalEndorsement,
                        ),
                        SwitchListTile(
                          title: const Text('Endorsement Complete'),
                          subtitle: const Text('Get notified when your proposal reaches full endorsement'),
                          value: settings.notifyProposalEndorsementComplete,
                          onChanged: settings.setNotifyProposalEndorsementComplete,
                        ),
                        SwitchListTile(
                          title: const Text('New Replies'),
                          subtitle: const Text('Get notified when someone replies to your proposal'),
                          value: settings.notifyProposalReply,
                          onChanged: settings.setNotifyProposalReply,
                        ),
                      ],
                    ),
                  ),

                  const Divider(),
                  // Article Notifications
                  ListTile(
                    title: const Text('Article Notifications'),
                    subtitle: const Text('Manage article-related notifications'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: SwitchListTile(
                      title: const Text('New Articles'),
                      subtitle: const Text('Get notified when new articles are published'),
                      value: settings.notifyArticle,
                      onChanged: settings.setNotifyArticle,
                    ),
                  ),

                  const Divider(),
                  // Event Notifications
                  ListTile(
                    title: const Text('Event Notifications'),
                    subtitle: const Text('Manage event-related notifications'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      children: [
                        SwitchListTile(
                          title: const Text('New Events'),
                          subtitle: const Text('Get notified when new events are added'),
                          value: settings.notifyNewEvent,
                          onChanged: settings.setNotifyNewEvent,
                        ),
                        SwitchListTile(
                          title: const Text('Event Reminders'),
                          subtitle: const Text('Get reminders before events start'),
                          value: settings.notifyEventReminder,
                          onChanged: settings.setNotifyEventReminder,
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // About Section
              _buildSection(
                theme,
                title: 'About',
                icon: Icons.info_outline,
                children: [
                  ListTile(
                    title: const Text('Version'),
                    subtitle: Text(_packageInfo?.version ?? 'Loading...'),
                  ),
                  ListTile(
                    title: const Text('Build Number'),
                    subtitle: Text(_packageInfo?.buildNumber ?? 'Loading...'),
                  ),
                  ListTile(
                    title: const Text('Third-Party Licenses'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'Ashesi Engage',
                        applicationVersion: _packageInfo?.version,
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Image.asset(
                            'assets/images/ashesi_logo.png',
                            height: 64,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    ThemeData theme, {
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(
                icon,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildColorOption(ThemeData theme, SettingsViewModel settings, String colorName) {
    final isSelected = settings.themeColorName == colorName;
    final isSystemDefault = colorName == SettingsViewModel.systemDefaultTheme;
    
    // For system default, use the actual system accent color
    final color = isSystemDefault 
      ? MediaQuery.platformBrightnessOf(context) == Brightness.dark
          ? theme.colorScheme.primary
          : theme.colorScheme.primary
      : SettingsViewModel.themeColors[colorName]!;

    return InkWell(
      onTap: () => settings.setThemeColor(colorName),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: isSelected
                ? Icon(
                    Icons.check,
                    color: theme.colorScheme.onPrimary,
                    size: 20,
                  )
                : isSystemDefault
                  ? Icon(
                      Icons.phone_android,
                      color: theme.colorScheme.onPrimary,
                      size: 20,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            Text(
              isSystemDefault ? 'System' : colorName.split(' ').last,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: isSelected ? FontWeight.bold : null,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _getThemeModeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }
}