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
//   set-release-note <csproj> <note>                replace <PackageReleaseNotes>, newlines allowed
//   set-package-version <csproj> <pkgId> <version>  rewrite one <PackageReference> version
//   check-min-os <csproj> <native-min>              raise the floor when the native lib needs more
//   compare-versions <a> <b>                        print -1, 0 or 1 (dotted numeric)
//   last-published-native <pkgId>                   native version behind the newest nuget.org release
//   changelog-range <android|ios> <after> <through> Microsoft's notes for (after, through], one per line
//   strip-verify <file>                             drop Sharpie's advisory [Verify(...)] attrs
//   normalize-usings <ApiDefinitions.cs>            drop `using Clarity;`, ensure `using UIKit;`

using System.Globalization;
using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using System.Xml.Linq;

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
        "last-published-native" => Print(await LastPublishedNative(Arg(1))),
        "changelog-range" => Print(await ChangelogRange(Arg(1), Arg(2), Arg(3))),
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
// Exit 3 so a caller can tell "upstream is down" from "the arguments were wrong". A bump
// that cannot read a source must stop: the note it would otherwise invent gets published
// once and then cannot be corrected.
catch (SourceUnavailableException ex)
{
    Console.Error.WriteLine($"ERROR: {ex.Message}");
    return 3;
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

static int Replace(string path, string pattern, string replacement, string what, RegexOptions options = RegexOptions.None)
{
    var (bom, _, text) = ReadFile(path);
    var updated = Regex.Replace(text, pattern, replacement, options);
    if (updated == text && !Regex.IsMatch(text, pattern, options))
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

// The note covers every native release since the binding that is actually on nuget.org,
// which is not the same as "since the previous commit". A bump can merge and never be
// published - Android 3.9.0.0 was merged and superseded by 3.10.0.0 before anyone ran
// publish-android - and the versions skipped that way have no package of their own, so
// nuget.org will never show their notes anywhere else. Anchoring to the published version
// is what keeps them from disappearing.
//
// Singleline matters: the note is multi-line from here on, and without it the *next* bump
// cannot match across the newlines and dies claiming <PackageReleaseNotes> is missing.
static int SetReleaseNote(string csproj, string note)
{
    if (note.AsSpan().IndexOfAny('<', '>', '&') >= 0)
        return Fail($"the note must not contain XML markup: {note}");

    // The note's own newlines take the file's line endings. Leaving them as LF inside a CRLF
    // csproj is what makes an editor "fix" the whole file later and bury the real change.
    var eol = ReadFile(csproj).Eol;
    var normalized = note.Replace("\r\n", "\n").Replace("\n", eol);

    return Replace(
        csproj,
        "(<PackageReleaseNotes>).*?(</PackageReleaseNotes>)",
        $"${{1}}{normalized.Replace("$", "$$")}${{2}}",
        "<PackageReleaseNotes>",
        RegexOptions.Singleline);
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

// The range is (after, through], never just `through`: binding versions get skipped - merged,
// superseded, published never - and a skipped version has no package of its own, so its
// upstream notes would exist nowhere on nuget.org at all.
//
// The version list comes from the release source itself rather than from the notes, so a
// release Microsoft has shipped but not yet written up is still enumerated and says so.
// Android 3.10.0 was exactly that for four days.
//
// Sources for the note text, in order of preference:
//   ios      microsoft/clarity-apps GitHub releases, then Microsoft Learn. The releases
//            carry per-version notes the moment the SDK ships, while Learn lags by days or
//            weeks - iOS 4.0.0 had release notes on GitHub while Learn still stopped at
//            3.5.4.
//   android  Microsoft Learn only. Those releases are iOS-only (all 51 of them), and
//            neither Maven Central nor the AAR carries notes.
//
// Every fetch either answers or throws. "Unreachable" and "nothing published" are different
// facts, and only one of them is safe to write into a package version that can never be
// edited again - so a source that cannot be read stops the bump instead of being guessed at.
static async Task<string> ChangelogRange(string platform, string after, string through)
{
    if (platform is not ("android" or "ios")) throw new UsageException($"unknown platform '{platform}'");

    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    http.DefaultRequestHeaders.UserAgent.ParseAdd("Kebechet.Maui.MicrosoftClarity-bump/1.0");

    // One releases request serves both the version list and the notes.
    var releases = platform == "ios" ? await Releases(http) : [];
    var released = platform == "ios" ? IosVersions(releases) : await AndroidVersions(http);
    var inRange = released
        .Where(x => CompareVersions(x, after) > 0 && CompareVersions(x, through) <= 0)
        .Order(Comparer<string>.Create(CompareVersions))
        .ToList();

    if (inRange.Count == 0)
        throw new SourceUnavailableException(
            $"upstream lists no {platform} release in ({after}, {through}] - the version list is incomplete, so the range cannot be described");

    var fromGitHub = GitHubNotes(releases);

    // Learn is only worth a request when GitHub left a gap; on Android it is the only source.
    var missing = inRange.Where(x => !fromGitHub.ContainsKey(x)).ToList();
    var fromLearn = missing.Count > 0 ? await LearnNotes(http, platform) : [];

    var lines = inRange.Select(version =>
    {
        var note = fromGitHub.GetValueOrDefault(version) ?? fromLearn.GetValueOrDefault(version);
        return note is null
            ? $"{version}: no upstream note published."
            : $"{version}: {Sanitize(note)}";
    });

    return string.Join("\n", lines);
}

// nuget.org, not the working tree, is what a consumer upgrades from, and the two diverge the
// moment a bump merges without being published. A 404 is the one legitimate "nothing
// published yet"; every other failure throws, because falling back to the csproj pin would
// silently recreate the bug this exists to prevent.
static async Task<string> LastPublishedNative(string packageId)
{
    using var http = new HttpClient { Timeout = TimeSpan.FromSeconds(30) };
    http.DefaultRequestHeaders.UserAgent.ParseAdd("Kebechet.Maui.MicrosoftClarity-bump/1.0");

    var url = $"https://api.nuget.org/v3-flatcontainer/{packageId.ToLowerInvariant()}/index.json";
    using var response = await Get(http, url, "nuget.org");
    if (response.StatusCode == HttpStatusCode.NotFound) return string.Empty;
    if (!response.IsSuccessStatusCode)
        throw new SourceUnavailableException($"nuget.org returned {(int)response.StatusCode} for {packageId}");

    using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());
    var published = json.RootElement.GetProperty("versions")
        .EnumerateArray()
        .Select(x => x.GetString() ?? string.Empty)
        .Where(x => x.Length > 0 && !x.Contains('-'))
        .ToList();

    if (published.Count == 0) return string.Empty;

    // Binding versions are <native>.<revision>, and nuget.org normalises a trailing ".0" away:
    // 3.10.0.0 comes back as 3.10.0 while 3.8.2.1 stays 3.8.2.1. Dropping only a fourth
    // component reads both correctly.
    var newest = published.Aggregate((a, b) => CompareVersions(a, b) >= 0 ? a : b);
    var parts = newest.Split('.');
    return parts.Length >= 4 ? string.Join('.', parts.Take(3)) : newest;
}

static async Task<HttpResponseMessage> Get(HttpClient http, string url, string source)
{
    try
    {
        return await http.GetAsync(url);
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
    {
        throw new SourceUnavailableException($"could not reach {source}: {ex.Message}");
    }
}

// Maven Central is the release list for Android; the AAR carries no notes, only versions.
static async Task<List<string>> AndroidVersions(HttpClient http)
{
    using var response = await Get(http, "https://repo1.maven.org/maven2/com/microsoft/clarity/clarity/maven-metadata.xml", "Maven Central");
    if (!response.IsSuccessStatusCode)
        throw new SourceUnavailableException($"Maven Central returned {(int)response.StatusCode} for com.microsoft.clarity:clarity");

    var metadata = XDocument.Parse(await response.Content.ReadAsStringAsync());
    return metadata.Descendants("version")
        .Select(x => x.Value.Trim())
        .Where(x => x.Length > 0 && !x.Contains('-'))
        .ToList();
}

static List<string> IosVersions(List<JsonElement> releases)
{
    return releases
        .Select(release => (release.TryGetProperty("tag_name", out var tag) ? tag.GetString() : null)?.TrimStart('v') ?? string.Empty)
        .Where(x => Regex.IsMatch(x, @"^\d+(\.\d+)*$"))
        .ToList();
}

// The result is written into <PackageReleaseNotes>, which set-release-note refuses to fill
// with markup rather than corrupt the csproj.
static string Sanitize(string value) =>
    Regex.Replace(value.Replace("&", "and").Replace("<", string.Empty).Replace(">", string.Empty), @"\s+", " ").Trim();

static async Task<List<JsonElement>> Releases(HttpClient http)
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

    HttpResponseMessage response;
    try
    {
        response = await http.SendAsync(request);
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
    {
        throw new SourceUnavailableException($"could not reach the microsoft/clarity-apps releases API: {ex.Message}");
    }

    using (response)
    {
        if (!response.IsSuccessStatusCode)
            throw new SourceUnavailableException($"the microsoft/clarity-apps releases API returned {(int)response.StatusCode}");

        try
        {
            using var json = JsonDocument.Parse(await response.Content.ReadAsStringAsync());

            // Clone: the elements outlive the document they were parsed from.
            return json.RootElement.EnumerateArray().Select(x => x.Clone()).ToList();
        }
        catch (JsonException ex)
        {
            throw new SourceUnavailableException($"the microsoft/clarity-apps releases API returned unreadable JSON: {ex.Message}");
        }
    }
}

static Dictionary<string, string> GitHubNotes(List<JsonElement> releases)
{
    var notes = new Dictionary<string, string>();
    foreach (var release in releases)
    {
        var tag = (release.TryGetProperty("tag_name", out var t) ? t.GetString() : null)?.TrimStart('v') ?? string.Empty;
        if (tag.Length == 0 || notes.ContainsKey(tag)) continue;

        var body = (release.TryGetProperty("body", out var b) ? b.GetString() : null) ?? string.Empty;
        var items = body.Split('\n')
            .Select(line => line.Trim())
            .Where(line => line.StartsWith("- ") || line.StartsWith("* "))
            .Select(line => line[2..].Replace("**", string.Empty).Trim())
            .Where(line => line.Length > 0 && !line.StartsWith("Full Changelog", StringComparison.OrdinalIgnoreCase))
            .Select(line => line.EndsWith('.') ? line : line + ".")
            .ToList();

        if (items.Count > 0) notes[tag] = string.Join(" ", items);
    }

    return notes;
}

static async Task<Dictionary<string, string>> LearnNotes(HttpClient http, string platform)
{
    var heading = platform == "ios" ? "iOS SDK Changelog" : "Android SDK Changelog";

    // Learn serves the page as static HTML, but only to browser-like user agents.
    using var request = new HttpRequestMessage(HttpMethod.Get, "https://learn.microsoft.com/en-us/clarity/mobile-sdk/sdk-changelog");
    request.Headers.UserAgent.Clear();
    request.Headers.UserAgent.ParseAdd("Mozilla/5.0");

    HttpResponseMessage response;
    try
    {
        response = await http.SendAsync(request);
    }
    catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
    {
        throw new SourceUnavailableException($"could not reach the Microsoft Learn changelog: {ex.Message}");
    }

    string html;
    using (response)
    {
        if (!response.IsSuccessStatusCode)
            throw new SourceUnavailableException($"the Microsoft Learn changelog returned {(int)response.StatusCode}");

        html = await response.Content.ReadAsStringAsync();
    }

    // Flatten to one text node per line, then walk: platform section -> version block. A
    // "[Tag]" line starts an item; every other line continues it, because Learn splits
    // sentences around inline <code> elements.
    var lines = Regex.Replace(html, "<[^>]*>", "\n")
        .Split('\n')
        .Select(line => WebUtility.HtmlDecode(line).Trim())
        .Where(line => line.Length > 0)
        .ToList();

    var notes = new Dictionary<string, string>();
    var items = new List<string>();
    var current = new StringBuilder();
    var version = string.Empty;
    var inSection = false;

    void FlushItem()
    {
        if (current.Length == 0) return;
        items.Add(Regex.Replace(current.ToString(), @"\s+", " ").Trim());
        current.Clear();
    }

    void FlushBlock()
    {
        FlushItem();
        if (version.Length > 0 && items.Count > 0 && !notes.ContainsKey(version))
            notes[version] = string.Join(" ", items);

        items.Clear();
        version = string.Empty;
    }

    foreach (var line in lines)
    {
        if (line.StartsWith(heading, StringComparison.Ordinal)) { FlushBlock(); inSection = true; continue; }
        if (inSection && line.EndsWith("SDK Changelog", StringComparison.Ordinal)) { FlushBlock(); inSection = false; }
        if (!inSection) continue;

        var header = Regex.Match(line, @"^(\d+(?:\.\d+)+) \(");
        if (header.Success) { FlushBlock(); version = header.Groups[1].Value; continue; }
        if (version.Length == 0) continue;

        if (Regex.IsMatch(line, @"^\[[A-Za-z ]+\]$")) { FlushItem(); current.Append(line).Append(' '); }
        else current.Append(current.Length > 0 && !current.ToString().EndsWith(' ') ? " " : string.Empty).Append(line);
    }

    FlushBlock();
    return notes;
}

file sealed class UsageException(string message) : Exception(message);

// An upstream source that cannot be read, as opposed to one that answers "nothing here".
// Only the second is safe to describe in a package version that can never be edited again.
file sealed class SourceUnavailableException(string message) : Exception(message);
