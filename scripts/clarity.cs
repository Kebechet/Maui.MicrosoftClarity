// Every read, edit and parse the bump pipeline needs, as one .NET 10 file-based app:
//
//   dotnet run scripts/clarity.cs -- <command> [args]
//
// The shell scripts stay thin glue (curl, gh, git, dotnet, unzip, sharpie). This file is
// where XML, JSON and HTML handling lives, so the repository never grows a second
// scripting language - see CLAUDE.md.
//
// Every write preserves the file's BOM and line endings byte-for-byte: Git Bash's sed -i
// strips CRLF, which silently rewrote every line of a csproj once.
//
// Commands
//   get-version <csproj>                            print <Version>
//   get-maven-pin <csproj>                          print the com.microsoft.clarity:clarity pin
//   get-min-os <csproj>                             print <SupportedOSPlatformVersion>
//   set-version <csproj> <version>                  rewrite <Version>
//   set-maven-pin <csproj> <version>                rewrite the AndroidMavenLibrary pin
//   set-release-note <csproj> <note>                replace <PackageReleaseNotes> with one entry
//   set-package-version <csproj> <pkgId> <version>  rewrite one <PackageReference> version
//   check-min-os <csproj> <native-min>              raise the floor when the native lib needs more
//   compare-versions <a> <b>                        print -1, 0 or 1 (dotted numeric)
//   changelog-excerpt <android|ios> <version>       Microsoft's note for that version, one line
//   strip-verify <file>                             drop Sharpie's advisory [Verify(...)] attrs
//   normalize-usings <ApiDefinitions.cs>            drop `using Clarity;`, ensure `using UIKit;`

using System.Globalization;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;

if (args.Length == 0)
{
    Console.Error.WriteLine("usage: dotnet run scripts/clarity.cs -- <command> [args]");
    return 2;
}

try
{
    return args[0] switch
    {
        "get-version" => Print(ReadElement(Arg(1), "Version")),
        "get-maven-pin" => Print(ReadMavenPin(Arg(1))),
        "get-min-os" => Print(ReadElement(Arg(1), "SupportedOSPlatformVersion")),
        "set-version" => SetElement(Arg(1), "Version", Arg(2)),
        "set-maven-pin" => SetMavenPin(Arg(1), Arg(2)),
        "set-release-note" => SetReleaseNote(Arg(1), Arg(2)),
        "set-package-version" => SetPackageVersion(Arg(1), Arg(2), Arg(3)),
        "check-min-os" => CheckMinOs(Arg(1), Arg(2)),
        "compare-versions" => Print(CompareVersions(Arg(1), Arg(2)).ToString(CultureInfo.InvariantCulture)),
        "changelog-excerpt" => await ChangelogExcerpt(Arg(1), Arg(2)),
        "strip-verify" => StripVerify(Arg(1)),
        "normalize-usings" => NormalizeUsings(Arg(1)),
        var other => Fail($"unknown command '{other}'"),
    };
}
catch (UsageException ex)
{
    Console.Error.WriteLine($"ERROR: {ex.Message}");
    return 2;
}

string Arg(int index) => index < args.Length
    ? args[index]
    : throw new UsageException($"'{args[0]}' is missing argument {index}");

int Print(string value)
{
    Console.WriteLine(value);
    return 0;
}

static int Fail(string message)
{
    Console.Error.WriteLine($"ERROR: {message}");
    return 1;
}

// --- file IO that leaves the encoding exactly as it found it ---------------------------

static (bool Bom, string Eol, string Text) ReadFile(string path)
{
    var bytes = File.ReadAllBytes(path);
    var bom = bytes.Length >= 3 && bytes[0] == 0xEF && bytes[1] == 0xBB && bytes[2] == 0xBF;
    var text = new UTF8Encoding(false).GetString(bytes, bom ? 3 : 0, bytes.Length - (bom ? 3 : 0));
    return (bom, text.Contains("\r\n") ? "\r\n" : "\n", text);
}

static void WriteFile(string path, bool bom, string text)
{
    var body = new UTF8Encoding(false).GetBytes(text);
    using var stream = File.Create(path);
    if (bom) stream.Write([0xEF, 0xBB, 0xBF]);
    stream.Write(body);
}

