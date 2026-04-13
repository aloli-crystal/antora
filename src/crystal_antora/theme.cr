module CrystalAntora
  module Theme
    CSS = <<-STYLESHEET
    :root {
      --color-brand: #1a73e8;
      --color-brand-hover: #1557b0;
      --color-bg: #ffffff;
      --color-bg-secondary: #f8f9fa;
      --color-bg-sidebar: #f1f3f4;
      --color-text: #202124;
      --color-text-secondary: #5f6368;
      --color-text-muted: #80868b;
      --color-border: #dadce0;
      --color-link: #1a73e8;
      --color-code-bg: #f5f6f7;
      --color-header-bg: #1a1a2e;
      --color-header-text: #ffffff;
      --sidebar-width: 280px;
      --toc-width: 220px;
      --header-height: 56px;
      --content-max-width: 800px;
      --font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen, Ubuntu, sans-serif;
      --font-mono: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
    }

    @media (prefers-color-scheme: dark) {
      :root {
        --color-brand: #8ab4f8;
        --color-brand-hover: #aecbfa;
        --color-bg: #1e1e1e;
        --color-bg-secondary: #252526;
        --color-bg-sidebar: #252526;
        --color-text: #d4d4d4;
        --color-text-secondary: #a0a0a0;
        --color-text-muted: #6a6a6a;
        --color-border: #3c3c3c;
        --color-link: #8ab4f8;
        --color-code-bg: #2d2d2d;
        --color-header-bg: #161625;
        --color-header-text: #e0e0e0;
      }
    }

    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    html {
      scroll-behavior: smooth;
    }

    body {
      font-family: var(--font-family);
      font-size: 16px;
      line-height: 1.6;
      color: var(--color-text);
      background: var(--color-bg);
      display: flex;
      flex-direction: column;
      min-height: 100vh;
    }

    a {
      color: var(--color-link);
      text-decoration: none;
    }

    a:hover {
      text-decoration: underline;
    }

    .site-header {
      background: var(--color-header-bg);
      color: var(--color-header-text);
      height: var(--header-height);
      position: sticky;
      top: 0;
      z-index: 100;
      border-bottom: 1px solid var(--color-border);
    }

    .header-inner {
      max-width: 1440px;
      margin: 0 auto;
      padding: 0 1.5rem;
      height: 100%;
      display: flex;
      align-items: center;
      gap: 1.5rem;
    }

    .site-title {
      font-size: 1.25rem;
      font-weight: 700;
      color: var(--color-header-text);
      white-space: nowrap;
    }

    .site-title:hover {
      text-decoration: none;
      opacity: 0.9;
    }

    .component-selector select {
      background: rgba(255,255,255,0.1);
      color: var(--color-header-text);
      border: 1px solid rgba(255,255,255,0.2);
      padding: 0.375rem 0.75rem;
      border-radius: 4px;
      font-size: 0.875rem;
    }

    .search-placeholder {
      margin-left: auto;
    }

    .search-placeholder input {
      background: rgba(255,255,255,0.1);
      color: var(--color-header-text);
      border: 1px solid rgba(255,255,255,0.2);
      padding: 0.375rem 1rem;
      border-radius: 20px;
      font-size: 0.875rem;
      width: 240px;
    }

    .search-placeholder input::placeholder {
      color: rgba(255,255,255,0.5);
    }

    .main-wrapper {
      display: flex;
      flex: 1;
      max-width: 1440px;
      margin: 0 auto;
      width: 100%;
    }

    .sidebar {
      width: var(--sidebar-width);
      flex-shrink: 0;
      background: var(--color-bg-sidebar);
      border-right: 1px solid var(--color-border);
      padding: 1.5rem 0;
      position: sticky;
      top: var(--header-height);
      height: calc(100vh - var(--header-height));
      overflow-y: auto;
    }

    .nav-menu {
      padding: 0 1rem;
    }

    .nav-list {
      list-style: none;
      padding: 0;
      margin: 0;
    }

    .nav-list .nav-list {
      padding-left: 1rem;
    }

    .nav-item {
      margin: 0.125rem 0;
    }

    .nav-link {
      display: block;
      padding: 0.375rem 0.75rem;
      color: var(--color-text);
      border-radius: 4px;
      font-size: 0.9rem;
      transition: background 0.15s ease;
    }

    .nav-link:hover {
      background: var(--color-border);
      text-decoration: none;
    }

    .nav-text {
      display: block;
      padding: 0.375rem 0.75rem;
      color: var(--color-text-secondary);
      font-size: 0.8rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
    }

    .content {
      flex: 1;
      min-width: 0;
      max-width: var(--content-max-width);
      padding: 2rem 3rem;
    }

    .breadcrumbs {
      margin-bottom: 1.5rem;
    }

    .breadcrumbs ul {
      list-style: none;
      display: flex;
      flex-wrap: wrap;
      gap: 0.25rem;
      font-size: 0.85rem;
      color: var(--color-text-muted);
    }

    .breadcrumbs li:not(:last-child)::after {
      content: "/";
      margin-left: 0.5rem;
      color: var(--color-text-muted);
    }

    .breadcrumbs .current {
      color: var(--color-text);
    }

    .doc h1 {
      font-size: 2rem;
      font-weight: 700;
      margin-bottom: 1rem;
      padding-bottom: 0.5rem;
      border-bottom: 1px solid var(--color-border);
      line-height: 1.3;
    }

    .doc h2 {
      font-size: 1.5rem;
      font-weight: 600;
      margin-top: 2rem;
      margin-bottom: 0.75rem;
      padding-bottom: 0.25rem;
      border-bottom: 1px solid var(--color-border);
    }

    .doc h3 {
      font-size: 1.25rem;
      font-weight: 600;
      margin-top: 1.5rem;
      margin-bottom: 0.5rem;
    }

    .doc h4 {
      font-size: 1.1rem;
      font-weight: 600;
      margin-top: 1.25rem;
      margin-bottom: 0.5rem;
    }

    .doc p {
      margin-bottom: 1rem;
    }

    .doc ul, .doc ol {
      margin-bottom: 1rem;
      padding-left: 1.5rem;
    }

    .doc li {
      margin-bottom: 0.25rem;
    }

    .doc code {
      background: var(--color-code-bg);
      padding: 0.125rem 0.375rem;
      border-radius: 3px;
      font-family: var(--font-mono);
      font-size: 0.875em;
    }

    .doc pre {
      background: var(--color-code-bg);
      border: 1px solid var(--color-border);
      border-radius: 6px;
      padding: 1rem 1.25rem;
      overflow-x: auto;
      margin-bottom: 1rem;
    }

    .doc pre code {
      background: none;
      padding: 0;
      font-size: 0.875rem;
      line-height: 1.5;
    }

    .doc .imageblock {
      margin: 1.5rem 0;
      text-align: center;
    }

    .doc .imageblock img {
      max-width: 100%;
      height: auto;
      border-radius: 6px;
    }

    .doc strong {
      font-weight: 600;
    }

    .toc {
      width: var(--toc-width);
      flex-shrink: 0;
      padding: 1.5rem 1rem;
      position: sticky;
      top: var(--header-height);
      height: calc(100vh - var(--header-height));
      overflow-y: auto;
      border-left: 1px solid var(--color-border);
    }

    .toc-title {
      font-size: 0.8rem;
      font-weight: 600;
      text-transform: uppercase;
      letter-spacing: 0.05em;
      color: var(--color-text-secondary);
      margin-bottom: 0.75rem;
    }

    .toc-list {
      list-style: none;
      padding: 0;
    }

    .toc-item {
      margin: 0.25rem 0;
    }

    .toc-item a {
      font-size: 0.85rem;
      color: var(--color-text-secondary);
      display: block;
      padding: 0.125rem 0;
      border-left: 2px solid transparent;
      padding-left: 0.75rem;
      transition: all 0.15s ease;
    }

    .toc-item a:hover {
      color: var(--color-brand);
      border-left-color: var(--color-brand);
      text-decoration: none;
    }

    .toc-level-1 {
      padding-left: 1rem;
    }

    .toc-level-2 {
      padding-left: 2rem;
    }

    .prev-next {
      display: flex;
      justify-content: space-between;
      margin-top: 3rem;
      padding-top: 1.5rem;
      border-top: 1px solid var(--color-border);
      gap: 1rem;
    }

    .prev-next a {
      display: flex;
      align-items: center;
      padding: 0.75rem 1rem;
      border: 1px solid var(--color-border);
      border-radius: 6px;
      transition: border-color 0.15s ease;
      font-size: 0.9rem;
    }

    .prev-next a:hover {
      border-color: var(--color-brand);
      text-decoration: none;
    }

    .prev-next .prev {
      margin-right: auto;
    }

    .prev-next .next {
      margin-left: auto;
    }

    .site-footer {
      border-top: 1px solid var(--color-border);
      padding: 1.5rem;
      text-align: center;
      font-size: 0.85rem;
      color: var(--color-text-muted);
      background: var(--color-bg-secondary);
    }

    @media (max-width: 1024px) {
      .toc {
        display: none;
      }

      .content {
        padding: 1.5rem 2rem;
      }
    }

    @media (max-width: 768px) {
      .sidebar {
        display: none;
      }

      .content {
        padding: 1rem;
      }

      .search-placeholder {
        display: none;
      }

      .doc h1 {
        font-size: 1.5rem;
      }

      .doc h2 {
        font-size: 1.25rem;
      }
    }
    STYLESHEET
  end
end
