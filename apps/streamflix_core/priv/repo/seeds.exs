# Script for populating the database with initial data.
#
# Run it with:
#     mix run apps/streamflix_core/priv/repo/seeds.exs

alias StreamflixCore.Repo

IO.puts("🌱 Seeding StreamFlix database...")

# ============================================
# GENRES
# ============================================

genres = [
  %{name: "Acción", slug: "accion", description: "Películas y series de acción"},
  %{name: "Aventura", slug: "aventura", description: "Aventuras épicas"},
  %{name: "Animación", slug: "animacion", description: "Contenido animado"},
  %{name: "Comedia", slug: "comedia", description: "Contenido de comedia"},
  %{name: "Crimen", slug: "crimen", description: "Historias de crimen y misterio"},
  %{name: "Documental", slug: "documental", description: "Documentales"},
  %{name: "Drama", slug: "drama", description: "Dramas intensos"},
  %{name: "Familia", slug: "familia", description: "Contenido para toda la familia"},
  %{name: "Fantasía", slug: "fantasia", description: "Mundos de fantasía"},
  %{name: "Historia", slug: "historia", description: "Contenido histórico"},
  %{name: "Terror", slug: "terror", description: "Películas de terror"},
  %{name: "Música", slug: "musica", description: "Contenido musical"},
  %{name: "Misterio", slug: "misterio", description: "Misterios intrigantes"},
  %{name: "Romance", slug: "romance", description: "Historias románticas"},
  %{name: "Ciencia Ficción", slug: "ciencia-ficcion", description: "Ciencia ficción"},
  %{name: "Thriller", slug: "thriller", description: "Thrillers de suspenso"},
  %{name: "Guerra", slug: "guerra", description: "Películas de guerra"},
  %{name: "Western", slug: "western", description: "Westerns clásicos"},
  %{name: "Anime", slug: "anime", description: "Anime japonés"},
  %{name: "K-Drama", slug: "k-drama", description: "Dramas coreanos"},
  %{name: "Reality", slug: "reality", description: "Reality shows"},
  %{name: "Deportes", slug: "deportes", description: "Contenido deportivo"},
  %{name: "Stand-Up", slug: "stand-up", description: "Comedia Stand-Up"},
  %{name: "True Crime", slug: "true-crime", description: "Crímenes reales"}
]

now = DateTime.utc_now() |> DateTime.truncate(:second)

genre_entries =
  Enum.map(genres, fn genre ->
    Map.merge(genre, %{
      id: Ecto.UUID.generate(),
      inserted_at: now,
      updated_at: now
    })
  end)

{count, _} = Repo.insert_all("genres", genre_entries, on_conflict: :nothing, conflict_target: :slug)
IO.puts("  ✅ Inserted #{count} genres")

# ============================================
# SAMPLE CONTENT (Optional - for testing)
# ============================================

# Sample movie
sample_content = [
  %{
    id: Ecto.UUID.generate(),
    title: "StreamFlix Original: El Comienzo",
    slug: "streamflix-original-el-comienzo",
    type: "movie",
    description: "Una película de prueba para verificar el sistema.",
    synopsis: "Esta es una película de demostración creada automáticamente por el seed de StreamFlix.",
    release_year: 2026,
    duration_minutes: 120,
    rating: "PG-13",
    maturity_level: "teen",
    status: "published",
    featured: true,
    view_count: 0,
    average_rating: Decimal.new("0.0"),
    total_ratings: 0,
    metadata: %{},
    inserted_at: now,
    updated_at: now
  },
  %{
    id: Ecto.UUID.generate(),
    title: "Serie Demo: Episodio Piloto",
    slug: "serie-demo-episodio-piloto",
    type: "series",
    description: "Una serie de prueba para verificar el sistema.",
    synopsis: "Esta es una serie de demostración con múltiples temporadas.",
    release_year: 2026,
    duration_minutes: nil,
    rating: "TV-14",
    maturity_level: "teen",
    status: "published",
    featured: true,
    view_count: 0,
    average_rating: Decimal.new("0.0"),
    total_ratings: 0,
    metadata: %{},
    inserted_at: now,
    updated_at: now
  }
]

{count, _} = Repo.insert_all("content", sample_content, on_conflict: :nothing, conflict_target: :slug)
IO.puts("  ✅ Inserted #{count} sample content items")

IO.puts("")
IO.puts("🎉 Database seeding complete!")
IO.puts("")
IO.puts("You can now start the server with: mix phx.server")
