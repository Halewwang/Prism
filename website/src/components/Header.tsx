import { ArrowUpRight } from 'lucide-react';
import { release } from '../release';

export const Header = () => (
  <header className="site-header">
    <div className="page-width header-inner">
      <a className="brand" href="#" aria-label="Prism home">
        <img src="/brand/titlebar-32.svg" alt="" width={32} height={32} />
        <span>Prism</span>
      </a>
      <nav className="main-nav" aria-label="Main navigation">
        <a href="#features">Features</a>
        <a href="#browser-picker">Preview &amp; pick</a>
        <a href={release.repositoryUrl}>GitHub ↗</a>
      </nav>
      <a className="header-download" href={release.downloadUrl}>
        Download test <ArrowUpRight size={16} aria-hidden="true" />
      </a>
    </div>
  </header>
);
