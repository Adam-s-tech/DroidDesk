import 'dart:async';
import 'dart:typed_data';

import 'package:droiddesk/services/platform_bridge.dart';
import 'package:droiddesk/state/app_state.dart';
import 'package:droiddesk/theme/droid_theme.dart';
import 'package:droiddesk/widgets/droid_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

class AppCatalogScreen extends StatefulWidget {
  const AppCatalogScreen({super.key});

  @override
  State<AppCatalogScreen> createState() => _AppCatalogScreenState();
}

class _AppCatalogScreenState extends State<AppCatalogScreen> {
  static const _featured = [
    _FeaturedApp(
      'firefox',
      'Firefox',
      'Fast, private desktop web browser.',
      Icons.public_rounded,
      Color(0xFFFF7139),
      iconNames: ['firefox'],
    ),
    _FeaturedApp(
      'code-oss',
      'Code OSS',
      'Powerful desktop code editor and IDE.',
      Icons.code_rounded,
      Color(0xFF23A8F2),
      iconNames: ['vscode', 'code-oss'],
    ),
    _FeaturedApp(
      'libreoffice',
      'LibreOffice',
      'Documents, spreadsheets, and presentations.',
      Icons.description_rounded,
      Color(0xFF18A303),
      iconNames: ['libreoffice-startcenter', 'libreoffice-main'],
    ),
    _FeaturedApp(
      'gimp',
      'GIMP',
      'Professional image editing and design tools.',
      Icons.brush_rounded,
      Color(0xFF9A7654),
      iconNames: ['gimp'],
    ),
    _FeaturedApp(
      'blender',
      'Blender',
      'Complete open-source 3D creation suite.',
      Icons.view_in_ar_rounded,
      Color(0xFFF5792A),
      iconNames: ['blender'],
    ),
    _FeaturedApp(
      'vlc',
      'VLC',
      'Play almost every audio and video format.',
      Icons.play_circle_rounded,
      Color(0xFFFF8800),
      iconNames: ['vlc'],
    ),
    _FeaturedApp(
      'nodejs',
      'Node.js + npm',
      'JavaScript runtime and package manager.',
      Icons.javascript_rounded,
      Color(0xFF68A063),
      iconNames: [],
    ),
    _FeaturedApp(
      'python',
      'Python',
      'Popular programming language and tools.',
      Icons.terminal_rounded,
      Color(0xFFFFD43B),
      iconNames: ['python'],
    ),
    _FeaturedApp(
      'imagemagick',
      'ImageMagick',
      'Image conversion and processing toolkit.',
      Icons.image_rounded,
      DroidTheme.primaryLight,
      iconNames: ['display-im6.q16'],
    ),
  ];

  int _tab = 0;
  final _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<_PackageItem> _searchResults = const [];
  List<_PackageItem> _installedPackages = const [];
  bool _searching = true;
  bool _loadingInstalled = true;
  String? _activePackage;
  double _operationProgress = 0;
  String _operationStatus = '';
  String _operationLog = '';
  bool _cancelRequested = false;
  bool _cancelling = false;

  Set<String> get _installedNames =>
      _installedPackages.map((package) => package.name).toSet();

