// Keep the website on the native public-test release. GitHub's `latest` release
// still points to the older Electron channel and excludes prereleases.
export const release = {
  version: '1.14.11',
  build: '12',
  channel: 'Native Public Test',
  minimumSystem: 'macOS 15.0+',
  architecture: 'Universal · Apple Silicon + Intel',
  downloadUrl: 'https://github.com/Halewwang/Prism/releases/download/v1.14.11/Prism-1.14.11-universal-test.dmg',
  notesUrl: 'https://github.com/Halewwang/Prism/releases/tag/v1.14.11',
  checksumsUrl: 'https://github.com/Halewwang/Prism/releases/download/v1.14.11/SHA256SUMS.txt',
  repositoryUrl: 'https://github.com/Halewwang/Prism',
  issuesUrl: 'https://github.com/Halewwang/Prism/issues',
} as const;
