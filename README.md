# Git Visualizer

A lightweight, AI-powered git visualizer for macOS that brings clarity to your repository without the bloat of traditional git UIs.

## Vision

Unlike VSCode's embedded git integration or heavy Electron-based tools, Git Visualizer is:
- **Minimal & Fast**: Native Swift, zero bloat
- **Beautiful**: Clean 2D visualization with scalable 3D future
- **Intelligent**: Extensible ontology system for understanding commit intent, team dynamics, and code health
- **AI-Ready**: First-class Claude and Grok API integration (coming soon)
- **Brew-Installable**: `brew tap soticnisse374-png/git-visualizer && brew install git-visualizer`

## Features

### Phase 1: MVP (Current)

#### Core Functionality
- ✅ Open any local git repository
- ✅ View all commits with full details (author, timestamp, files, diffs)
- ✅ Branch tree visualization and navigation
- ✅ Repository status and tracking information
- ✅ Search commits by message, author, hash

#### Smart Analysis (Ontology Engine)
- ✅ **Commit Intent Classification**: Automatically categorize commits as feature, bugfix, refactor, docs, test, ci, or chore
- ✅ **Collaboration Graph**: Identify who works with whom, based on shared files
- ✅ **File Health Tracking**: Find volatile files, hotspots, and tightly coupled code
- ✅ **Repository Analytics**: Contributors, activity trends, commit distribution

#### The Daily Entity
A small companion that lives in the corner of the app and reacts to your work.

- ✅ **Seeded by the date**: the day is hashed into a seed that picks species, name, palette, and accessories. Same day, same creature, on every machine — a new one tomorrow. No image assets ship with the app; it's all drawn procedurally.
- ✅ **Mood read from your repo**: the ontology engine's commit classification drives the state. Features shipped → celebrating. Bugfixes → focused. A revert → concerned. Nothing in 24h → asleep.
- ✅ **Six species, seven moods**: capybara, blob, cat, bird, ghost, fox — each with idle, waving, celebrating, focused, thinking, concerned, and sleeping states.