// --- csproj reads ----------------------------------------------------------------------

static string ReadElement(string csproj, string element)
{
    var match = Regex.Match(ReadFile(csproj).Text, $"<{element}>([^<]+)</{element}>");
    return match.Success
        ? match.Groups[1].Value.Trim()
        : throw new UsageException($"no <{element}> found in {csproj}");
}

static string ReadMavenPin(string csproj)
{
    var match = Regex.Match(
        ReadFile(csproj).Text,
        @"<AndroidMavenLibrary\s+Include=""com\.microsoft\.clarity:clarity""\s+Version=""([^""]+)""");
    return match.Success
        ? match.Groups[1].Value
        : throw new UsageException($"no <AndroidMavenLibrary Include=\"com.microsoft.clarity:clarity\" .../> in {csproj}");
}

// --- csproj writes ---------------------------------------------------------------------

static int Replace(string path, string pattern, string replacement, string what)
{
    var (bom, _, text) = ReadFile(path);
    var updated = Regex.Replace(text, pattern, replacement);
    if (updated == text && !Regex.IsMatch(text, pattern))
        return Fail($"{what} not found in {path}");

    WriteFile(path, bom, updated);
    return 0;
}

static int SetElement(string csproj, string element, string value) =>
    Replace(csproj, $"<{element}>[^<]+</{element}>", $"<{element}>{value}</{element}>", $"<{element}>");

static int SetMavenPin(string csproj, string version) =>
    Replace(
        csproj,
        """(<AndroidMavenLibrary\s+Include="com\.microsoft\.clarity:clarity"\s+Version=")[^"]+(")""",
        $"${{1}}{version}${{2}}",
        "the AndroidMavenLibrary pin");

static int SetPackageVersion(string csproj, string packageId, string version) =>
    Replace(
        csproj,
        $"""(<PackageReference\s+Include="{Regex.Escape(packageId)}"\s+Version=")[^"]+(")""",
        $"${{1}}{version}${{2}}",
        $"a <PackageReference> for {packageId}");

// The notes are metadata for the version being published, not a changelog of past
// releases: nuget.org already shows every earlier version's own notes.
static int SetReleaseNote(string csproj, string note)
{
    if (note.AsSpan().IndexOfAny('<', '>', '&') >= 0)
        return Fail($"the note must not contain XML markup: {note}");

    return Replace(
        csproj,
        "(<PackageReleaseNotes>).*?(</PackageReleaseNotes>)",
        $"${{1}}{note.Replace("$", "$$")}${{2}}",
        "<PackageReleaseNotes>");
}

// --- minimum OS ------------------------------------------------------------------------

// Dotted numeric comparison: "16.0" > "14.2", "21" > "19", "3.9.1" > "3.9.0".
static int CompareVersions(string left, string right)
{
    var a = left.Split('.');
    var b = right.Split('.');
    for (var i = 0; i < Math.Max(a.Length, b.Length); i++)
    {
        var x = i < a.Length && int.TryParse(a[i], NumberStyles.Integer, CultureInfo.InvariantCulture, out var pa) ? pa : 0;
        var y = i < b.Length && int.TryParse(b[i], NumberStyles.Integer, CultureInfo.InvariantCulture, out var pb) ? pb : 0;
        if (x != y) return x < y ? -1 : 1;
    }
    return 0;
}

// A native SDK that raises its floor while the binding still claims a lower one compiles,
// packs and passes every build check - it only breaks at deployment. So the floor is read
// from the artifact and the binding is raised to match. Whether the WRAPPER follows is
// breaking for consumers and stays a human decision, which is why the caller turns a
// raise into a draft PR.
static int CheckMinOs(string csproj, string nativeMin)
{
    var current = ReadElement(csproj, "SupportedOSPlatformVersion");
    var raised = CompareVersions(nativeMin, current) > 0;
    var updated = raised ? nativeMin : current;

    if (raised)
    {
        var result = SetElement(csproj, "SupportedOSPlatformVersion", nativeMin);
        if (result != 0) return result;
        Console.Error.WriteLine($"==> minimum OS raised: {current} -> {nativeMin} (required by the native library)");
    }
    else
    {
        Console.Error.WriteLine($"==> minimum OS unchanged: csproj {current}, native library {nativeMin}");
    }

    Emit($"min_os_native={nativeMin}");
    Emit($"min_os_previous={current}");
    Emit($"min_os_current={updated}");
    Emit($"min_os_raised={(raised ? "true" : "false")}");
    return 0;

    static void Emit(string line)
    {
        Console.WriteLine(line);
        var output = Environment.GetEnvironmentVariable("GITHUB_OUTPUT");
        if (!string.IsNullOrEmpty(output)) File.AppendAllText(output, line + Environment.NewLine);
    }
}

