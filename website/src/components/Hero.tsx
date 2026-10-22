import { motion } from 'framer-motion';
import { Command, Download } from 'lucide-react';
import { release } from '../release';

export const Hero = () => {
  return (
    <section className="relative pt-28 lg:pt-32 pb-16 lg:pb-20 overflow-hidden px-4 md:px-6">
      {/* Background Blobs - Optimized for Mobile */}
      <div className="absolute top-0 left-1/2 -translate-x-1/2 w-full h-full -z-10 opacity-40 pointer-events-none overflow-hidden">
        <div className="absolute top-[-10%] left-[10%] w-[300px] md:w-[500px] h-[300px] md:h-[500px] bg-neutral-200/50 rounded-full mix-blend-multiply filter blur-[80px] md:blur-[100px] animate-blob"></div>
        <div className="absolute top-[-10%] right-[10%] w-[300px] md:w-[500px] h-[300px] md:h-[500px] bg-gray-200/50 rounded-full mix-blend-multiply filter blur-[80px] md:blur-[100px] animate-blob animation-delay-2000"></div>
        <div className="absolute bottom-[-20%] left-[20%] w-[300px] md:w-[500px] h-[300px] md:h-[500px] bg-neutral-200/50 rounded-full mix-blend-multiply filter blur-[80px] md:blur-[100px] animate-blob animation-delay-4000"></div>
      </div>

      <div className="container mx-auto max-w-7xl grid grid-cols-1 lg:grid-cols-[minmax(0,5fr)_minmax(0,7fr)] gap-10 lg:gap-12 items-center text-center lg:text-left">
        <motion.div
          initial={{ opacity: 0, y: 20 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.6 }}
          className="min-w-0"
        >
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-neutral-100 text-neutral-800 text-xs font-semibold mb-6 border border-neutral-200">
            <span className="flex h-2 w-2 rounded-full bg-black"></span>
            v{release.version} · {release.channel}
          </div>

          <h1 className="text-4xl sm:text-5xl xl:text-6xl font-bold tracking-tight text-neutral-900 mb-6 leading-tight">
            Your links. <br className="hidden sm:block" />
            <span className="text-transparent bg-clip-text bg-gradient-to-r from-neutral-900 to-neutral-600">
              Your browser.
            </span>
          </h1>

          <p className="text-lg md:text-xl text-neutral-600 max-w-2xl mx-auto lg:mx-0 mb-8 leading-relaxed">
            Send links to the right browser on your Mac. Use URL rules, route confirmed source apps, or make a quick choice yourself.
          </p>

          <div className="flex flex-col items-center lg:items-start gap-4">
            <a href={release.downloadUrl} className="inline-flex items-center gap-2 bg-neutral-900 text-white px-6 py-3 rounded-full font-medium hover:bg-neutral-800 transition-colors shadow-lg">
              <Download size={18} /> Download Native Public Test
            </a>
            <div className="flex flex-wrap justify-center lg:justify-start items-center gap-3 text-neutral-500 text-sm font-medium bg-white/50 backdrop-blur-sm px-4 py-2 rounded-full border border-neutral-100">
               <a href={release.repositoryUrl} className="flex items-center gap-1 hover:text-neutral-900 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4"><Command size={14}/> Source on GitHub</a>
               <span className="text-neutral-300">•</span>
               <span>{release.minimumSystem}</span>
               <span className="text-neutral-300">•</span>
               <span>{release.architecture}</span>
            </div>
            <p className="text-sm text-neutral-500 max-w-xl leading-relaxed">
              Build {release.build}. This test build uses ad hoc signing, without Developer ID signing or Apple notarization.
              See the first-open steps below.{' '}
              <a href="#public-test" className="underline underline-offset-4 hover:text-neutral-900">Installation &amp; test limits</a>
            </p>
          </div>
        </motion.div>

        <motion.div
          initial={{ opacity: 0, y: 40 }}
          animate={{ opacity: 1, y: 0 }}
          transition={{ duration: 0.8, delay: 0.2 }}
          className="min-w-0 w-full max-w-4xl mx-auto"
        >
          <img
            src="/screenshots/1.14.9/prism-rules-en.png"
            alt="Prism 1.14.9 with circular titlebar logo and URL and source-app rules in one list"
            width={1600}
            height={1440}
            fetchPriority="high"
            className="w-full h-auto drop-shadow-2xl"
          />
          <p className="mt-4 text-center text-xs md:text-sm text-neutral-500">Prism 1.14.9 · Sample data</p>
        </motion.div>
      </div>
    </section>
  );
};
