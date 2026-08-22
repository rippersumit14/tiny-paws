import { StrictMode } from "react";
import { createRoot } from "react-dom/client";
import {
  BadgeInfo,
  Bone,
  Box,
  Download,
  Github,
  Moon,
  PawPrint,
  Shield,
  Sparkles,
  Swords,
} from "lucide-react";
import "./styles.css";

const releaseUrl = "https://github.com/rippersumit14/tiny-paws/releases/latest";
const windowsDownloadUrl =
  "https://github.com/rippersumit14/tiny-paws/releases/latest/download/TinyPaws-Windows-x64.zip";
const repoUrl = "https://github.com/rippersumit14/tiny-paws";

const features = [
  "Windows-first downloadable multiplayer game",
  "AI Uncle and future Player Uncle villain modes",
  "Moonlit Grumble Town with gardens, street lamps, sheds, fences, and a huge manor",
  "Tiny dog routes under furniture, through vents, and around Uncle-only blockers",
  "Server-authoritative room flow with name, host, join, ready, difficulty, and room code",
  "Small quick inventory with keys, fictional boosts, distractions, and utility items",
];

const characters = [
  { name: "Milo", role: "Pug-inspired", detail: "Round, brave, stubborn, and built for squeezing under furniture." },
  { name: "Bean", role: "Dachshund-inspired", detail: "Long, quick, and perfect for dog-scale shortcuts." },
  { name: "Rocket", role: "Terrier-inspired", detail: "Scrappy, loud, and ideal for distraction plays." },
  { name: "Uncle Grumble", role: "The Neighbor", detail: "A looming cartoon villain who patrols the manor and listens for noise." },
];

const modes = [
  { title: "AI Uncle", copy: "Cooperate against a server-controlled Uncle with patrol, suspicion, investigation, chase, and search states." },
  { title: "Player Uncle", copy: "A planned mode where one player becomes Uncle while the rest sneak, rescue, and escape as dogs." },
];

const requirements = [
  ["OS", "Windows 10 / Windows 11 64-bit"],
  ["CPU", "Modern quad-core processor"],
  ["GPU", "Dedicated GPU recommended for high settings"],
  ["Memory", "8 GB RAM target"],
  ["Network", "Broadband internet for multiplayer"],
];

