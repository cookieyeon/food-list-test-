# 상품 관리 페이지용 로컬 개발 서버 (설치 필요 없음, Windows PowerShell만 있으면 됨)
# 같은 폴더의 .env.local을 읽어 페이지에 Supabase 연결 정보를 넘긴다
# index.html · .env.local을 고치면 열려 있는 페이지가 자동으로 새로고침된다
# 실행: powershell -ExecutionPolicy Bypass -File app\product-admin\server.ps1
# 종료: Ctrl+C
param([int]$Port = 8787)

$root = $PSScriptRoot
$envPath = Join-Path $root '.env.local'

# KEY=VALUE 형식만 읽는다. 빈 줄과 # 주석은 건너뛰고, 값의 따옴표는 벗긴다
function Read-EnvFile($path) {
    $vars = @{}
    if (-not (Test-Path $path)) { return $vars }
    foreach ($line in [IO.File]::ReadAllLines($path, [Text.Encoding]::UTF8)) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#') -or -not $t.Contains('=')) { continue }
        # 값 안에 '='가 있을 수 있으므로 첫 번째 '='에서만 나눈다
        $i = $t.IndexOf('=')
        $vars[$t.Substring(0, $i).Trim()] = $t.Substring($i + 1).Trim().Trim('"').Trim("'")
    }
    return $vars
}

# 페이지에 넘길 연결 정보. service_role 키가 있으면 그걸, 없으면 anon 키를 쓴다
function Get-ConfigScript {
    $e = Read-EnvFile $envPath
    if ($e['SUPABASE_SERVICE_ROLE_KEY']) { $key = $e['SUPABASE_SERVICE_ROLE_KEY']; $type = 'service_role' }
    else { $key = $e['NEXT_PUBLIC_SUPABASE_ANON_KEY']; $type = 'anon' }
    $cfg = @{ url = $e['NEXT_PUBLIC_SUPABASE_URL']; key = $key; keyType = $type } | ConvertTo-Json -Compress
    return "window.APP_CONFIG = $cfg;"
}

# 개발용 자동 새로고침: index.html · .env.local 수정 시각을 버전으로 쓴다
function Get-Version {
    $ticks = foreach ($p in (Join-Path $root 'index.html'), $envPath) {
        if (Test-Path $p) { (Get-Item $p).LastWriteTimeUtc.Ticks } else { 0 }
    }
    return ($ticks -join '-')
}

# 페이지에 끼워 넣는 스크립트. 1초마다 버전을 물어보고 바뀌면 새로고침한다
$reloadScript = @'
<script>
  // 개발 서버: index.html이나 .env.local이 바뀌면 자동 새로고침
  (() => {
    let v;
    setInterval(async () => {
      try {
        const n = await (await fetch('/__version', { cache: 'no-store' })).text();
        if (v && n !== v) location.reload();
        v = n;
      } catch { /* 서버가 꺼져 있으면 다음에 다시 시도 */ }
    }, 1000);
  })();
</script>
'@

function Get-Page {
    $html = [IO.File]::ReadAllText((Join-Path $root 'index.html'), [Text.Encoding]::UTF8)
    $i = $html.LastIndexOf('</body>')
    if ($i -lt 0) { return $html + $reloadScript }
    return $html.Insert($i, $reloadScript)
}

function Send($ctx, [int]$status, [string]$type, [string]$body) {
    $bytes = [Text.Encoding]::UTF8.GetBytes($body)
    $res = $ctx.Response
    $res.StatusCode = $status
    $res.ContentType = "$type; charset=utf-8"
    $res.Headers['Cache-Control'] = 'no-store'
    $res.ContentLength64 = $bytes.Length
    $res.OutputStream.Write($bytes, 0, $bytes.Length)
    $res.Close()
}

if (-not (Test-Path $envPath)) { Write-Warning ".env.local이 없습니다: $envPath" }

# localhost로만 받는다 (같은 네트워크의 다른 PC에서는 접속 불가)
$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
"상품 관리: http://localhost:$Port  (종료: Ctrl+C)"

try {
    while ($listener.IsListening) {
        # 짧게 기다리며 반복해야 Ctrl+C가 바로 먹는다
        $pending = $listener.GetContextAsync()
        while (-not $pending.AsyncWaitHandle.WaitOne(500)) { }
        $ctx = $pending.GetAwaiter().GetResult()
        try {
            # 이 세 경로만 내보낸다. .env.local 등 다른 파일은 절대 제공하지 않는다
            switch ($ctx.Request.Url.AbsolutePath) {
                '/' { Send $ctx 200 'text/html' (Get-Page) }
                # 요청마다 다시 읽으므로 .env.local을 고치면 자동 새로고침으로 바로 반영된다
                '/config.js' { Send $ctx 200 'application/javascript' (Get-ConfigScript) }
                '/__version' { Send $ctx 200 'text/plain' (Get-Version) }
                default { Send $ctx 404 'text/plain' 'Not Found' }
            }
        }
        catch { Write-Warning "요청 처리 실패: $($_.Exception.Message)" }
    }
}
finally {
    $listener.Stop()
    $listener.Close()
}
