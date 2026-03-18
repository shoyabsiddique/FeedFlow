**FeedFlow**

Software Requirements Specification

Version 1.0

March 2026

Confidential --- Personal Project

**Document Information**

  ------------------- ---------------------------------------------------
  **Document Title**  FeedFlow --- Software Requirements Specification

  **Version**         1.0

  **Date**            March 2026

  **Platform**        iOS & Android (Cross-platform)

  **Tech Stack**      Flutter · Supabase · Firebase Cloud Messaging

  **Status**          Draft
  ------------------- ---------------------------------------------------

**Table of Contents**

**1. Introduction**

**1.1 Purpose**

This document defines the software requirements for FeedFlow, a personal
cross-platform RSS reader application built with Flutter. It describes
the functional requirements, system features, technical architecture,
data models, and external interface requirements for the application.
This document serves as the single source of truth for the design and
development of FeedFlow.

**1.2 Product Overview**

FeedFlow is a zero-configuration RSS and Atom feed aggregator designed
to replace email newsletters and bookmark-based content tracking. The
application allows a user to follow content from any website or
newsletter that exposes an RSS or Atom feed, without relying on email
subscriptions or visiting individual websites manually.

The application is built entirely client-side. Flutter handles all UI
and business logic, while Supabase acts as a serverless backend for a
curated feed library. There is no custom application server. All feed
fetching, parsing, storage, and search happens on-device.

**1.3 Scope**

FeedFlow covers the following functional areas:

-   Aggregation of RSS and Atom feeds from multiple sources into a
    single unified home feed

-   A curated, remotely-managed feed library backed by Supabase from
    which users can enable feeds instantly

-   Custom RSS feed addition via direct URL input

-   In-app RSS discovery via a browser with automatic RSS link detection

-   Home feed filtering by source category and user-defined custom tags

-   Flood control to prevent high-frequency sources from dominating the
    feed

-   Article bookmarking with offline access

-   Full-text search across all fetched articles

-   Background feed sync with push notifications for new articles

-   OPML import and export for feed portability

**1.4 Definitions & Abbreviations**

  ------------------------------ ---------------------------------------- --
  **Term**                       **Definition**                           

  RSS                            Really Simple Syndication --- an         
                                 XML-based web feed format                

  Atom                           An alternative XML-based web feed format 
                                 (RFC 4287)                               

  Feed                           A single RSS or Atom subscription source 

  Article                        An individual content item fetched from  
                                 a feed                                   

  Library                        The curated list of pre-defined feeds    
                                 managed via Supabase                     

  OPML                           Outline Processor Markup Language ---    
                                 standard format for feed lists           

  FCM                            Firebase Cloud Messaging                 

  Isar                           A high-performance NoSQL local database  
                                 for Flutter                              
  ------------------------------ ---------------------------------------- --

**2. Overall Description**

**2.1 Product Perspective**

FeedFlow is a standalone mobile application. It does not depend on any
third-party RSS aggregation service or API proxy. All feed data is
fetched directly from source URLs by the client device. Supabase is used
solely for hosting the curated feed library and recording anonymous
engagement counts. Firebase Cloud Messaging is used for local push
notifications triggered by on-device background sync, with no
server-side notification dispatch required.

**2.2 User Class**

FeedFlow is a single-user personal application. There is no
authentication, no user accounts, and no multi-user functionality. All
data is local to the device. The user is technically proficient,
comfortable managing RSS feeds, and wants full control over their
reading experience without depending on third-party aggregator services.

**2.3 Operating Environment**

  ---------------------- ------------------------------------------------
  **Environment**        **Specification**

  **Mobile OS --- iOS**  iOS 14.0 and above

  **Mobile OS ---        Android 8.0 (API 26) and above
  Android**              

  **Framework**          Flutter (Dart) --- latest stable channel

  **Local Storage**      Isar NoSQL embedded database

  **Remote Backend**     Supabase (PostgreSQL + Row Level Security + Edge
                         Functions)

  **Notifications**      Firebase Cloud Messaging with
                         flutter_local_notifications

  **Background Sync**    workmanager Flutter plugin

  **Network**            Requires internet for initial feed fetch and
                         library sync; offline reading available for
                         bookmarked articles
  ---------------------- ------------------------------------------------

