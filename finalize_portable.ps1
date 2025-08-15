param(
  [switch]$AutoBootstrap = $true,
  [switch]$ProDesigner   = $true,
  [switch]$ProImplement  = $true,
  [switch]$ProDeliver    = $true,
  [string]$DeployEnv     = "none",      # none|staging|prod
  [int]$CoverageMin      = 90,
  [int]$JavaMinVersion   = 17,
  [string]$ServeUrl      = "http://localhost:3000"
)

$ErrorActionPreference='Stop'
$ROOT = (Get-Location).Path
$ART  = Join-Path $ROOT "artifacts"; New-Item -Force -ItemType Directory -Path $ART | Out-Null
$LOG  = Join-Path $ART ("run_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
Start-Transcript -Path $LOG -Append

function Need($cmd){ (Get-Command $cmd -ErrorAction SilentlyContinue) -ne $null }
function Ok($m){ Write-Host "OK: $m" }
function Fail($m){ Write-Error $m; Stop-Transcript; exit 1 }

# --- light installer (winget/choco if present) ---
function EnsureBin($bin, $wingetId='', $chocoId=''){
  if (Need $bin) { return }
  if (-not $AutoBootstrap) { Fail "Missing $bin" }
  if (Need winget -and $wingetId) { winget install --silent --accept-source-agreements --accept-package-agreements $wingetId | Out-Null }
  elseif (Need choco -and $chocoId){ choco install $chocoId -y | Out-Null }
  if (-not (Need $bin)) { Write-Warning "Still missing $bin; continuing where possible." }
}

# --- Detect project types (FIXED) ---
$IsWeb  = Test-Path (Join-Path $ROOT 'package.json')
$IsML   = (Test-Path (Join-Path $ROOT 'env.yml')) -or (Test-Path (Join-Path $ROOT 'requirements.txt'))
$IsHPC  = Test-Path (Join-Path $ROOT 'slurm.sbatch')
$IsJava = (Test-Path (Join-Path $ROOT 'pom.xml')) -or (Test-Path (Join-Path $ROOT 'build.gradle')) -or (Test-Path (Join-Path $ROOT 'build.gradle.kts'))
if (-not ($IsWeb -or $IsML -or $IsHPC -or $IsJava)) { Fail "No supported project markers." }

# --- Global gates ---
Write-Host "== Placeholders =="
$ph = Get-ChildItem -Recurse -File -ErrorAction SilentlyContinue |
  Where-Object { $_.FullName -notmatch "\\(node_modules|.git|dist|build|.next)\\"
                 -and $_.Extension -match '\.(js|ts|tsx|jsx|html|css|java|md)$' } |
  Select-String -Pattern 'TODO|FIXME|Lorem ipsum|PLACEHOLDER'
if ($ph){ Fail "Placeholders found" } else { Ok "No placeholders" }

Write-Host "== Secrets (gitleaks if available) =="
if (Need gitleaks){ gitleaks detect --no-banner --report-path (Join-Path $ART "gitleaks.json") } else { Write-Host "gitleaks not found" }

# --- Web bootstrap helpers ---
function Bootstrap-Next {
  EnsureBin node "OpenJS.NodeJS" "nodejs"
  npx --yes create-next-app@latest . --ts --eslint --tailwind --src-dir --app --import-alias "@/*" --use-npm --no-git --no-experimental-app
  npm i -D @types/node prettier eslint-config-prettier eslint-plugin-import @typescript-eslint/parser @typescript-eslint/eslint-plugin @axe-core/cli @lhci/cli serve playwright
  @'
{"extends":["next/core-web-vitals","plugin:@typescript-eslint/recommended","prettier"],
 "rules":{"no-console":["error",{"allow":["warn","error"]}],"import/no-default-export":"error","@typescript-eslint/explicit-function-return-type":"warn","@typescript-eslint/no-misused-promises":"error"}}
'@ | Set-Content .eslintrc.json
  @'
{"compilerOptions":{"target":"ES2022","module":"ESNext","lib":["ES2022","DOM"],"strict":true,"noUncheckedIndexedAccess":true,"noFallthroughCasesInSwitch":true,"moduleResolution":"Bundler","jsx":"preserve","allowJs":false,"baseUrl":".","paths":{"@/*":["src/*"]}},"include":["next-env.d.ts","**/*.ts","**/*.tsx"],"exclude":["node_modules"]}
'@ | Set-Content tsconfig.json
  if (-not (Test-Path src/components)){ New-Item -ItemType Directory -Force -Path src/components | Out-Null }
  if (-not (Test-Path src/app)){ New-Item -ItemType Directory -Force -Path src/app | Out-Null }
  @'
"use client";
export default function SmartHero(){ return (<section className="min-h-[60vh] grid place-items-center p-12 text-center">
  <h1 className="text-6xl font-extrabold">Adaptive Hero</h1>
  <p className="mt-4 text-xl opacity-80">Unique per session with WebGL backdrop.</p>
  <canvas id="hero-canvas" className="fixed inset-0 -z-10"></canvas>
</section>); }
'@ | Set-Content "src/components/SmartHero.tsx"
  @"
{"ci":{"collect":{"url":["$ServeUrl"],"numberOfRuns":2,"startServerCommand":"npm run start"},
 "assert":{"assertions":{"categories:performance":["error",{"minScore":0.95}],
                        "categories:accessibility":["error",{"minScore":0.95}],
                        "categories:seo":["error",{"minScore":0.95}],
                        "cumulative-layout-shift":["error",{"maxNumericValue":0.1}]}}}}
"@ | Set-Content ".lighthouserc.json"
}
function Ensure-Server {
  try { Invoke-WebRequest -UseBasicParsing -Uri $ServeUrl -TimeoutSec 2 | Out-Null; return } catch {}
  if (Test-Path package.json -and (Get-Content package.json -Raw) -match '"start"') {
    Start-Process -FilePath "npm" -ArgumentList "run","start" -WindowStyle Hidden
    Start-Sleep -Seconds 3
  } elseif (Test-Path dist) {
    npx --yes serve -s dist -l 3000 | Out-Null
    Start-Sleep -Seconds 2
  }
}
function EnsureNpmPkg([string]$pkg){
  if (-not (Test-Path package.json)) { return }
  $has = (npm ls $pkg --depth=0 2>$null) -like "*$pkg*"
  if (-not $has){ npm i -D $pkg }
}

# --- WEB pipeline ---
if ($IsWeb) {
  EnsureBin node "OpenJS.NodeJS" "nodejs"
  if ($AutoBootstrap -and -not (Select-String '"next"' package.json -Quiet)) { Bootstrap-Next }

  npx --yes playwright install --with-deps; npx --yes playwright init --quiet | Out-Null
  npm install --no-audit --no-fund

  if (Need npx){ npx eslint . --max-warnings=0 }

  if (npm run | Select-String "test"){
    $out = (npm run test -- --coverage --coverageReporters=text-summary) -join "`n"
    if ($out -match "All files.*?(\d+)%"){
      $cov=[int]$matches[1]
      if ($cov -lt $CoverageMin){ Fail "Coverage $cov% < $CoverageMin%" } else { Ok "Coverage $cov%" }
    }
  }

  Ensure-Server
  if (Test-Path ".lighthouserc.json"){ npx @lhci/cli autorun | Out-Null }
  if (Need npx){ npx @axe-core/cli $ServeUrl --exit 1 | Out-Null }

  if (npm run | Select-String "build"){ npm run build }
  if (Need docker){ docker build --pull --no-cache -t project/app:local . | Out-Null }
}

# --- JAVA pipeline ---
function JavaEnsure {
  if (-not (Need java)){
    if ($AutoBootstrap){
      if (Need winget){ winget install --silent EclipseAdoptium.Temurin.$JavaMinVersion.JDK | Out-Null }
      elseif (Need choco){ choco install "openjdk$JavaMinVersion" -y | Out-Null }
    }
  }
  if (-not (Need java)){ Fail "Java missing" }
}
function JavaBootstrapMaven {
  if (-not (Test-Path mvnw)) { mvn -N -q wrapper }
  if (-not (Select-String "jacoco-maven-plugin" pom.xml -Quiet)){
    (Get-Content pom.xml -Raw) -replace "</project>", @"
  <build><plugins>
    <plugin><groupId>org.jacoco</groupId><artifactId>jacoco-maven-plugin</artifactId><version>0.8.12</version>
      <executions><execution><goals><goal>prepare-agent</goal></goals></execution>
      <execution><id>report</id><phase>verify</phase><goals><goal>report</goal></goals></execution></executions>
    </plugin>
    <plugin><groupId>com.github.spotbugs</groupId><artifactId>spotbugs-maven-plugin</artifactId><version>4.8.6.4</version></plugin>
  </plugins></build>
</project>
"@ | Set-Content pom.xml
  }
}
if ($IsJava){
  JavaEnsure
  if (Test-Path (Join-Path $ROOT 'pom.xml')){
    if ($AutoBootstrap){ JavaBootstrapMaven }
    ./mvnw -q -DskipTests=false test
    ./mvnw -q -DskipTests=false verify spotbugs:check
    $jac=Join-Path $ROOT "target/site/jacoco/jacoco.xml"
    if (Test-Path $jac){
      $xml=Get-Content $jac
      $ln=($xml|Select-String '<counter type="LINE"').ToString()
      if ($ln -match 'missed="(\d+)" covered="(\d+)"'){
        $miss=[double]$matches[1]; $covd=[double]$matches[2]; $pct=[int](100*$covd/($miss+$covd))
        if ($pct -lt $CoverageMin){ Fail "Java coverage $pct% < $CoverageMin%" } else { Ok "Java coverage $pct%" }
      }
    }
    if (Need docker){ ./mvnw -q jib:dockerBuild -Dimage=project/java-app:local | Out-Null }
  } elseif (Test-Path (Join-Path $ROOT 'build.gradle')) {
    ./gradlew test jacocoTestReport
  } elseif (Test-Path (Join-Path $ROOT 'build.gradle.kts')) {
    ./gradlew test jacocoTestReport
  }
}

# --- ML pipeline ---
if ($IsML){
  if (-not (Need python)) { Fail "Python missing" }
  if (Test-Path (Join-Path $ROOT 'requirements.txt')){ python -m pip install -U pip; python -m pip install -r requirements.txt }
  if (Test-Path (Join-Path $ROOT 'tests')){ pytest -q --maxfail=1 }
  if (Test-Path (Join-Path $ROOT 'docker') -and (Need docker)){ docker build --pull --no-cache -t project/ml:local docker | Out-Null }
}

# --- HPC pipeline (SLURM) ---
if ($IsHPC){
  if (Need sbatch){
    $jid = (sbatch (Join-Path $ROOT 'slurm.sbatch') | Select-String "Submitted batch job").ToString().Split()[-1]
    if (-not $jid){ Fail "SLURM submit failed" }
    $deadline=(Get-Date).AddHours(1)
    while ((Get-Date) -lt $deadline -and (squeue -j $jid | Select-String $jid)){ Start-Sleep -Seconds 20 }
    if (squeue -j $jid | Select-String $jid){ Fail "SLURM watch timeout" }
    if (Test-Path (Join-Path $ROOT 'output')){
      Get-ChildItem -Recurse (Join-Path $ROOT 'output') -File | ForEach-Object { try { Get-FileHash $_.FullName | Out-File -Append (Join-Path $ART "hpc_checksums.txt") } catch {} }
    }
  } else { Write-Host "sbatch not found. Skipping HPC." }
}

# === Designer / Implementer / Deliverer ===
function DesignPack{
  if (-not $IsWeb -or -not $ProDesigner) { return }
  foreach($p in @("tailwindcss","@tailwindcss/typography","@tailwindcss/forms","framer-motion","three")){ EnsureNpmPkg $p }
  if (-not (Test-Path tailwind.config.cjs)){
@'
module.exports={content:["./src/**/*.{ts,tsx,js,jsx}","./app/**/*.{ts,tsx}"],theme:{extend:{fontFamily:{display:["Inter","ui-sans-serif","system-ui"]}}},plugins:[require("@tailwindcss/typography"),require("@tailwindcss/forms")]}
'@ | Set-Content tailwind.config.cjs
  }
  $comp = Join-Path $ROOT "src/components/SignatureHero.tsx"
  if (-not (Test-Path $comp)){
@'
"use client";
import { useEffect, useRef } from "react";
import * as THREE from "three";
export default function SignatureHero(){
  const ref=useRef<HTMLDivElement>(null);
  useEffect(()=>{ const el=ref.current!; const s=new THREE.Scene();
    const cam=new THREE.PerspectiveCamera(60, el.clientWidth/el.clientHeight, 0.1, 1000);
    const r=new THREE.WebGLRenderer({antialias:true}); r.setSize(el.clientWidth, el.clientHeight); el.appendChild(r.domElement);
    cam.position.z=6; const g=new THREE.IcosahedronGeometry(2,2);
    const m=new THREE.MeshStandardMaterial({metalness:0.6, roughness:0.2, color:new THREE.Color("hsl("+(Date.now()%360)+",80%,60%)")});
    const mesh=new THREE.Mesh(g,m); s.add(mesh); s.add(new THREE.DirectionalLight(0xffffff,1)); s.add(new THREE.AmbientLight(0x404040,1.2));
    let id=0; const loop=()=>{ mesh.rotation.x+=0.005; mesh.rotation.y+=0.008; r.render(s,cam); id=requestAnimationFrame(loop); }; loop();
    return ()=>{ cancelAnimationFrame(id); el.innerHTML=""; };
  },[]);
  return (<section className="min-h-[80vh] grid place-items-center relative">
    <div ref={ref} className="absolute inset-0 -z-10"></div>
    <h1 className="text-6xl md:text-8xl font-extrabold tracking-tight">Your Unforgettable Site</h1>
    <p className="mt-4 text-xl text-white/80">Unique per session. Zero templates.</p>
  </section>);
}
'@ | Set-Content $comp
  }
  $page = Get-ChildItem -Recurse -Include page.tsx -File | Select-Object -First 1
  if ($page){
    $txt = Get-Content $page.FullName -Raw
    if ($txt -notmatch "SignatureHero"){
      $txt = "import SignatureHero from ""@/components/SignatureHero"";`n" + ($txt -replace "return\s*\(", "return (<main><SignatureHero/>")
      if ($txt -notmatch "</main>"){ $txt = $txt + "</main>" }
      Set-Content $page.FullName $txt
    }
  }
}
function ImplementPack{
  if (-not $ProImplement){ return }
  if ($IsWeb -and (Test-Path package.json)){
    if (-not (Test-Path .eslintrc.json)){
@'
{ "extends": ["next/core-web-vitals","plugin:@typescript-eslint/recommended","prettier"],
  "rules": {"no-console":["error",{"allow":["warn","error"]}],"import/no-default-export":"error","@typescript-eslint/explicit-function-return-type":"warn"} }
'@ | Set-Content .eslintrc.json
    }
    if (-not (Test-Path tsconfig.json)){
@'
{"compilerOptions":{"target":"ES2022","module":"ESNext","strict":true,"noUncheckedIndexedAccess":true,"noFallthroughCasesInSwitch":true}}
'@ | Set-Content tsconfig.json
    }
    $spec="tests/e2e/smoke.spec.ts"
    if (-not (Test-Path $spec)){ New-Item -Force -ItemType Directory -Path (Split-Path $spec) | Out-Null
@'
import { test, expect } from "@playwright/test";
test("home loads", async ({ page }) => { await page.goto("/"); await expect(page.locator("h1")).toBeVisible(); });
'@ | Set-Content $spec
    }
  }
  if ($IsJava -and (Test-Path (Join-Path $ROOT 'pom.xml')) -and -not (Select-String "jacoco-maven-plugin" pom.xml -Quiet)){
    (Get-Content pom.xml -Raw) -replace "</project>", @"
  <build><plugins>
    <plugin><groupId>org.jacoco</groupId><artifactId>jacoco-maven-plugin</artifactId><version>0.8.12</version>
      <executions><execution><goals><goal>prepare-agent</goal></goals></execution>
      <execution><id>report</id><phase>verify</phase><goals><goal>report</goal></goals></execution></executions>
    </plugin>
  </plugins></build>
</project>
"@ | Set-Content pom.xml
  }
}
function DeliverPack{
  if (-not $ProDeliver){ return }
  if (Need docker){ docker build --pull --no-cache -t project/app:release . | Out-Null }
  $bundle = Join-Path $ART ("release_{0}.zip" -f (Get-Date -Format "yyyyMMdd_HHmmss"))
  $paths=@("artifacts","docs")
  if (Test-Path "dist"){ $paths+="dist" }
  if (Test-Path ".next"){ $paths+=".next" }
  if (Test-Path "target"){ $paths+="target" }
  Compress-Archive -Path $paths -DestinationPath $bundle -Force
  Write-Host "Bundle: $bundle"
}

# call modes
DesignPack; ImplementPack; DeliverPack

# --- Docs auto-update ---
New-Item -ItemType Directory -Force -Path (Join-Path $ROOT "docs") | Out-Null
Add-Content -Path "$ROOT/docs/CHANGELOG.md" -Value "## $(Get-Date -Format o)`n- Finalize run on $(hostname)`n"
if (Test-Path (Join-Path $ROOT 'data')){
  $files=(Get-ChildItem -Recurse (Join-Path $ROOT 'data') -File | Measure-Object).Count
  Set-Content -Path "$ROOT/docs/DATA_README.md" -Value "# Data README`n- Files: $files"
}
if (Test-Path (Join-Path $ROOT 'models')) -or (Test-Path (Join-Path $ROOT 'src')){
  Set-Content -Path "$ROOT/docs/MODEL_CARD.md" -Value "# Model Card`n- Metrics: see artifacts/`n- Risks: PII redaction"
}

# --- Optional deploy ---
if ($DeployEnv -in @("staging","prod")){
  if (-not (Need kubectl)){ Fail "kubectl required for deploy" }
  if (-not (Test-Path (Join-Path $ROOT 'k8s'))){ Fail "k8s/ missing" }
  kubectl apply -f (Join-Path $ROOT 'k8s')
}

Ok "Finalize complete. Artifacts: $ART"
Stop-Transcript