// --- Sharpie output --------------------------------------------------------------------

// [Verify(...)] is advisory and fails the build if left in. Sharpie emits it on its own
// line, indented, and inline next to other attributes.
static int StripVerify(string path)
{
    var (bom, eol, text) = ReadFile(path);
    var lines = text.Split('\n')
        .Where(line => !Regex.IsMatch(line, @"^\s*\[Verify\s*\([^)]*\)\]\s*\r?$"))
        .Select(line => Regex.Replace(line, @"\[Verify\s*\([^)]*\)\]\s*", string.Empty));
    WriteFile(path, bom, string.Join("\n", lines));
    _ = eol;
    return 0;
}

// Sharpie emits `using Clarity;` - the Swift module name, not a .NET namespace - and omits
// `using UIKit;` although maskView:/unmaskView: take a UIView. That one line is what failed
// the 3.5.3, 3.5.4 and 4.0.0 bumps with CS0246.
static int NormalizeUsings(string path)
{
    var (bom, eol, text) = ReadFile(path);
    var lines = text.Split('\n')
        .Where(line => !Regex.IsMatch(line, @"^using Clarity;\s*\r?$"))
        .ToList();

    if (!lines.Any(line => Regex.IsMatch(line, @"^using UIKit;\s*\r?$")))
    {
        // After ObjCRuntime when present, so the result matches the using order already
        // committed in ApiDefinitions.cs and a re-bind produces no incidental diff.
        var anchor = lines.FindIndex(line => Regex.IsMatch(line, @"^using ObjCRuntime;\s*\r?$"));
        if (anchor < 0) anchor = lines.FindIndex(line => Regex.IsMatch(line, @"^using Foundation;\s*\r?$"));
        var carriage = eol == "\r\n" ? "\r" : string.Empty;
        lines.Insert(anchor >= 0 ? anchor + 1 : 0, $"using UIKit;{carriage}");
    }

    WriteFile(path, bom, string.Join("\n", lines));
    return 0;
}

// --- changelog -------------------------------------------------------------------------

// Sources, in order of preference:
//   ios      microsoft/clarity-apps GitHub releases, then Microsoft Learn. The releases
//            carry per-version notes the moment the SDK ships, while Learn lags by days or
//            weeks - iOS 4.0.0 had release notes on GitHub while Learn still stopped at
//            3.5.4.
//   android  Microsoft Learn only. Those releases are iOS-only (all 51 of them), and
//            neither Maven Central nor the AAR carries notes.
// Never throws: a missing changelog must not block a bump.
static async Task<int> ChangelogExcerpt(string platform, string version)
{
    if (platform is not ("android" or "ios")) return Fail($"unknown platform '{platform}'");

    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    http.DefaultRequestHeaders.UserAgent.ParseAdd("Kebechet.Maui.MicrosoftClarity-bump/1.0");

    var excerpt = platform == "ios" ? await FromGitHubReleases(http, version) : null;
    excerpt ??= await FromLearn(http, platform, version);

    if (!string.IsNullOrWhiteSpace(excerpt)) Console.WriteLine(Sanitize(excerpt));
    return 0;
}

// The result is written into <PackageReleaseNotes>, which set-release-note refuses to fill
// with markup rather than corrupt the csproj.
static string Sanitize(string value) =>
    Regex.Replace(value.Replace("&", "and").Replace("<", string.Empty).Replace(">", string.Empty), @"\s+", " ").Trim();

