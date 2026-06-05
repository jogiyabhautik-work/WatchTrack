class Movie {
  final String id;
  final String title;
  final String overview;
  final String posterPath;
  final String backdropPath;
  final double rating;
  final String releaseDate;
  final String runtime;
  final String ageRating;
  final String ageRatingDescription;
  final List<String> genres;
  final List<Cast> cast;
  final List<ContentWarning> contentWarnings;
  final List<Season> seasons;
  final bool isMovie; // true for movie, false for series

  final List<String> spokenLanguages;
  final List<WatchProvider> watchProviders;
  final int? movieTotalEpisodes; // From number_of_episodes in TMDB

  Movie({
    required this.id,
    required this.title,
    required this.overview,
    required this.posterPath,
    required this.backdropPath,
    required this.rating,
    required this.releaseDate,
    required this.runtime,
    required this.ageRating,
    this.ageRatingDescription = '',
    required this.genres,
    required this.cast,
    this.contentWarnings = const [],
    this.seasons = const [],
    this.isMovie = true,
    this.spokenLanguages = const [],
    this.watchProviders = const [],
    this.movieTotalEpisodes,
  });
  
  int get totalEpisodes => movieTotalEpisodes ?? seasons.fold(0, (sum, s) => sum + s.episodeCount);

  static List<String> _parseGenres(Map<String, dynamic> json) {
    // 1. Check for explicit genre objects (from detail API)
    if (json['genres'] != null) {
      return (json['genres'] as List).map((g) {
        if (g is Map) return (g['name'] ?? '').toString();
        return g.toString();
      }).toList();
    }
    // 2. Check for genre IDs (from search/trending API)
    if (json['genre_ids'] != null) {
      final List<int> ids = List<int>.from(json['genre_ids']);
      return ids.map((id) => _genreIdMap[id] ?? '').where((n) => n.isNotEmpty).toList();
    }
    return [];
  }

  static const Map<int, String> _genreIdMap = {
    28: 'Action', 12: 'Adventure', 16: 'Animation', 35: 'Comedy', 80: 'Crime',
    99: 'Documentary', 18: 'Drama', 10751: 'Family', 14: 'Fantasy', 36: 'History',
    27: 'Horror', 10402: 'Music', 9648: 'Mystery', 10749: 'Romance', 878: 'Sci-Fi',
    10770: 'TV Movie', 53: 'Thriller', 10752: 'War', 37: 'Western',
    10759: 'Action & Adventure', 10762: 'Kids', 10763: 'News', 10764: 'Reality',
    10765: 'Sci-Fi & Fantasy', 10766: 'Soap', 10767: 'Talk', 10768: 'War & Politics'
  };

  factory Movie.fromJson(Map<String, dynamic> json, {bool isMovie = true}) {
    return Movie(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? json['name'] ?? '',
      overview: json['overview'] ?? '',
      posterPath: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['poster_path']}'
          : '',
      backdropPath: json['backdrop_path'] != null
          ? 'https://image.tmdb.org/t/p/original${json['backdrop_path']}'
          : '',
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      releaseDate: json['release_date'] ?? json['first_air_date'] ?? '',
      runtime: (json['runtime'] ?? '').toString(),
      ageRating: (json['ageRating'] ?? '').toString(),
      genres: _parseGenres(json),
      cast: [],
      isMovie: json['isMovie'] ?? isMovie,
      movieTotalEpisodes: json['number_of_episodes'],
      contentWarnings: (json['content_warnings'] as List?)
              ?.map((cw) => ContentWarning.fromJson(cw))
              .toList() ??
          [],
      seasons: (json['seasons'] as List?)
              ?.map((s) => Season.fromJson(s))
              .toList() ??
          [],
      spokenLanguages: (json['spoken_languages'] as List?)?.map((l) {
        if (l is Map) return (l['english_name'] ?? l['name'] ?? '').toString();
        return l.toString();
      }).toList() ?? [],
      watchProviders: (json['watch_providers'] as List?)?.map((p) => WatchProvider.fromJson(p)).toList() ?? [],
    );
  }
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'overview': overview,
      'poster_path': posterPath.replaceFirst('https://image.tmdb.org/t/p/w500', ''),
      'backdrop_path': backdropPath.replaceFirst('https://image.tmdb.org/t/p/w1280', '').replaceFirst('https://image.tmdb.org/t/p/original', ''),
      'vote_average': rating,
      'release_date': releaseDate,
      'runtime': runtime,
      'genres': genres.map((g) => {'name': g}).toList(),
      'isMovie': isMovie,
      'spoken_languages': spokenLanguages,
      'watch_providers': watchProviders.map((p) => p.toJson()).toList(),
      'cast': cast.map((c) => c.toJson()).toList(),
      'content_warnings': contentWarnings.map((cw) => cw.toJson()).toList(),
      'seasons': seasons.map((s) => s.toJson()).toList(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Movie && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

class WatchProvider {
  final String name;
  final String logoPath;
  final String providerId;

  WatchProvider({required this.name, required this.logoPath, required this.providerId});

  factory WatchProvider.fromJson(Map<String, dynamic> json) {
    return WatchProvider(
      name: json['provider_name'] ?? json['name'] ?? '',
      logoPath: json['logo_path'] != null 
          ? (json['logo_path'].startsWith('http') ? json['logo_path'] : 'https://image.tmdb.org/t/p/w92${json['logo_path']}')
          : '',
      providerId: json['provider_id']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'provider_name': name,
      'logo_path': logoPath,
      'provider_id': providerId,
    };
  }
}

class Season {
  final String id;
  final String name;
  final String overview;
  final String posterPath;
  final int seasonNumber;
  final int episodeCount;
  final List<Episode> episodes;

  Season({
    required this.id,
    required this.name,
    required this.overview,
    required this.posterPath,
    required this.seasonNumber,
    required this.episodeCount,
    this.episodes = const [],
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    final episodesJson = json['episodes'] as List? ?? [];
    return Season(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      overview: json['overview']?.toString() ?? '',
      posterPath: json['poster_path'] != null
          ? 'https://image.tmdb.org/t/p/w185${json['poster_path']}'
          : '',
      seasonNumber: json['season_number'] ?? 0,
      episodeCount: json['episode_count'] ?? 0,
      episodes: episodesJson
          .whereType<Map>()
          .map((e) => Episode.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overview': overview,
      'poster_path': posterPath,
      'season_number': seasonNumber,
      'episode_count': episodeCount,
      'episodes': episodes.map((e) => e.toJson()).toList(),
    };
  }
}

class Episode {
  final String id;
  final String name;
  final String overview;
  final String stillPath;
  final int episodeNumber;
  final double rating;
  final String airDate;
  final String runtime;

  Episode({
    required this.id,
    required this.name,
    required this.overview,
    required this.stillPath,
    required this.episodeNumber,
    required this.rating,
    required this.airDate,
    required this.runtime,
  });

  factory Episode.fromJson(Map<String, dynamic> json) {
    return Episode(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Episode ${json['episode_number'] ?? ''}',
      overview: json['overview']?.toString() ?? 'No description available.',
      stillPath: json['still_path'] != null
          ? 'https://image.tmdb.org/t/p/w300${json['still_path']}'
          : '',
      episodeNumber: json['episode_number'] ?? 0,
      rating: (json['vote_average'] as num?)?.toDouble() ?? 0.0,
      airDate: json['air_date']?.toString() ?? '',
      runtime: json['runtime'] != null ? '${json['runtime']}m' : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'overview': overview,
      'still_path': stillPath,
      'episode_number': episodeNumber,
      'vote_average': rating,
      'air_date': airDate,
      'runtime': runtime,
    };
  }
}

class Cast {
  final String id;
  final String name;
  final String character;
  final String profilePath;

  Cast({
    required this.id,
    required this.name,
    required this.character,
    required this.profilePath,
  });

  factory Cast.fromJson(Map<String, dynamic> json) {
    return Cast(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      character: json['character'] ?? '',
      profilePath: json['profile_path'] != null
          ? 'https://image.tmdb.org/t/p/w185${json['profile_path']}'
          : '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'character': character,
      'profile_path': profilePath,
    };
  }
}

class Actor {
  final String id;
  final String name;
  final String biography;
  final String profilePath;
  final String birthday;
  final String placeOfBirth;
  final List<Movie> movieCredits;

  Actor({
    required this.id,
    required this.name,
    required this.biography,
    required this.profilePath,
    required this.birthday,
    required this.placeOfBirth,
    required this.movieCredits,
  });

  factory Actor.fromJson(Map<String, dynamic> json, List<Movie> credits) {
    return Actor(
      id: json['id'].toString(),
      name: json['name'] ?? '',
      biography: json['biography'] ?? '',
      profilePath: json['profile_path'] != null
          ? 'https://image.tmdb.org/t/p/w500${json['profile_path']}'
          : '',
      birthday: json['birthday'] ?? '',
      placeOfBirth: json['place_of_birth'] ?? '',
      movieCredits: credits,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'biography': biography,
      'profile_path': profilePath,
      'birthday': birthday,
      'place_of_birth': placeOfBirth,
      'credits': movieCredits.map((m) => m.toJson()).toList(),
    };
  }
}

class ContentWarning {
  final String category;
  final String description;

  ContentWarning({required this.category, required this.description});
  factory ContentWarning.fromJson(Map<String, dynamic> json) {
    return ContentWarning(
      category: json['category'] ?? '',
      description: json['description'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
    };
  }
}

class Review {
  final String author;
  final String content;
  final String createdAt;
  final double? rating;
  final String authorProfilePath;

  Review({
    required this.author,
    required this.content,
    required this.createdAt,
    this.rating,
    this.authorProfilePath = '',
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    final authorDetails = json['author_details'] ?? {};
    String profile = authorDetails['avatar_path'] ?? '';
    if (profile.isNotEmpty && !profile.startsWith('http')) {
      profile = 'https://image.tmdb.org/t/p/w185$profile';
    }

    return Review(
      author: json['author'] ?? 'Anonymous',
      content: json['content'] ?? '',
      createdAt: json['created_at'] ?? '',
      rating: (authorDetails['rating'] as num?)?.toDouble(),
      authorProfilePath: profile,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'content': content,
      'created_at': createdAt,
      'rating': rating,
      'author_profile_path': authorProfilePath,
    };
  }
}