**2.4 Design Constraints**

-   No custom backend server --- all logic runs on-device or via
    Supabase client SDK directly

-   No user authentication --- Supabase feed library is read via
    anonymous public policy

-   Feed fetching is performed directly from source URLs; no proxy or
    caching server is used

-   Notifications are triggered on-device by background sync; no
    server-side push dispatch

-   The application must function fully in offline mode for reading
    bookmarked articles and viewing previously synced feeds

**3. System Features**

**3.1 Unified Home Feed**

**Description**

The Home screen is the primary interface of FeedFlow. It presents a
chronologically sorted, unified list of articles from all enabled feed
sources. The user can filter this list in real time using category and
tag filters.

**Functional Requirements**

-   The system shall fetch and display articles from all user-enabled
    feeds in a single list, sorted by publish date descending.

-   Each article card shall display: source favicon, source name,
    article title, summary snippet, publish timestamp, and thumbnail
    image if available.

-   The user shall be able to swipe right on an article card to bookmark
    it and swipe left to mark it as read.

-   The feed shall support pull-to-refresh to trigger an immediate sync
    of all enabled sources.

-   Unread article count shall be shown as a badge on the Home
    navigation item.

**3.2 Home Feed Filtering**

**Description**

Two rows of horizontally scrollable chip pills appear below the app
header. The first row shows source categories. The second row shows the
user\'s custom tags. Selecting chips filters the feed. Filters from both
rows can be combined simultaneously.

**Functional Requirements**

-   Row 1 --- Category pills: shall display all categories present among
    the user\'s enabled feeds, plus an \'All\' chip. Categories are
    sourced from the Supabase library for library feeds and
    user-assigned for custom feeds.

-   Row 2 --- Tag pills: shall display all user-defined tags plus a \'+
    New Tag\' chip. Tapping \'+ New Tag\' opens an inline text input to
    create a new tag.

-   Selecting a category chip shall filter the home feed to show only
    articles from feeds in that category.

-   Selecting a tag chip shall filter the home feed to show only
    articles from feeds assigned that tag.

-   Selecting both a category chip and a tag chip simultaneously shall
    apply an AND filter.

-   The active filter selection shall persist across app sessions,
    stored locally in Isar.

-   Tags are managed per-feed from the feed detail page (accessible via
    long-press on a feed card in the Library or from Feed Settings).

**3.3 Flood Control**

**Description**

High-frequency sources can dominate the home feed. Flood control
provides two capping mechanisms --- a per-source article limit and a
time-based recency filter --- both configurable globally and overridable
per-feed.

**Functional Requirements**

-   Per-feed article cap: the system shall allow the user to set a
    maximum number of articles displayed per source in the home feed.
    Default is 10. Range is 1 to 20.

-   Time-based cap: the system shall allow the user to restrict the home
    feed to articles published within a selected time window: 6 hours,
    12 hours, 24 hours, 3 days, 7 days, or All Time. Default is All
    Time.

-   Both flood control settings shall be configurable globally under
    Settings → Feed Preferences.

-   Both settings shall be overridable at the individual feed level from
    the feed\'s detail page.

-   Articles suppressed by flood control shall remain stored in Isar and
    shall be accessible from the individual feed\'s article list.

**3.4 Feed Library**

**Description**

The Library screen presents a curated catalogue of pre-configured feeds
fetched from Supabase. Feeds are grouped by category. The user can
enable any feed with a single tap, instantly adding it to the home feed
without any additional configuration.

**Functional Requirements**

-   The system shall fetch the feed library from the Supabase \'feeds\'
    table on app launch and cache it locally.

-   The library shall be organised into horizontal category tabs: All,
    Tech & Dev, AI/ML, Finance & Business, Science & Research, Design &
    Product, Startups & VC, and Politics & World News.

-   Each feed card shall display: source logo, feed name, short
    description, and an enable/disable toggle.

-   Tapping the toggle shall instantly add or remove the feed from the
    user\'s active subscriptions and update the home feed accordingly.

-   The library shall include a search bar to filter feeds by name or
    description within the current category.

-   A \'Suggest a Feed\' option at the bottom of the library shall allow
    the user to submit a URL to the Supabase \'feed_suggestions\' table
    for review.