  @override
  void initState() {
    super.initState();
    DroidDeskPlatform.onPackageOperationProgress = _onProgress;
    DroidDeskPlatform.onPackageOperationLog = _onLog;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refreshOptionalApps();
      _loadInstalled();
      _search('');
    });
  }

  @override
  void dispose() {
    if (_activePackage != null) {
      unawaited(DroidDeskPlatform.cancelNativePackageOperation());
    }
    _searchDebounce?.cancel();
    _searchController.dispose();
    DroidDeskPlatform.onPackageOperationProgress = null;
    DroidDeskPlatform.onPackageOperationLog = null;
    super.dispose();
  }

  void _onProgress(double progress, String status) {
    if (!mounted) return;
    setState(() {
      _operationProgress = progress.clamp(0, 1);
      _operationStatus = status;
    });
  }

  void _onLog(String text) {
    if (!mounted) return;
    setState(() {
      _operationLog += text;
      if (_operationLog.length > 12000) {
        _operationLog = _operationLog.substring(_operationLog.length - 12000);
      }
    });
  }

  Future<void> _loadInstalled() async {
    if (mounted) setState(() => _loadingInstalled = true);
    try {
      final packages = await DroidDeskPlatform.getInstalledNativePackages();
      if (!mounted) return;
      setState(() {
        _installedPackages = packages.map(_PackageItem.fromMap).toList();
        _loadingInstalled = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingInstalled = false);
    }
  }

  void _queueSearch(String query) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _search(query),
    );
  }

  Future<void> _search(String query) async {
    if (mounted) setState(() => _searching = true);
    try {
      final packages = await DroidDeskPlatform.searchNativePackages(query);
      if (!mounted || query != _searchController.text.trim()) return;
      setState(() {
        _searchResults = packages.map(_PackageItem.fromMap).toList();
        _searching = false;
      });
    } catch (_) {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _install(String packageName) async {
    if (_activePackage != null) return;
    setState(() {
      _activePackage = packageName;
      _operationProgress = 0;
      _operationStatus = 'Preparing $packageName...';
      _operationLog = '';
      _cancelRequested = false;
      _cancelling = false;
    });
    final ok = await DroidDeskPlatform.installNativePackage(packageName);
    await _loadInstalled();
    if (!mounted) return;
    final cancelled = _cancelRequested;
    setState(() {
      _activePackage = null;
      _cancelling = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cancelled
              ? '$packageName installation cancelled'
              : ok
              ? '$packageName installed'
              : '$packageName installation failed',
        ),
        backgroundColor: cancelled
            ? DroidTheme.surfaceLight
            : ok
            ? DroidTheme.success
            : DroidTheme.error,
      ),
    );
  }

  Future<void> _cancelOperation() async {
    if (_activePackage == null || _cancelling) return;
    setState(() {
      _cancelRequested = true;
      _cancelling = true;
      _operationStatus = 'Cancelling installation...';
    });
    await DroidDeskPlatform.cancelNativePackageOperation();
  }

  Future<void> _remove(_PackageItem package) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${package.displayName}?'),
        content: const Text('Dependent packages may also be affected.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || _activePackage != null) return;
    setState(() {
      _activePackage = package.name;
      _operationProgress = 0;
      _operationStatus = 'Preparing removal...';
      _operationLog = '';
      _cancelRequested = false;
      _cancelling = false;
    });
    final ok = await DroidDeskPlatform.removeNativePackage(package.name);
    await _loadInstalled();
    if (!mounted) return;
    setState(() => _activePackage = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? '${package.displayName} removed' : 'Removal failed'),
        backgroundColor: ok ? DroidTheme.success : DroidTheme.error,
      ),
    );
  }

  void _selectTab(int index) {
    setState(() => _tab = index);
    if (index == 2) _loadInstalled();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: DroidTheme.backgroundGradient),
        child: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const DroidPageHeader(
                title: 'Linux App Store',
                subtitle: 'Apps and tools for your desktop',
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: DroidSegmentedTabs(
                  labels: const ['Featured', 'Browse', 'Installed'],
                  icons: const [
                    Icons.auto_awesome_rounded,
                    Icons.search_rounded,
                    Icons.check_circle_outline_rounded,
                  ],
                  selected: _tab,
                  onChanged: _selectTab,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: KeyedSubtree(
                    key: ValueKey(_tab),
                    child: switch (_tab) {
                      0 => _featuredView(),
                      1 => _browseView(),
                      _ => _installedView(),
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: _activePackage == null
            ? const SizedBox(width: double.infinity)
            : _operationPanel(),
      ),
    );
  }

  Widget _featuredView() {
    final state = context.watch<AppState>();
    final apps = [
      ..._featured,
      if (!state.hasRoot)
        const _FeaturedApp(
          'proot_debian',
          'Debian Compatibility',
          'Run packages unavailable in native repositories.',
          Icons.inventory_2_rounded,
          Color(0xFFD70A53),
          optional: true,
          iconNames: ['distributor-logo-debian'],
        ),
    ];
    final hero = apps.first;
    final rest = apps.skip(1).toList();

    _PackageItem itemFor(_FeaturedApp app) => _PackageItem(
          name: app.packageName,
          description: app.description,
          installed: app.optional
              ? state.optionalApps[app.packageName] == true
              : _installedNames.contains(app.packageName),
        );
    Future<void> Function()? installerFor(_FeaturedApp app) => app.optional
        ? () => state.installOptionalApp(app.packageName)
        : null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        _heroCard(hero, itemFor(hero), installerFor(hero)),
        const SizedBox(height: 26),
        const DroidSectionLabel('Popular apps'),
        const SizedBox(height: 10),
        DroidGroupCard(
          child: Column(
            children: [
              for (var i = 0; i < rest.length; i++) ...[
                if (i > 0) const DroidInsetDivider(indent: 76),
                _packageRow(
                  itemFor(rest[i]),
                  featured: rest[i],
                  onInstall: installerFor(rest[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Large spotlight card for the first featured app.
  Widget _heroCard(
    _FeaturedApp app,
    _PackageItem item,
    Future<void> Function()? onInstall,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(DroidTheme.radiusXl),
        gradient: LinearGradient(
          colors: [
            app.color.withValues(alpha: 0.30),
            app.color.withValues(alpha: 0.08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: app.color.withValues(alpha: 0.30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'FEATURED',
            style: DroidTheme.label.copyWith(color: app.color, letterSpacing: 1),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _LinuxAppIcon(
                package: app.packageName,
                iconNames: app.iconNames,
                fallback: _appTile(app.icon, app.color, size: 60),
                size: 60,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(app.name, style: DroidTheme.headingMd),
                    const SizedBox(height: 3),
                    Text(app.description, style: DroidTheme.bodySm),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _actionButton(item, onInstall: onInstall, prominent: true),
        ],
      ),
    );
  }

  Widget _browseView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
          child: DroidSearchField(
            controller: _searchController,
            hint: 'Search packages, apps and tools',
            onChanged: (value) {
              setState(() {});
              _queueSearch(value);
            },
            busy: _searching,
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty && !_searching
              ? ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: const [
                    DroidEmptyCard(
                      icon: Icons.search_off_rounded,
                      title: 'No matching packages',
                      subtitle: 'Try another name or keyword.',
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                  children: [
                    if (_searchResults.isNotEmpty)
                      DroidGroupCard(
                        child: Column(
                          children: [
                            for (var i = 0; i < _searchResults.length; i++) ...[
                              if (i > 0) const DroidInsetDivider(indent: 76),
                              _packageRow(_searchResults[i]),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _installedView() {
    if (_loadingInstalled && _installedPackages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    return RefreshIndicator(
      onRefresh: _loadInstalled,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        children: [
          Row(
            children: [
              const DroidSectionLabel('Installed packages'),
              const Spacer(),
              if (_installedPackages.isNotEmpty)
                Text('${_installedPackages.length}', style: DroidTheme.bodySm),
            ],
          ),
          const SizedBox(height: 10),
          if (_installedPackages.isEmpty)
            const DroidEmptyCard(
              icon: Icons.inventory_2_outlined,
              title: 'Nothing installed yet',
              subtitle: 'Apps you install from Featured or Browse show up here.',
            )
          else
            DroidGroupCard(
              child: Column(
                children: [
                  for (var i = 0; i < _installedPackages.length; i++) ...[
                    if (i > 0) const DroidInsetDivider(indent: 76),
                    _packageRow(_installedPackages[i], allowRemove: true),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _appTile(IconData icon, Color color, {double size = 46}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.24), color.withValues(alpha: 0.12)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }

  /// One package inside a grouped card: icon, name, description, meta and action.
  Widget _packageRow(
    _PackageItem package, {
    _FeaturedApp? featured,
    bool allowRemove = false,
    Future<void> Function()? onInstall,
  }) {
    final color = featured?.color ?? _categoryColor(package.section);
    final meta = [
      if (package.version.isNotEmpty) package.version,
      package.gui ? 'GUI app' : package.section,
    ].where((e) => e.isNotEmpty).join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          _LinuxAppIcon(
            package: package.name,
            iconNames: featured?.iconNames ?? const [],
            fallback: _appTile(
              featured?.icon ?? _categoryIcon(package.section, package.gui),
              color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  featured?.name ?? package.displayName,
                  style: DroidTheme.headingSm.copyWith(fontSize: 15),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  package.description.isEmpty
                      ? 'Linux package'
                      : package.description,
                  style: DroidTheme.bodySm,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (meta.isNotEmpty && featured == null) ...[
                  const SizedBox(height: 3),
                  Text(meta, style: DroidTheme.monoSm),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          _actionButton(package, allowRemove: allowRemove, onInstall: onInstall),
        ],
      ),
    );
  }

  /// App Store style capsule: Get / progress / Installed / Remove.
  Widget _actionButton(
    _PackageItem package, {
    bool allowRemove = false,
    Future<void> Function()? onInstall,
    bool prominent = false,
  }) {
    final installed =
        package.installed || _installedNames.contains(package.name);
    final busy = _activePackage != null;
    final active = _activePackage == package.name;

    if (active) {
      final value = _operationProgress > 0 ? _operationProgress : null;
      final percent = '${(_operationProgress * 100).round()}%';
      if (prominent) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  _cancelling ? 'Cancelling…' : 'Installing…',
                  style: DroidTheme.bodySm.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  value == null ? '' : percent,
                  style: DroidTheme.bodySm.copyWith(
                    fontWeight: FontWeight.w700,
                    color: DroidTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: value,
                backgroundColor: DroidTheme.surfaceBorder,
              ),
            ),
          ],
        );
      }
      return SizedBox(
        width: 74,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    value: value,
                    backgroundColor: DroidTheme.surfaceBorder,
                  ),
                ),
                if (value != null)
                  Text(
                    percent,
                    style: DroidTheme.label.copyWith(
                      fontSize: 10,
                      letterSpacing: 0,
                      color: DroidTheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }
    if (installed && allowRemove && package.removable) {
      return _capsule(
        label: 'Remove',
        color: DroidTheme.error,
        onTap: busy ? null : () => _remove(package),
      );
    }
    if (installed && prominent) {
      return Container(
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: DroidTheme.accent,
          borderRadius: BorderRadius.circular(DroidTheme.radiusMd),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, size: 18, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              'INSTALLED',
              style: DroidTheme.label.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }
    if (installed) {
      return Container(
        padding: const EdgeInsets.fromLTRB(9, 6, 12, 6),
        decoration: BoxDecoration(
          color: DroidTheme.accent.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DroidTheme.accent.withValues(alpha: 0.45)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_rounded, size: 15, color: DroidTheme.accent),
            const SizedBox(width: 4),
            Text(
              'Installed',
              style: DroidTheme.label.copyWith(
                color: DroidTheme.accent,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      );
    }
    return _capsule(
      label: 'Get',
      color: DroidTheme.primary,
      filled: prominent,
      onTap: busy
          ? null
          : () async {
              if (onInstall != null) {
                await onInstall();
                if (mounted) setState(() {});
              } else {
                await _install(package.name);
              }
            },
    );
  }

  Widget _capsule({
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool filled = false,
  }) {
    final enabled = onTap != null;
    return Material(
      color: filled
          ? color.withValues(alpha: enabled ? 1 : 0.4)
          : color.withValues(alpha: enabled ? 0.14 : 0.06),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minWidth: 74),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          alignment: Alignment.center,
          child: Text(
            label.toUpperCase(),
            style: DroidTheme.label.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: filled
                  ? Colors.white
                  : color.withValues(alpha: enabled ? 1 : 0.4),
            ),
          ),
        ),
      ),
    );
  }

  /// Floating progress card shown while a package is being installed or removed.
  Widget _operationPanel() {
    final clean = _operationLog.replaceAll(
      RegExp(r'\x1B\[[0-?]*[ -/]*[@-~]'),
      '',
    );
    final tail = clean
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList()
        .reversed
        .take(2)
        .toList()
        .reversed
        .join('\n');
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
        padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
        decoration: BoxDecoration(
          color: DroidTheme.surfaceLight,
          borderRadius: BorderRadius.circular(DroidTheme.radiusLg),
          border: Border.all(color: DroidTheme.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _operationStatus,
                        style: DroidTheme.headingSm.copyWith(fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _operationProgress > 0
                            ? '${(_operationProgress * 100).round()}% complete'
                            : 'Starting…',
                        style: DroidTheme.bodySm,
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _cancelling ? null : _cancelOperation,
                  style: TextButton.styleFrom(foregroundColor: DroidTheme.error),
                  child: Text(_cancelling ? 'Cancelling…' : 'Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: DroidTheme.surfaceBorder,
                  value: _operationProgress > 0 ? _operationProgress : null,
                ),
              ),
            ),
            if (tail.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                tail,
                style: DroidTheme.monoSm,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(String section, bool gui) {
    final value = section.toLowerCase();
    if (value.contains('internet')) return Icons.public_rounded;
    if (value.contains('develop')) return Icons.code_rounded;
    if (value.contains('graphic')) return Icons.palette_rounded;
    if (value.contains('media')) return Icons.movie_rounded;
    if (value.contains('office')) return Icons.description_rounded;
    return gui ? Icons.apps_rounded : Icons.terminal_rounded;
  }

  Color _categoryColor(String section) {
    final value = section.toLowerCase();
    if (value.contains('internet')) return const Color(0xFF39A0FF);
    if (value.contains('develop')) return const Color(0xFF9B7BFF);
    if (value.contains('graphic')) return const Color(0xFFFF6B9E);
    if (value.contains('media')) return const Color(0xFFFF9F43);
    if (value.contains('office')) return const Color(0xFF38C793);
    return DroidTheme.primaryLight;
  }
}

class _PackageItem {
  final String name;
  final String description;
  final String version;
  final String section;
  final bool installed;
  final bool gui;
  final bool removable;

  const _PackageItem({
    required this.name,
    this.description = '',
    this.version = '',
    this.section = 'System',
    this.installed = false,
    this.gui = false,
    this.removable = true,
  });

  factory _PackageItem.fromMap(Map<String, dynamic> map) => _PackageItem(
    name: map['name']?.toString() ?? '',
    description: map['description']?.toString() ?? '',
    version: map['version']?.toString() ?? '',
    section: map['section']?.toString() ?? 'System',
    installed: map['installed'] == true,
    gui: map['gui'] == true,
    removable: map['removable'] != false,
  );

  String get displayName => name
      .split('-')
      .map(
        (word) => word.isEmpty
            ? word
            : '${word[0].toUpperCase()}${word.substring(1)}',
      )
      .join(' ');
}

class _FeaturedApp {
  final String packageName;
  final String name;
  final String description;
  final IconData icon;
  final Color color;
  final bool optional;
  final List<String> iconNames;

  const _FeaturedApp(
    this.packageName,
    this.name,
    this.description,
    this.icon,
    this.color, {
    this.optional = false,
    this.iconNames = const [],
  });
}

/// Real icon for a Linux package (installed .desktop icon or Papirus), cached per package.
/// Shows [fallback] while loading and when no icon exists.
class _LinuxAppIcon extends StatefulWidget {
  final String package;
  final List<String> iconNames;
  final Widget fallback;
  final double size;

  const _LinuxAppIcon({
    required this.package,
    required this.iconNames,
    required this.fallback,
    this.size = 46,
  });

  static final Map<String, Future<Map<String, dynamic>?>> _cache = {};

  @override
  State<_LinuxAppIcon> createState() => _LinuxAppIconState();
}

class _LinuxAppIconState extends State<_LinuxAppIcon> {
  late Future<Map<String, dynamic>?> _icon;

  @override
  void initState() {
    super.initState();
    _icon = _load();
  }

  @override
  void didUpdateWidget(covariant _LinuxAppIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.package != widget.package) _icon = _load();
  }

  Future<Map<String, dynamic>?> _load() => _LinuxAppIcon._cache.putIfAbsent(
        widget.package,
        () => DroidDeskPlatform.getLinuxAppIcon(
          widget.package,
          iconNames: widget.iconNames,
        ).catchError((_) => null),
      );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _icon,
      builder: (context, snapshot) {
        final icon = snapshot.data;
        final bytes = icon?['bytes'];
        if (bytes is! Uint8List) return widget.fallback;
        final image = icon!['format'] == 'svg'
            ? SvgPicture.memory(
                bytes,
                width: widget.size,
                height: widget.size,
                placeholderBuilder: (_) => widget.fallback,
              )
            : Image.memory(
                bytes,
                width: widget.size,
                height: widget.size,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, _, _) => widget.fallback,
              );
        return SizedBox(width: widget.size, height: widget.size, child: image);
      },
    );
  }
}
