$ErrorActionPreference = 'Continue'
$cs = @'
using System;
using System.IO;
using System.Runtime.InteropServices.WindowsRuntime;
using Windows.Media.Control;
using Windows.Storage.Streams;

public static class SmtcArt {
  public static string DumpCurrent() {
    var mgr = GlobalSystemMediaTransportControlsSessionManager.RequestAsync().GetAwaiter().GetResult();
    var s = mgr.GetCurrentSession();
    if (s == null) return "no-session";
    var p = s.TryGetMediaPropertiesAsync().GetAwaiter().GetResult();
    if (p.Thumbnail == null) return "no-thumbnail";
    var st = p.Thumbnail.OpenReadAsync().GetAwaiter().GetResult();
    var ms = new MemoryStream();
    st.AsStreamForRead().CopyTo(ms);
    var bytes = ms.ToArray();
    if (bytes.Length < 8) return "empty:" + bytes.Length;
    var ext = (bytes[0] == 0x89 && bytes[1] == 0x50) ? "png" : "jpg";
    var path = Path.Combine(Path.GetTempPath(), "media-widget-cover." + ext);
    File.WriteAllBytes(path, bytes);
    return path + " (" + bytes.Length + ")";
  }
}
'@
try {
  Add-Type -TypeDefinition $cs -ReferencedAssemblies 'System.Runtime.WindowsRuntime.dll', 'C:\Windows\System32\WinMetadata\Windows.winmd' -Language CSharp -ErrorAction Stop
  Write-Output 'COMPILE OK'
  Write-Output ('RESULT: ' + [SmtcArt]::DumpCurrent())
} catch {
  Write-Output ('COMPILE FAILED: ' + $_.Exception.Message)
}