Character concept owes a debt to the pixel companions in [hermes-pixel-office](https://github.com/teknium1/hermes-pixel-office).

```bash
git-visualizer entity .
```

```
      .-----.
     ( ^ o ^ )
      `~~~~~'

   Tara the blob
   features shipped!

   day        2026-08-25
   accessory  scarf
   pattern    plain
   energy     ######.... 60%
   commits    6 in the last 24h
```

**[→ Live preview in the browser](docs/entity-preview.html)** — pick a day, flip through the moods, watch it jump. The preview reimplements the seed hash and drawing code in JavaScript so it matches the Swift app exactly (`DailyEntityTests` pins the shared hash values).

#### The macOS App
```bash
cd /path/to/any/repo
swift run --package-path /path/to/git-visualizer GitVisualizerApp
```

Opens a three-pane window on whatever repository you launch it from:

- **Sidebar** — commit/contributor counts, branches with tracking status, and a commit-intent breakdown. The daily companion sits at the bottom, reacting to the repo.
- **Middle** — searchable commit list (by summary, author, or hash prefix), each row tagged with its classified intent.
- **Detail** — full message, every changed file colour-coded by status, and parent commits.

`⌘O` opens a different repository, `⌘R` re-reads the current one.

#### CLI Commands
- `git-visualizer analyze <path>` - Deep repository analysis
- `git-visualizer status <path>` - Quick status check
- `git-visualizer health <path>` - Repository health report
- `git-visualizer entity <path>` - Meet today's companion

### Phase 2: SwiftUI App (Upcoming)
- Native macOS app with three-pane layout
- Interactive branch graph (2D Canvas-based DAG)
- Diff viewer with syntax highlighting
- Real-time analysis overlays
- Settings and preferences

### Phase 3: AI Features (With Claude & Grok)
- Intelligent commit message generation
- Automated diff summarization
- Workflow recommendations (rebase vs merge)
- Code smell detection
- Repository trend analysis

### Phase 4: 3D Visualization (Future)
- Force-directed 3D commit graph
- Temporal terrain visualization
- Interactive exploration with gestures

## Installation

### From Source
```bash
git clone https://github.com/soticnisse374-png/git-visualizer-for-our-host
cd git-visualizer-for-our-host
swift build -c release
.build/release/GitVisualizer --help
```

### Via Homebrew (Coming Soon)
```bash
brew tap soticnisse374-png/git-visualizer
brew install git-visualizer
```

## Quick Start

### Analyze a Repository
```bash
git-visualizer analyze /path/to/repo --limit 100
```

Output:
```
Repository: my-project
Commits: 127
Branches: 8

Repository Analysis:
- Total commits: 127
- Contributors: 5
- Volatile files: src/api/handler.swift, src/models/user.swift, ...

Top Volatile Files:
  src/api/handler.swift: 24 changes
  src/models/user.swift: 18 changes
  ...
```

### Check Repository Status
```bash
git-visualizer status /path/to/repo
```

### Generate Health Report
```bash
git-visualizer health /path/to/repo
```

Output:
```
Repository Health Report: my-project
========================================

Commit Distribution by Intent:
  feature: 45
  bugfix: 32
  refactor: 20
  ...

Top Contributors:
  alice: ~25 commits
  bob: ~22 commits
  ...

Activity Trends:
  Commits per week: 3.2
  Average commit size: 4 files
```

## Architecture

### Source Structure
```
Sources/
├── GitVisualizer/
│   └── GitVisualizerCLI.swift  # CLI entry point & commands
├── GitVisualizerCore/
│   ├── Models/
│   │   ├── Commit.swift        # Commit + FileChange models
│   │   ├── Branch.swift        # Branch model
│   │   └── Repository.swift    # Repository model
│   ├── Entity/
│   │   └── DailyEntity.swift   # Daily companion: generation + mood
│   ├── GitCore/
│   │   ├── GitCommandRunner.swift    # Git CLI wrapper
│   │   └── GitRepositoryManager.swift # Fetch commits, branches
│   ├── Ontology/
│   │   ├── CommitAnalyzer.swift      # Orchestrator
│   │   ├── IntentClassifier.swift    # Classify commit intent
│   │   ├── CollaborationGraph.swift  # Track co-authorship
│   │   └── FileHealthTracker.swift   # File volatility & coupling
│   └── AIBridge/
│       ├── AIProvider.swift      # Protocol for AI backends
│       ├── ClaudeProvider.swift  # Anthropic API integration
│       └── GrokProvider.swift    # xAI Grok integration
└── GitVisualizerUI/
    └── Views/
        └── DailyEntityView.swift # Canvas-drawn companion + animation
```

The preview page lives at `docs/entity-preview.html` and mirrors the Swift
implementation in JavaScript, so design changes can be tried in a browser
before porting them back to `DailyEntityView.swift`.
```

### Data Flow

```
Git Repository
    ↓
GitRepositoryManager (git CLI)
    ↓ (fetches commits, branches, diffs)
Models (Commit, Branch, Repository)
    ↓
CommitAnalyzer (Ontology Engine)
    ├─ IntentClassifier
    ├─ CollaborationGraph
    └─ FileHealthTracker
    ↓
Annotated Commits (with analysis)
    ↓
AIBridge (Optional)
    ├─ Claude (Anthropic API)
    └─ Grok (xAI API)
    ↓
CLI Output or SwiftUI Views
```

## AI Integration

Git Visualizer supports both Claude and Grok APIs for intelligent analysis. Both are optional; the app works perfectly without API keys.

### Configure Claude
```bash
export CLAUDE_API_KEY="sk-ant-..."
git-visualizer analyze /path/to/repo  # Will use Claude for enhanced summaries
```

### Configure Grok
```bash
export GROK_API_KEY="sk-..."
git-visualizer analyze /path/to/repo  # Will use Grok for real-time insights
```

### Fallback Strategy
- If both APIs are configured, Claude is used by default (or specified in settings)
- If primary provider fails, automatically falls back to secondary
- If both unavailable, app continues with built-in analysis

## Development

### Build
```bash
swift build
```

### Run CLI Commands
```bash
swift run GitVisualizer analyze .
swift run GitVisualizer status .
swift run GitVisualizer health .
```

### Test
```bash
swift test
```

### Run on Your Own Repo
```bash
swift run GitVisualizer analyze /path/to/this/repo
```

## Roadmap

- **v0.1** (Current): CLI with ontology engine
- **v0.2**: SwiftUI macOS app with 2D visualization
- **v0.3**: Claude + Grok API integration
- **v0.4**: 3D visualization with SceneKit
- **v0.5**: Homebrew distribution
- **v1.0**: Stable release with full feature set

## Contributing

This is an actively evolving project. Contributions welcome!

### Areas for Help
- SwiftUI views (Branch graph, commit list, diff viewer)
- Improved intent classifier
- More ontology analyzers (bug prediction, code smells, etc.)
- 3D visualization prototypes
- macOS app polish

## Design Philosophy

1. **Minimal Dependencies**: Only essential Swift packages
2. **Ontology First**: Build smart analysis from day 1
3. **AI as Plugin**: Not baked into core; easily swappable
4. **Beautiful by Default**: Native macOS UX, no Electron
5. **Extensible**: Easy to add new analyzers, visualizers, AI providers

## License

CC0 1.0 Universal (Public Domain)

## Author

Built with ❤️ for developers who care about understanding their git history.
