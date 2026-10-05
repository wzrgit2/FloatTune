using System;
using System.IO;
using System.Threading.Tasks;
using Windows.Media.Control;
using Windows.Storage.Streams;

namespace SmtcArt
{
    /// <summary>
    /// Reads the current Windows media session's cover art and writes it to a temp file.
    /// Prints the file path on stdout, or "none" when there is nothing to read.
    /// PowerShell 5.1 cannot read WinRT streams, which is why this helper exists.
    /// </summary>
    internal static class Program
    {
        private static void Diag(string msg)
        {
            if (Environment.GetEnvironmentVariable("SMTCART_DEBUG") == "1")
                Console.Error.WriteLine("SmtcArt: " + msg);
        }

        private static async Task<int> Main(string[] args)
        {
            try
            {
                var mgr = await GlobalSystemMediaTransportControlsSessionManager.RequestAsync();
                if (mgr == null) { Diag("no session manager"); Console.WriteLine("none"); return 0; }

                var session = mgr.GetCurrentSession();
                if (session == null) { Diag("no current session"); Console.WriteLine("none"); return 0; }
                Diag("session app=" + session.SourceAppUserModelId);

                var props = await session.TryGetMediaPropertiesAsync();
                if (props == null) { Diag("no media properties"); Console.WriteLine("none"); return 0; }
                Diag("title=" + props.Title);

                if (props.Thumbnail == null) { Diag("thumbnail is null"); Console.WriteLine("none"); return 0; }

                using (var stream = await props.Thumbnail.OpenReadAsync())
                using (var reader = new DataReader(stream.GetInputStreamAt(0)))
                using (var ms = new MemoryStream())
                {
                    const uint chunk = 64 * 1024;
                    while (true)
                    {
                        uint n = await reader.LoadAsync(chunk);
                        if (n == 0) break;
                        var buf = new byte[n];
                        reader.ReadBytes(buf);
                        ms.Write(buf, 0, (int)n);
                    }

                    var bytes = ms.ToArray();
                    Diag("read " + bytes.Length + " bytes");
                    if (bytes.Length < 8) { Console.WriteLine("none"); return 0; }

                    string ext = (bytes[0] == 0x89 && bytes[1] == 0x50) ? "png" : "jpg";
                    string path = Path.Combine(Path.GetTempPath(), "media-widget-cover." + ext);
                    File.WriteAllBytes(path, bytes);
                    Console.WriteLine(path);
                    return 0;
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine("SmtcArt: " + ex.GetType().Name + ": " + ex.Message);
                Console.WriteLine("none");
                return 1;
            }
        }
    }
}