-   The enable count of a feed (number of times any user has enabled it)
    shall be displayed on the feed card for social proof, updated via a
    Supabase Edge Function on toggle.

-   The library shall refresh from Supabase at app launch and when the
    user explicitly pulls to refresh, ensuring new feeds added to
    Supabase are available without an app update.

**3.5 Custom Feed Addition**

**Description**

Users can add any RSS or Atom feed by providing a URL directly. The
system validates the URL, retrieves feed metadata, and adds it to the
user\'s local subscription list.

**Functional Requirements**

-   An \'Add Feed\' button shall be available on the Library screen and
    in Settings.

-   Tapping \'Add Feed\' shall present a URL input dialog.

-   Upon submission, the system shall perform a GET request to the URL,
    validate that the response is a valid RSS 2.0 or Atom feed, and
    extract metadata (feed title, description, site URL, icon).

-   If validation succeeds, the feed shall be saved to Isar and
    immediately appear in the home feed.

-   If validation fails, the system shall display a clear error message
    indicating the URL is not a valid feed.

-   The user shall be able to assign a category and custom tags to any
    manually added feed.

**3.6 RSS Discovery (In-App Browser)**

**Description**

The Discovery screen embeds a full in-app web browser. As the user
navigates, the application automatically scans every loaded page for RSS
and Atom feed links. Detected feeds surface in a bottom sheet, from
which the user can add them directly to their subscriptions.

**Functional Requirements**

-   The Discovery screen shall open an in-app browser defaulting to
    DuckDuckGo (configurable in Settings).

-   A persistent bottom sheet shall be visible above the browser,
    indicating scan status.

-   On every page load, the system shall inject JavaScript to scan the
    page\'s \<head\> for \<link\> elements with type
    \'application/rss+xml\' or \'application/atom+xml\'.

-   The system shall additionally probe common feed URL patterns
    relative to the current page\'s origin: /feed, /rss, /feed.xml,
    /atom.xml, /feeds/posts/default.

-   Detected feed URLs shall be validated by the app via a lightweight
    GET request before being surfaced to the user.

-   The bottom sheet shall expand to show detected feeds, each
    displaying feed name, URL, and article count from a preview fetch.

-   Tapping \'+ Add\' on any detected feed shall save it to Isar and add
    it to the home feed.

-   Added feeds shall optionally be submitted to Supabase
    feed_suggestions for library inclusion.

**3.7 Article Reader**

**Description**

Tapping an article opens a full reading view inside the app. The reader
attempts to display a clean, readable version of the article content. If
parsing fails, it falls back to a full in-app webview.

**Functional Requirements**

-   The reader shall attempt to extract and display the article\'s main
    content in a clean typographic layout, stripping navigation, ads,
    and boilerplate.

-   If content extraction fails or produces insufficient content, the
    system shall fall back to rendering the full article URL in an
    embedded webview.

-   The reader shall provide: a bookmark toggle, a share button, an
    \'Open in Browser\' button, and an estimated read time based on word
    count.

-   Font size shall be adjustable from within the reader.

-   The article shall be marked as read automatically upon opening.

**3.8 Bookmarks**

**Description**

Users can save any article for later reading. Bookmarked articles are
stored fully offline in Isar and available without a network connection.

**Functional Requirements**

-   The system shall store the full article content (title, summary,
    body, source, URL, publish date) of bookmarked articles in Isar.

-   The Bookmarks screen shall display all saved articles, sorted by
    date bookmarked descending.

-   The user shall be able to filter bookmarks by source or date range.

-   Bookmarked articles shall be accessible in full offline, with no
    network dependency.

-   Removing a bookmark shall delete the stored article content from
    Isar.

**3.9 Full-Text Search**

**Description**

The Search screen allows the user to query all fetched article titles
and summaries using full-text search powered by Isar\'s built-in
indexing.

**Functional Requirements**

-   The system shall maintain a full-text index on article title and
    summary fields in Isar.

-   The search input shall be debounced to avoid excessive queries
    during typing.

-   Results shall be displayed as article cards identical to the home
    feed.

-   The user shall be able to filter search results by: source,
    category, date range, and read/unread status using filter chips.

-   Search shall operate entirely on locally stored data; no network
    request is required.

