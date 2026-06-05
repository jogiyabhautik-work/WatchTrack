import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/features/import_watchlist/domain/import_matcher.dart';
import 'package:watch_track/features/import_watchlist/presentation/watchlist_import_provider.dart';
import 'package:watch_track/features/import_watchlist/widgets/import_item_tile.dart';
import 'package:watch_track/core/providers/watchlist_folder_provider.dart';

class ImportReviewScreen extends StatefulWidget {
  const ImportReviewScreen({super.key});

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedFolder;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WatchlistImportProvider>();
    final folderProvider = context.read<WatchlistFolderProvider>();

    if (provider.state == ImportState.readingFile || provider.state == ImportState.searchingTMDB) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 24),
              Text(
                provider.state == ImportState.readingFile ? 'Reading File...' : 'Searching TMDB...',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 8),
              if (provider.state == ImportState.searchingTMDB)
                Text(
                  '${provider.processedItems} / ${provider.totalItems}',
                  style: GoogleFonts.dmSans(color: AppColors.textMuted),
                ),
            ],
          ),
        ),
      );
    }

    if (provider.state == ImportState.error) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(backgroundColor: AppColors.background),
        body: Center(
          child: Text(
            provider.errorMessage ?? 'An error occurred',
            style: GoogleFonts.dmSans(color: Colors.red),
          ),
        ),
      );
    }

    if (provider.state == ImportState.done) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: AppColors.primary, size: 64),
              const SizedBox(height: 24),
              Text(
                'Import Complete!',
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                ),
                child: Text('DONE', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      );
    }

    final matched = provider.results.where((r) => r.status == MatchStatus.matched).toList();
    final duplicate = provider.results.where((r) => r.status == MatchStatus.duplicate).toList();
    final review = provider.results.where((r) => r.status == MatchStatus.needsReview).toList();
    final notFound = provider.results.where((r) => r.status == MatchStatus.notFound).toList();
    final selectedCount = provider.results.where((r) => r.isSelected).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text('Import Review', style: GoogleFonts.dmSans(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.select_all),
            onPressed: () => provider.selectAll(),
            tooltip: 'Select All',
          ),
          IconButton(
            icon: const Icon(Icons.deselect),
            onPressed: () => provider.deselectAll(),
            tooltip: 'Deselect All',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          tabs: [
            Tab(text: 'Ready (${matched.length})'),
            Tab(text: 'Dupes (${duplicate.length})'),
            Tab(text: 'Review (${review.length})'),
            Tab(text: 'Missing (${notFound.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildList(matched, provider),
          _buildList(duplicate, provider),
          _buildList(review, provider),
          _buildList(notFound, provider),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          color: AppColors.surface,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Folder Selection
              Row(
                children: [
                  Text('Import to: ', style: GoogleFonts.dmSans(color: Colors.white70)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      dropdownColor: AppColors.surface,
                      value: _selectedFolder,
                      hint: Text('Default Watchlist', style: GoogleFonts.dmSans(color: Colors.white54)),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Default Watchlist')),
                        ...folderProvider.folders.map((f) => DropdownMenuItem(
                          value: f.name,
                          child: Text(f.name),
                        )),
                        DropdownMenuItem(
                          value: 'Create "${provider.fileName.split('.').first}"',
                          child: Text('Create Folder from File'),
                        ),
                      ],
                      onChanged: (val) {
                        setState(() {
                          _selectedFolder = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: selectedCount > 0
                      ? () {
                          String? targetFolder = _selectedFolder;
                          if (_selectedFolder != null && _selectedFolder!.startsWith('Create ')) {
                            targetFolder = provider.fileName.split('.').first;
                          }
                          provider.commitImport(targetFolderName: targetFolder);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text(
                    'Import $selectedCount Items',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<MatchResult> items, WatchlistImportProvider provider) {
    if (items.isEmpty) {
      return Center(
        child: Text('No items here.', style: GoogleFonts.dmSans(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return ImportItemTile(
          result: items[index],
          onToggle: () => provider.toggleSelection(items[index]),
        );
      },
    );
  }
}
