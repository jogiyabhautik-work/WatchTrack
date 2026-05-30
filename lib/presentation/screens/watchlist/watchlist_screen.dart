import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/watchlist_folder_provider.dart';
import 'package:watch_track/presentation/screens/watchlist/watchlist_detail_screen.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/data/models/movie_model.dart';


// ─────────────────────────────────────────────────────────────────────────────
// WATCHLIST SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with TickerProviderStateMixin {
  // Sort & Filter
  _SortOption _sort = _SortOption.recent;
  _StatusFilter _statusFilter = _StatusFilter.all;
  _MediaTypeFilter _typeFilter = _MediaTypeFilter.all;
  String _query = '';
  final _searchController = TextEditingController();
  bool _searchActive = false;

  // Advanced Filters
  String? _selectedGenre;
  String? _selectedYear;

  // View
  bool _folderView = false; // false = all titles, true = folder view

  // Batch Selection
  bool _isSelectionMode = false;
  final Set<int> _selectedIds = {};

  // Selected folder for detail view
  String? _activeFolderId;

  // Animations
  late AnimationController _headerAnim;
  late AnimationController _fabAnim;
  late Animation<double> _fabScale;

  final ScrollController _scrollController = ScrollController();
  bool _headerCollapsed = false;

  @override
  void initState() {
    super.initState();
    _headerAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _fabScale = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _fabAnim, curve: Curves.elasticOut));
    _fabAnim.forward();

    _scrollController.addListener(() {
      final collapsed = _scrollController.offset > 60;
      if (collapsed != _headerCollapsed) {
        setState(() => _headerCollapsed = collapsed);
        collapsed ? _headerAnim.forward() : _headerAnim.reverse();
      }
    });
  }

  @override
  void dispose() {
    _headerAnim.dispose();
    _fabAnim.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  List<UserTitle> _filteredSorted(List<UserTitle> items) {
    var list = items.where((m) {
      // Search query
      final matchesQuery =
          _query.isEmpty || m.title.toLowerCase().contains(_query.toLowerCase());

      // Status filter
      bool matchesStatus = true;
      final currentFilter = _statusFilter;
      if (currentFilter != _StatusFilter.all) {
        final targetStatus = switch (currentFilter) {
          _StatusFilter.watching => TrackingStatus.watching,
          _StatusFilter.completed => TrackingStatus.watched,
          _StatusFilter.onHold => TrackingStatus.onHold,
          _StatusFilter.dropped => TrackingStatus.dropped,
          _StatusFilter.planToWatch => TrackingStatus.watchlist,
          _StatusFilter.all || _ => null,
        };
        if (targetStatus != null) {
          matchesStatus = m.status == targetStatus;
        }
      }

      // Media type filter
      bool matchesType = true;
      if (_typeFilter != _MediaTypeFilter.all) {
        matchesType = _typeFilter == _MediaTypeFilter.movies
            ? m.mediaType == 'movie'
            : m.mediaType == 'tv';
      }

      // Advanced filters (placeholder implementation for tags/notes matching)
      bool matchesGenre = _selectedGenre == null ||
          m.tags.contains(_selectedGenre) ||
          (m.notes?.toLowerCase().contains(_selectedGenre!.toLowerCase()) ?? false);
      
      bool matchesYear = _selectedYear == null ||
          (m.notes?.contains(_selectedYear!) ?? false) ||
          m.tags.contains(_selectedYear!);

      return matchesQuery && matchesStatus && matchesType && matchesGenre && matchesYear;
    }).toList();

    switch (_sort) {
      case _SortOption.recent:
      case _SortOption.updated:
        list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        break;
      case _SortOption.az:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case _SortOption.rating:
        list.sort((a, b) => (b.userRating ?? 0).compareTo(a.userRating ?? 0));
        break;
      case _SortOption.added:
        list.sort((a, b) => b.addedAt.compareTo(a.addedAt));
        break;
    }
    return list;
  }

  List<UserTitle> _folderItems(
      List<UserTitle> all, WatchlistFolder folder) {
    return all
        .where((m) =>
            folder.movieIds.contains(m.tmdbId.toString()))
        .toList();
  }


  Future<void> _handleRefresh() async {
    await context.read<TrackingProvider>().refresh();
    await context.read<WatchlistFolderProvider>().syncFromAppwrite();
  }

  // ─── UI Builders ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Consumer2<TrackingProvider, WatchlistFolderProvider>(
      builder: (ctx, provider, folderProvider, _) {
        final folders = folderProvider.folders;
        final allWatchlist = _filteredSorted(provider.allTracked);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle.light,
          child: Scaffold(
            backgroundColor: AppColors.background,
            body: Stack(
              children: [
                // Background gradient
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(-0.6, -0.8),
                        radius: 1.2,
                        colors: [
                          AppColors.primary.withOpacity(0.12),
                          AppColors.background,
                        ],
                      ),
                    ),
                  ),
                ),

                // Main Content
                RefreshIndicator(
                  onRefresh: _handleRefresh,
                  backgroundColor: AppColors.surface,
                  color: AppColors.primary,
                  displacement: 80,
                  child: _folderView
                      ? _buildFolderView(allWatchlist, folders)
                      : _buildAllView(allWatchlist, folders),
                ),

                // FAB
                Positioned(
                  bottom: 28,
                  right: 24,
                  child: ScaleTransition(
                    scale: _fabScale,
                    child: _isSelectionMode ? const SizedBox.shrink() : _buildFAB(),
                  ),
                ),

                // Selection Action Bar
                if (_isSelectionMode)
                  _buildSelectionActionBar(provider, folderProvider),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSelectionActionBar(TrackingProvider provider, WatchlistFolderProvider folderProvider) {
    return Positioned(
      bottom: 20,
      left: 20,
      right: 20,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  '${_selectedIds.length} Selected',
                  style: GoogleFonts.dmSans(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : () => _bulkMoveToFolder(provider, folderProvider),
                  icon: const Icon(Icons.folder_open_rounded, size: 18),
                  label: const Text('Move'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _selectedIds.isEmpty ? null : () => _bulkRemove(provider),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _bulkRemove(TrackingProvider provider) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Selected?', style: TextStyle(color: Colors.white)),
        content: Text('Are you sure you want to remove ${_selectedIds.length} titles from your library?', 
          style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('REMOVE', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      for (final id in _selectedIds) {
        await provider.removeTracking(id);
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
    }
  }

  void _bulkMoveToFolder(TrackingProvider provider, WatchlistFolderProvider folderProvider) async {
    final folders = folderProvider.folders;
    final folder = await showModalBottomSheet<WatchlistFolder>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Move to Folder', style: GoogleFonts.dmSans(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...folders.map((f) => ListTile(
              leading: Text(f.emoji, style: const TextStyle(fontSize: 20)),
              title: Text(f.name, style: const TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(ctx, f),
            )),
          ],
        ),
      ),
    );

    if (folder != null) {
      for (final id in _selectedIds) {
        final title = provider.getTracking(id);
        if (title != null) {
          folderProvider.addToFolder(
            id: id.toString(),
            title: title.title,
            posterPath: title.posterPath,
            isMovie: title.mediaType == 'movie',
            folderId: folder.id,
          );
        }
      }
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Moved ${_selectedIds.length} items to ${folder.name}')),
      );
    }
  }

  // ── All Titles View ─────────────────────────────────────────────────────────

  Widget _buildAllView(List<UserTitle> items, List<WatchlistFolder> folders) {

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(items.length),
        _buildFilterBar(items),
        _buildSortBar(),
        if (items.isEmpty)
          SliverFillRemaining(child: _buildEmpty())
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.65,
              ),
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _MovieGridCard(
                  movie: items[i],
                  isSelected: _selectedIds.contains(items[i].tmdbId),
                  isSelectionMode: _isSelectionMode,
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (_selectedIds.contains(items[i].tmdbId)) {
                          _selectedIds.remove(items[i].tmdbId);
                          if (_selectedIds.isEmpty) _isSelectionMode = false;
                        } else {
                          _selectedIds.add(items[i].tmdbId);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WatchlistDetailScreen(tmdbId: items[i].tmdbId)),
                      );
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedIds.add(items[i].tmdbId);
                    });
                  },
                  onRemove: () => context
                      .read<TrackingProvider>()
                      .removeTracking(items[i].tmdbId),
                ),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Folder View ─────────────────────────────────────────────────────────────

  Widget _buildFolderView(List<UserTitle> allItems, List<WatchlistFolder> folders) {
    if (_activeFolderId != null) {
      final activeFolder = folders.firstWhere((f) => f.id == _activeFolderId,
          orElse: () => folders.first);
      final folderItems = _folderItems(allItems, activeFolder);
      return _buildFolderDetail(folderItems, folders);
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverHeader(allItems.length, folderMode: true),
        _buildFilterBar(allItems),
        _buildSortBar(),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.0,
            ),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) {
                if (i == folders.length) return _buildNewFolderCard();
                final folder = folders[i];
                final count = allItems
                    .where((m) =>
                        folder.movieIds.contains(m.tmdbId.toString()))
                    .length;
                return _FolderCard(
                  folder: folder,
                  movieCount: count,
                  movies: allItems
                      .where((m) =>
                          folder.movieIds.contains(m.tmdbId.toString()))
                      .take(4)
                      .toList(),
                  onTap: () => setState(() => _activeFolderId = folder.id),
                  onEdit: () => _showEditFolderSheet(folder),
                  onDelete: () => _deleteFolder(folder),
                );
              },
              childCount: folders.length + 1,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFolderDetail(List<UserTitle> items, List<WatchlistFolder> folders) {

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverAppBar(
          backgroundColor: Colors.transparent,
          expandedHeight: 130,
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: Colors.white),
            onPressed: () => setState(() => _activeFolderId = null),
          ),
          title: const SizedBox.shrink(),
          actions: [
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              onPressed: () {
                final activeFolder = folders.firstWhere((f) => f.id == _activeFolderId);
                _showEditFolderSheet(activeFolder);
              },
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding:
                const EdgeInsets.only(left: 56, bottom: 16),
            title: Row(
              children: [
                Builder(
                  builder: (context) {
                    final activeFolder = folders.firstWhere((f) => f.id == _activeFolderId);
                    return Text(
                      activeFolder.emoji,
                      style: const TextStyle(fontSize: 24),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final activeFolder = folders.firstWhere((f) => f.id == _activeFolderId);
                    return Text(
                      activeFolder.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
        _buildFilterBar(items),
        _buildSortBar(),
        if (items.isEmpty)
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Builder(
                    builder: (context) {
                      final activeFolder = folders.firstWhere((f) => f.id == _activeFolderId);
                      return Text(activeFolder.emoji,
                          style: const TextStyle(fontSize: 48));
                    }
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'This folder is empty',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.5), fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add titles from the watchlist',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.3), fontSize: 13),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _MovieCard(
                  movie: items[i],
                  folders: folders,
                  relativeTime: _relativeTime(items[i].updatedAt),
                  isSelected: _selectedIds.contains(items[i].tmdbId),
                  isSelectionMode: _isSelectionMode,
                  onTap: () {
                    if (_isSelectionMode) {
                      setState(() {
                        if (_selectedIds.contains(items[i].tmdbId)) {
                          _selectedIds.remove(items[i].tmdbId);
                          if (_selectedIds.isEmpty) _isSelectionMode = false;
                        } else {
                          _selectedIds.add(items[i].tmdbId);
                        }
                      });
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => WatchlistDetailScreen(tmdbId: items[i].tmdbId)),
                      );
                    }
                  },
                  onLongPress: () {
                    setState(() {
                      _isSelectionMode = true;
                      _selectedIds.add(items[i].tmdbId);
                    });
                  },
                  onAddToFolder: (fid) =>
                      _addToFolder(items[i], fid),
                  onRemove: () => context
                      .read<TrackingProvider>()
                      .removeTracking(items[i].tmdbId),
                ),
                childCount: items.length,
              ),
            ),
          ),
      ],
    );
  }

  // ── Sliver Header ───────────────────────────────────────────────────────────

  Widget _buildSliverHeader(int count, {bool folderMode = false}) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      expandedHeight: 120,
      pinned: true,
      floating: false,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(builder: (ctx, constraints) {
        final collapsed = constraints.maxHeight < 100;
        return ClipRect(
          child: BackdropFilter(
            filter: collapsed
                ? ImageFilter.blur(sigmaX: 18, sigmaY: 18)
                : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
            child: Container(
              decoration: BoxDecoration(
                color: collapsed
                    ? AppColors.background.withOpacity(0.85)
                    : Colors.transparent,
              ),
              child: FlexibleSpaceBar(
                titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
                title: collapsed
                    ? _buildCollapsedHeader(count)
                    : null,
                background: _buildExpandedHeader(count, folderMode),
              ),
            ),
          ),
        );
      }),
      actions: [
        if (_isSelectionMode) ...[
          TextButton(
            onPressed: () {
              setState(() {
                final allTracked = context.read<TrackingProvider>().allTracked;
                if (_selectedIds.length == allTracked.length) {
                  _selectedIds.clear();
                  _isSelectionMode = false;
                } else {
                  _selectedIds.addAll(allTracked.map((m) => m.tmdbId));
                }
              });
            },
            child: Text(
              _selectedIds.length == context.read<TrackingProvider>().allTracked.length 
                  ? 'DESELECT ALL' : 'SELECT ALL',
              style: GoogleFonts.dmSans(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => setState(() {
              _isSelectionMode = false;
              _selectedIds.clear();
            }),
          ),
        ] else if (_searchActive)
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () {
              setState(() {
                _searchActive = false;
                _query = '';
                _searchController.clear();
              });
            },
          )
        else ...[
          IconButton(
            icon: Icon(Icons.search_rounded,
                color: Colors.white.withOpacity(0.85)),
            onPressed: () => setState(() => _searchActive = true),
          ),
          // Toggle: list ↔ folder
          IconButton(
            icon: Icon(
              _folderView
                  ? Icons.list_rounded
                  : Icons.folder_outlined,
              color: Colors.white.withOpacity(0.85),
            ),
            onPressed: () => setState(() {
              _folderView = !_folderView;
              _activeFolderId = null;
            }),
          ),
        ],
      ],
    );
  }

  Widget _buildExpandedHeader(int count, bool folderMode) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 45, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.primary.withOpacity(0.35),
                    width: 1),
              ),
              child: Text(
                folderMode ? 'FOLDERS' : 'LIBRARY',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          if (_searchActive)
            _buildSearchField()
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    folderMode ? 'My Folders' : 'My Library',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.1,
                    ),
                  ),
                ),
                _CountBadge(count: count),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildCollapsedHeader(int count) {
    return _searchActive
        ? SizedBox(
            height: 36,
            child: _buildSearchField(compact: true),
          )
        : Row(
            children: [
              const Text(
                'My Library',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              _CountBadge(count: count, small: true),
            ],
          );
  }

  Widget _buildSearchField({bool compact = false}) {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: TextStyle(
          color: Colors.white, fontSize: compact ? 15 : 18),
      decoration: InputDecoration(
        hintText: 'Search watchlist…',
        hintStyle:
            TextStyle(color: Colors.white.withOpacity(0.35), fontSize: compact ? 15 : 18),
        prefixIcon: Icon(Icons.search_rounded,
            color: Colors.white.withOpacity(0.4),
            size: compact ? 18 : 22),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
            vertical: compact ? 8 : 0, horizontal: 4),
      ),
      onChanged: (v) => setState(() => _query = v),
    );
  }

  // ── Filter Bar ───────────────────────────────────────────────────────────────

  Widget _buildFilterBar(List<UserTitle> allItems) {
    return SliverToBoxAdapter(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: _StatusFilter.values.map((f) {
            final isSelected = _statusFilter == f;
            final count = _getCountForStatus(allItems, f);
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _statusFilter = f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white10,
                    ),
                    boxShadow: isSelected ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      )
                    ] : null,
                  ),
                  child: Row(
                    children: [
                      Text(
                        _getStatusLabel(f),
                        style: GoogleFonts.dmSans(
                          color: isSelected ? Colors.white : Colors.white54,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 6),
                        Text(
                          '($count)',
                          style: GoogleFonts.dmSans(
                            color: isSelected
                                ? Colors.white.withOpacity(0.7)
                                : Colors.white24,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  int _getCountForStatus(List<UserTitle> items, _StatusFilter f) {
    if (f == _StatusFilter.all) return items.length;
    final target = switch (f) {
      _StatusFilter.watching => TrackingStatus.watching,
      _StatusFilter.completed => TrackingStatus.watched,
      _StatusFilter.onHold => TrackingStatus.onHold,
      _StatusFilter.dropped => TrackingStatus.dropped,
      _StatusFilter.planToWatch => TrackingStatus.watchlist,
      _StatusFilter.all => null,
    };
    return items.where((m) => m.status == target).length;
  }

  String _getStatusLabel(_StatusFilter f) {
    return switch (f) {
      _StatusFilter.all => 'All',
      _StatusFilter.watching => 'Watching',
      _StatusFilter.completed => 'Completed',
      _StatusFilter.onHold => 'On Hold',
      _StatusFilter.dropped => 'Dropped',
      _StatusFilter.planToWatch => 'Plan to Watch',
    };
  }

  String _getTypeLabel(_MediaTypeFilter f) {
    return switch (f) {
      _MediaTypeFilter.all => 'All Media',
      _MediaTypeFilter.movies => 'Movies',
      _MediaTypeFilter.series => 'Series',
    };
  }

  // ── Sort Bar ────────────────────────────────────────────────────────────────

  Widget _buildSortBar() {
    return SliverPersistentHeader(
      pinned: false,
      delegate: _SortBarDelegate(
        selectedSort: _sort,
        onChanged: (s) => setState(() => _sort = s),
        onFilterTap: _showAdvancedFilters,
        isFilterActive: _selectedGenre != null || _selectedYear != null || _typeFilter != _MediaTypeFilter.all,
      ),
    );
  }

  void _showAdvancedFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _AdvancedFilterSheet(
        selectedGenre: _selectedGenre,
        selectedYear: _selectedYear,
        selectedType: _typeFilter,
        onApply: (genre, year, type) {
          setState(() {
            _selectedGenre = genre;
            _selectedYear = year;
            _typeFilter = type ?? _MediaTypeFilter.all;
          });
        },
        onReset: () {
          setState(() {
            _selectedGenre = null;
            _selectedYear = null;
            _typeFilter = _MediaTypeFilter.all;
          });
        },
      ),
    );
  }

  // ── Empty State ─────────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.08),
              border: Border.all(
                  color: AppColors.primary.withOpacity(0.2), width: 1.5),
            ),
            child: const Icon(Icons.bookmark_border_rounded,
                color: AppColors.primary, size: 36),
          ),
          const SizedBox(height: 20),
          const Text(
            'Nothing here yet',
            style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the bookmark on any title\nto add it to your watchlist',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: Colors.white.withOpacity(0.4),
                fontSize: 14,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  // ── FAB ─────────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return GestureDetector(
      onTap: () => _showCreateFolderSheet(),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFFB71C1C)],
          ),
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.create_new_folder_outlined,
                color: Colors.white, size: 20),
            SizedBox(width: 8),
            Text(
              'New Folder',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── New Folder Card ─────────────────────────────────────────────────────────

  Widget _buildNewFolderCard() {
    return GestureDetector(
      onTap: _showCreateFolderSheet,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.5,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: const Icon(Icons.add_rounded,
                  color: AppColors.primary, size: 26),
            ),
            const SizedBox(height: 10),
            const Text(
              'New Folder',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Folder Actions ──────────────────────────────────────────────────────────

  void _addToFolder(UserTitle title, String folderId) {
    context.read<WatchlistFolderProvider>().addToFolder(
          id: title.tmdbId.toString(),
          title: title.title,
          posterPath: title.posterPath,
          isMovie: title.mediaType == 'movie',
          folderId: folderId,
        );
  }


  void _deleteFolder(WatchlistFolder folder) {
    context.read<WatchlistFolderProvider>().deleteFolder(folder.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${folder.emoji} ${folder.name} deleted'),
        backgroundColor: AppColors.surface2,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showCreateFolderSheet() {
    _showFolderSheet(
      title: 'New Folder',
      onSave: (name, emoji) {
        context.read<WatchlistFolderProvider>().addFolder(WatchlistFolder(
              id: 'f${DateTime.now().millisecondsSinceEpoch}',
              name: name,
              emoji: emoji,
              createdAt: DateTime.now(),
            ));
        setState(() => _folderView = true);
      },
    );
  }

  void _showEditFolderSheet(WatchlistFolder folder) {
    _showFolderSheet(
      title: 'Edit Folder',
      initialName: folder.name,
      initialEmoji: folder.emoji,
      onSave: (name, emoji) {
        context
            .read<WatchlistFolderProvider>()
            .updateFolder(folder.id, name: name, emoji: emoji);
      },
    );
  }

  void _showFolderSheet({
    required String title,
    String initialName = '',
    String initialEmoji = '📁',
    required void Function(String name, String emoji) onSave,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderFormSheet(
        title: title,
        initialName: initialName,
        initialEmoji: initialEmoji,
        onSave: (name, emoji) {
          Navigator.pop(context);
          onSave(name, emoji);
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SORT BAR DELEGATE
// ─────────────────────────────────────────────────────────────────────────────

enum _SortOption { recent, az, rating, added, updated }
enum _StatusFilter { all, watching, completed, onHold, dropped, planToWatch }
enum _MediaTypeFilter { all, movies, series }

class _SortBarDelegate extends SliverPersistentHeaderDelegate {
  final _SortOption selectedSort;
  final ValueChanged<_SortOption> onChanged;
  final VoidCallback onFilterTap;
  final bool isFilterActive;

  _SortBarDelegate({
    required this.selectedSort,
    required this.onChanged,
    required this.onFilterTap,
    this.isFilterActive = false,
  });

  @override
  double get minExtent => 44;
  @override
  double get maxExtent => 44;

  @override
  bool shouldRebuild(_SortBarDelegate old) =>
      old.selectedSort != selectedSort || old.isFilterActive != isFilterActive;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      height: 44,
      color: AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            'Sort by',
            style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: _SortOption.values.map((opt) {
                  final label = switch (opt) {
                    _SortOption.recent => 'Recent',
                    _SortOption.az => 'A–Z',
                    _SortOption.rating => 'Top Rated',
                    _SortOption.added => 'Date Added',
                    _SortOption.updated => 'Last Updated',
                  };
                  final selected = selectedSort == opt;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => onChanged(opt),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : Colors.white.withOpacity(0.55),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onFilterTap,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isFilterActive
                    ? AppColors.primary.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isFilterActive
                      ? AppColors.primary.withOpacity(0.5)
                      : Colors.white10,
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                size: 18,
                color: isFilterActive ? AppColors.primary : Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// MOVIE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _MovieCard extends StatelessWidget {
  final UserTitle movie;
  final List<WatchlistFolder> folders;
  final String relativeTime;
  final void Function(String folderId) onAddToFolder;
  final VoidCallback onRemove;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MovieCard({
    required this.movie,
    required this.folders,
    required this.relativeTime,
    required this.onAddToFolder,
    required this.onRemove,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          height: 110,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.white.withOpacity(0.07), 
                width: 1),
          ),
          child: Row(children: [
            if (isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Icon(
                  isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: isSelected ? AppColors.primary : Colors.white30,
                  size: 24,
                ),
              ),
            // Poster
            ClipRRect(
              borderRadius:
                  const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Hero(
                tag: 'poster_${movie.tmdbId}',
                child: CachedNetworkImage(
                  imageUrl: movie.posterPath.startsWith('http')
                      ? movie.posterPath
                      : 'https://image.tmdb.org/t/p/w200${movie.posterPath}',
                  width: 74,
                  height: 110,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => _posterPlaceholder(),
                  errorWidget: (context, url, error) => _posterPlaceholder(),
                ),
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      movie.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Row(children: [
                      if (movie.userRating != null) ...[
                        const Icon(Icons.star_rounded,
                            color: AppColors.ratingGold, size: 14),
                        const SizedBox(width: 3),
                        Text(
                          movie.userRating!.toStringAsFixed(1),
                          style: const TextStyle(
                              color: AppColors.ratingGold,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 10),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _getStatusColor(movie.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: _getStatusColor(movie.status).withOpacity(0.3), width: 0.5),
                        ),
                        child: Text(
                          movie.status.displayName.toUpperCase(),
                          style: TextStyle(
                            color: _getStatusColor(movie.status),
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        relativeTime,
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.35),
                            fontSize: 11),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Actions column
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Folder add
                _ActionBtn(
                  icon: Icons.folder_outlined,
                  color: AppColors.primary,
                  onTap: () => _showFolderPicker(context),
                ),
                // Remove
                _ActionBtn(
                  icon: Icons.bookmark_remove_outlined,
                  color: Colors.redAccent,
                  onTap: onRemove,
                ),
              ],
            ),
            const SizedBox(width: 8),
          ]),
        ),
      ),
    );
  }


  Color _getStatusColor(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.watchlist: return Colors.blueAccent;
      case TrackingStatus.watching: return AppColors.primary;
      case TrackingStatus.watched: return Colors.greenAccent;
      case TrackingStatus.onHold: return Colors.orangeAccent;
      case TrackingStatus.dropped: return Colors.redAccent;
      case TrackingStatus.rewatching: return Colors.purpleAccent;
    }
  }

  Widget _posterPlaceholder() {
    return Container(
      width: 74,
      height: 110,
      color: Colors.white.withOpacity(0.06),
      child: Icon(Icons.movie_outlined,
          color: Colors.white.withOpacity(0.2), size: 28),
    );
  }

  void _showFolderPicker(BuildContext context) {
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Create a folder first'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolderPickerSheet(
        folders: folders,
        onSelect: onAddToFolder,
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn(
      {required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOLDER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _FolderCard extends StatelessWidget {
  final WatchlistFolder folder;
  final int movieCount;
  final List<UserTitle> movies;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FolderCard({
    required this.folder,
    required this.movieCount,
    required this.movies,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: () => _showMenu(context),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.05), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              // Poster collage background
              if (movies.isNotEmpty)
                Positioned.fill(
                  child: _MagazineCollage(movies: movies),
                ),

              // Glassmorphic Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.2),
                        Colors.black.withOpacity(0.8),
                      ],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        folder.emoji,
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      folder.name.toUpperCase(),
                      style: GoogleFonts.playfairDisplay(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$movieCount TITLES',
                      style: GoogleFonts.dmSans(
                        color: AppColors.primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),

              // Options
              Positioned(
                top: 12,
                right: 12,
                child: GestureDetector(
                  onTap: () => _showMenu(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.more_horiz_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _QuickMenuSheet(
        title: '${folder.emoji} ${folder.name}',
        items: [
          _QuickMenuItem(
              icon: Icons.edit_outlined,
              label: 'Edit Folder',
              onTap: onEdit),
          _QuickMenuItem(
              icon: Icons.delete_outline_rounded,
              label: 'Delete Folder',
              color: Colors.redAccent,
              onTap: onDelete),
        ],
      ),
    );
  }
}

class _MagazineCollage extends StatelessWidget {
  final List<UserTitle> movies;
  const _MagazineCollage({required this.movies});

  @override
  Widget build(BuildContext context) {
    if (movies.length == 1) return _poster(movies[0]);
    
    return Stack(
      children: [
        Positioned.fill(child: _poster(movies[0])),
        if (movies.length > 1)
          Positioned(
            right: -20,
            bottom: -20,
            child: Transform.rotate(
              angle: 0.2,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _poster(movies[1]),
                ),
              ),
            ),
          ),
        if (movies.length > 2)
          Positioned(
            left: -10,
            top: 20,
            child: Transform.rotate(
              angle: -0.1,
              child: Container(
                width: 60,
                height: 90,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 8)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _poster(movies[2]),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _poster(UserTitle m) {
    final url = m.posterPath.startsWith('http') 
        ? m.posterPath 
        : 'https://image.tmdb.org/t/p/w200${m.posterPath}';
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      placeholder: (context, url) => Container(color: AppColors.surface),
      errorWidget: (context, url, error) => Container(color: Colors.black26),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COUNT BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _CountBadge extends StatelessWidget {
  final int count;
  final bool small;
  const _CountBadge({required this.count, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 8 : 12, vertical: small ? 3 : 5),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: small ? 11 : 14,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SHEETS
// ─────────────────────────────────────────────────────────────────────────────

class _FolderFormSheet extends StatefulWidget {
  final String title;
  final String initialName;
  final String initialEmoji;
  final void Function(String name, String emoji) onSave;

  const _FolderFormSheet({
    required this.title,
    required this.initialName,
    required this.initialEmoji,
    required this.onSave,
  });

  @override
  State<_FolderFormSheet> createState() => _FolderFormSheetState();
}

class _FolderFormSheetState extends State<_FolderFormSheet> {
  late TextEditingController _nameCtrl;
  late String _selectedEmoji;

  static const _emojis = [
    '📁', '🔥', '💑', '🎬', '⭐', '🍿', '😱', '😂',
    '😍', '🎭', '🌙', '🏆', '🎞️', '🧠', '🌟', '📽️',
  ];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _selectedEmoji = widget.initialEmoji;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 20,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                widget.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 20),

              // Emoji picker
              Text(
                'Pick an icon',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _emojis.map((e) {
                    final sel = e == _selectedEmoji;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedEmoji = e),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 46,
                        height: 46,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: sel
                              ? AppColors.primary.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: sel ? AppColors.primary : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            e,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 20),

              // Name field
              Text(
                'Folder name',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) {
                    final name = _nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      widget.onSave(name, _selectedEmoji);
                    }
                  },
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  decoration: InputDecoration(
                    hintText: 'e.g. Must Watch, Movie Night…',
                    hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () {
                    final name = _nameCtrl.text.trim();
                    if (name.isNotEmpty) {
                      widget.onSave(name, _selectedEmoji);
                    }
                  },
                  child: const Text(
                    'Save Folder',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Folder Picker ───────────────────────────────────────────────────────────

class _FolderPickerSheet extends StatelessWidget {
  final List<WatchlistFolder> folders;
  final void Function(String folderId) onSelect;

  const _FolderPickerSheet({required this.folders, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Add to Folder',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          ...folders.map((f) => ListTile(
                leading: Text(f.emoji, style: const TextStyle(fontSize: 24)),
                title: Text(
                  f.name,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  '${f.movieIds.length} titles',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.4), fontSize: 12),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(context);
                  onSelect(f.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Added to ${f.emoji} ${f.name}'),
                      backgroundColor: AppColors.surface2,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                },
              )),
        ],
      ),
    );
  }
}

// ─── Quick Menu ──────────────────────────────────────────────────────────────

class _QuickMenuItem {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;
  _QuickMenuItem(
      {required this.icon,
      required this.label,
      this.color,
      required this.onTap});
}

class _QuickMenuSheet extends StatelessWidget {
  final String title;
  final List<_QuickMenuItem> items;

  const _QuickMenuSheet({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          ...items.map((item) => ListTile(
                leading: Icon(item.icon,
                    color: item.color ?? Colors.white.withOpacity(0.8),
                    size: 22),
                title: Text(
                  item.label,
                  style: TextStyle(
                    color: item.color ?? Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                contentPadding: EdgeInsets.zero,
                onTap: () {
                  Navigator.pop(context);
                  item.onTap();
                },
              )),
        ],
      ),
    );
  }
}

// ─── Advanced Filter Sheet ──────────────────────────────────────────────────

class _AdvancedFilterSheet extends StatefulWidget {
  final String? selectedGenre;
  final String? selectedYear;
  final _MediaTypeFilter selectedType;
  final Function(String?, String?, _MediaTypeFilter?) onApply;
  final VoidCallback onReset;

  const _AdvancedFilterSheet({
    this.selectedGenre,
    this.selectedYear,
    required this.selectedType,
    required this.onApply,
    required this.onReset,
  });

  @override
  State<_AdvancedFilterSheet> createState() => _AdvancedFilterSheetState();
}

class _AdvancedFilterSheetState extends State<_AdvancedFilterSheet> {
  String? _genre;
  String? _year;
  _MediaTypeFilter? _type;

  final List<String> _genres = [
    'Action', 'Adventure', 'Animation', 'Comedy', 'Crime', 'Documentary',
    'Drama', 'Family', 'Fantasy', 'History', 'Horror', 'Music', 'Mystery',
    'Romance', 'Science Fiction', 'TV Movie', 'Thriller', 'War', 'Western'
  ];

  final List<String> _years = List.generate(30, (i) => (2026 - i).toString());

  @override
  void initState() {
    super.initState();
    _genre = widget.selectedGenre;
    _year = widget.selectedYear;
    _type = widget.selectedType;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onReset();
                  Navigator.pop(context);
                },
                child: Text(
                  'RESET ALL',
                  style: GoogleFonts.dmSans(
                    color: Colors.redAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('CONTENT TYPE'),
          const SizedBox(height: 12),
          Row(
            children: _MediaTypeFilter.values.map((t) {
              final isSelected = _type == t;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(switch (t) {
                    _MediaTypeFilter.all => 'All',
                    _MediaTypeFilter.movies => 'Movies',
                    _MediaTypeFilter.series => 'Series',
                  }),
                  selected: isSelected,
                  onSelected: (val) => setState(() => _type = val ? t : _MediaTypeFilter.all),
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white.withOpacity(0.05),
                  labelStyle: GoogleFonts.dmSans(
                    color: isSelected ? Colors.white : Colors.white60,
                    fontSize: 12,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('GENRE'),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: _genres.map((g) {
                final isSelected = _genre == g;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _genre = val ? g : null),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: GoogleFonts.dmSans(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle('RELEASE YEAR'),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: _years.map((y) {
                final isSelected = _year == y;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(y),
                    selected: isSelected,
                    onSelected: (val) => setState(() => _year = val ? y : null),
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white.withOpacity(0.05),
                    labelStyle: GoogleFonts.dmSans(
                      color: isSelected ? Colors.white : Colors.white60,
                      fontSize: 12,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              onPressed: () {
                widget.onApply(_genre, _year, _type);
                Navigator.pop(context);
              },
              child: Text(
                'SHOW RESULTS',
                style: GoogleFonts.dmSans(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        color: AppColors.textMuted,
        fontSize: 10,
        letterSpacing: 2,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}

class _MovieGridCard extends StatelessWidget {
  final UserTitle movie;
  final VoidCallback onRemove;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _MovieGridCard({
    required this.movie,
    required this.onRemove,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Hero(
                  tag: 'poster_${movie.tmdbId}',
                  child: CachedNetworkImage(
                    imageUrl: 'https://image.tmdb.org/t/p/w342${movie.posterPath}',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: AppColors.surface),
                  ),
                ),
              ),
              // Gradient Overlay
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.9),
                      ],
                    ),
                  ),
                ),
              ),
              // Selection Mode Overlay
              if (isSelectionMode)
                Positioned.fill(
                  child: Container(
                    color: isSelected ? AppColors.primary.withOpacity(0.4) : Colors.black45,
                    child: Center(
                      child: Icon(
                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                ),
              // Metadata
              Positioned(
                bottom: 12,
                left: 10,
                right: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movie.title.toUpperCase(),
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            movie.status.name.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 6, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (movie.userRating != null) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 8),
                          Text(
                            ' ${movie.userRating!.toStringAsFixed(1)}',
                            style: const TextStyle(color: Colors.white70, fontSize: 8, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Remove from Library', style: TextStyle(color: Colors.redAccent)),
              onTap: () {
                Navigator.pop(context);
                onRemove();
              },
            ),
          ],
        ),
      ),
    );
  }
}