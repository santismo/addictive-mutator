"use client";

import { useMemo, useState } from "react";

type StyleId = "popPunk" | "indie" | "metal" | "soul" | "electronic";
type LockName = "kick" | "snare" | "cymbals" | "mix";

type Style = {
  id: StyleId;
  name: string;
  eyebrow: string;
  description: string;
  color: string;
  short: string;
};

const styles: Style[] = [
  {
    id: "popPunk",
    name: "Modern Pop Punk",
    eyebrow: "TIGHT • BRIGHT • FORWARD",
    description: "A punchy, chorus-ready kit that earns its place next to loud guitars.",
    color: "#ff6d4d",
    short: "Pop Punk",
  },
  {
    id: "indie",
    name: "Dry Indie Rock",
    eyebrow: "CLOSE • HUMAN • DUSTY",
    description: "Small-room intimacy with imperfect edges and a quick, honest response.",
    color: "#a8b990",
    short: "Indie",
  },
  {
    id: "metal",
    name: "Modern Metal",
    eyebrow: "FOCUSED • HUGE • CONTROLLED",
    description: "Low-end discipline, high-impact transients, and a mix that stays clear.",
    color: "#9c89ff",
    short: "Metal",
  },
  {
    id: "soul",
    name: "Dusty Soul",
    eyebrow: "WARM • LOOSE • TEXTURED",
    description: "Rounded transients, tape color, and a room you can almost touch.",
    color: "#f0bd63",
    short: "Soul",
  },
  {
    id: "electronic",
    name: "Hybrid Electronic",
    eyebrow: "SHARP • WIDE • UNEXPECTED",
    description: "Acoustic foundation, designed edges, and controlled moments of excess.",
    color: "#5ec7d6",
    short: "Hybrid",
  },
];

const packs = ["Fairfax Vol. 1", "United Heavy", "Black Velvet", "Studio Rock", "Modern Jazz Sticks"];

const kitLibraries: Record<StyleId, Record<string, string[]>> = {
  popPunk: {
    kick: ["22\" Maple Kick", "24\" Rock Kick", "22\" Beech Kick"],
    snare: ["14×6.5\" Brass Snare", "14×8\" Steel Snare", "14×6.5\" Maple Snare"],
    hats: ["15\" Bright Hi-Hat", "14\" New Beat Hi-Hat", "15\" Rock Hi-Hat"],
    cymbals: ["20\" Bright Crash", "19\" A Crash", "22\" Ride — Bell"],
  },
  indie: {
    kick: ["20\" Vintage Kick", "22\" Soft Maple Kick", "20\" Low-Tuned Kick"],
    snare: ["14×5\" Wood Snare", "14×6.5\" Dry Maple", "13×7\" Piccolo Snare"],
    hats: ["14\" Dark Hi-Hat", "15\" Vintage Hi-Hat", "14\" Thin Hi-Hat"],
    cymbals: ["18\" Thin Crash", "20\" Dark Ride", "19\" Dry Crash"],
  },
  metal: {
    kick: ["22\" Deep Kick — Beater", "24\" Birch Kick", "22\" Focused Kick"],
    snare: ["14×6.5\" Bell Brass", "14×8\" Steel Snare", "14×6.5\" Attack Snare"],
    hats: ["14\" Tight Hi-Hat", "15\" Heavy Hi-Hat", "14\" Brilliant Hi-Hat"],
    cymbals: ["20\" Heavy Crash", "22\" Ride — Ping", "19\" China"],
  },
  soul: {
    kick: ["20\" Vintage Maple Kick", "22\" Round Kick", "20\" Soft Felt Kick"],
    snare: ["14×5\" Brass Snare", "14×6.5\" Maple Snare", "14×5\" Vintage Snare"],
    hats: ["15\" Dark Hi-Hat", "14\" Vintage Hi-Hat", "15\" Thin Hi-Hat"],
    cymbals: ["18\" Thin Crash", "20\" Flat Ride", "20\" Dark Crash"],
  },
  electronic: {
    kick: ["22\" Tight Kick", "20\" Punch Kick", "22\" Sampled Kick"],
    snare: ["14×6.5\" Steel Snare", "13×7\" Crack Snare", "14×5\" Short Snare"],
    hats: ["14\" Tight Hi-Hat", "15\" Bright Hi-Hat", "14\" Closed Hi-Hat"],
    cymbals: ["18\" Trash Crash", "20\" Bright Crash", "22\" Ride — Bell"],
  },
};