function App() {
  return (
    <main>
      <section className="hero" id="home">
        <Scene />
        <nav className="nav">
          <a href="#about">About</a>
          <a href="#features">Features</a>
          <a href="#download">Download</a>
          <a href={repoUrl}>GitHub</a>
        </nav>
        <div className="hero-copy">
          <p className="eyebrow">Windows multiplayer stealth-horror</p>
          <h1>TINY PAWS</h1>
          <p className="tagline">Small Dogs. Huge House. One Terrible Neighbor.</p>
          <div className="hero-actions">
            <a className="primary" href="#download">
              <Download size={20} />
              Download For Windows
            </a>
            <a className="secondary" href={repoUrl}>
              <Github size={20} />
              View On GitHub
            </a>
          </div>
        </div>
      </section>

      <section className="band intro" id="about">
        <div>
          <p className="eyebrow">New Direction</p>
          <h2>Downloadable Windows Game</h2>
          <p>
            Tiny Paws is moving away from an embedded browser prototype. The public site now presents the project,
            while the game is being rebuilt toward a packaged Windows release with native C++ gameplay foundations,
            multiplayer rooms, a moonlit town, and Grumble Manor as the main stealth-horror playground.
          </p>
        </div>
        <div className="status-panel">
          <span>Current milestone</span>
          <strong>0.1.0 Windows foundation</strong>
          <p>Website live, Windows export path added, C++ foundation started, and night town work underway.</p>
        </div>
      </section>

      <section className="band" id="features">
        <div className="section-heading">
          <p className="eyebrow">Features</p>
          <h2>Built Around Tiny Dogs In A Giant Night World</h2>
        </div>
        <div className="feature-grid">
          {features.map((feature, index) => (
            <article className="feature" key={feature}>
              {index % 3 === 0 ? <PawPrint /> : index % 3 === 1 ? <Moon /> : <Shield />}
              <p>{feature}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band split" id="characters">
        <div>
          <p className="eyebrow">Characters</p>
          <h2>Dogs, Collars, And One Very Bad Host</h2>
        </div>
        <div className="character-list">
          {characters.map((character) => (
            <article key={character.name}>
              <h3>{character.name}</h3>
              <span>{character.role}</span>
              <p>{character.detail}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band" id="modes">
        <div className="section-heading">
          <p className="eyebrow">Game Modes</p>
          <h2>Co-op Escape And Future Villain Play</h2>
        </div>
        <div className="mode-grid">
          {modes.map((mode) => (
            <article className="mode" key={mode.title}>
              <Swords />
              <h3>{mode.title}</h3>
              <p>{mode.copy}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="band roadmap" id="how-to-play">
        <div>
          <p className="eyebrow">How To Play</p>
          <h2>Sneak, Search, Rescue, Escape</h2>
        </div>
        <ol>
          <li>Spawn outside at night with Grumble Manor visible ahead.</li>
          <li>Enter the manor, search rooms, and collect randomized keys.</li>
          <li>Use dog-scale shortcuts, bark distractions, and quick inventory items.</li>
          <li>Rescue captured friends from the basement cage before their third capture.</li>
          <li>Return to the exit when the keys are complete and escape together.</li>
        </ol>
      </section>

      <section className="band requirements" id="requirements">
        <div>
          <p className="eyebrow">System Requirements</p>
          <h2>Windows 10 / 11</h2>
        </div>
        <div className="requirements-grid">
          {requirements.map(([label, value]) => (
            <div key={label}>
              <span>{label}</span>
              <strong>{value}</strong>
            </div>
          ))}
        </div>
      </section>

      <section className="download-band" id="download">
        <Box />
        <div>
          <p className="eyebrow">Download</p>
          <h2>Download Tiny Paws</h2>
          <p>Download the packaged Windows x64 build. Extract the ZIP, then launch TinyPaws.exe.</p>
          <div className="release-meta">
            <span>Version v0.1.2</span>
            <span>Windows 10 / 11</span>
            <span>x64 ZIP, approx. 38 MB</span>
          </div>
        </div>
        <a className="primary" href={windowsDownloadUrl}>
          <Download size={20} />
          Download For Windows
        </a>
      </section>

      <section className="band roadmap" id="roadmap">
        <div>
          <p className="eyebrow">Roadmap</p>
          <h2>Next Milestones</h2>
        </div>
        <ol>
          <li>Promote the Windows build through GitHub Releases.</li>
          <li>Continue replacing procedural placeholder models with authored stylized production assets.</li>
          <li>Replace procedural placeholder models with authored stylized production assets.</li>
          <li>Implement Player Uncle mode, customization, inventory syncing, and edge-case handling.</li>
        </ol>
      </section>

      <footer>
        <span>Tiny Paws</span>
        <a href={repoUrl}>
          <Github size={18} />
          GitHub Project
        </a>
      </footer>
    </main>
  );
}

function Scene() {
  return (
    <div className="scene" aria-hidden="true">
      <div className="stars" />
      <div className="moon">
        <Sparkles size={26} />
      </div>
      <div className="cloud cloud-a" />
      <div className="cloud cloud-b" />
      <div className="manor">
        <div className="roof roof-left" />
        <div className="roof roof-main" />
        <div className="roof roof-right" />
        <div className="tower" />
        <div className="house-body">
          {Array.from({ length: 9 }).map((_, index) => (
            <span className="window" key={index} />
          ))}
          <span className="door" />
        </div>
      </div>
      <div className="streetlight">
        <BadgeInfo size={24} />
      </div>
      <div className="tree tree-a" />
      <div className="tree tree-b" />
      <div className="grass" />
      <div className="dogs">
        <Bone />
        <PawPrint />
      </div>
    </div>
  );
}

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);