**3.10 Background Sync & Push Notifications**

**Description**

FeedFlow periodically syncs feeds in the background even when the app is
closed. New articles trigger local push notifications that deep-link
directly to the relevant article.

**Functional Requirements**

-   The system shall register a periodic background task using the
    workmanager plugin.

-   The background task shall fetch all enabled feed URLs, parse
    responses, and compare against articles already stored in Isar.

-   New articles detected during a background sync shall be stored in
    Isar and trigger a local push notification via
    flutter_local_notifications.

-   Notifications shall display the feed source name and article title.

-   Tapping a notification shall deep-link to the article reader for
    that specific article.

-   The sync interval shall be configurable in Settings: 15 minutes, 1
    hour, or 6 hours. Default is 1 hour.

-   Notifications shall be configurable globally (on/off) and per-feed
    (on/off) from Settings.

**3.11 OPML Import & Export**

**Description**

FeedFlow supports the OPML standard for importing and exporting feed
lists, enabling portability to and from other RSS readers.

**Functional Requirements**

-   The system shall parse OPML 1.0 and 2.0 files on import, extracting
    feed title and XML URL from each \<outline\> element.

-   Each imported feed shall be validated and added to the user\'s local
    subscription list.

-   The system shall generate a valid OPML 2.0 file on export containing
    all user-enabled feeds.

-   Import and export shall be accessible from Settings.

**4. Data Models**

**4.1 Local Data --- Isar Collections**

