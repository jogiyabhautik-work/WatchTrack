import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:watch_track/core/constants/app_colors.dart';
import 'package:watch_track/core/providers/tracking_provider.dart';
import 'package:watch_track/data/models/user_title_model.dart';
import 'package:watch_track/data/models/movie_model.dart';
import '../../../back-end/api_service.dart';
import 'package:watch_track/presentation/screens/detail/detail_screen.dart';

class WatchlistDetailScreen extends StatefulWidget {
  final int tmdbId;

  const WatchlistDetailScreen({super.key, required this.tmdbId});

  @override
  State<WatchlistDetailScreen> createState() => _WatchlistDetailScreenState();
}

class _WatchlistDetailScreenState extends State<WatchlistDetailScreen> {
  final TextEditingController _notesController = TextEditingController();
  final ApiService _apiService = ApiService();
  Movie? _fullMovie;
  bool _isLoadingMetadata = false;
  String? _metadataError;
  bool _isEditingNotes = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchMetadata();
    });
  }

  Future<void> _fetchMetadata() async {
    final tracking = context.read<TrackingProvider>();
    final item = tracking.getTracking(widget.tmdbId);
    if (item == null) return;

    setState(() {
      _isLoadingMetadata = true;
      _metadataError = null;
    });

    try {
      final movieDetails = await _apiService.getMovieById(
        item.tmdbId.toString(),
        isMovie: item.mediaType == 'movie',
      );

      if (!mounted) return;

      if (movieDetails != null) {
        setState(() => _fullMovie = movieDetails);
        tracking.updateTrackingDetails(
          tmdbId: item.tmdbId,
          backdropPath: item.backdropPath.isEmpty
              ? movieDetails.backdropPath
              : null,
          overview: item.overview.isEmpty ? movieDetails.overview : null,
          totalEpisodes: item.mediaType == 'tv'
              ? movieDetails.totalEpisodes
              : null,
        );
      }
    } catch (e) {
      debugPrint('Error fetching metadata: $e');
      if (mounted) setState(() => _metadataError = 'Failed to load seasons');
    } finally {
      if (mounted) {
        setState(() => _isLoadingMetadata = false);
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _updateStatus(BuildContext context, TrackingStatus status) {
    final item = context.read<TrackingProvider>().getTracking(widget.tmdbId);
    context.read<TrackingProvider>().updateTrackingDetails(
      tmdbId: widget.tmdbId,
      status: status,
      progress: item?.mediaType == 'movie' && status == TrackingStatus.watched
          ? 100
          : null,
    );
    HapticFeedback.mediumImpact();
  }

  Movie _movieFromTitle(UserTitle item) {
    final enriched = _fullMovie;
    if (enriched != null) return enriched;

    return Movie(
      id: item.tmdbId.toString(),
      title: item.title,
      overview: item.overview,
      posterPath: item.posterPath,
      backdropPath: item.backdropPath,
      rating: 0,
      releaseDate: '',
      runtime: '',
      ageRating: '',
      genres: const [],
      cast: const [],
      isMovie: item.mediaType == 'movie',
      movieTotalEpisodes: item.totalEpisodes > 0 ? item.totalEpisodes : null,
    );
  }

  void _updatePriority(BuildContext context, String priority) {
    context.read<TrackingProvider>().updateTrackingDetails(
      tmdbId: widget.tmdbId,
      priority: priority,
    );
  }

  void _saveNotes(BuildContext context) {
    context.read<TrackingProvider>().updateTrackingDetails(
      tmdbId: widget.tmdbId,
      notes: _notesController.text,
    );
    setState(() => _isEditingNotes = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Notes saved!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<TrackingProvider>(
      builder: (context, tracking, child) {
        final item = tracking.getTracking(widget.tmdbId);

        if (item == null) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (_notesController.text.isEmpty &&
            item.notes != null &&
            !_isEditingNotes) {
          _notesController.text = item.notes!;
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, item),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildMainInfo(item),
                      const SizedBox(height: 32),
                      _buildStatusSection(context, item),
                      const SizedBox(height: 32),
                      if (item.mediaType == 'tv')
                        _buildTVProgressSection(context, item),
                      if (item.mediaType == 'movie')
                        _buildMovieProgressSection(context, item),
                      const SizedBox(height: 32),
                      _buildPersonalSection(context, item),
                      const SizedBox(height: 32),
                      _buildNotesSection(context, item),
                      const SizedBox(height: 40),
                      _buildDangerZone(context, item),
                      const SizedBox(height: 60),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSliverAppBar(BuildContext context, UserTitle item) {
    return SliverAppBar(
      expandedHeight: 280,
      backgroundColor: AppColors.background,
      elevation: 0,
      pinned: true,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new,
          color: Colors.white,
          size: 20,
        ),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white),
          onPressed: () {
            // Navigate to Discovery Detail Screen
            final movie = Movie(
              id: item.tmdbId.toString(),
              title: item.title,
              overview: item.overview,
              posterPath: item.posterPath,
              backdropPath: item.backdropPath,
              rating: 0, // Will fetch
              releaseDate: '',
              runtime: '',
              ageRating: '',
              genres: [],
              cast: [],
              isMovie: item.mediaType == 'movie',
            );
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DetailScreen(movie: movie),
              ),
            );
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            CachedNetworkImage(
              imageUrl: item.backdropPath,
              fit: BoxFit.cover,
              errorWidget: (context, url, error) =>
                  Container(color: AppColors.surface),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withValues(alpha: 0.3), AppColors.background],
                ),
              ),
            ),
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Hero(
                    tag: 'poster_${item.tmdbId}',
                    child: Container(
                      width: 100,
                      height: 150,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                        image: DecorationImage(
                          image: CachedNetworkImageProvider(item.posterPath),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.dmSans(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.primary.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                item.mediaType.toUpperCase(),
                                style: GoogleFonts.dmSans(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              item.status.displayName,
                              style: GoogleFonts.dmSans(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildMainInfo(UserTitle item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'OVERVIEW',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          item.overview.isNotEmpty ? item.overview : "No overview available.",
          style: GoogleFonts.dmSans(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusSection(BuildContext context, UserTitle item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TRACKING STATUS',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: TrackingStatus.values.map((s) {
            final isSelected = item.status == s;
            return GestureDetector(
              onTap: () => _updateStatus(context, s),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : AppColors.borderDefault,
                    width: 1,
                  ),
                ),
                child: Text(
                  s.displayName,
                  style: GoogleFonts.dmSans(
                    color: isSelected ? Colors.white : Colors.white70,
                    fontSize: 13,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTVProgressSection(BuildContext context, UserTitle item) {
    final movie = _movieFromTitle(item);
    final seasons = (_fullMovie?.seasons ?? [])
        .where((season) => season.seasonNumber > 0)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'EPISODE PROGRESS',
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              '${item.watchedEpisodes.length}/${item.totalEpisodes > 0 ? item.totalEpisodes : movie.totalEpisodes} EPS',
              style: GoogleFonts.dmSans(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: item.progressPercent / 100,
            minHeight: 4,
            backgroundColor: AppColors.surface2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          'SEASONS',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 4,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 18),
        if (_isLoadingMetadata && seasons.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_metadataError != null && seasons.isEmpty)
          Text(
            _metadataError!,
            style: GoogleFonts.dmSans(color: Colors.redAccent, fontSize: 13),
          )
        else if (seasons.isEmpty)
          Text(
            'Season details are not available yet.',
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 13),
          )
        else
          ...seasons.map(
            (season) => _WatchlistSeasonTile(
              tvId: item.tmdbId.toString(),
              season: season,
              apiService: _apiService,
              movie: movie,
            ),
          ),
      ],
    );
  }

  Widget _buildMovieProgressSection(BuildContext context, UserTitle item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WATCH PROGRESS',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    item.status == TrackingStatus.watched
                        ? 'COMPLETED'
                        : 'IN PROGRESS',
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${item.progressPercent}%',
                    style: GoogleFonts.dmSans(
                      color: AppColors.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: AppColors.primary,
                  inactiveTrackColor: Colors.black26,
                  thumbColor: AppColors.primary,
                  overlayColor: AppColors.primary.withValues(alpha: 0.2),
                  trackHeight: 4,
                ),
                child: Slider(
                  value: item.progressPercent.toDouble(),
                  min: 0,
                  max: 100,
                  onChanged: (v) {
                    final progress = v.round();
                    context.read<TrackingProvider>().updateTrackingDetails(
                      tmdbId: item.tmdbId,
                      progress: progress,
                      status: progress >= 100
                          ? TrackingStatus.watched
                          : (progress > 0
                                ? TrackingStatus.watching
                                : TrackingStatus.watchlist),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalSection(BuildContext context, UserTitle item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PERSONAL',
          style: GoogleFonts.dmSans(
            color: AppColors.textMuted,
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildInfoCard(
                label: 'Rating',
                child: Row(
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      item.userRating?.toString() ?? 'NR',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildInfoCard(
                label: 'Priority',
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: item.priority,
                    dropdownColor: AppColors.surface,
                    style: GoogleFonts.dmSans(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                    onChanged: (v) => _updatePriority(context, v!),
                    items: ['Low', 'Medium', 'High'].map((p) {
                      return DropdownMenuItem(value: p, child: Text(p));
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildInfoCard({required String label, required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(color: AppColors.textMuted, fontSize: 10),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }

  Widget _buildNotesSection(BuildContext context, UserTitle item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'PRIVATE NOTES',
              style: GoogleFonts.dmSans(
                color: AppColors.textMuted,
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_isEditingNotes)
              TextButton(
                onPressed: () => _saveNotes(context),
                child: Text(
                  'SAVE',
                  style: GoogleFonts.dmSans(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.edit_note,
                  color: Colors.white70,
                  size: 20,
                ),
                onPressed: () => setState(() => _isEditingNotes = true),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isEditingNotes
                  ? AppColors.primary
                  : AppColors.borderDefault,
            ),
          ),
          child: _isEditingNotes
              ? TextField(
                  controller: _notesController,
                  maxLines: 5,
                  autofocus: true,
                  style: GoogleFonts.dmSans(color: Colors.white, fontSize: 14),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Add your personal notes or review...',
                    hintStyle: TextStyle(color: Colors.white24),
                  ),
                )
              : Text(
                  item.notes?.isNotEmpty == true
                      ? item.notes!
                      : 'No notes added yet.',
                  style: GoogleFonts.dmSans(
                    color: item.notes?.isNotEmpty == true
                        ? Colors.white70
                        : Colors.white24,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildDangerZone(BuildContext context, UserTitle item) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DANGER ZONE',
          style: GoogleFonts.dmSans(
            color: Colors.redAccent.withValues(alpha: 0.7),
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppColors.surface,
                  title: const Text(
                    'Remove from Library?',
                    style: TextStyle(color: Colors.white),
                  ),
                  content: const Text(
                    'This will delete all your tracking progress and notes.',
                    style: TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('CANCEL'),
                    ),
                    TextButton(
                      onPressed: () {
                        context.read<TrackingProvider>().removeTracking(
                          item.tmdbId,
                        );
                        Navigator.pop(context); // Pop dialog
                        Navigator.pop(context); // Pop screen
                      },
                      child: const Text(
                        'REMOVE',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              );
            },
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Colors.redAccent.withValues(alpha: 0.3)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'REMOVE FROM LIBRARY',
              style: GoogleFonts.dmSans(
                color: Colors.redAccent,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WatchlistSeasonTile extends StatefulWidget {
  final String tvId;
  final Season season;
  final ApiService apiService;
  final Movie movie;

  const _WatchlistSeasonTile({
    required this.tvId,
    required this.season,
    required this.apiService,
    required this.movie,
  });

  @override
  State<_WatchlistSeasonTile> createState() => _WatchlistSeasonTileState();
}

class _WatchlistSeasonTileState extends State<_WatchlistSeasonTile> {
  bool _isLoading = false;
  Season? _fullSeason;
  String? _error;

  Future<void> _loadSeasonDetails() async {
    if (_fullSeason != null || _isLoading) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final season = await widget.apiService.getSeasonDetails(
        widget.tvId,
        widget.season.seasonNumber,
      );
      if (mounted) {
        setState(() {
          _fullSeason = season;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load episodes';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        hoverColor: Colors.transparent,
        splashColor: Colors.transparent,
      ),
      child: ExpansionTile(
        key: PageStorageKey('watchlist_season_${widget.season.seasonNumber}'),
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(top: 18, bottom: 16),
        onExpansionChanged: (expanded) {
          if (expanded) _loadSeasonDetails();
        },
        iconColor: AppColors.primary,
        collapsedIconColor: Colors.white70,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: CachedNetworkImage(
            imageUrl: widget.season.posterPath,
            width: 54,
            height: 74,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(color: AppColors.surface2),
            errorWidget: (context, url, error) => Container(
              width: 54,
              height: 74,
              color: AppColors.surface2,
              child: const Icon(Icons.tv, color: Colors.white30, size: 20),
            ),
          ),
        ),
        title: Text(
          widget.season.name.isNotEmpty
              ? widget.season.name
              : 'Season ${widget.season.seasonNumber}',
          style: GoogleFonts.dmSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '${widget.season.episodeCount} Episodes',
            style: GoogleFonts.dmSans(
              color: AppColors.textMuted,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ),
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: GoogleFonts.dmSans(
                  color: Colors.redAccent,
                  fontSize: 13,
                ),
              ),
            )
          else if (_fullSeason == null || _fullSeason!.episodes.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Episode details are not available yet.',
                style: GoogleFonts.dmSans(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            )
          else
            ..._fullSeason!.episodes.map(
              (episode) => _WatchlistEpisodeItem(
                episode: episode,
                seasonNumber: widget.season.seasonNumber,
                movie: widget.movie,
              ),
            ),
        ],
      ),
    );
  }
}

class _WatchlistEpisodeItem extends StatelessWidget {
  final Episode episode;
  final int seasonNumber;
  final Movie movie;

  const _WatchlistEpisodeItem({
    required this.episode,
    required this.seasonNumber,
    required this.movie,
  });

  @override
  Widget build(BuildContext context) {
    final epKey = 'S${seasonNumber}E${episode.episodeNumber}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    CachedNetworkImage(
                      imageUrl: episode.stillPath,
                      width: 132,
                      height: 76,
                      fit: BoxFit.cover,
                      placeholder: (context, url) =>
                          Container(color: AppColors.surface2),
                      errorWidget: (context, url, error) => Container(
                        width: 132,
                        height: 76,
                        color: AppColors.surface2,
                        child: const Icon(
                          Icons.play_circle_outline,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                    if (episode.runtime.isNotEmpty)
                      Positioned(
                        right: 6,
                        bottom: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.78),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            episode.runtime,
                            style: GoogleFonts.dmSans(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${episode.episodeNumber}. ${episode.name}',
                      style: GoogleFonts.dmSans(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: AppColors.ratingGold,
                          size: 15,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          episode.rating.toStringAsFixed(1),
                          style: GoogleFonts.dmSans(
                            color: AppColors.ratingGold,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            _episodeYear(episode.airDate),
                            style: GoogleFonts.dmSans(
                              color: AppColors.textMuted,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Selector<TrackingProvider, bool>(
                selector: (context, provider) {
                  final tracking = provider.getTracking(
                    int.tryParse(movie.id) ?? 0,
                  );
                  return tracking?.watchedEpisodes.contains(epKey) ?? false;
                },
                builder: (context, isWatched, child) {
                  return GestureDetector(
                    onTap: () {
                      context.read<TrackingProvider>().toggleEpisode(
                        movie,
                        seasonNumber,
                        episode.episodeNumber,
                        movie.totalEpisodes,
                      );
                      HapticFeedback.selectionClick();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(left: 12),
                      decoration: BoxDecoration(
                        color: isWatched
                            ? AppColors.primary.withValues(alpha: 0.18)
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isWatched
                              ? AppColors.primary
                              : AppColors.borderDefault,
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.check_rounded,
                        color: isWatched
                            ? AppColors.primary
                            : AppColors.textMuted,
                        size: 20,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            episode.overview,
            style: GoogleFonts.dmSans(
              color: AppColors.textSecondary,
              fontSize: 15,
              height: 1.45,
              letterSpacing: 0.1,
            ),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _episodeYear(String airDate) {
    if (airDate.length >= 4) return airDate.substring(0, 4);
    return '';
  }
}