static async Task<string?> FromGitHubReleases(HttpClient http, string version)
{
    try
    {
        using var request = new HttpRequestMessage(
            HttpMethod.Get,
            "https://api.github.com/repos/microsoft/clarity-apps/releases?per_page=100");
        request.Headers.Accept.ParseAdd("application/vnd.github+json");
        request.Headers.Add("X-GitHub-Api-Version", "2022-11-28");

        // Unauthenticated this shares the runner IP's hourly budget.
        var token = Environment.GetEnvironmentVariable("GH_TOKEN")
                    ?? Environment.GetEnvironmentVariable("GITHUB_TOKEN");
        if (!string.IsNullOrEmpty(token))
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var response = await http.SendAsync(request);
        if (!response.IsSuccessStatusCode) return null;

        using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
        foreach (var release in json.RootElement.EnumerateArray())
        {
            var tag = (release.TryGetProperty("tag_name", out var t) ? t.GetString() : null)?.TrimStart('v') ?? string.Empty;
            var name = (release.TryGetProperty("name", out var n) ? n.GetString() : null) ?? string.Empty;
            if (tag != version && !name.Contains($"v{version}", StringComparison.OrdinalIgnoreCase)) continue;

            var body = (release.TryGetProperty("body", out var b) ? b.GetString() : null) ?? string.Empty;
            var items = body.Split('\n')
                .Select(line => line.Trim())
                .Where(line => line.StartsWith("- ") || line.StartsWith("* "))
                .Select(line => line[2..].Replace("**", string.Empty).Trim())
                .Where(line => line.Length > 0 && !line.StartsWith("Full Changelog", StringComparison.OrdinalIgnoreCase))
                .Select(line => line.EndsWith('.') ? line : line + ".")
                .ToList();

            return items.Count > 0 ? string.Join(" ", items) : null;
        }
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException or JsonException)
    {
        // Fall through to Learn.
    }

    return null;
}

static async Task<string?> FromLearn(HttpClient http, string platform, string version)
{
    var heading = platform == "ios" ? "iOS SDK Changelog" : "Android SDK Changelog";
    string html;
    try
    {
        // Learn serves the page as static HTML, but only to browser-like user agents.
        using var request = new HttpRequestMessage(HttpMethod.Get, "https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog");
        request.Headers.UserAgent.Clear();
        request.Headers.UserAgent.ParseAdd("Mozilla/5.0");
        using var response = await http.SendAsync(request);
        if (!response.IsSuccessStatusCode) return null;
        html = await response.Content.ReadAsStringAsync();
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
    {
        return null;
    }

    // Flatten to one text node per line, then walk: platform section -> version block. A
    // "[Tag]" line starts an item; every other line continues it, because Learn splits
    // sentences around inline <code> elements.
    var lines = Regex.Replace(html, "<[^>]*>", "\n")
        .Split('\n')
        .Select(line => System.Net.WebUtility.HtmlDecode(line).Trim())
        .Where(line => line.Length > 0)
        .ToList();

    var items = new List<string>();
    var current = new StringBuilder();
    bool inSection = false, inBlock = false;

    void Flush()
    {
        if (current.Length == 0) return;
        items.Add(Regex.Replace(current.ToString(), @"\s+", " ").Trim());
        current.Clear();
    }

    foreach (var line in lines)
    {
        if (line.StartsWith(heading, StringComparison.Ordinal)) { inSection = true; continue; }
        if (inSection && line.EndsWith("SDK Changelog", StringComparison.Ordinal)) { inSection = false; }
        if (!inSection) continue;

        if (line.StartsWith($"{version} (", StringComparison.Ordinal)) { inBlock = true; continue; }
        if (inBlock && Regex.IsMatch(line, @"^\d+\.\d+\.\d+ \(")) { inBlock = false; }
        if (!inBlock) continue;

        if (Regex.IsMatch(line, @"^\[[A-Za-z ]+\]$")) { Flush(); current.Append(line).Append(' '); }
        else current.Append(current.Length > 0 && !current.ToString().EndsWith(' ') ? " " : string.Empty).Append(line);
    }

    Flush();
    return items.Count > 0 ? string.Join(" ", items) : null;
}

file sealed class UsageException(string message) : Exception(message);
