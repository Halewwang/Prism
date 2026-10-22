import fs from 'node:fs/promises';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const require = createRequire(import.meta.url);
const sharp = require('sharp');
const repositoryRoot = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const sourceDirectory = path.join(repositoryRoot, 'assets/brand/sources');
const pngDirectory = path.join(repositoryRoot, 'assets/brand/png');
const catalogDirectory = path.join(repositoryRoot, 'native/PrismNative/Resources/Assets.xcassets');

async function copyPNG(name, directory) {
  await fs.mkdir(directory, { recursive: true });
  await fs.copyFile(path.join(pngDirectory, name), path.join(directory, name));
}

async function writeImageSet(name, variants, renderingIntent) {
  const directory = path.join(catalogDirectory, `${name}.imageset`);
  const images = [];
  for (const { source, appearance } of variants) {
    for (const scale of [1, 2]) {
      const filename = `${source}${scale === 2 ? '@2x' : ''}.png`;
      await copyPNG(filename, directory);
      const image = { filename, idiom: 'universal', scale: `${scale}x` };
      if (appearance) image.appearances = [{ appearance: 'luminosity', value: appearance }];
      images.push(image);
    }
  }
  await fs.writeFile(path.join(directory, 'Contents.json'), `${JSON.stringify({
    images,
    info: { author: 'xcode', version: 1 },
    properties: { 'template-rendering-intent': renderingIntent },
  }, null, 2)}\n`);
}

export async function generateApprovedBrandAssets() {
  const sources = (await fs.readdir(sourceDirectory)).filter(name => name.endsWith('.svg')).sort();
  if (!sources.length) throw new Error('Approved brand SVG sources are missing.');
  await fs.mkdir(pngDirectory, { recursive: true });
  let count = 0;
  for (const filename of sources) {
    const name = path.basename(filename, '.svg');
    const size = Number(name.match(/-(\d+)$/)?.[1]);
    const svg = await fs.readFile(path.join(sourceDirectory, filename));
    const dimensions = svg.toString().match(/^<svg\b[^>]*\bwidth="(\d+)"[^>]*\bheight="(\d+)"/);
    if (!size || Number(dimensions?.[1]) !== size || Number(dimensions?.[2]) !== size) {
      throw new Error(`Approved SVG dimensions do not match its name: ${filename}`);
    }
    // Render each approved optical size directly from its own vector source.
    // Point-sized UI assets also receive a direct 2x vector rendition.
    for (const scale of name.startsWith('app-') ? [1] : [1, 2]) {
      const output = path.join(pngDirectory, `${name}${scale === 2 ? '@2x' : ''}.png`);
      const info = await sharp(svg, { density: 72 * scale }).ensureAlpha().png({ compressionLevel: 9 }).toFile(output);
      if (info.width !== size * scale || info.height !== size * scale) {
        throw new Error(`Unexpected rendered dimensions: ${output}`);
      }
      count += 1;
    }
  }

  const buildDirectory = path.join(repositoryRoot, 'build');
  await fs.mkdir(buildDirectory, { recursive: true });
  await fs.copyFile(path.join(sourceDirectory, 'app-1024.svg'), path.join(buildDirectory, 'logo.svg'));
  await fs.copyFile(path.join(pngDirectory, 'app-1024.png'), path.join(buildDirectory, 'icon.png'));
  await writeImageSet('PrismMenuBar', [{ source: 'menu-18' }], 'template');
  await writeImageSet('PrismTitlebar', [{ source: 'titlebar-18' }], 'original');
  // The default rendition is the approved light artwork; dark appearance overrides it.
  await writeImageSet('PrismBrand', [{ source: 'brand-64' }, { source: 'brand-dark-64', appearance: 'dark' }], 'original');

  const publicDirectory = path.join(repositoryRoot, 'public');
  await fs.mkdir(publicDirectory, { recursive: true });
  for (const [source, destination] of [
    ['menu-22.png', 'trayTemplate.png'],
    ['menu-22@2x.png', 'trayTemplate@2x.png'],
    ['menu-22.png', 'tray_icon.png'],
  ]) {
    await fs.copyFile(path.join(pngDirectory, source), path.join(publicDirectory, destination));
  }
  for (const name of ['icon.svg', 'logo_prism.svg']) {
    await fs.copyFile(path.join(sourceDirectory, 'app-1024.svg'), path.join(publicDirectory, name));
  }
  await fs.mkdir(path.join(publicDirectory, 'brand'), { recursive: true });
  await fs.copyFile(path.join(sourceDirectory, 'toolbar-32.svg'), path.join(publicDirectory, 'brand/toolbar-32.svg'));
  const websiteDirectory = path.join(repositoryRoot, 'website/public');
  await fs.mkdir(path.join(websiteDirectory, 'brand'), { recursive: true });
  await fs.copyFile(path.join(sourceDirectory, 'titlebar-32.svg'), path.join(websiteDirectory, 'brand/titlebar-32.svg'));
  await fs.copyFile(path.join(pngDirectory, 'app-1024.png'), path.join(websiteDirectory, 'app-icon.png'));
  for (const size of [16, 32]) {
    await fs.copyFile(path.join(pngDirectory, `app-${size}.png`), path.join(websiteDirectory, `brand/favicon-${size}.png`));
  }
  console.log(`Generated ${count} approved brand PNGs, native image sets, and legacy icon/tray aliases.`);
}

if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  await generateApprovedBrandAssets();
}
