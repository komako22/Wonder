using System.Net;
using System.Globalization;
using System.Text;
using System.Text.Json;
using GlassTranslate.Windows.Models;

namespace GlassTranslate.Windows.Services;

public sealed class TranslationClient
{
    private static readonly HttpClient Http = new() { Timeout = TimeSpan.FromSeconds(30) };

    public async Task<string> TranslateAsync(string source, SettingsStore settings, CancellationToken cancellationToken)
    {
        return await TranslateWithMyMemoryAsync(source, settings, cancellationToken);
    }

    private static async Task<string> TranslateWithMyMemoryAsync(
        string source,
        SettingsStore settings,
        CancellationToken cancellationToken)
    {
        var sourceLanguage = DetectLanguageCode(source);
        var targetLanguage = TargetLanguageCode(settings.TargetLanguage, sourceLanguage);
        if (sourceLanguage == targetLanguage) return source;

        var translations = new List<string>();
        foreach (var chunk in Utf8Chunks(source, 450))
        {
            var url = new StringBuilder("https://api.mymemory.translated.net/get?q=")
                .Append(Uri.EscapeDataString(chunk))
                .Append("&langpair=")
                .Append(Uri.EscapeDataString($"{sourceLanguage}|{targetLanguage}"))
                .Append("&mt=1");
            if (!string.IsNullOrWhiteSpace(settings.FreeServiceEmail))
                url.Append("&de=").Append(Uri.EscapeDataString(settings.FreeServiceEmail.Trim()));

            using var request = new HttpRequestMessage(HttpMethod.Get, url.ToString());
            request.Headers.UserAgent.ParseAdd("Wonder/0.3");
            using var response = await Http.SendAsync(request, cancellationToken);
            var body = await response.Content.ReadAsStringAsync(cancellationToken);
            if (!response.IsSuccessStatusCode)
                throw new InvalidOperationException($"免费翻译服务请求失败（{(int)response.StatusCode}）。");
            try
            {
                using var document = JsonDocument.Parse(body);
                var root = document.RootElement;
                if (root.TryGetProperty("quotaFinished", out var quota) && quota.ValueKind == JsonValueKind.True)
                    throw new InvalidOperationException("今日免费额度已用完，可在设置中填写邮箱提升额度。");
                if (root.TryGetProperty("responseStatus", out var status) && status.TryGetInt32(out var code) && code >= 400)
                {
                    var details = root.TryGetProperty("responseDetails", out var detail) ? detail.GetString() : "请求被拒绝";
                    throw new InvalidOperationException($"免费翻译服务：{details}");
                }
                var translated = root.GetProperty("responseData").GetProperty("translatedText").GetString()?.Trim();
                if (string.IsNullOrWhiteSpace(translated)) throw new InvalidOperationException("免费翻译服务返回了空结果。");
                translations.Add(WebUtility.HtmlDecode(translated));
            }
            catch (JsonException)
            {
                throw new InvalidOperationException("免费翻译服务返回了无法识别的数据。");
            }
        }
        return string.Join(source.Contains('\n') ? "\n" : " ", translations);
    }

    internal static string DetectLanguageCode(string text)
    {
        foreach (var character in text)
        {
            if (character is >= '\u3040' and <= '\u30ff') return "ja";
            if (character is >= '\uac00' and <= '\ud7af') return "ko";
            if (character is >= '\u0400' and <= '\u04ff') return "ru";
        }
        return text.Any(character => character is >= '\u3400' and <= '\u9fff') ? "zh-CN" : "en";
    }

    internal static string TargetLanguageCode(TargetLanguage target, string source) => target switch
    {
        TargetLanguage.Automatic => source.StartsWith("zh", StringComparison.OrdinalIgnoreCase) ? "en" : "zh-CN",
        TargetLanguage.SimplifiedChinese => "zh-CN",
        TargetLanguage.English => "en",
        TargetLanguage.Japanese => "ja",
        TargetLanguage.Korean => "ko",
        TargetLanguage.French => "fr",
        TargetLanguage.German => "de",
        TargetLanguage.Spanish => "es",
        _ => "zh-CN"
    };

    internal static IReadOnlyList<string> Utf8Chunks(string text, int maximumBytes)
    {
        if (Encoding.UTF8.GetByteCount(text) <= maximumBytes) return [text];
        var chunks = new List<string>();
        var current = new StringBuilder();
        var currentBytes = 0;
        var elements = StringInfo.GetTextElementEnumerator(text);
        while (elements.MoveNext())
        {
            var value = elements.GetTextElement();
            var bytes = Encoding.UTF8.GetByteCount(value);
            if (currentBytes + bytes > maximumBytes && current.Length > 0)
            {
                chunks.Add(current.ToString());
                current.Clear();
                currentBytes = 0;
            }
            current.Append(value);
            currentBytes += bytes;
        }
        if (current.Length > 0) chunks.Add(current.ToString());
        return chunks;
    }

}
