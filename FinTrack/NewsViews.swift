import Foundation
import Observation
import SwiftUI

struct FinancialNewsArticle: Decodable, Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String?
    let category: String?
    let source: FinancialNewsSource?
    let originalURL: URL?
    let publishedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case summary
        case category
        case source
        case originalURL = "original_url"
        case publishedAt = "published_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decodeIfPresent(String.self, forKey: .summary)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        source = try container.decodeIfPresent(FinancialNewsSource.self, forKey: .source)
        originalURL = try container.decodeIfPresent(URL.self, forKey: .originalURL)

        let timestamp = try container.decode(String.self, forKey: .publishedAt)
        guard let date = Self.timestampFormatter.date(from: timestamp) ??
                Self.fallbackTimestampFormatter.date(from: timestamp) else {
            throw DecodingError.dataCorruptedError(
                forKey: .publishedAt,
                in: container,
                debugDescription: "The news API returned an invalid publication date."
            )
        }
        publishedAt = date
    }

    private static let timestampFormatter = ISO8601DateFormatter()

    private static let fallbackTimestampFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

struct FinancialNewsSource: Decodable, Equatable {
    let name: String
}

private struct FinancialNewsResponse: Decodable {
    let data: [FinancialNewsArticle]
}

@MainActor
@Observable
final class FinancialNewsModel {
    private(set) var articles: [FinancialNewsArticle] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    func load() async {
        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let endpoint = URL(string: "https://capitaldatawire.com/api/v1/articles?limit=20")!
            let (data, response) = try await URLSession.shared.data(from: endpoint)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }

            articles = try JSONDecoder().decode(FinancialNewsResponse.self, from: data).data
        } catch {
            errorMessage = "Unable to load financial news. Check your connection and try again."
        }
    }
}

struct FinancialNewsScreen: View {
    @State private var model = FinancialNewsModel()

    var body: some View {
        NavigationStack {
            Group {
                if model.isLoading && model.articles.isEmpty {
                    ProgressView("Loading world financial news…")
                } else if let errorMessage = model.errorMessage, model.articles.isEmpty {
                    FinancialNewsErrorView(message: errorMessage) {
                        await model.load()
                    }
                } else {
                    FinancialNewsList(
                        articles: model.articles,
                        isRefreshing: model.isLoading,
                        refresh: {
                            await model.load()
                        }
                    )
                }
            }
            .navigationTitle("Financial News")
            .task {
                await model.load()
            }
        }
    }
}

struct FinancialNewsList: View {
    let articles: [FinancialNewsArticle]
    let isRefreshing: Bool
    let refresh: @MainActor () async -> Void

    var body: some View {
        List {
            Section {
                Text("Global market, economy, and business headlines. Tap an item to read the original article.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Section("Latest") {
                ForEach(articles) { article in
                    FinancialNewsRow(article: article)
                }
            }

            Section {
                Text("News provided by Capital Data Wire. News is informational only and is not financial advice.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .overlay {
            if isRefreshing && !articles.isEmpty {
                ProgressView()
            }
        }
        .refreshable {
            await refresh()
        }
    }
}

struct FinancialNewsRow: View {
    let article: FinancialNewsArticle

    var body: some View {
        Group {
            if let originalURL = article.originalURL {
                Link(destination: originalURL) {
                    content
                }
                .tint(.primary)
            } else {
                content
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(article.title)
                .font(.headline)

            if let summary = article.summary, !summary.isEmpty {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 6) {
                Text(article.source?.name ?? "Capital Data Wire")
                if let category = article.category {
                    Text("•")
                    Text(category)
                }
                Text("•")
                Text(article.publishedAt, format: .relative(presentation: .named))
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
    }
}

struct FinancialNewsErrorView: View {
    let message: String
    let retry: @MainActor () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("News Unavailable", systemImage: "newspaper")
        } description: {
            Text(message)
        } actions: {
            Button("Try Again") {
                Task {
                    await retry()
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