const styleRules: Record<StyleId, { room: string; processing: string; tip: string; kick: string; snare: string }> = {
  popPunk: {
    room: "Short room, tucked under the close mics",
    processing: "Parallel bus compression + a touch of saturation",
    tip: "Keep the kick fundamental clear of the bass guitar’s lowest note.",
    kick: "Focused low end with a beater-side lift",
    snare: "Forward 2–5 kHz crack, trimmed sustain",
  },
  indie: {
    room: "Near-dry close mics, barely-there room",
    processing: "Gentle tape color, minimal bus squeeze",
    tip: "Let velocity variation do more work than compression.",
    kick: "Soft attack with a rounded low-mid bloom",
    snare: "Woody center with imperfect, living dynamics",
  },
  metal: {
    room: "Wide room, controlled with a fast gate",
    processing: "Firm parallel bus compression and transient control",
    tip: "Protect 60–90 Hz for the kick; keep guitar weight slightly above it.",
    kick: "Fast beater definition with a disciplined sub",
    snare: "Dense body plus a high, assertive crack",
  },
  soul: {
    room: "Warm room kept audible between phrases",
    processing: "Tape drive, soft limiting, and gentle bus glue",
    tip: "Leave enough decay for the backbeat to feel relaxed, not late.",
    kick: "Felt-like attack and generous low-mid warmth",
    snare: "Warm center, softened transient, easy sustain",
  },
  electronic: {
    room: "Designed ambience with filtered, tempo-aware tails",
    processing: "Transient shaping, saturation, and a character send",
    tip: "Use the bus as the experimental layer—keep the dry kit dependable.",
    kick: "Tight transient with a controllable synthetic edge",
    snare: "Sharp transient with a compact, bright body",
  },
};

function hash(value: string) {
  let h = 2166136261;
  for (let i = 0; i < value.length; i += 1) {
    h ^= value.charCodeAt(i);
    h = Math.imul(h, 16777619);
  }
  return h >>> 0;
}

function createRng(seed: number) {
  let state = seed || 1;
  return () => {
    state |= 0;
    state = (state + 0x6d2b79f5) | 0;
    let result = Math.imul(state ^ (state >>> 15), 1 | state);
    result = (result + Math.imul(result ^ (result >>> 7), 61 | result)) ^ result;
    return ((result ^ (result >>> 14)) >>> 0) / 4294967296;
  };
}

function pick<T>(items: T[], random: () => number) {
  return items[Math.floor(random() * items.length)];
}

function db(value: number) {
  return `${value > 0 ? "+" : ""}${value.toFixed(1)} dB`;
}

function knobColor(value: number) {
  return `conic-gradient(#ff6d4d ${value * 3.6}deg, rgba(255,255,255,.12) 0deg)`;
}

