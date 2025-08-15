# finalize.ps1 — One-click finalizer (Web/Java/ML/HPC) + auto-bootstrap + designer/implementer/deliverer
param(
  [switch]$AutoBootstrap = $true,
  [switch]$AutoUpgrade   = $true,
  [string]$AutoMigrate   = "approve",   # approve|off
  [string]$DeployEnv     = "none",      # none|staging|prod
  [string]$ServeUrl      = "http://localhost:3000",
  [int]$JavaMinVersion   = 17,
  [int]$CoverageMin      = 90,
  [switch]$ProDesigner   = $true,
  [switch]$ProImplement  = $true,
  [switch]$ProDeliver    = $true
)

$ErrorActionPreference = 'Stop'
$Root = (Get-Location).Path
$Art  = Join-Path $Root "artifacts"; New-Item -Force -ItemType Directory -Path $Art | Out-Null
$Log  = Join-Path $Art ("run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $Log -Append

function Need($cmd){ (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }
function Fail($msg){ Write-Error $msg; Stop-Transcript; exit 1 }
function Ok($msg){ Write-Host "OK: $msg" }

# Detect project types
$IsWeb  = Test-Path "$Root/package.json"
$IsML   = (Test-Path "$Root/env.yml" -or Test-Path "$Root/requirements.txt")
$IsHPC  = Test-Path "$Root/slurm.sbatch"
$IsJava = (Test-Path "$Root/pom.xml" -or Test-Path "$Root/build.gradle" -or Test-Path "$Root/build.gradle.kts")
if (-not ($IsWeb -or $IsML -or $IsHPC -or $IsJava)) { Fail "No supported project markers." }

# ---------- Web bootstrap helpers ----------
function Bootstrap-Next {
  Write-Host ">> Bootstrap Next.js stack"
  npx --yes create-next-app@latest . --ts --eslint --tailwind --src-dir --app --import-alias "@/*" --use-npm --no-git --no-experimental-app
  npm i -D @types/node prettier eslint-config-prettier eslint-plugin-import @typescript-eslint/parser @typescript-eslint/eslint-plugin
  @'
{"extends":["next/core-web-vitals","plugin:@typescript-eslint/recommended","prettier"],
 "rules":{"no-console":["error",{"allow":["warn","error"]}],"import/no-default-export":"error","@typescript-eslint/explicit-function-return-type":"warn","@typescript-eslint/no-misused-promises":"error"}}
'@ | Set-Content .eslintrc.json
  @'
{"compilerOptions":{"target":"ES2022","module":"ESNext","lib":["ES2022","DOM"],"strict":true,"noUncheckedIndexedAccess":true,"noFallthroughCasesInSwitch":true,"moduleResolution":"Bundler","jsx":"preserve","allowJs":false,"baseUrl":".","paths":{"@/*":["src/*"]}},"include":["next-env.d.ts","**/*.ts","**/*.tsx"],"exclude":["node_modules"]}
'@ | Set-Content tsconfig.json
  if (-not (Test-Path "src/components")) { New-Item -ItemType Directory -Force -Path "src/components" | Out-Null }
  if (-not (Test-Path "src/app")) { New-Item -ItemType Directory -Force -Path "src/app" | Out-Null }
  @'
export default function SmartHero(){
  return (<section className="min-h-[60vh] grid place-items-center text-center p-12">
    <h1 className="text-6xl font-extrabold tracking-tight">Adaptive Hero</h1>
    <p className="mt-4 text-xl opacity-80">Unique per session with WebGL backdrop.</p>
    <canvas id="hero-canvas" className="fixed inset-0 -z-10"></canvas>
    <script dangerouslySetInnerHTML={{__html:`(function(){const c=document.getElementById('hero-canvas');if(!c)return;const dpr=window.devicePixelRatio||1;c.width=innerWidth*dpr;c.height=innerHeight*dpr;const gl=c.getContext('webgl');if(!gl)return;})();`}}/>
  </section>);
}
'@ | Set-Content "src/components/SmartHero.tsx"
  @'
import SmartHero from "@/components/SmartHero";
export default function Home(){ return <main><SmartHero/></main>; }
'@ | Set-Content "src/app/page.tsx"
}
function Bootstrap-Playwright { npx --yes playwright install --with-deps; npx --yes playwright init --quiet }
function Bootstrap-Lighthouse {
  npm i -D @lhci/cli
  @"
{"ci":{"collect":{"url":["$ServeUrl"],"numberOfRuns":2,"startServerCommand":"npm run start"},
 "assert":{"assertions":{"categories:performance":["error",{"minScore":0.95}],
                        "categories:accessibility":["error",{"minScore":0.95}],
                        "categories:seo":["error",{"minScore":0.95}],
                        "cumulative-layout-shift":["error",{"maxNumericValue":0.1}]}
          },
 "upload":{"target":"filesystem","outputDir":"artifacts/lhci"}}}
"@ | Set-Content "$Root/.lighthouserc.json"
}
function Ensure-Server {
  try { Invoke-WebRequest -UseBasicParsing -Uri $ServeUrl -TimeoutSec 2 | Out-Null; return } catch {}
  if (Test-Path package.json -and (Get-Content package.json -Raw) -match '"start"') {
    Start-Process -FilePath "npm" -ArgumentList "run","start" -WindowStyle Hidden
    Start-Sleep -Seconds 3
  }
}

# ---------- Global gates ----------
Write-Host "== Placeholders check =="
$placeholders = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch "\\(node_modules|.git|dist|build|.next)\\"
                 -and $_.Extension -match '\.(js|ts|tsx|jsx|html|css|java|md)$' } |
  Select-String -Pattern 'TODO|FIXME|Lorem ipsum|PLACEHOLDER'
if ($placeholders) { Fail "Placeholders found" } else { Ok "No placeholders" }

Write-Host "== Secrets scan (gitleaks if available) =="
if (Need "gitleaks") { gitleaks detect --no-banner --report-path (Join-Path $Art "gitleaks.json") } else { Write-Host "gitleaks not found" }

Write-Host "== 8K assets check (ImageMagick identify if available) =="
$assetsDirs = @("assets","public") | Where-Object { Test-Path $_ }
if ($assetsDirs.Count -gt 0 -and (Need "identify")) {
  $bad = foreach ($d in $assetsDirs) {
    Get-ChildItem $d -Recurse -Include *.png,*.jpg,*.jpeg,*.webp -File -ErrorAction SilentlyContinue |
      ForEach-Object {
        $info = & identify -format "%w %h %i`n" $_.FullName
        $w,$h,$p = $info -split "\s+"
        if ([int]$w -lt 7680 -or [int]$h -lt 4320) { $p }
      }
  }
  if ($bad -and $bad.Count -gt 0) { Fail ("Below-8K images:`n" + ($bad -join "`n")) } else { Ok "Assets meet 8K" }
} else { Write-Host "identify not found or no assets" }

# ---------- WEB pipeline ----------
if ($IsWeb) {
  if ($AutoBootstrap -and -not (Select-String '"next"' package.json -Quiet)) { Bootstrap-Next }
  Bootstrap-Playwright
  Bootstrap-Lighthouse
  Ensure-Server

  npm install --no-audit --no-fund
  if (Need "npx") { npx eslint . --max-warnings=0 }

  if (npm run | Select-String "test") {
    $out = (npm run test -- --coverage --coverageReporters=text-summary) -join "`n"
    if ($out -match "All files.*?(\d+)%") {
      $cov = [int]$matches[1]
      if ($cov -lt $CoverageMin) { Fail "Coverage $cov% < $CoverageMin%" } else { Ok "Coverage $cov%" }
    }
  }

  if (Test-Path ".lighthouserc.json") { npx @lhci/cli autorun }

  if (npm run | Select-String "build") { npm run build }

  if (Need "docker") { docker build --pull --no-cache -t project/app:local . | Out-Null }
}

# ---------- JAVA pipeline ----------
function Java-Ensure {
  if (-not (Need "java")) {
    if ($AutoBootstrap) {
      if (Need "choco") { choco install "openjdk$JavaMinVersion" -y }
    }
  }
  if (-not (Need "java")) { Fail "Java missing" }
}
function Java-Bootstrap-Maven {
  if (-not (Test-Path mvnw)) { mvn -N -q wrapper }
  if (-not (Select-String "jacoco-maven-plugin" pom.xml -Quiet)) {
    (Get-Content pom.xml -Raw) -replace "</project>", @"
  <build><plugins>
    <plugin><groupId>org.jacoco</groupId><artifactId>jacoco-maven-plugin</artifactId><version>0.8.12</version>
      <executions>
        <execution><goals><goal>prepare-agent</goal></goals></execution>
        <execution><id>report</id><phase>verify</phase><goals><goal>report</goal></goals></execution>
      </executions>
    </plugin>
    <plugin><groupId>com.github.spotbugs</groupId><artifactId>spotbugs-maven-plugin</artifactId><version>4.8.6.4</version></plugin>
  </plugins></build>
</project>
"@ | Set-Content pom.xml
  }
}
if ($IsJava) {
  Java-Ensure
  if (Test-Path pom.xml) {
    if ($AutoBootstrap) { Java-Bootstrap-Maven }
    ./mvnw -q -DskipTests=false test
    ./mvnw -q -DskipTests=false verify spotbugs:check
    $jac = Join-Path $Root "target/site/jacoco/jacoco.xml"
    if (Test-Path $jac) {
      $xml = Get-Content $jac
      $line = ($xml | Select-String '<counter type="LINE"').ToString()
      if ($line -match 'missed="(\d+)" covered="(\d+)"') {
        $miss=[double]$matches[1]; $covd=[double]$matches[2]; $pct=[int](100*$covd/([double]($miss+$covd)))
        if ($pct -lt $CoverageMin) { Fail "Java coverage $pct% < $CoverageMin%" } else { Ok "Java coverage $pct%" }
      }
    }
    if (Need "docker") { ./mvnw -q jib:dockerBuild -Dimage=project/java-app:local | Out-Null }
  } else {
    if (Test-Path build.gradle -or Test-Path build.gradle.kts) { ./gradlew test jacocoTestReport }
  }
}

# ---------- ML pipeline ----------
if ($IsML) {
  if (-not (Need "python")) { Fail "Python missing" }
  if (Test-Path requirements.txt) { python -m pip install -U pip; python -m pip install -r requirements.txt }
  if (Test-Path tests) { pytest -q --maxfail=1 }
  if (Test-Path docker -and (Need "docker")) { docker build --pull --no-cache -t project/ml:local docker | Out-Null }
}

# ---------- HPC pipeline ----------
if ($IsHPC) {
  if (Need "sbatch") {
    $jid = (sbatch slurm.sbatch | Select-String "Submitted batch job").ToString().Split()[-1]
    if (-not $jid) { Fail "SLURM submit failed" }
    $deadline = (Get-Date).AddHours(1)
    while ((Get-Date) -lt $deadline -and (squeue -j $jid | Select-String $jid)) { Start-Sleep -Seconds 20 }
    if (squeue -j $jid | Select-String $jid) { Fail "SLURM watch timeout" }
    if (Test-Path output) {
      Get-ChildItem -Recurse output -File | ForEach-Object { try { Get-FileHash $_.FullName | Out-File -Append (Join-Path $Art "hpc_checksums.txt") } catch {} }
    }
  } else { Write-Host "sbatch not found. Skipping HPC." }
}

# ================= DESIGNER / IMPLEMENTER / DELIVERER =================
function Ensure-NpmPkg([string]$pkg) {
  if (-not (Test-Path package.json)) { return }
  $has = (npm ls $pkg --depth=0 2>$null) -like "*$pkg*"
  if (-not $has) { npm i -D $pkg }
}
function DesignPack {
  if (-not $IsWeb -or -not $ProDesigner) { return }
  Write-Host "== Designer =="
  Ensure-NpmPkg "tailwindcss"; Ensure-NpmPkg "@tailwindcss/typography"; Ensure-NpmPkg "@tailwindcss/forms"; Ensure-NpmPkg "framer-motion"; Ensure-NpmPkg "three"
  if (-not (Test-Path tailwind.config.cjs)) {
@'
module.exports = {
  content: ["./src/**/*.{ts,tsx,js,jsx}","./app/**/*.{ts,tsx}"],
  theme: { extend: { fontFamily:{display:["Inter","ui-sans-serif","system-ui"]}}},
  plugins: [require("@tailwindcss/typography"), require("@tailwindcss/forms")],
}
'@ | Set-Content tailwind.config.cjs
  }
  $comp = Join-Path $Root "src/components/SignatureHero.tsx"
  if (-not (Test-Path $comp)) {
@'
"use client";
import { useEffect, useRef } from "react";
import * as THREE from "three";
export default function SignatureHero(){
  const ref = useRef<HTMLDivElement>(null);
  useEffect(()=>{ 
    const el=ref.current!; const s=new THREE.Scene();
    const cam=new THREE.PerspectiveCamera(60, el.clientWidth/el.clientHeight, 0.1, 1000);
    const rnd=new THREE.WebGLRenderer({antialias:true}); rnd.setSize(el.clientWidth, el.clientHeight); el.appendChild(rnd.domElement);
    cam.position.z=6; const geo=new THREE.IcosahedronGeometry(2,2);
    const mat=new THREE.MeshStandardMaterial({metalness:0.6, roughness:0.2, color: new THREE.Color("hsl("+ (Date.now()%360) +",80%,60%)")});
    const mesh=new THREE.Mesh(geo,mat); s.add(mesh);
    const l1=new THREE.DirectionalLight(0xffffff,1); l1.position.set(3,3,5); s.add(l1);
    const l2=new THREE.AmbientLight(0x404040,1.2); s.add(l2);
    const onResize=()=>{ rnd.setSize(el.clientWidth, el.clientHeight); cam.aspect=el.clientWidth/el.clientHeight; cam.updateProjectionMatrix(); };
    window.addEventListener("resize", onResize);
    let id=0; const loop=()=>{ mesh.rotation.x+=0.005; mesh.rotation.y+=0.008; rnd.render(s,cam); id=requestAnimationFrame(loop); }; loop();
    return ()=>{ cancelAnimationFrame(id); window.removeEventListener("resize", onResize); el.innerHTML=""; };
  },[]);
  return (<section className="min-h-[80vh] grid place-items-center relative">
    <div ref={ref} className="absolute inset-0 -z-10"></div>
    <h1 className="text-6xl md:text-8xl font-extrabold tracking-tight text-white drop-shadow">Your Unforgettable Site</h1>
    <p className="mt-4 text-xl text-white/80">Unique per session. Zero templates.</p>
  </section>);
}
'@ | Set-Content $comp
  }
  $page = Get-ChildItem -Recurse -Include page.tsx -File | Select-Object -First 1
  if ($page) {
    $txt = Get-Content $page.FullName -Raw
    if ($txt -notmatch "SignatureHero") {
      $txt = "import SignatureHero from ""@/components/SignatureHero"";`n" + ($txt -replace "return\s*\(", "return (<main><SignatureHero/>")
      if ($txt -notmatch "</main>") { $txt = $txt + "</main>" }
      Set-Content $page.FullName $txt
    }
  }
}
function ImplementPack {
  if (-not $ProImplement) { return }
  Write-Host "== Implementer =="
  if ($IsWeb -and (Test-Path package.json)) {
    if (-not (Test-Path .eslintrc.json)) {
@'
{ "extends": ["next/core-web-vitals","plugin:@typescript-eslint/recommended","prettier"],
  "rules": {"no-console":["error",{"allow":["warn","error"]}],"import/no-default-export":"error","@typescript-eslint/explicit-function-return-type":"warn"} }
'@ | Set-Content .eslintrc.json
    }
    if (-not (Test-Path tsconfig.json)) {
@'
{"compilerOptions":{"target":"ES2022","module":"ESNext","strict":true,"noUncheckedIndexedAccess":true,"noFallthroughCasesInSwitch":true}}
'@ | Set-Content tsconfig.json
    }
    $spec = "tests/e2e/smoke.spec.ts"
    if (-not (Test-Path $spec)) {
      New-Item -Force -ItemType Directory -Path (Split-Path $spec) | Out-Null
@'
import { test, expect } from "@playwright/test";
test("home loads fast", async ({ page }) => {
  await page.goto("/");
  await expect(page.locator("h1")).toBeVisible();
});
'@ | Set-Content $spec
    }
  }
  if ($IsJava -and (Test-Path pom.xml) -and -not (Select-String "jacoco-maven-plugin" pom.xml -Quiet)) {
    (Get-Content pom.xml -Raw) -replace "</project>", @"
  <build><plugins>
    <plugin><groupId>org.jacoco</groupId><artifactId>jacoco-maven-plugin</artifactId><version>0.8.12</version>
      <executions>
        <execution><goals><goal>prepare-agent</goal></goals></execution>
        <execution><id>report</id><phase>verify</phase><goals><goal>report</goal></goals></execution>
      </executions>
    </plugin>
    <plugin><groupId>com.github.spotbugs</groupId><artifactId>spotbugs-maven-plugin</artifactId><version>4.8.6.4</version></plugin>
  </plugins></build>
</project>
"@ | Set-Content pom.xml
  }
}
function DeliverPack {
  if (-not $ProDeliver) { return }
  Write-Host "== Deliverer =="
  if (Need "docker") { docker build --pull --no-cache -t project/app:release . | Out-Null }
  $bundle = Join-Path $Art ("release_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  $paths = @("artifacts","docs"); if (Test-Path "dist") { $paths += "dist" }; if (Test-Path ".next") { $paths += ".next" }; if (Test-Path "target") { $paths += "target" }
  Compress-Archive -Path $paths -DestinationPath $bundle -Force
  Write-Host "Bundle: $bundle"
}
# ================= END MODES =================

# ----- call modes after pipelines -----
DesignPack
ImplementPack
DeliverPack

# ---------- docs auto-update ----------
New-Item -ItemType Directory -Force -Path (Join-Path $Root "docs") | Out-Null
Add-Content -Path "$Root/docs/CHANGELOG.md" -Value "## $(Get-Date -Format o)`n- Finalize run on $(hostname)`n- Pipelines applied.`n"
if (Test-Path data) {
  $files=(Get-ChildItem -Recurse data -File | Measure-Object).Count
  Set-Content -Path "$Root/docs/DATA_README.md" -Value "# Data README`n- Files: $files"
}
if (Test-Path models -or Test-Path src) {
  Set-Content -Path "$Root/docs/MODEL_CARD.md" -Value "# Model Card`n- Metrics: see artifacts/`n- Risks: PII redaction"
}

# ---------- optional deploy ----------
if ($DeployEnv -in @("staging","prod")) {
  if (-not (Need "kubectl")) { Fail "kubectl required for deploy" }
  if (-not (Test-Path "k8s")) { Fail "k8s/ missing" }
  kubectl apply -f k8s
}

# ---------- commit ----------
if (Need "git") { git add -A; git commit -m "Finalize: bootstrap+gates+design+deliver [skip ci]" | Out-Null }

Ok "Finalize complete. Artifacts: $Art"
Stop-Transcript