**FeedSource**

  ---------------------- ---------------------- -------------------------
  **Field**              **Type**               **Description**

  id                     Id (auto)              Local Isar primary key

  rssUrl                 String                 RSS or Atom feed URL

  name                   String                 Display name of the feed

  description            String                 Short description

  siteUrl                String                 Homepage URL of the
                                                source

  logoUrl                String                 Feed favicon or logo URL

  category               String                 Category label (from
                                                library or user-set)

  userTags               List\<String\>         User-defined tag labels
                                                e.g. \[\'#morning\'\]

  isEnabled              bool                   Whether feed is active in
                                                home feed

  isFromLibrary          bool                   True if added from
                                                Supabase library

  supabaseId             String?                UUID from Supabase feeds
                                                table if applicable

  articleCap             int                    Per-feed article cap
                                                (default 10, 0 = global)

  timeCap                int                    Per-feed time cap in
                                                hours (0 = global
                                                setting)

  lastSyncedAt           DateTime?              Timestamp of most recent
                                                successful sync
  ---------------------- ---------------------- -------------------------

**Article**

  ---------------------- ---------------------- -------------------------
  **Field**              **Type**               **Description**

  id                     Id (auto)              Local Isar primary key

  feedSourceId           int                    Foreign key →
                                                FeedSource.id

  guid                   String                 Unique identifier from
                                                feed item (for
                                                deduplication)

  title                  String \@Index         Article title ---
                                                full-text indexed

  summary                String \@Index         Article summary or
                                                description --- full-text
                                                indexed

  body                   String?                Full body content if
                                                bookmarked

  url                    String                 Link to the full article

  thumbnailUrl           String?                Preview image URL if
                                                available

  publishedAt            DateTime               Publication date from
                                                feed

  fetchedAt              DateTime               When the article was
                                                stored locally

  isRead                 bool                   Whether the user has
                                                opened the article

  isBookmarked           bool                   Whether the article is
                                                saved offline
  ---------------------- ---------------------- -------------------------

**UserTag**

  ---------------------- ---------------------- -------------------------
  **Field**              **Type**               **Description**

  id                     Id (auto)              Local Isar primary key

  label                  String                 Tag name e.g.
                                                \'#deep-dive\'

  color                  String                 Hex color for the pill
                                                chip

  createdAt              DateTime               When the tag was created
  ---------------------- ---------------------- -------------------------

**AppSettings**

  ----------------------- ---------------------- -------------------------
  **Field**               **Type**               **Description**

  globalArticleCap        int                    Global per-feed article
                                                 cap (default 10)

  globalTimeCap           int                    Global time cap in hours
                                                 (0 = all time)

  syncIntervalMinutes     int                    Background sync interval
                                                 (15, 60, 360)

  notificationsEnabled    bool                   Global notification
                                                 toggle

  theme                   String                 light / dark / system

  discoverySearchEngine   String                 URL of default search
                                                 engine for Discovery

  lastCategoryFilter      String?                Persisted active category
                                                 chip

  lastTagFilter           String?                Persisted active tag chip
  ----------------------- ---------------------- -------------------------

**4.2 Remote Data --- Supabase Schema**

**feeds (public, read-only)**

  ---------------------- ---------------------- -------------------------
  **Column**             **Type**               **Description**

  id                     uuid (PK)              Primary key

  name                   text                   Display name of the feed

  description            text                   Short description shown
                                                in library card

  rss_url                text                   RSS or Atom feed URL

  site_url               text                   Source website URL

  logo_url               text                   Feed logo or favicon URL

  category               text (enum)            tech \| ai \| finance \|
                                                science \| design \|
                                                startups \| politics

  is_active              boolean                Set to false to deprecate
                                                a feed remotely

  enable_count           integer                Aggregate count of users
                                                who enabled this feed

  created_at             timestamptz            Row creation timestamp
  ---------------------- ---------------------- -------------------------

**feed_suggestions (insert-only)**

  ---------------------- ---------------------- -------------------------
  **Column**             **Type**               **Description**

  id                     uuid (PK)              Primary key

  suggested_url          text                   User-submitted RSS URL

  suggested_name         text?                  Optional name provided by
                                                user

  status                 text (enum)            pending \| approved \|
                                                rejected

  created_at             timestamptz            Submission timestamp
  ---------------------- ---------------------- -------------------------

**Row Level Security Policies**

-   feeds: SELECT allowed for anon role. No INSERT, UPDATE, or DELETE
    from client.

-   feed_suggestions: INSERT allowed for anon role. No SELECT, UPDATE,
    or DELETE from client.

-   enable_count increments are handled by a Supabase Edge Function
    called via a client HTTP request, preventing direct integer
    manipulation from the client.

**5. Technology Stack**

**5.1 Mobile Application**

  ---------------------- ------------------------------------------------
  **Component**          **Technology / Package**

  **Language**           Dart

  **Framework**          Flutter (latest stable)

  **State Management**   flutter_riverpod

  **Local Database**     isar

  **HTTP Client**        dio

  **RSS & Atom Parsing** webfeed

  **In-App Browser**     flutter_inappwebview

  **Background Tasks**   workmanager

  **Push Notifications** flutter_local_notifications

  **Supabase Client**    supabase_flutter

  **OPML Parsing**       Custom XML parser (dart:xml)

  **File Picker (OPML    file_picker
  import)**              

  **Share**              share_plus
  ---------------------- ------------------------------------------------

**5.2 Backend --- Supabase**

  ---------------------- ------------------------------------------------
  **Component**          **Supabase Feature**

  **Feed Library         PostgreSQL table: feeds
  Storage**              

  **Feed Suggestions**   PostgreSQL table: feed_suggestions

  **Client Access**      Supabase Flutter SDK with anon public key

  **Access Control**     Row Level Security (RLS) policies

  **Enable Count         Supabase Edge Function (Deno)
  Updates**              

  **Library              Real-time read via Supabase REST API
  Availability**         
  ---------------------- ------------------------------------------------

**5.3 Notifications Infrastructure**

Push notifications are delivered entirely on-device. No Firebase
server-side messaging or APNs server token is required. The flow is:

-   workmanager wakes the app process in the background on the
    configured interval.

-   The background isolate fetches all enabled feed URLs via dio and
    parses responses with webfeed.

-   New articles (not present in Isar by GUID) are stored and trigger
    flutter_local_notifications to display a local notification.

-   FCM is used only as the delivery channel for local notifications on
    Android; APNs for iOS. No cloud messaging server is involved.

**5.4 Project Structure**

The Flutter project follows a feature-first folder structure:

-   lib/main.dart --- App entry point, Isar initialisation, Riverpod
    ProviderScope

-   lib/core/db/ --- Isar collection definitions and repository classes

    -   feed_source.dart, article.dart, user_tag.dart, app_settings.dart

-   lib/core/services/ --- Stateless service classes

    -   rss_parser_service.dart --- webfeed parsing and feed validation

    -   supabase_library_service.dart --- Supabase fetch and sync

    -   rss_detector_service.dart --- JS injection and URL probing for
        Discovery

    -   notification_service.dart --- flutter_local_notifications setup
        and dispatch

    -   background_sync_service.dart --- workmanager task handler

-   lib/core/providers/ --- Riverpod providers for all services and
    repositories

-   lib/features/home/ --- Unified feed screen, filter bar, article
    cards

-   lib/features/library/ --- Supabase-backed feed catalogue and
    category tabs

-   lib/features/discovery/ --- In-app browser, JS channel, bottom sheet
    detector

-   lib/features/reader/ --- Article reading view with readable mode and
    webview fallback

-   lib/features/bookmarks/ --- Offline saved article list

-   lib/features/search/ --- Full-text Isar search with filter chips

-   lib/features/settings/ --- All user preferences and flood control
    configuration

-   lib/shared/widgets/ --- Reusable components: ArticleCard,
    CategoryChip, FeedToggle

**6. Non-Functional Requirements**

**6.1 Performance**

-   The home feed shall render the first 20 articles within 300ms of app
    launch when data is cached in Isar.

-   Full-text search results shall appear within 200ms of query input
    after debounce.

-   Feed parsing for a single source shall complete within 3 seconds on
    a standard mobile connection.

-   Background sync shall complete for up to 50 feeds within 60 seconds
    to remain within OS background execution time limits.

**6.2 Reliability**

-   Feed fetch failures for individual sources shall not prevent other
    sources from syncing. Each feed is fetched independently with its
    own error handling.

-   The app shall remain fully functional in offline mode for all
    bookmarked content and previously synced articles.

-   Isar transactions shall be used for article batch inserts to ensure
    data consistency if the background task is interrupted.

**6.3 Usability**

-   A first-time user shall be able to start reading content within 30
    seconds of installing the app by enabling feeds from the Library,
    with no configuration required.

-   The UI shall support system light and dark mode and respect the
    user\'s OS-level preference by default.

-   All interactive elements shall meet minimum touch target sizes of
    44x44 points.

**6.4 Privacy**

-   No personally identifiable information is collected or transmitted.

-   The enable_count increment sent to Supabase contains only the feed
    UUID --- no device identifier, IP address, or usage pattern is
    stored.

-   All reading history, bookmarks, and preferences are stored
    exclusively on-device in Isar.

**6.5 Maintainability**

-   The feed library is maintained entirely through the Supabase
    dashboard. Adding, editing, or deprecating a feed requires no app
    update.

-   The category taxonomy is defined in Supabase and consumed by the
    client; adding a new category propagates to the app without a
    release.

**7. External Interface Requirements**

**7.1 RSS / Atom Feed Sources**

-   The app shall support RSS 2.0 and Atom 1.0 formats as parsed by the
    webfeed package.

-   Feeds shall be fetched via HTTPS. HTTP-only feeds shall display a
    warning to the user.

-   The app shall handle common feed encoding issues including UTF-8 and
    ISO-8859-1.

-   GUID or link fields shall be used for article deduplication across
    syncs.

**7.2 Supabase API**

-   The app communicates with Supabase using the supabase_flutter client
    SDK with the project\'s public anon key.

-   All Supabase reads are unauthenticated (anon role) and governed by
    Row Level Security.

-   Enable count updates are sent to a Supabase Edge Function endpoint
    via an authenticated-free POST request.

-   The app shall gracefully handle Supabase unavailability by serving
    the locally cached library.

**7.3 In-App Browser**

-   The in-app browser shall be rendered by flutter_inappwebview on both
    iOS and Android.

-   JavaScript execution shall be enabled in the webview to support RSS
    auto-detection injection.

-   A JavaScriptHandler named \'rssDetected\' shall receive JSON-encoded
    feed link arrays from the injected script.

-   The default search engine URL shall be configurable; DuckDuckGo
    (https://duckduckgo.com) is the default.

**7.4 System Notifications**

-   On Android, the app shall request POST_NOTIFICATIONS permission
    (Android 13+) on first launch.

-   On iOS, the app shall request notification authorisation via the
    flutter_local_notifications plugin on first launch.

-   Notification channels shall be created with a default importance
    level of HIGH on Android.

End of Document --- FeedFlow SRS v1.0