export default function Home() {
  const [styleId, setStyleId] = useState<StyleId>("popPunk");
  const [role, setRole] = useState("Chorus");
  const [tempo, setTempo] = useState(155);
  const [natural, setNatural] = useState(35);
  const [space, setSpace] = useState(28);
  const [energy, setEnergy] = useState(76);
  const [selectedPacks, setSelectedPacks] = useState<string[]>(["Fairfax Vol. 1", "United Heavy", "Black Velvet"]);
  const [seed, setSeed] = useState(427);
  const [locks, setLocks] = useState<Record<LockName, boolean>>({ kick: false, snare: false, cymbals: false, mix: false });
  const [copied, setCopied] = useState(false);

  const style = styles.find((item) => item.id === styleId) ?? styles[0];

  const recipe = useMemo(() => {
    const random = createRng(hash(`${seed}-${styleId}-${role}-${tempo}-${natural}-${space}-${energy}-${selectedPacks.join("|")}`));
    const library = kitLibraries[styleId];
    const rule = styleRules[styleId];
    const packName = selectedPacks.length ? pick(selectedPacks, random) : "Your installed library";
    const energyBias = (energy - 50) / 50;
    const spaceBias = (space - 50) / 50;
    const naturalBias = (natural - 50) / 50;
    const kickPitch = Math.round((-1.5 + random() * 2.3) - energyBias * 0.4);
    const snarePitch = Math.round((-1 + random() * 2.7) + energyBias * 0.4);
    const roomLevel = Math.round(-17 + space * 0.14 + random() * 2);
    const roomDistance = Math.max(0, Math.round(space * 0.34 + random() * 5));
    const compRatio = Math.max(2, Math.round(3 + energy * 0.045 - natural * 0.015));
    const compReduction = Math.max(1, Math.round(2 + energy * 0.05 - natural * 0.02));
    const busMix = Math.max(8, Math.round(14 + energy * 0.26 - natural * 0.11));
    const reverbMs = Math.max(300, Math.round(490 + space * 18 + random() * 170));
    const soundIdeal = natural > 67 ? "Natural" : energy > 70 ? "Produced" : "Balanced";
    const variants = ["Closer & tighter", "Bigger room", "More character"].map((label, index) => ({
      label,
      description: index === 0 ? "Pull room down and favor close-mic punch." : index === 1 ? "Open the rooms while preserving the core kit." : "Raise the bus character without losing the backbeat.",
      delta: index === 0 ? "Room −4.0 dB" : index === 1 ? "Room +4.0 dB" : "Bus +8%",
    }));

    return {
      name: `${style.short} ${role} ${String(seed).padStart(3, "0")}`,
      packName,
      kick: pick(library.kick, random),
      snare: pick(library.snare, random),
      hats: pick(library.hats, random),
      cymbals: pick(library.cymbals, random),
      kickPitch,
      snarePitch,
      roomLevel,
      roomDistance,
      compRatio,
      compReduction,
      busMix,
      reverbMs,
      soundIdeal,
      rule,
      variants,
      headline: role === "Chorus" ? "Designed to clear the chorus" : role === "Verse" ? "Leaves room for the vocal" : "Built to command the arrangement",
    };
  }, [energy, natural, role, seed, selectedPacks, space, styleId, tempo]);

  function regenerate() {
    setSeed((current) => current + 1);
  }

  function togglePack(pack: string) {
    setSelectedPacks((current) => current.includes(pack) ? current.filter((item) => item !== pack) : [...current, pack]);
  }

  function toggleLock(lock: LockName) {
    setLocks((current) => ({ ...current, [lock]: !current[lock] }));
  }

  const exportText = `AD2 Kit Architect — ${recipe.name}\n\nStyle: ${style.name}\nRole: ${role}\nTempo: ${tempo} BPM\nSource library: ${recipe.packName}\nSound ideal: ${recipe.soundIdeal}\n\nKIT\nKick: ${recipe.kick} (${recipe.kickPitch > 0 ? "+" : ""}${recipe.kickPitch} semitones)\nSnare: ${recipe.snare} (${recipe.snarePitch > 0 ? "+" : ""}${recipe.snarePitch} semitones)\nHi-hat: ${recipe.hats}\nCymbals: ${recipe.cymbals}\n\nMIX\nRoom: ${recipe.roomLevel} dB, ${recipe.roomDistance} ms distance\nKick EQ: ${recipe.rule.kick}\nSnare EQ: ${recipe.rule.snare}\nBus: ${recipe.rule.processing}; ${recipe.compRatio}:1, ~${recipe.compReduction} dB GR, ${recipe.busMix}% blend\nFX: ${recipe.rule.room}; Delerb decay ${recipe.reverbMs} ms\n\nProducer note: ${recipe.rule.tip}\n\nGenerated deterministically by AD2 Kit Architect. Apply this recipe in your own licensed AD2 installation, then save it as a User Preset.`;

  async function copyRecipe() {
    await navigator.clipboard.writeText(exportText);
    setCopied(true);
    window.setTimeout(() => setCopied(false), 1600);
  }

  function downloadRecipe() {
    const blob = new Blob([exportText], { type: "text/plain" });
    const url = URL.createObjectURL(blob);
    const anchor = document.createElement("a");
    anchor.href = url;
    anchor.download = `${recipe.name.toLowerCase().replace(/[^a-z0-9]+/g, "-")}-recipe.txt`;
    anchor.click();
    URL.revokeObjectURL(url);
  }

  return (
    <main className="app-shell" style={{ "--style-color": style.color } as React.CSSProperties}>
      <header className="topbar">
        <a className="brand" href="#top" aria-label="AD2 Kit Architect home">
          <span className="brand-mark"><i /><i /><i /></span>
          <span>AD2 <b>Kit Architect</b></span>
        </a>
        <div className="status"><span className="status-dot" /> Local procedural engine <span className="status-divider" /> No samples included</div>
        <button className="seed-button" onClick={regenerate} aria-label="Generate a new seed">Seed <b>{String(seed).padStart(3, "0")}</b> <span>↻</span></button>
      </header>

      <section id="top" className="hero">
        <div className="hero-copy">
          <p className="eyebrow">PROCEDURAL AD2 PRESET EXPLORER</p>
          <h1>Find the kit<br />inside the kit.</h1>
          <p className="hero-description">A deterministic sound-design engine for the AD2 library you already own. Set the context, lock what works, and explore deliberate variations.</p>
          <div className="hero-note"><span>✦</span> Every choice is a rule—not a mystery.</div>
        </div>
        <div className="drum-abstract" aria-hidden="true">
          <div className="drum cymbal cymbal-left" /><div className="drum cymbal cymbal-right" />
          <div className="drum rack" /><div className="drum kick-drum"><span /></div>
          <div className="drum snare-drum" /><div className="drum tom tom-left" /><div className="drum tom tom-right" />
          <div className="sound-wave wave-one" /><div className="sound-wave wave-two" />
        </div>
      </section>

      <div className="workspace">
        <aside className="controls-panel">
          <div className="panel-heading"><span className="step-number">01</span><div><p className="micro-label">SONIC INTENT</p><h2>Set the brief</h2></div></div>
          <div className="field-group">
            <label>Style family</label>
            <div className="style-grid">
              {styles.map((item) => <button key={item.id} onClick={() => setStyleId(item.id)} className={`style-chip ${styleId === item.id ? "active" : ""}`}><span style={{ backgroundColor: item.color }} />{item.short}</button>)}
            </div>
          </div>
          <div className="field-row">
            <div className="field-group"><label htmlFor="role">Song role</label><select id="role" value={role} onChange={(event) => setRole(event.target.value)}><option>Verse</option><option>Pre-Chorus</option><option>Chorus</option><option>Bridge</option><option>Full song</option></select></div>
            <div className="field-group"><label htmlFor="tempo">Tempo</label><div className="tempo-input"><input id="tempo" type="number" min="50" max="240" value={tempo} onChange={(event) => setTempo(Number(event.target.value))} /><span>BPM</span></div></div>
          </div>
          <div className="knobs-row">
            <Knob label="Natural" value={natural} setValue={setNatural} />
            <Knob label="Space" value={space} setValue={setSpace} />
            <Knob label="Energy" value={energy} setValue={setEnergy} />
          </div>
          <div className="panel-heading inventory-heading"><span className="step-number">02</span><div><p className="micro-label">YOUR LIBRARY</p><h2>Available sounds</h2></div></div>
          <p className="helper">Recommendations are restricted to the packs you choose.</p>
          <div className="pack-list">
            {packs.map((pack) => <label key={pack} className="pack-toggle"><input type="checkbox" checked={selectedPacks.includes(pack)} onChange={() => togglePack(pack)} /><span className="box-check">✓</span><span>{pack}</span></label>)}
          </div>
        </aside>

        <section className="result-panel">
          <div className="result-topline"><span className="result-eyebrow">YOUR GENERATED DIRECTION</span><span className="availability">● {selectedPacks.length || 0} pack{selectedPacks.length === 1 ? "" : "s"} selected</span></div>
          <div className="recipe-title"><div><p className="style-tag" style={{ color: style.color }}>{style.eyebrow}</p><h2>{recipe.name}</h2><p>{recipe.headline}. <span>{style.description}</span></p></div><div className="ideal-badge"><span>Sound ideal</span><b>{recipe.soundIdeal}</b></div></div>
          <div className="kit-card">
            <div className="card-heading"><div><p className="micro-label">KIT CONFIGURATION</p><h3>Core voices</h3></div><span className="source-label">from {recipe.packName}</span></div>
            <div className="kit-grid">
              <KitChoice icon="◉" label="Kick" value={recipe.kick} detail={`${recipe.kickPitch > 0 ? "+" : ""}${recipe.kickPitch} semitones`} locked={locks.kick} onLock={() => toggleLock("kick")} />
              <KitChoice icon="✦" label="Snare" value={recipe.snare} detail={`${recipe.snarePitch > 0 ? "+" : ""}${recipe.snarePitch} semitones`} locked={locks.snare} onLock={() => toggleLock("snare")} />
              <KitChoice icon="⌁" label="Hi-hat" value={recipe.hats} detail="Standard articulation" locked={false} onLock={() => {}} />
              <KitChoice icon="◌" label="Cymbals" value={recipe.cymbals} detail="Wide stereo image" locked={locks.cymbals} onLock={() => toggleLock("cymbals")} />
            </div>
          </div>
          <div className="mix-card">
            <div className="card-heading"><div><p className="micro-label">MIX ARCHITECTURE</p><h3>Make it sit</h3></div><button className={`lock-all ${locks.mix ? "locked" : ""}`} onClick={() => toggleLock("mix")}>{locks.mix ? "▣ Mix locked" : "▢ Lock mix"}</button></div>
            <div className="mix-grid">
              <MixCell label="Room" value={`${recipe.roomLevel} dB`} detail={`${recipe.roomDistance} ms distance`} bar={Math.max(12, space)} />
              <MixCell label="Bus" value={`${recipe.busMix}% blend`} detail={`${recipe.compRatio}:1 • ~${recipe.compReduction} dB GR`} bar={Math.max(12, energy)} />
              <MixCell label="Delerb 1" value={`${recipe.reverbMs} ms`} detail="Pre-master • filtered" bar={Math.max(12, space * 0.88)} />
              <MixCell label="Character" value={natural > 58 ? "Tape & Shape" : "Comp & Dist"} detail={natural > 58 ? "Subtle drive" : "Parallel crunch"} bar={Math.max(12, 100 - natural)} />
            </div>
            <div className="mix-notes"><div><span>Kick</span><p>{recipe.rule.kick}</p></div><div><span>Snare</span><p>{recipe.rule.snare}</p></div><div><span>Producer note</span><p>{recipe.rule.tip}</p></div></div>
          </div>
          <div className="variation-section"><div className="variation-heading"><div><p className="micro-label">EXPLORE AROUND IT</p><h3>Three intentional variations</h3></div><button className="ghost-button" onClick={regenerate}>Generate new direction <span>↻</span></button></div><div className="variations">{recipe.variants.map((variant, index) => <button key={variant.label} className="variation-card" onClick={() => index === 0 ? setSpace((value) => Math.max(0, value - 12)) : index === 1 ? setSpace((value) => Math.min(100, value + 12)) : setNatural((value) => Math.max(0, value - 12))}><span className="variant-num">0{index + 1}</span><b>{variant.label}</b><p>{variant.description}</p><em>{variant.delta} <span>→</span></em></button>)}</div></div>
          <div className="export-bar"><div><p className="micro-label">READY FOR AD2</p><p>Apply the recipe, audition it, then save it in AD2 as a User Preset.</p></div><div className="export-actions"><button className="secondary-button" onClick={copyRecipe}>{copied ? "Copied ✓" : "Copy recipe"}</button><button className="primary-button" onClick={downloadRecipe}>Download recipe <span>↓</span></button></div></div>
        </section>
      </div>

      <footer><span>AD2 KIT ARCHITECT</span><p>Open-source concept prototype · Works with your own licensed AD2 content · No samples, presets, or AI</p><span>v0.1</span></footer>
    </main>
  );
}

function Knob({ label, value, setValue }: { label: string; value: number; setValue: (value: number) => void }) {
  return <div className="knob-wrap"><button className="knob" style={{ background: knobColor(value) }} onClick={() => setValue((value + 10) % 110)} aria-label={`${label}: ${value}%`}><span>{value}</span></button><input type="range" aria-label={`${label} amount`} value={value} onChange={(event) => setValue(Number(event.target.value))} /><label>{label}</label></div>;
}

function KitChoice({ icon, label, value, detail, locked, onLock }: { icon: string; label: string; value: string; detail: string; locked: boolean; onLock: () => void }) {
  return <article className="kit-choice"><div className="voice-icon">{icon}</div><div className="voice-meta"><span>{label}</span><b>{value}</b><small>{detail}</small></div><button className={`tiny-lock ${locked ? "locked" : ""}`} onClick={onLock} aria-label={`Lock ${label}`}>{locked ? "▣" : "▢"}</button></article>;
}

function MixCell({ label, value, detail, bar }: { label: string; value: string; detail: string; bar: number }) {
  return <div className="mix-cell"><span>{label}</span><b>{value}</b><small>{detail}</small><div className="mini-meter"><i style={{ width: `${bar}%` }} /></div></div>;
}
